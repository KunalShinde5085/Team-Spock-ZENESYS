              ┌──────────────────────────┐
              │   OWNER / PURCHASER      │
              │   Creates / Updates Order│
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │       ORDER DATABASE     │
              │                          │
              │ Order ID                 │
              │ Part ID                  │
              │ Quantity                 │
              │ Required Date            │
              │ Customer                 │
              │ Priority                 │
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │     INVENTORY CHECK      │
              │                          │
              │ Current Stock            │
              │ Reserved Stock           │
              │ Raw Material             │
              └─────────────┬────────────┘
                            │
                   ┌────────┴────────┐
                   │                 │
                   ▼                 ▼
              ENOUGH STOCK       LOW STOCK
                   │                 │
                   │                 ▼
                   │          ┌───────────────┐
                   │          │ ISSUE DETECTED│
                   │          │               │
                   │          │ Stock Shortage│
                   │          │ Reorder Risk  │
                   │          └───────┬───────┘
                   │                  │
                   └────────┬─────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │ HISTORICAL DATA ANALYSIS │
              │                          │
              │ Sales / Orders           │
              │ Production               │
              │ Inventory                │
              │ Part Demand              │
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │    DEMAND FORECASTING    │
              │                          │
              │ Next 7 / 30 Days         │
              │ Demand Prediction        │
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │ INVENTORY CALCULATION    │
              │                          │
              │ Safety Stock             │
              │ Reorder Point            │
              │ Stockout Risk            │
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │ RECOMMENDATION ENGINE    │
              │                          │
              │ Produce?                 │
              │ Purchase?                │
              │ How Much?                │
              │ When?                    │
              └─────────────┬────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │      MANAGEMENT          │
              │      DASHBOARD           │
              │                          │
              │ ⚠️ Alerts                │
              │ 📈 Forecast              │
              │ 📦 Inventory             │
              │ 🏭 Production            │
              │ 🛒 Recommendations       │
              └──────────────────────────┘
