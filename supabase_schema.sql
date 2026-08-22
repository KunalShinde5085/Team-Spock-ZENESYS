-- ============================================================================
-- MECHFLOW — Supabase schema, run once in the SQL Editor (or via the CLI:
-- `supabase db push` / `psql ... -f supabase_schema.sql`) against a fresh
-- project. Idempotent-ish: safe to re-run (uses IF NOT EXISTS / OR REPLACE
-- / DROP POLICY IF EXISTS everywhere), but it does NOT drop your data.
--
-- Order matters: enums -> profiles (+ auth trigger) -> domain tables ->
-- helper functions -> RLS. Read the "RLS gotchas" comment block near the
-- bottom before you assume this is "done" — it explains the four mistakes
-- that make RLS silently not protect anything, and how this script avoids
-- each one.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Extensions (Supabase projects already have these, but no harm asserting)
-- ----------------------------------------------------------------------------
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. Enum types (mirrors app/models.py exactly)
-- ----------------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('admin', 'supervisor', 'technician');
exception when duplicate_object then null; end $$;

do $$ begin
  create type machine_status as enum ('operational', 'idle', 'maintenance', 'down', 'decommissioned');
exception when duplicate_object then null; end $$;

do $$ begin
  create type criticality as enum ('low', 'medium', 'high');
exception when duplicate_object then null; end $$;

do $$ begin
  create type work_order_type as enum ('preventive', 'corrective', 'inspection', 'emergency');
exception when duplicate_object then null; end $$;

