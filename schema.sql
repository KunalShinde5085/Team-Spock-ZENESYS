-- ============================================================================
-- Zenesys / MachinIQ — Supabase schema
-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------- customers ----------
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text,
  email text,
  phone text,
  created_at timestamptz not null default now()
);

-- ---------- products (also holds current inventory levels) ----------
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  category text not null,
  warehouse text not null default 'Main',
  current_stock integer not null default 0,
  reserved_stock integer not null default 0,
  damaged_stock integer not null default 0,
  safety_stock integer not null default 0,
  reorder_level integer not null default 0,
  lead_time_days integer not null default 0,
  unit_cost numeric(12,2) not null default 0,
  updated_at timestamptz not null default now()
);

-- ---------- orders ----------
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete restrict,
  product_id uuid not null references products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  order_date date not null default current_date,
  required_date date not null,
  priority text not null default 'Medium'
    check (priority in ('Low','Medium','High','Urgent')),
  status text not null default 'Pending'
    check (status in ('Pending','Confirmed','Processing','Packed','Ready to Ship','Shipped','In Transit','Delivered','Cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_orders_customer on orders(customer_id);
create index if not exists idx_orders_product on orders(product_id);
create index if not exists idx_orders_status on orders(status);

-- ---------- order status history (drives the order timeline UI) ----------
create table if not exists order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  label text not null,
  status text not null,
  "timestamp" timestamptz not null default now()
);

create index if not exists idx_osh_order on order_status_history(order_id);

-- ---------- inventory transactions (stock trend / recent activity) ----------
create table if not exists inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  type text not null check (type in ('Inbound','Outbound','Adjustment','Reserved','Released')),
  quantity integer not null,
  reference text,
  "timestamp" timestamptz not null default now()
);

create index if not exists idx_inv_txn_product on inventory_transactions(product_id);

-- ---------- production ----------
create table if not exists production (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete restrict,
  date date not null default current_date,
  planned integer not null default 0,
  produced integer not null default 0,
  rejected integer not null default 0,
  status text not null default 'Scheduled'
    check (status in ('Scheduled','In Progress','Completed','Delayed')),
  created_at timestamptz not null default now()
);

create index if not exists idx_production_product on production(product_id);

-- ---------- alerts ----------
create table if not exists alerts (
  id uuid primary key default gen_random_uuid(),
  severity text not null check (severity in ('Critical','High','Medium','Low')),
  type text not null check (type in
    ('Stock Shortage','Low Stock','Inventory Threshold Breach','Delayed Order','Delayed Shipment','Production Delay','Stockout Risk')),
  title text not null,
  product_id uuid references products(id) on delete set null,
  order_id uuid references orders(id) on delete set null,
  detected_at timestamptz not null default now(),
  status text not null default 'Open'
    check (status in ('Open','Acknowledged','Resolved','Dismissed')),
  description text
);

create index if not exists idx_alerts_product on alerts(product_id);
create index if not exists idx_alerts_order on alerts(order_id);

-- ---------- sales history (feeds forecasting) ----------
create table if not exists sales_history (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  date date not null,
  quantity_sold integer not null default 0
);

create index if not exists idx_sales_history_product on sales_history(product_id, date);

-- ---------- forecasts (precomputed; series/summary as JSON) ----------
create table if not exists forecasts (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  horizon integer not null check (horizon in (7,30,60,90)),
  series jsonb not null default '[]'::jsonb,
  summary jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  unique (product_id, horizon)
);

-- ---------- recommendations ----------
create table if not exists recommendations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  current_stock integer not null default 0,
  predicted_demand integer not null default 0,
  safety_stock integer not null default 0,
  reorder_point integer not null default 0,
  recommended_quantity integer not null default 0,
  action text not null check (action in ('PRODUCE','PURCHASE','TRANSFER','HOLD')),
  priority text not null check (priority in ('Critical','High','Medium','Low')),
  status text not null default 'Pending'
    check (status in ('Pending','Approved','Rejected','Completed')),
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_recommendations_product on recommendations(product_id);

-- ---------- suppliers (referenced by spec doc; not yet consumed by the UI) ----------
create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text
);

create table if not exists supplier_products (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  unit_cost numeric(12,2),
  lead_time_days integer
);

-- ============================================================================
-- Row Level Security
-- Hackathon-speed setup: RLS on, permissive policy for anon + authenticated.
-- Tighten this before using real data (see README-SUPABASE.md).
-- ============================================================================
do $$
declare t text;
begin
  for t in select unnest(array[
    'customers','products','orders','order_status_history','inventory_transactions',
    'production','alerts','sales_history','forecasts','recommendations',
    'suppliers','supplier_products'
  ])
  loop
    execute format('alter table %I enable row level security;', t);
    execute format(
      'create policy if not exists "allow all - hackathon" on %I for all using (true) with check (true);',
      t
    );
  end loop;
end $$;
