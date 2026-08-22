# System Architecture

## Overview

The platform connects order management, inventory, production data, and demand forecasting into a single workflow.

## System Flow

```text
Owner / Purchaser
       ↓
   Frontend
       ↓
   Backend API
       ↓
    Supabase
       ↓
 ┌─────┼──────────┐
 ↓     ↓          ↓
Orders Inventory Production
       │
       ↓
 Historical Data
       ↓
 Forecasting Engine
       ↓
 Inventory Analysis
       ↓
 Recommendations
       ↓
    Dashboard
```

## Main Components

### Frontend

Provides interfaces for:

* Creating and managing orders
* Viewing inventory
* Monitoring alerts
* Viewing demand forecasts
* Reviewing recommendations

### Backend

Handles:

* API requests
* Order processing
* Inventory checks
* Business logic
* Alert generation
* Communication between the frontend, database, and forecasting module

### Database

Supabase PostgreSQL stores:

* Products
* Orders
* Inventory
* Sales history
* Production records
* Suppliers
* Alerts
* Forecasts
* Recommendations

### Forecasting & Analytics

Uses historical sales and inventory data to:

* Identify demand trends
* Forecast future demand
* Calculate safety stock and reorder points
* Identify stockout risks
* Recommend purchasing or production quantities

## Core Workflow

```text
1. Purchaser creates an order
2. Order is stored in the database
3. Inventory availability is checked
4. Shortages or risks are detected
5. Historical data is analyzed
6. Future demand is forecast
7. Inventory requirements are calculated
8. Purchase or production recommendations are generated
9. Management reviews the recommendation
```

## Goal

The architecture is designed to provide a single data flow from **order creation to data-driven production and purchasing decisions**.