do $$ begin
  create type work_order_priority as enum ('low', 'medium', 'high', 'critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type work_order_status as enum ('open', 'assigned', 'in_progress', 'on_hold', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type maintenance_type as enum ('preventive', 'corrective', 'predictive', 'inspection');
exception when duplicate_object then null; end $$;

do $$ begin
  create type alert_severity as enum ('info', 'warning', 'critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type alert_status as enum ('active', 'acknowledged', 'resolved');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- 2. profiles — app-facing user row, 1:1 with auth.users, same primary key.
--    This is what every other table's "who did this" columns reference.
--    Credentials/password/email-verification stay in auth.users; this table
--    only carries what the app needs (username, role, active flag).
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null unique,
  email       text not null unique,
  full_name   text not null,
  role        user_role not null default 'technician',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Auto-create a profile row whenever someone signs up through Supabase Auth.
-- SECURITY DEFINER + a pinned search_path so it runs as the (trusted) owner
-- regardless of who's inserting into auth.users, and can't be tricked by a
-- hostile search_path. New accounts always land as 'technician' — matches
-- the app's existing rule that self-registration can never grant elevated
-- roles; only an admin can promote someone afterwards.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email, full_name, role, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email),
    'technician',
    true
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Block someone from PATCHing their own row to grant themselves a higher
-- role or flip is_active back on after being deactivated. Admins (checked
-- via the SECURITY DEFINER helper below, so this doesn't recurse into RLS
-- on profiles) are exempt.
create or replace function public.prevent_self_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id
     and not public.is_admin()
     and (new.role is distinct from old.role or new.is_active is distinct from old.is_active) then
    raise exception 'Only an admin can change role or is_active';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_privilege_escalation on public.profiles;
create trigger trg_prevent_self_privilege_escalation
  before update on public.profiles
  for each row execute function public.prevent_self_privilege_escalation();

-- ----------------------------------------------------------------------------
-- 3. Domain tables (bigint identity PKs, same shape as app/models.py;
--    every "who" column is uuid -> profiles(id) instead of the old int ->
--    users(id)).
-- ----------------------------------------------------------------------------
create table if not exists public.departments (
  id         bigint generated by default as identity primary key,
  name       text not null unique,
  location   text
);

create table if not exists public.machines (
  id                    bigint generated by default as identity primary key,
  name                  text not null,
  code                  text not null unique,
  machine_type          text,
  manufacturer          text,
  model_number          text,
  serial_number         text,
  location              text,
  status                machine_status not null default 'operational',
  criticality           criticality not null default 'medium',
  department_id         bigint references public.departments(id) on delete set null,
  installed_at          timestamptz,
  last_maintenance_at   timestamptz,
  next_maintenance_due  timestamptz,
  notes                 text,
  created_at            timestamptz not null default now()
);
create index if not exists idx_machines_department_id on public.machines(department_id);
create index if not exists idx_machines_status on public.machines(status);

create table if not exists public.work_orders (
  id               bigint generated by default as identity primary key,
  machine_id       bigint not null references public.machines(id) on delete cascade,
  title            text not null,
  description      text,
  wo_type          work_order_type not null default 'corrective',
  priority         work_order_priority not null default 'medium',
  status           work_order_status not null default 'open',
  assigned_to_id   uuid references public.profiles(id) on delete set null,
  created_by_id    uuid not null references public.profiles(id) on delete restrict,
  created_at       timestamptz not null default now(),
  due_date         timestamptz,
  started_at       timestamptz,
  completed_at     timestamptz,
  estimated_hours  double precision,
  actual_hours     double precision
);
create index if not exists idx_work_orders_machine_id on public.work_orders(machine_id);
create index if not exists idx_work_orders_assigned_to_id on public.work_orders(assigned_to_id);
create index if not exists idx_work_orders_status on public.work_orders(status);
create index if not exists idx_work_orders_priority on public.work_orders(priority);

create table if not exists public.maintenance_records (
  id                 bigint generated by default as identity primary key,
  machine_id         bigint not null references public.machines(id) on delete cascade,
  work_order_id      bigint unique references public.work_orders(id) on delete set null,
  performed_by_id    uuid not null references public.profiles(id) on delete restrict,
  maintenance_type   maintenance_type not null default 'corrective',
  description        text,
  performed_at       timestamptz not null default now(),
  downtime_minutes   integer not null default 0,
  cost               double precision not null default 0,
  created_at         timestamptz not null default now()
);
create index if not exists idx_maintenance_records_machine_id on public.maintenance_records(machine_id);
create index if not exists idx_maintenance_records_performed_by_id on public.maintenance_records(performed_by_id);

create table if not exists public.spare_parts (
  id                 bigint generated by default as identity primary key,
  name               text not null,
  part_number        text not null unique,
  category           text,
  quantity_in_stock  integer not null default 0,
  reorder_level      integer not null default 5,
  unit_cost          double precision not null default 0,
  supplier           text,
  storage_location   text,
  created_at         timestamptz not null default now()
);

create table if not exists public.part_usages (
  id                       bigint generated by default as identity primary key,
  maintenance_record_id    bigint not null references public.maintenance_records(id) on delete cascade,
  -- ON DELETE RESTRICT is deliberate: a spare part that appears in any
  -- maintenance history can never be hard-deleted, matching the app's rule.
  part_id                  bigint not null references public.spare_parts(id) on delete restrict,
  quantity_used            integer not null,
  unit_cost_at_time        double precision not null default 0,
  unique (maintenance_record_id, part_id)
);
create index if not exists idx_part_usages_part_id on public.part_usages(part_id);

create table if not exists public.alerts (
  id                    bigint generated by default as identity primary key,
  machine_id            bigint not null references public.machines(id) on delete cascade,
  severity              alert_severity not null default 'warning',
  source                text not null default 'manual',
  message               text not null,
  status                alert_status not null default 'active',
  triggered_at          timestamptz not null default now(),
  acknowledged_at       timestamptz,
  acknowledged_by_id    uuid references public.profiles(id) on delete set null,
  resolved_at           timestamptz,
  resolved_by_id        uuid references public.profiles(id) on delete set null
);
create index if not exists idx_alerts_machine_id on public.alerts(machine_id);
create index if not exists idx_alerts_status on public.alerts(status);

-- ----------------------------------------------------------------------------
-- 4. Helper functions used inside RLS policies.
--    STABLE + SECURITY DEFINER + pinned search_path. Because they're defined
--    by the table owner, they read profiles WITHOUT going through RLS —
--    that's what stops "policy on profiles queries profiles" from becoming
--    infinite recursion (see gotcha #2 at the bottom).
-- ----------------------------------------------------------------------------
create or replace function public.current_role()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_active from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_supervisor_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role in ('admin', 'supervisor') from public.profiles where id = auth.uid()), false);
$$;

