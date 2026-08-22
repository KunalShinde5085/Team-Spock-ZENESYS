-- ============================================================================
-- Optional demo seed data — run AFTER schema.sql if you want the dashboard
-- populated immediately instead of starting from an empty database.
-- ============================================================================

with p as (
  insert into products (code, name, category, warehouse, current_stock, reserved_stock, damaged_stock, safety_stock, reorder_level, lead_time_days, unit_cost)
  values
    ('GEAR-001', 'Precision Helical Gear', 'Gears', 'Main', 1000, 300, 50, 200, 400, 7, 45.00),
    ('SHFT-014', 'Stainless Drive Shaft', 'Shafts', 'Main', 400, 120, 10, 150, 250, 10, 32.50),
    ('BRNG-102', 'Sealed Ball Bearing', 'Bearings', 'North', 2200, 500, 0, 600, 900, 5, 6.75),
    ('VLVE-220', 'Hydraulic Control Valve', 'Valves', 'North', 150, 40, 5, 80, 120, 14, 118.00)
  returning id, code
),
c as (
  insert into customers (name, company, email, phone)
  values
    ('Priya Nair', 'Orbit Manufacturing', 'priya@orbitmfg.com', '+91-98200-11223'),
    ('Daniel Osei', 'Kestrel Robotics', 'daniel@kestrelrobotics.com', '+1-415-555-0134')
  returning id, name
)
select 1;

-- Orders (reference the seeded products/customers by code/name lookups)
insert into orders (customer_id, product_id, quantity, order_date, required_date, priority, status, notes)
select c.id, p.id, 650, current_date - interval '5 days', current_date + interval '4 days', 'High', 'Processing', 'Rush order for Q3 line expansion'
from customers c, products p where c.name = 'Priya Nair' and p.code = 'GEAR-001';

insert into orders (customer_id, product_id, quantity, order_date, required_date, priority, status, notes)
select c.id, p.id, 300, current_date - interval '2 days', current_date + interval '10 days', 'Medium', 'Confirmed', null
from customers c, products p where c.name = 'Daniel Osei' and p.code = 'BRNG-102';

-- Sales history for the last 14 days per product (rough synthetic trend)
insert into sales_history (product_id, date, quantity_sold)
select p.id, d::date, (80 + (random() * 60)::int)
from products p, generate_series(current_date - interval '13 days', current_date, interval '1 day') d
where p.code = 'GEAR-001';

-- A couple of alerts
insert into alerts (severity, type, title, product_id, status, description)
select 'High', 'Low Stock', 'Sealed Ball Bearing nearing reorder point', p.id, 'Open', 'Available stock is approaching the reorder level.'
from products p where p.code = 'BRNG-102';

-- A production run
insert into production (product_id, date, planned, produced, rejected, status)
select p.id, current_date - interval '1 day', 500, 480, 12, 'Completed'
from products p where p.code = 'GEAR-001';
