# Supabase setup — MachinIQ / Zenesys

This frontend now talks to Supabase **directly** (no separate backend server)
using the Supabase JS client and your public **anon key**, protected by
Row Level Security (RLS). This is the standard, fastest pattern for a
hackathon build. Every file in `src/api/*.ts` keeps its original exported
function signatures, so nothing in `src/hooks` or `src/pages` had to change.

## 1. Create the Supabase project

1. Go to https://supabase.com/dashboard -> New project.
2. Once it's created, go to **Project Settings -> Data API**. You'll need:
   - **Project URL** (looks like `https://xxxxxxxxxxxx.supabase.co`)
   - **anon public** key (under Project API keys)

## 2. Create the tables

1. In the Supabase dashboard, open **SQL Editor -> New query**.
2. Paste the contents of `supabase/schema.sql` (in this repo) and run it.
   This creates all tables (`products`, `customers`, `orders`,
   `order_status_history`, `inventory_transactions`, `production`, `alerts`,
   `sales_history`, `forecasts`, `recommendations`, `suppliers`,
   `supplier_products`) with RLS enabled and a permissive "allow all" policy
   so the hackathon build works immediately.
3. Optional: run `supabase/seed.sql` afterwards to load a few demo rows so
   the dashboard isn't empty on first load.

## 3. Put your credentials here — this is the important part

Open the **`.env`** file at the project root (already created for you) and
replace the placeholders:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY
```

- `.env` is already in `.gitignore` — it will not be committed.
- `.env.example` is the template teammates copy from (`cp .env.example .env`).
- These are read at build time by Vite via `import.meta.env.VITE_SUPABASE_URL`
  and `import.meta.env.VITE_SUPABASE_ANON_KEY` in `src/lib/supabaseClient.ts`.
- **Only use the `anon` public key here — never the `service_role` key.**
  The anon key is safe to ship in a frontend bundle because RLS is what
  actually controls access; the service_role key bypasses RLS entirely and
  must never reach the browser.

No other file needs credentials. Every `src/api/*.ts` file imports the
already-configured client from `src/lib/supabaseClient.ts`.

## 4. Install and run

```bash
npm install
npm run dev
```

## What changed in the code

| File | What it does now |
|---|---|
| `src/lib/supabaseClient.ts` | Creates the Supabase client from `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`. |
| `src/lib/mappers.ts` | Converts snake_case DB rows into the camelCase types your components already expect (`Product`, `Order`, `OrderDetail`, etc.), and computes derived fields like `availableStock`, `stockStatus`, and order `risk` that used to live on a backend. |
| `src/api/*.ts` | Each file (`products.ts`, `orders.ts`, `inventory.ts`, `production.ts`, `alerts.ts`, `forecasts.ts`, `recommendations.ts`, `dashboard.ts`, `analytics.ts`) now queries Supabase directly instead of calling `/api/...` over axios. **Function names and signatures are unchanged**, so `src/hooks/*` and `src/pages/*` needed zero edits. |
| `src/api/client.ts` | Removed (was the axios instance; no longer needed). |
| `src/pages/Analytics.tsx` | Now calls `analyticsApi.get()` (Supabase-backed) instead of `GET /api/analytics`. |
| `src/pages/Settings.tsx` | Now displays the Supabase project URL instead of the old API base URL. |
| `package.json` | Added `@supabase/supabase-js`, removed `axios`. |
| `.env` / `.env.example` | Now hold `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` instead of `VITE_API_BASE_URL`. |

## Known simplifications (fine for a hackathon, call out before production)

- **RLS policy is "allow all."** Anyone with your anon key can read/write
  every table. Before sharing this beyond the hackathon, replace the
  `"allow all - hackathon"` policy in `supabase/schema.sql` with real
  per-role policies (see the Access Matrix / role table you already had
  in your planning doc — that maps directly to RLS policies).
- **Order creation isn't atomic.** Creating an order does 3 sequential
  writes (insert order → insert status history → update reserved stock,
  plus a conditional alert insert) rather than one DB transaction. For a
  hackathon this is fine; for production, move this into a Postgres
  function and call it with `supabase.rpc(...)`.
- **Forecasts are precomputed, not calculated live.** The `forecasts` table
  stores a `series` (jsonb) and `summary` (jsonb) per product/horizon. You
  (or a scheduled job / Edge Function) are expected to populate these —
  the frontend just reads them. This matches how the original spec doc
  described the forecasting engine as a separate concern from the CRUD API.
- **Dashboard/analytics aggregates are computed client-side** by fetching
  raw rows and reducing them in JS, not via SQL `GROUP BY`/RPC. Fine at
  hackathon data volumes; move to Postgres views or RPC functions if the
  tables grow large.
