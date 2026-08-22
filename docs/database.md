# Database

## Overview

The project uses **Supabase PostgreSQL** as the central database for the manufacturing demand forecasting and order fulfillment platform.

The database stores order, inventory, production, sales, supplier, and forecasting data used by the backend and analytics modules.

## Database Structure

| Table                  | Purpose                                                         |
| ---------------------- | --------------------------------------------------------------- |
| `products`             | Stores mechanical parts and their inventory planning parameters |
| `customers`            | Stores customer information                                     |
| `suppliers`            | Stores supplier information                                     |
| `supplier_products`    | Maps suppliers to the products they supply                      |
| `orders`               | Stores customer orders and fulfillment status                   |
| `inventory`            | Tracks current, reserved, and damaged stock                     |
| `sales_history`        | Stores historical product demand data                           |
| `production`           | Stores planned, produced, and rejected quantities               |
| `alerts`               | Stores stock, fulfillment, and operational alerts               |
| `forecasts`            | Stores predicted future demand                                  |
| `recommendations`      | Stores inventory and purchasing/production recommendations      |
| `order_status_history` | Tracks order status changes over time                           |

## Data Flow

```text
Order Created
     ↓
Orders
     ↓
Inventory Check
     ↓
Issue Detection
     ↓
Historical Data Analysis
     ↓
Demand Forecast
     ↓
Inventory Recommendation
     ↓
Purchase / Production Decision
```

## Database Operations

The system supports:

* Create new orders, products, inventory records, etc.
* Read and filter operational data
* Update order, inventory, and production information
* Track order status changes
* Detect stock shortages and inventory risks
* Store forecasts and recommendations
* Deactivate records where deletion is not appropriate

## Security

Supabase Row Level Security (RLS) is enabled on the database tables. Authenticated users are given controlled CRUD access, while privileged server-side operations are handled through the backend.

The database is treated as the **single source of truth** for the application.

## Development

Database schema and SQL scripts are maintained in this repository. Any schema changes should be documented and coordinated with the backend and analytics modules.
