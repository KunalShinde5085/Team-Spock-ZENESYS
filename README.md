                 ┌─────────────────────┐
                 │   Historical Data   │
                 │ Sales + Inventory   │
                 └──────────┬──────────┘
                            ↓
                  ┌─────────────────┐
                  │ Demand Forecast │
                  │     ML Model    │
                  └────────┬────────┘
                           ↓
              ┌────────────────────────┐
              │ Inventory Recommendation│
              └───────────┬────────────┘
                          ↓
        ┌──────────────────────────────────┐
        │       Order Fulfillment          │
        │                                  │
        │ Order → Processing → Shipped →   │
        │ Delivered                        │
        └──────────────────────────────────┘
                          ↓
               ┌─────────────────┐
               │ Alert System    │
               │                 │
               │ 🔴 Stockout     │
               │ 🟠 Delay        │
               │ 🟡 Low Stock    │
               └─────────────────┘
