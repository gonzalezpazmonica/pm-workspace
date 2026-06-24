---
id: SE-225
title: TimesFM forecasting zero-shot para velocity y burndown con quantiles
status: PROPOSED
priority: P2
effort: M (5h)
origin: Research 2026-06-24 — github.com/google-research/timesfm (Google Research, ICML 2024)
author: Savia
related: sprint-management skill, capacity-planning skill, /sprint-forecast command
proposed_at: "2026-06-24"
era: 235
---

# SE-225 — TimesFM: forecasting velocity y burndown con intervalos de confianza

## Problema

El comando `/sprint-forecast` de Savia devuelve una predicción puntual de velocity basada en media histórica. No hay intervalos de confianza. El PO recibe "42 SP próximo sprint" sin saber si ese número tiene 80% de certeza o 30%. El equipo no puede cuantificar el riesgo de comprometer un sprint concreto.

Cost of inaction: decisiones de commitment basadas en media histórica sin incertidumbre producen overpromise sistemático. El equipo no mejora su estimación porque no tiene feedback cuantificado de su imprecisión.

## Tesis

Integrar TimesFM (Google Research, ICML 2024, 200M params, zero-shot) como motor de forecasting para velocity histórica de sprints. El diferencial no es la predicción puntual sino los **quantiles p10-p90**: Savia pasa de reportar un número a reportar un intervalo calibrado.

Caso de uso principal: `horizon=3, freq="W"` para forecast de los 3 próximos sprints. Salida: velocity media + rango 80% (p10-p90) + flag de riesgo si p10 < compromisos actuales.

## Diseño

### Modo de despliegue (coste mínimo)

Dos opciones según infra disponible:

**Opción A (sin infra, recomendada para inicio)**: BigQuery ML via `timesfm` vertex AI connector. Sin servidor propio, sin 32GB RAM. Pay-per-query. Coste estimado: <1€/mes para un equipo.

**Opción B (local)**: Script Python con `timesfm` pip package. Requiere 32GB RAM. Válido en servidor Ubuntu dedicado (homelab).

### Formato de entrada

```python
# Una serie por equipo/proyecto
forecast_input = [
    {
        "unique_id": "pm-workspace-velocity",
        "ds": ["2026-01-13", "2026-01-27", "2026-02-10", ...],  # fechas sprint
        "y": [38, 44, 41, 39, 47, ...]  # velocity SP
    }
]
```

Fuente de datos: Azure DevOps API (sprint histórico via `scripts/ado-velocity-history.sh`) o JSONL manual.

### Salida de `/sprint-forecast` enriquecida

```
Sprint S+1 forecast: 44 SP
  Rango 80%: 38–51 SP (p10-p90)
  Rango 95%: 33–56 SP
  → Riesgo BAJO si commitment ≤ 38 SP
  → Riesgo MEDIO si commitment 38–44 SP
  → Riesgo ALTO si commitment > 44 SP

Sprint S+2 forecast: 43 SP (incertidumbre +12% vs S+1)
Sprint S+3 forecast: 42 SP (incertidumbre +25% vs S+1)
```

### Limitaciones conocidas y mitigaciones

| Limitación | Mitigación |
|---|---|
| Series < 10 sprints: baja precisión | Fallback automático a EWMA (media móvil exponencial) |
| No captura causalidad (baja de team, vacaciones) | Savia añade contexto narrativo; TimesFM solo extrapola patrón |
| 32GB RAM si modelo local | BigQuery ML como primera opción; modelo local solo en homelab |
| No es producto oficial Google (excepto BigQuery ML) | Citar fuente, usar BigQuery ML en producción |

## Slices

### Slice 1 — Script scripts/timesfm-velocity-forecast.py (S, 2h)

- Python 20 líneas, usa `timesfm` pip package o BigQuery ML client
- Lee JSONL de velocity histórica (formato estándar Savia)
- Output JSON con point forecast + quantiles p10/p25/p75/p90
- Fallback automático a EWMA si <10 puntos
- Tests: 3 series sintéticas de referencia (corta, media, larga) + 1 serie real pm-workspace

### Slice 2 — Integrar en /sprint-forecast (S, 2h)

- Actualizar comando `/sprint-forecast` para llamar al script
- Formatear salida con intervalos + flag de riesgo (BAJO/MEDIO/ALTO)
- Si BigQuery ML: añadir `TIMESFM_BIGQUERY_PROJECT` a `.env.example`
- BATS: output contiene quantiles, riesgo correcto para 3 escenarios

### Slice 3 — Burndown intra-sprint (M, 3h) [diferido]

- `horizon=N_dias_restantes, infer_is_positive=True` para burndown
- Integrarse en daily report: "Al ritmo actual, el sprint cierra con X SP pendientes (p10: Y, p90: Z)"
- Anomaly detection: si burndown actual sale del rango histórico → alerta

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|
| BigQuery billing no configurado | Media | Script detecta y usa fallback EWMA automáticamente |
| Velocidad histórica tiene outliers (sprint partido, festivos) | Alta | Preprocessing: eliminar sprints < 5 días |
| Modelo no mejora sobre media móvil con <10 sprints | Alta | Fallback documentado; umbral configurable |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Script Python | `scripts/timesfm-velocity-forecast.py` | Invocado via bash tool |
| Comando `/sprint-forecast` | `.claude/commands/sprint-forecast.md` | N/A (bash puro) |

### Portability classification

- [x] **PURE_BASH**: script Python invocado desde bash. Sin bindings de frontend.
