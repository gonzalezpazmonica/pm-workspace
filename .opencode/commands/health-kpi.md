---
name: /health-kpi
description: >
  Definición y seguimiento de KPIs clínicos: estancia media, tasa infección,
  reingresos, satisfacción paciente, mortalidad, tiempos de espera. Alertas
  automáticas cuando KPIs se desvían de objetivo. Análisis de tendencias.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /health-kpi — KPIs Clínicos

Gestiona indicadores de desempeño clínico y operativo.

## Sintaxis

```bash
/health-kpi <subcommand> [opciones]
```

## Subcomandos

### define
Crear un KPI.

```bash
/health-kpi define \
  --nombre "Estancia media" \
  --formula "sum(dias_internacion) / numero_egresos" \
  --unidad "días" \
  --target 4.2 \
  --frecuencia "mensual" \
  --owner "Jefe Calidad"
```

Crea: `projects/{proyecto}/quality/kpis/KPI-NNN.yml`

### measure
Registrar medición.

```bash
/health-kpi measure --id KPI-001 \
  --valor 4.5 \
  --periodo "2026-03"
```

### trend
Mostrar evolución histórica.

```bash
/health-kpi trend --id KPI-001 --ultimos-periodos 12
```

Incluye:
- Gráfico de serie temporal
- Dirección (mejorando/estable/empeorando)
- Delta respecto a target

### dashboard
Ver resumen de todos los KPIs.

```bash
/health-kpi dashboard
```

Formato tabla:
| KPI | Valor | Target | Estado | Dirección |

Estados: 🟢 OK | 🟡 Alerta | 🔴 Crítico

### alert
Mostrar KPIs fuera de objetivo.

```bash
/health-kpi alert --severidad "critico"
```

## KPIs Clínicos Estándar

| KPI | Fórmula | Target | Unidad |
|-----|---------|--------|--------|
| Estancia media | dias/egresos | 3.5-4.5 | días |
| Tasa infección | (infecciones/egresos)×100 | <2% | % |
| Tasa reingresos | reingresos <7d / egresos | <5% | % |
| Satisfacción | encuestas positivas | >85% | % |
| Mortalidad | muertes / ingresos | sector-dependiente | % |
| Tiempo espera consulta | promedio citas no-urgentes | <15 días | días |

### Almacenamiento

```
projects/{proyecto}/quality/kpis/
  KPI-001.yml (estancia-media)
  KPI-002.yml (tasa-infeccion)
  ...
  historico/
    YYYYMM-mediciones.csv
```

## Ciclo de medición

**Inicio mes** → planificar recopilación
**Durante mes** → registrar datos
**Final mes** → calcular KPIs, generar alertas
**Review** → analizar tendencias, acciones si desviaciones

## Alertas automáticas

🔴 **Crítico**: Valor <50% de target o >150% de target
🟡 **Alerta**: Valor 50-85% o 115-150% de target
🟢 **OK**: Dentro de rango target
