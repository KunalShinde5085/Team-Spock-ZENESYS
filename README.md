# MECHFLOW Operations API

A backend for a mechanical/factory operations dashboard: machines, work
orders, preventive & corrective maintenance, spare-parts inventory, and
real-time alerts — built to sit behind the MECHFLOW React/Vite frontend
(FastAPI + SQLAlchemy + SQLite, JWT auth).

> Your uploaded `src/` folder came through empty, so this backend wasn't
> built against actual frontend components — it's designed from the
> project's name, title ("MECHFLOW | Factory Operations"), and the
> Recharts dependency, covering the data a factory-ops dashboard needs.
> Endpoints and field names are easy to adjust once I can see your
> actual UI/API calls.

## Domain model

| Entity | Purpose |
|---|---|
| **User** | Login accounts. Roles: `admin`, `supervisor`, `technician`. |
| **Department** | Organizational grouping for machines (e.g. Machining, Assembly). |
| **Machine** | A piece of equipment: status, criticality, maintenance dates. |
| **WorkOrder** | A task against a machine: repair, inspection, PM, emergency — with a status workflow. |
| **MaintenanceRecord** | What was actually done to a machine, optionally linked to a work order, with parts consumed and downtime logged. |
| **SparePart** | Inventory item with stock level and reorder threshold. |
| **PartUsage** | Join row: which parts (and how many) a maintenance record consumed. |
| **Alert** | Machine-level alert (sensor, system, or manual) with acknowledge/resolve workflow. |

## Getting started

```bash
cd mechflow-backend
./run.sh
```

`run.sh` creates a virtualenv, installs `requirements.txt`, copies
`.env.example` to `.env` on first run, and starts the API on
**http://localhost:8000**.

Interactive API docs: **http://localhost:8000/docs**

On first startup (empty database), the app auto-creates all tables and
seeds demo data — a few machines, work orders, parts, alerts, and four
login accounts — so the dashboard has something to show immediately:

| Username | Password | Role |
|---|---|---|
| `admin` | `ChangeMe123!` | admin |
| `jrivera` | `Supervisor123!` | supervisor |
| `dkowalski` | `Technician123!` | technician |
| `mchen` | `Technician123!` | technician |

**Change these before deploying anywhere real** — set `SEED_ADMIN_PASSWORD`
in `.env`, or just update the passwords via the API afterward. Set
`SEED_DEMO_DATA=false` in `.env` to skip seeding entirely and start empty.

## Authentication

JWT bearer tokens, standard OAuth2 password flow:

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=ChangeMe123!"
# -> {"access_token": "...", "token_type": "bearer"}

curl http://localhost:8000/api/v1/machines \
  -H "Authorization: Bearer <token>"
```

New accounts via `POST /api/v1/auth/register` are always created as
`technician` (self-registration can't grant elevated roles). An admin
promotes someone via `PATCH /api/v1/users/{id}` with `{"role": "supervisor"}`.

Role checks:
- **Read** endpoints (list/get machines, work orders, alerts, inventory,
  dashboard) — any authenticated, active user.
- **Write** endpoints for machines, work orders, and inventory — `supervisor`
  or `admin`.
- **User management** (`/users/*`) — `admin` only.
- Logging maintenance and handling alerts (create/acknowledge/resolve) —
  any authenticated user, since that's normally the technician on the floor.

## Key endpoints

All routes are under `/api/v1`.

```
POST   /auth/register              POST /auth/login              GET /auth/me

GET    /machines                   POST   /machines               GET/PATCH/DELETE /machines/{id}
GET    /machines/{id}/work-orders  GET    /machines/{id}/maintenance-history

GET    /work-orders                POST   /work-orders            GET/PATCH/DELETE /work-orders/{id}
PATCH  /work-orders/{id}/status    (enforces a valid status-transition graph)

GET    /maintenance                POST   /maintenance             GET /maintenance/{id}
                                    (consumes spare-part stock atomically; 400 if insufficient)

GET    /inventory/parts            POST   /inventory/parts        GET/PATCH/DELETE /inventory/parts/{id}
GET    /inventory/parts/low-stock  POST   /inventory/parts/{id}/restock

GET    /alerts                     POST   /alerts
POST   /alerts/{id}/acknowledge    POST   /alerts/{id}/resolve

GET    /departments                POST/PATCH/DELETE /departments/{id}
GET    /users                      PATCH/DELETE /users/{id}          (admin only)

GET    /dashboard/summary          -> counts + breakdowns for cards/pie charts
GET    /dashboard/downtime-trend   -> daily downtime minutes for the last N days (line/bar chart)
```

Every list endpoint supports `skip`/`limit` pagination and relevant filters
(e.g. `GET /work-orders?status=open&priority=critical`).

## Business rules worth knowing

- **Work order status** follows a fixed graph (`open → assigned → in_progress
  → completed`, with `on_hold`/`cancelled` branches). Invalid transitions
  return `400`. Completing a work order auto-fills `completed_at` and, if not
  supplied, `actual_hours` from `started_at`.
- **Maintenance + parts** is one transaction: stock is checked for every part
  *before* any row is written, so a record either fully applies or fails
  cleanly with a clear "not enough stock" message — never a partial
  deduction. Recording maintenance against a work order auto-completes that
  work order and updates `machine.last_maintenance_at`.
- **Deactivating a user** is a soft delete (`is_active=False`), not a hard
  delete, so historical work orders and maintenance records keep valid
  references to who did what.
- **Spare parts** used in any maintenance history can't be hard-deleted, to
  keep that history intact.

## Connecting the React frontend

Add to the frontend's `.env`:
```
VITE_API_BASE_URL=http://localhost:8000/api/v1
```

CORS is open to `http://localhost:5173` (Vite's default dev port) out of
the box — add any other origins to `CORS_ORIGINS` in `.env`.

## Project layout

```
app/
  main.py          FastAPI app, CORS, router registration, startup/seed
  config.py        Settings from environment variables
  database.py      SQLAlchemy engine/session
  models.py        ORM models + enums
  schemas.py       Pydantic request/response models
  security.py      Password hashing, JWT encode/decode
  dependencies.py  get_current_user / role-check dependencies
  seed.py          Demo data (runs once, only against an empty DB)
  routers/         One file per resource (auth, users, machines, work_orders,
                    maintenance, inventory, alerts, departments, dashboard)
```

## Notes on this environment

This sandbox has no network access, so the exact dependency versions in
`requirements.txt` (pinned to what was current and mutually compatible as of
early 2026) could not be `pip install`ed and run here to smoke-test end to
end — every file was written and manually re-checked line-by-line against
the FastAPI/SQLAlchemy 2.0/Pydantic v2 APIs instead. If anything doesn't
import cleanly on your machine, tell me the traceback and I'll fix it
immediately.

`bcrypt` is pinned to `4.0.1` deliberately: newer `bcrypt` 4.1+ removes an
attribute `passlib` 1.7.4 reads on startup, which throws a warning (and on
some versions an error) the first time you hash a password. This is a
known, common gotcha — pinning avoids it.
