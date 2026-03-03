---
name: excel-report
description: Generar plantillas Excel interactivas con Claude-in-Excel para reporting
developer_type: all
agent: task
context_cost: medium
---

# /excel-report

> Genera plantillas Excel interactivas para reportes PM.

## Sintaxis

```
/excel-report {capacity|ceo|time-tracking|custom} [proyecto] [--format xlsx|csv]
```

## Templates Disponibles

### capacity — Planificación de Capacidad

Genera Excel multi-tab con:
- **Team**: Miembros, roles, horas/día, factor de foco
- **Sprint**: Días hábiles, festivos, vacaciones
- **Capacity**: Fórmulas automáticas (días × horas × foco)
- **Scenarios**: What-if con 3 escenarios (optimista, base, pesimista)
- **Charts**: Gráfico de capacidad vs. compromisos

### ceo — Informe Ejecutivo

Genera Excel multi-tab con:
- **Summary**: KPIs principales, velocity, burndown
- **DORA**: Métricas de delivery (deploy freq, lead time, MTTR, CFR)
- **Risks**: Matriz de riesgos con probabilidad × impacto
- **Budget**: Burn rate, forecast, desviación
- **Trends**: Gráficos de tendencia últimos 5 sprints

### time-tracking — Imputación de Horas

Genera Excel multi-tab con:
- **Timesheet**: Matriz persona × día con horas
- **Projects**: Distribución por proyecto (% y horas)
- **Summary**: Totales por persona, promedio, desviación
- **Validation**: Reglas (8h/día, alertas >10h, vacaciones)

### custom — Plantilla Personalizada

Savia pregunta qué datos incluir y genera la estructura.

---

## Flujo

1. **Paso 1** — Identificar proyecto y datos disponibles
2. **Paso 2** — Recopilar datos (WIQL, capacity, metrics)
3. **Paso 3** — Generar estructura de tabs con fórmulas
4. **Paso 4** — Exportar a CSV (una pestaña por fichero)
5. **Paso 5** — Guardar en `output/excel/`

---

## Output

```
output/excel/
├── YYYYMMDD-capacity-{proyecto}/
│   ├── team.csv
│   ├── sprint.csv
│   ├── capacity.csv
│   └── scenarios.csv
├── YYYYMMDD-ceo-{proyecto}/
│   ├── summary.csv
│   ├── dora.csv
│   ├── risks.csv
│   └── trends.csv
└── YYYYMMDD-timesheet-{proyecto}/
    ├── timesheet.csv
    ├── projects.csv
    └── summary.csv
```

**Formato CSV**: Importable en Excel, Google Sheets, LibreOffice.
Las fórmulas se documentan como comentarios en la primera fila.

---

## Claude-in-Excel Integration

Si el usuario tiene Claude en Excel (plan Pro/Max):
- Los CSVs se abren directamente en Excel
- Claude puede analizar los datos in-situ
- Escenarios what-if se ejecutan con Claude en la hoja

---

## Ejemplo de Uso

```
/excel-report capacity sala-reservas
→ Genera output/excel/20260303-capacity-sala-reservas/
→ 4 CSVs con datos del sprint actual + fórmulas documentadas
```
