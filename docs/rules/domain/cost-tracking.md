---
name: cost-tracking
description: "Cost Tracking — Append-only ledger, burn calculation, forecasting, alerts"
auto_load: false
paths: [".opencode/commands/cost-center*", ".opencode/skills/cost-management/*"]
---

# Regla: Seguimiento de Costes

> Era 38: v2.12.1 — Cost Management & Billing

**Principio**: Un único ledger inmutable por proyecto, sin modificaciones retroactivas.

## Append-Only Ledger

```
.flow-data/ledger/{project}.jsonl
```

Cada entrada:
```json
{"timestamp":"2026-03-03T14:30:00Z","type":"time","amount":637.5,"currency":"EUR","user":"@monica","task_id":"TASK-2026-0042","description":"7.5h dev @ €85/h"}
{"timestamp":"2026-03-05T09:00:00Z","type":"expense","amount":250.00,"currency":"EUR","user":"@carlos","description":"AWS services — March"}
{"timestamp":"2026-03-10T16:45:00Z","type":"adjustment","amount":-50.00,"currency":"EUR","user":"@admin","description":"Correction: duplicate entry"}
```

Fields:
- `timestamp`: UTC ISO 8601 (when entry was recorded)
- `type`: "time" (hours×rate) | "expense" (manual invoice) | "adjustment" (correction)
- `amount`: cost in currency (always positive for type time/expense; may be negative for adjustment)
- `currency`: EUR | USD | GBP
- `user`: @handle who incurred the cost
- `task_id`: optional reference (for time entries)
- `description`: mandatory explanation

## Budget Burn Calculation

```
actual_burn = sum(ledger entries where date >= budget.start_date AND date <= budget.end_date)
remaining = budget.total_budget - actual_burn
burn_rate = actual_burn / elapsed_days
```

Alert when:
- `actual_burn >= budget.total_budget × 0.50` → warn at 50%
- `actual_burn >= budget.total_budget × 0.75` → warn at 75%
- `actual_burn >= budget.total_budget × 0.90` → critical at 90%

## Forecast (Velocity-Based)

```
elapsed_time = today - budget.start_date (in days)
remaining_time = budget.end_date - today
burn_rate = actual_burn / elapsed_time
forecast_burn = burn_rate × (elapsed_time + remaining_time)
EAC = forecast_burn  (Estimate at Completion)
```

If `EAC > BAC`: project at risk. Alert PM with corrective actions:
- Reduce scope (remove low-priority PBIs)
- Extend timeline
- Increase budget (needs approval)

## Cost Per Deliverable

```
Σ(hours × rate) per PBI / feature = cost_per_pbi
Sum all PBIs → total_project_cost
```

Tracked in output report for ROI analysis per feature.

## Profitability Analysis

```
Revenue (invoiced to client) - Cost (internal timesheet × rates) = Profit
Profit Margin = Profit / Revenue × 100
```

Only applies if client has separate invoicing model (not all projects are billable).

## Monthly Aggregation

At end of month, generate `output/cost-summary/{project}-{YYYY-MM}.md`:
- Total time entries (count, hours, cost)
- Total expenses
- Total adjustments
- Running burn vs. budget
- Forecast updated
- Trends (comparing to previous month)
