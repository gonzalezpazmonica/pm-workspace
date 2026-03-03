# Excel Templates — Estructura de Plantillas CSV

> Plantillas CSV multi-tab para importar en Excel con fórmulas documentadas.

---

## Capacity Planning Template

### team.csv
```csv
Name,Role,Hours/Day,Focus Factor,Available Days,Capacity (h)
# Formula: Capacity = Hours/Day × Focus Factor × Available Days
"Member Name","Developer",8,0.75,10,60
```

### sprint.csv
```csv
Sprint,Start Date,End Date,Working Days,Holidays,Net Days
# Formula: Net Days = Working Days - Holidays
"Sprint 2026-05","2026-03-03","2026-03-14",10,0,10
```

### capacity.csv
```csv
Name,Capacity (h),Committed (SP),SP/h Ratio,Utilization %
# Formula: Utilization = (Committed × avg_h_per_SP) / Capacity × 100
"Member Name",60,8,7.5,100
```

### scenarios.csv
```csv
Scenario,Team Capacity,Velocity Avg,Committed SP,Risk Level
# Optimistic: velocity +20%, Pessimistic: velocity -20%
"Optimistic",480,52,52,"Low"
"Base",480,43,43,"Medium"
"Pessimistic",480,34,34,"High"
```

---

## CEO Report Template

### summary.csv
```csv
Metric,Current Sprint,Previous Sprint,Trend,Target
"Velocity (SP)",43,40,"↑","≥40"
"Completion Rate",92%,88%,"↑","≥90%"
"WIP Average",3.2,4.1,"↓","≤3"
"Lead Time (days)",4.5,5.2,"↓","≤5"
```

### dora.csv
```csv
Metric,Value,Previous,Trend,Elite Target
"Deploy Frequency","daily","daily","→","on-demand"
"Lead Time","4.5h","6h","↓","<1h"
"MTTR","2h","3h","↓","<1h"
"Change Failure Rate","5%","8%","↓","<15%"
```

---

## Time Tracking Template

### timesheet.csv
```csv
Name,Mon,Tue,Wed,Thu,Fri,Total,Expected,Delta
# Expected: 8h/day × working days. Delta: Total - Expected
"Member Name",8,7.5,8,8,7,38.5,40,-1.5
```

### projects.csv
```csv
Name,Project A (%),Project A (h),Project B (%),Project B (h)
"Member Name",60,24,40,16
```

---

## Validation Rules

| Rule | Severity | Check |
|---|---|---|
| Daily hours > 10 | Warning | Possible burnout |
| Daily hours < 4 | Warning | Under-reporting |
| Weekly total > 45 | Alert | Over-allocation |
| Missing days | Error | Incomplete timesheet |
| Capacity > 110% | Alert | Over-commitment |
