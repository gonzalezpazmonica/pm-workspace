---
name: flow-metrics
description: Value Stream dashboard con Lead Time E2E, Flow Efficiency, WIP aging y distribución
developer_type: agent-single
agent: azure-devops-operator
context_cost: medium
---

# Flow Metrics Dashboard

## Descripción
Dashboard completo de Value Stream Mapping que presenta Lead Time end-to-end, eficiencia de flujo, distribución WIP y métricas de throughput.

## Uso
```bash
claude flow-metrics [--period 30] [--state-filter Active,Resolved]
```

## Métricas Principales

### 1. Lead Time End-to-End
- Tiempo desde Created hasta Done
- Incluye todos los estados intermedios
- Unidad: días
- Estadísticas: promedio, mediana, P95

### 2. Cycle Time
- Tiempo desde Active/In Progress hasta Done
- Exluye tiempo en New/Backlog
- Indicador de eficiencia operativa

### 3. Flow Efficiency
- Fórmula: (Active Time / Total Elapsed Time) × 100
- Active Time: suma de días en "Active" o "In Progress"
- Total Elapsed: días desde Created hasta Done
- Meta: >40% es aceptable, >60% es excelente

### 4. %Complete & Accurate (%C&A)
- Porcentaje de items que pasaron review sin rework
- Calculado como: (Items completados sin rework) / Total completados
- Indicador de calidad

### 5. Work Item Age (WIP Aging)
- Ranking de items en progreso por antigüedad
- Alertas: >1.5× cycle time promedio = rojo
- Identifica cuellos de botella

### 6. WIP Distribution
- Desglose por tipo: Feature / Bug / Technical Debt / Risk
- Visualización: pie chart o tabla
- Ayuda a balancear cartera

### 7. Flow Load
- Recuento de items por estado
- Estados: New, Active, Resolved, Closed
- Identifica congestión

### 8. Throughput Trend
- Items completados por semana (últimas 4 semanas)
- Tendencia: lineal regression
- Indicador: ↑ improving, → stable, ↓ declining

## Salida

```
╔═══════════════════════════════════════════════════════════════╗
║              FLOW METRICS DASHBOARD                           ║
║              Periodo: Últimos 30 días                         ║
╚═══════════════════════════════════════════════════════════════╝

📊 LEAD TIME & CYCLE TIME
┌──────────────────────────┬──────────┐
│ Métrica                  │ Valor    │
├──────────────────────────┼──────────┤
│ Lead Time (E2E)          │ 12.3 días│
│ Cycle Time (Active→Done) │ 7.8 días │
│ Lead Time P95            │ 22.1 días│
└──────────────────────────┴──────────┘

⚡ FLOW EFFICIENCY
├─ Flow Efficiency      : 58% ↑
├─ %Complete & Accurate : 94% →
└─ Meta (Goal)          : >60%

🔄 WIP AGING (Items en Progreso)
┌──────────┬────────┬──────────┬────────┐
│ Item ID  │ Tipo   │ Días     │ Status │
├──────────┼────────┼──────────┼────────┤
│ FEAT-801 │ Feature│ 8 días   │ 🟡 AMBER
│ BUG-345  │ Bug    │ 5 días   │ 🟢 OK
│ DEBT-12  │ Debt   │ 3 días   │ 🟢 OK
└──────────┴────────┴──────────┴────────┘

📦 WIP DISTRIBUTION
┌────────────┬──────────┬────────┐
│ Tipo       │ Cantidad │ %      │
├────────────┼──────────┼────────┤
│ Features   │ 8        │ 53%    │
│ Bugs       │ 4        │ 27%    │
│ Tech Debt  │ 2        │ 13%    │
│ Risks      │ 1        │ 7%     │
└────────────┴──────────┴────────┘

📈 FLOW LOAD (Items por Estado)
├─ New      : 24 items
├─ Active   : 15 items ←─ WIP
├─ Resolved : 8 items
└─ Closed   : 142 items

📊 THROUGHPUT TREND (Últimas 4 semanas)
├─ Semana 1 : 12 items ↓
├─ Semana 2 : 14 items ↑
├─ Semana 3 : 15 items ↑
├─ Semana 4 : 13 items ↓
└─ Tendencia: ESTABLE →

╚═══════════════════════════════════════════════════════════════╝
```

## Prerrequisitos
- Conexión a Azure DevOps
- Histórico de transiciones de estado (mínimo 30 días)
- Estados configurados: New, Active, Resolved, Closed

## Opciones
- `--period N`: Análisis de últimos N días
- `--state-filter`: Filtrar por estados específicos