-- ----------------------------------------------------------------------------
-- 5. Row Level Security.
--    ENABLE + FORCE on every table (see gotcha #1: without FORCE, the table
--    owner — which is who your own migrations run as — silently bypasses
--    RLS, which is easy to mistake for "it's working" during testing and
--    then be wrong in production under a different role).
--    Every table also gets explicit GRANTs — RLS policies only ever narrow
--    what a GRANT already allows; without the GRANT, PostgREST/Supabase
--    calls fail even though the policy looks right (gotcha #4).
-- ----------------------------------------------------------------------------

-- profiles ---------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.profiles force row level security;
grant select, update on public.profiles to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- No insert/delete policy for `authenticated`: rows are created only by the
-- handle_new_user() trigger and removed only via auth.users cascade, both
-- of which run as the table owner and therefore bypass RLS entirely.

-- departments --------------------------------------------------------------
alter table public.departments enable row level security;
alter table public.departments force row level security;
grant select, insert, update, delete on public.departments to authenticated;

drop policy if exists departments_select on public.departments;
create policy departments_select on public.departments
  for select to authenticated using (public.is_active_user());

drop policy if exists departments_write on public.departments;
create policy departments_write on public.departments
  for all to authenticated
  using (public.is_active_user() and public.is_admin())
  with check (public.is_active_user() and public.is_admin());

-- machines -------------------------------------------------------------
alter table public.machines enable row level security;
alter table public.machines force row level security;
grant select, insert, update, delete on public.machines to authenticated;

drop policy if exists machines_select on public.machines;
create policy machines_select on public.machines
  for select to authenticated using (public.is_active_user());

drop policy if exists machines_write on public.machines;
create policy machines_write on public.machines
  for all to authenticated
  using (public.is_active_user() and public.is_supervisor_or_admin())
  with check (public.is_active_user() and public.is_supervisor_or_admin());

-- work_orders ----------------------------------------------------------
alter table public.work_orders enable row level security;
alter table public.work_orders force row level security;
grant select, insert, update, delete on public.work_orders to authenticated;

drop policy if exists work_orders_select on public.work_orders;
create policy work_orders_select on public.work_orders
  for select to authenticated using (public.is_active_user());

drop policy if exists work_orders_write on public.work_orders;
create policy work_orders_write on public.work_orders
  for all to authenticated
  using (public.is_active_user() and public.is_supervisor_or_admin())
  with check (public.is_active_user() and public.is_supervisor_or_admin());

-- maintenance_records ----------------------------------------------------
-- Any active authenticated user can log maintenance (this is normally the
-- technician on the floor) and it must be logged as themselves.
alter table public.maintenance_records enable row level security;
alter table public.maintenance_records force row level security;
grant select, insert, update, delete on public.maintenance_records to authenticated;

drop policy if exists maintenance_records_select on public.maintenance_records;
create policy maintenance_records_select on public.maintenance_records
  for select to authenticated using (public.is_active_user());

drop policy if exists maintenance_records_insert on public.maintenance_records;
create policy maintenance_records_insert on public.maintenance_records
  for insert to authenticated
  with check (public.is_active_user() and performed_by_id = auth.uid());

-- No app endpoint edits/removes a maintenance record once logged; only
-- admins get an escape hatch to correct mistakes.
drop policy if exists maintenance_records_admin_write on public.maintenance_records;
create policy maintenance_records_admin_write on public.maintenance_records
  for update to authenticated
  using (public.is_active_user() and public.is_admin())
  with check (public.is_active_user() and public.is_admin());

drop policy if exists maintenance_records_admin_delete on public.maintenance_records;
create policy maintenance_records_admin_delete on public.maintenance_records
  for delete to authenticated
  using (public.is_active_user() and public.is_admin());

-- spare_parts ------------------------------------------------------------
alter table public.spare_parts enable row level security;
alter table public.spare_parts force row level security;
grant select, insert, update, delete on public.spare_parts to authenticated;

drop policy if exists spare_parts_select on public.spare_parts;
create policy spare_parts_select on public.spare_parts
  for select to authenticated using (public.is_active_user());

drop policy if exists spare_parts_write on public.spare_parts;
create policy spare_parts_write on public.spare_parts
  for all to authenticated
  using (public.is_active_user() and public.is_supervisor_or_admin())
  with check (public.is_active_user() and public.is_supervisor_or_admin());

-- part_usages --------------------------------------------------------------
-- Follows maintenance_records: written alongside it by whoever logged the
-- maintenance, read by anyone active.
alter table public.part_usages enable row level security;
alter table public.part_usages force row level security;
grant select, insert, update, delete on public.part_usages to authenticated;

drop policy if exists part_usages_select on public.part_usages;
create policy part_usages_select on public.part_usages
  for select to authenticated using (public.is_active_user());

drop policy if exists part_usages_insert on public.part_usages;
create policy part_usages_insert on public.part_usages
  for insert to authenticated
  with check (
    public.is_active_user()
    and exists (
      select 1 from public.maintenance_records mr
      where mr.id = maintenance_record_id and mr.performed_by_id = auth.uid()
    )
  );

drop policy if exists part_usages_admin_write on public.part_usages;
create policy part_usages_admin_write on public.part_usages
  for update to authenticated
  using (public.is_active_user() and public.is_admin())
  with check (public.is_active_user() and public.is_admin());

drop policy if exists part_usages_admin_delete on public.part_usages;
create policy part_usages_admin_delete on public.part_usages
  for delete to authenticated
  using (public.is_active_user() and public.is_admin());

-- alerts -----------------------------------------------------------------
-- Create/acknowledge/resolve: any authenticated user, per the app's rules.
alter table public.alerts enable row level security;
alter table public.alerts force row level security;
grant select, insert, update on public.alerts to authenticated;

drop policy if exists alerts_select on public.alerts;
create policy alerts_select on public.alerts
  for select to authenticated using (public.is_active_user());

drop policy if exists alerts_insert on public.alerts;
create policy alerts_insert on public.alerts
  for insert to authenticated with check (public.is_active_user());

drop policy if exists alerts_update on public.alerts;
create policy alerts_update on public.alerts
  for update to authenticated
  using (public.is_active_user())
  with check (public.is_active_user());
-- No delete policy anywhere (alerts are never hard-deleted by the app; that
-- default-denies delete for everyone except service_role).

-- ============================================================================
-- RLS gotchas this script exists to head off (the ask was "don't forget the
-- RLS problem" — these are the ways RLS quietly does nothing even though it
-- "looks" configured):
--
-- 1. ENABLE ROW LEVEL SECURITY alone is not enough. Table owners bypass RLS
--    by default, so anything you run as the `postgres` role (migrations,
--    the SQL editor, and — importantly — this FastAPI backend's own
--    DATABASE_URL connection) sails right through with RLS "on" and every
--    policy still passing trivially. Every table above also has FORCE ROW
--    LEVEL SECURITY so policies apply even to the owner. If you'd rather
--    the backend keep bypassing RLS on purpose (see integration notes),
--    that's a legitimate choice — just make it deliberately, not because
--    FORCE was left off by accident.
--
-- 2. A policy on `profiles` that queries `profiles` to check the caller's
--    role recurses infinitely (or Postgres detects it and errors). The
--    is_admin()/is_supervisor_or_admin()/is_active_user()/current_role()
--    functions above are SECURITY DEFINER, owned by the table owner, so
--    their internal SELECT against profiles does not itself go through RLS
--    — no recursion, and every other table's policies can safely reuse them
--    instead of re-deriving role logic per table.
--
-- 3. A user could otherwise UPDATE their own profiles row to set
--    role = 'admin' or is_active = true after being deactivated — RLS's
--    `with check` alone can't easily express "this column may not change
--    unless...", so a BEFORE UPDATE trigger
--    (prevent_self_privilege_escalation) enforces it instead.
--
-- 4. RLS policies only ever narrow a base GRANT — they never substitute for
--    one. A table with perfect policies but no `grant ... to authenticated`
--    rejects every request before a policy is even evaluated. All the
--    GRANT statements above are required, not decorative.
--
-- 5. service_role bypasses RLS entirely, by design (Supabase's backend
--    trust boundary). Never send SUPABASE_SERVICE_ROLE_KEY to a browser or
--    mobile client — only this FastAPI backend should hold it. Same caution
--    applies to DATABASE_URL: it currently connects as the `postgres` role,
--    which (per #1) also bypasses RLS by ownership. See
--    SUPABASE_INTEGRATION.md for what that means for this specific app.
-- ============================================================================
