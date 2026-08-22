# MechFlow — Demand Forecasting & Order Fulfillment Platform

Enterprise frontend for a mechanical parts manufacturer: orders, inventory,
production, demand forecasting, recommendations, alerts, and analytics.

## 1. Install

```bash
npm install
```

## 2. Point the app at your backend — WHERE to put the API URL

Open the **`.env`** file in the project root (already created for you):

```
VITE_API_BASE_URL=http://localhost:3000/api
```

Change this one line to wherever your backend actually runs, e.g.
`https://api.yourcompany.com/api`. Nothing else needs to change — every
request in the app goes through this single value.

- Never hardcode URLs inside components. All requests flow through
  `src/api/client.ts`, which reads `VITE_API_BASE_URL`.
- After editing `.env`, restart `npm run dev` (Vite only reads `.env` at
  startup).
- For different environments, copy `.env` to `.env.production` /
  `.env.staging` with the right URL — Vite picks the right one based on
  the build mode.

## 3. Run

```bash
npm run dev
```

Opens at `http://localhost:5173`. The app expects a REST backend at the
`VITE_API_BASE_URL` you set above. Until that backend exists, every page
will correctly show its **loading skeleton** and then an **error / retry**
state — that's expected, not a bug. Wire up the endpoints below one at a
time and each page will start rendering real data automatically.

## 4. Backend endpoints the frontend expects

All defined in `src/api/*.ts` — change the path strings there if your
backend uses different routes; nothing elsewhere needs to change.

```
GET    /dashboard/kpis
GET    /dashboard/fulfillment-breakdown
GET    /dashboard/inventory-risk-breakdown
GET    /dashboard/demand-vs-inventory

GET    /orders?search=&status=&priority=&customerId=&productId=&dateFrom=&dateTo=&page=&pageSize=
GET    /orders/:id
POST   /orders
PATCH  /orders/:id
DELETE /orders/:id

GET    /products?search=
GET    /products/:id

GET    /inventory?search=&category=&warehouse=&stockStatus=
GET    /inventory/:id
PATCH  /inventory/:id

GET    /production?search=&status=&dateFrom=&dateTo=
GET    /production/:id
POST   /production

GET    /forecasts?horizon=
GET    /forecasts/:productId?horizon=

GET    /recommendations?status=
PATCH  /recommendations/:id

GET    /alerts?severity=&status=
PATCH  /alerts/:id

GET    /analytics?dateFrom=&dateTo=
```

Response shapes match the TypeScript interfaces in `src/types/index.ts`
(`Order`, `OrderDetail`, `Product`, `InventoryDetail`, `ProductionRecord`,
`Forecast`, `Recommendation`, `Alert`, `DashboardKpis`, etc.) — treat that
file as the API contract.

## 5. Build for production

```bash
npm run build
```

Output goes to `dist/`. Set `VITE_API_BASE_URL` for the target environment
before building (env vars are baked in at build time, not runtime).

## Project structure

```
src/
├── api/            # one file per resource; client.ts holds the base URL + axios instance
├── components/
│   ├── layout/      # Sidebar, Header, AppLayout
│   ├── common/      # Badge, KpiCard, EmptyState, ErrorState, Skeleton, ConfirmModal, PageHeader
├── pages/           # one component per route
├── hooks/           # React Query hooks wrapping each api/ module
├── types/           # shared TS interfaces — the API contract
└── utils/           # formatters (currency, date, relative time)
```

## Notes

- Every list/detail page implements all 5 required UI states: loading
  (skeleton), empty, error (with retry), success, and real data — nothing
  renders a blank screen.
- Deleting an order requires confirmation via `ConfirmModal`.
- No business data is hardcoded — every page fetches through React Query.
- Sidebar collapses into a drawer below the `lg` breakpoint; tables scroll
  horizontally on small screens.
