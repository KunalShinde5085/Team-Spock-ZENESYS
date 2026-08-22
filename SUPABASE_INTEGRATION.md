# Connecting MECHFLOW to Supabase

## What changed

- **Database**: SQLite → Supabase Postgres. Run `supabase_schema.sql` once
  (SQL Editor in the dashboard, or `psql -f supabase_schema.sql "$DATABASE_URL"`).
- **Auth**: the app's own JWT login/password-hash code → **Supabase Auth**.
  `app/security.py` now verifies the JWT Supabase issues and wraps the
  `supabase-py` client for sign-up/sign-in; `app/routers/auth.py` calls
  Supabase Auth instead of hashing passwords itself.
- **Users**: `users` table → `profiles` table (`app/models.py`'s `User`
  class now maps to it). `id` is a `uuid` that's identical to the matching
  `auth.users.id`, not an autoincrementing int. A Postgres trigger
  (`handle_new_user`, in the SQL file) creates the `profiles` row
  automatically the moment someone signs up — the FastAPI backend never
  inserts into `profiles` itself.
- Every "who did this" column (`assigned_to_id`, `created_by_id`,
  `performed_by_id`, `acknowledged_by_id`, `resolved_by_id`) is now a `uuid`
  instead of an `int`, in `models.py` and `schemas.py`.

Business logic — the work-order status graph, the atomic
maintenance/stock-deduction transaction, soft-delete on user deactivation,
`ON DELETE RESTRICT` on spare parts with history — is unchanged.

## Architecture: who talks to Postgres, and how RLS fits in

This app keeps the FastAPI backend as the only thing that talks to the
database (React frontend → FastAPI → Postgres), rather than moving to
"React talks to Supabase directly via `supabase-js`". That means:

- `DATABASE_URL` in `.env` connects SQLAlchemy straight to Supabase's Postgres
  (via the pooler) as the `postgres` role. That role **owns** the tables, so
  it bypasses RLS by default — the backend keeps doing its own role checks
  (`require_admin`, `require_supervisor_or_admin` in `dependencies.py`),
  same as before.
- **RLS is still fully enabled and `FORCE`d on every table** in
  `supabase_schema.sql`. It's not decorative: it's what protects the data
  the moment *anything else* touches this database with a non-owner
  role — Supabase Realtime subscriptions (if you turn them on), the
  Supabase dashboard's table editor used by a teammate with the `anon`/
  `authenticated` role, a future direct-from-frontend Supabase client, or
  simply a mistake in a different service that gets the anon key instead of
  the service key. Two layers of enforcement (app-level + RLS) is the
  standard, recommended Supabase pattern for exactly this reason — it is
  not redundant.
- `SUPABASE_SERVICE_ROLE_KEY` is used only server-side, for two admin
  operations that must run as Supabase Auth's admin: creating seed users
  (`app/seed.py`) and resetting a user's password / banning a deactivated
  user (`app/routers/users.py`). It also bypasses RLS — never let it reach
  the browser.
- `SUPABASE_ANON_KEY` is used server-side too, only to call
  `auth.sign_up` / `auth.sign_in_with_password` (that's what the anon key
  is for — it still goes through Supabase Auth's own password rules and
  rate limits, it does not grant table access by itself).

If you'd rather move to option B — frontend talks to Supabase directly with
`supabase-js`, and RLS becomes the *only* authorization layer, no FastAPI
in the read/write path — the same `supabase_schema.sql` already supports
that: swap `DATABASE_URL`'s role for one that is **not** the table owner
(Supabase's default `authenticated`/`anon` roles already aren't), and the
policies in the file take over completely. `FORCE ROW LEVEL SECURITY` was
written with that migration path in mind, in case you go that direction
later.

## Setup steps

1. **Create the Supabase project**, then in Project Settings → API note the
   project URL, `anon` key, `service_role` key, and JWT secret.
2. **Run the schema**: paste `supabase_schema.sql` into the SQL Editor and
   run it (or `psql -f supabase_schema.sql "$DATABASE_URL"`).
3. **Fill in `.env`** (see the updated `.env.example`): `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`,
   and `DATABASE_URL` (Project Settings → Database → Connection string,
   use the **pooler** connection, "Session" or "Transaction" mode).
4. **Install deps**: `pip install -r requirements.txt` (adds `supabase` and
   `psycopg[binary]`; drops `passlib`/`bcrypt`, no longer needed).
5. **Run it**: `./run.sh` (or `uvicorn app.main:app --reload`). On first
   startup against an empty database it seeds four demo accounts exactly as
   before, except now via `supabase.auth.admin.create_user(...)` — check the
   Supabase dashboard's Authentication tab and you'll see them there too.
6. Frontend `.env` is unchanged: `VITE_API_BASE_URL=http://localhost:8000/api/v1`.
   `POST /auth/login` still takes `username`/`password` form fields for
   OAuth2-form compatibility — put the user's **email** in the `username`
   field, since Supabase Auth signs in with email + password.

## Things worth checking after you deploy

- If you enable **Confirm email** in Supabase Auth settings, `POST
  /auth/register` will succeed but the user won't be able to log in until
  they click the confirmation link — decide whether that's the behavior you
  want for this internal tool, or turn email confirmation off.
- The RLS policies assume every column value they reference exists — e.g. a
  `profiles` row must exist for `auth.uid()` before any policy that calls
  `is_active_user()`/`is_admin()` can pass. That's guaranteed for normal
  sign-ups (the trigger runs first), but if you ever create an
  `auth.users` row through a path that skips the trigger, that user will be
  locked out of everything until a `profiles` row exists for them.
