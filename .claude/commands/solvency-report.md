---
name: solvency-report
description: >
  Gestiona reportes de solvencia Solvency II: cálculo de ratios, estado actual,
  sumisión a regulador y evolución histórica.
  Almacena en projects/{proyecto}/insurance/solvency/ con simplificación de fórmulas.
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# /solvency-report {proyecto} {subcomando} [opciones]

## Subcomandos

### calculate
```bash
/solvency-report {proyecto} calculate \
  [--date {YYYY-MM-DD}]
```
Computa ratios Solvency II: SCR, MCR, fondos propios, ratio SCR.
Usa fórmulas básicas, no modelo interno completo.

Ratios calculados:
- **Fondos propios**: suma neta de activos - pasivos
- **SCR (Solvency Capital Req)**: 18% × fondos propios (simplificado)
- **MCR (Minimum Capital Req)**: 6% × SCR
- **Ratio SCR**: fondos propios / SCR (objetivo ≥ 100%)

### status
```bash
/solvency-report {proyecto} status
```
Muestra posición actual con indicador RAG:
- 🟢 GREEN (≥ 150%): Posición fuerte
- 🟡 YELLOW (100-150%): Cumple, pero vigilar
- 🔴 RED (< 100%): Incumplimiento, acción requerida

### submit
```bash
/solvency-report {proyecto} submit \
  --date {YYYY-MM-DD}
```
Marca reporte como enviado a regulador, registra fecha.

### history
```bash
/solvency-report {proyecto} history \
  [--months N]
```
Tabla histórica: fechas, ratios SCR, tendencia gráfica ASCII.

## Estructura de datos

```yaml
date: YYYY-MM-DD
own_funds: XXX.XX
scr_requirement: XXX.XX
mcr_requirement: XXX.XX
scr_ratio: XXX.XX%
status: GREEN|YELLOW|RED
submitted: false
submitted_date: null
created_by: "sistema"
```

## Reglas

- Cálculos base sin modelo interno (simplificación)
- Ratio SCR < 100% es incumplimiento
- Historiales se retienen 3 años mínimo
- Sumisión requiere confirmación explícita
