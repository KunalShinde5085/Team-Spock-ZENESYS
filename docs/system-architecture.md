# System Architecture

## Overview

Zenesys is a demand forecasting and order fulfillment platform for mechanical manufacturing.

## Data Flow

Customer / Purchaser
        ↓
Order Creation
        ↓
Supabase Database
        ↓
Inventory Validation
        ↓
Issue Detection
        ↓
Demand Forecasting
        ↓
Inventory Recommendation
        ↓
Purchase / Production Decision

## Main Components

- React + Vite — Frontend
- Supabase — Database
- Forecasting Module — Demand prediction
- Analytics Module — Historical data analysis
- Alert Module — Operational issue detection
