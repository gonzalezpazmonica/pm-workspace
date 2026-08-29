---
context_tier: L3
token_budget: 1000
---

# Regla: Layer Baseline Test y Señal de Error Ponderada

> SE-348 — Política derivada del análisis de resiliencia adaptativa 2026-08-28.
> Criterio humano aplicable: CRIT-001 — todo el análisis y las métricas se
> computan en local; datos N3+ jamás salen a proveedor cloud.

## 1. Criterio 7 de falsabilidad — toda capa debe vencer a su baseline

> "Si el sistema complejo no supera a un baseline más simple, no aporta valor."

Toda capa de coordinación nueva en Savia — orquestador multiagente, tribunal,
skill de orquestación, capa de routing — DEBE pasar el **layer baseline test**
antes de aprobarse:

```
bash scripts/layer-baseline-test.sh \
  --full-metrics full.json --baseline-metrics baseline.json \
  [--cost-multiplier N] [--min-delta 0.05] [--json]
```

- `full` = métricas del sistema con la capa; `baseline` = agente único / capa
  ablated / sistema sin la capa.
- `JUSTIFIED` solo si `avg_delta STRICTO > min_delta × cost_multiplier`
  (exit 0). La complejidad cuesta latencia, tokens y mantenimiento: una capa
  que cuesta 2x debe ganar 2x para justificarse.
- `UNJUSTIFIED` (exit 1) ⇒ la capa no aporta valor medible sobre su baseline:
  se simplifica o se archiva la propuesta.

**Gate en spec**: la spec de cualquier capa de coordinación nueva debe incluir
`baseline_metrics` y `full_metrics` planificados, o marcar por qué el test no
aplica (con justificación). Sin métricas de baseline, la complejidad no se
aprueba.

## 2. Señal de error ponderada — η = f(P_error)

No reaccionar igual ante cualquier fallo de una tool-call. La tasa de
corrección (η) se pondera por la **fiabilidad de la señal de error**, no por
el mero hecho de haber fallado.

Tabla canónica (implementada en `scripts/agent-run-logger.sh` →
`_reliability_for`):

| status | reliability | interpretación |
|---|---|---|
| `ok` | 0.0 | no es señal de error |
| `skipped` | 0.0 | decisión deliberada |
| `error` | 0.9 | señal más fiable de fallo real (ej. validación de esquema fallida) |
| `blocked` | 0.5 | señal de política — a veces legítima |
| `timeout` | 0.2 | puede ser ruido de infraestructura, no de razonamiento |
| `aborted` | 0.2 | corte de seguridad, no fallo de razonamiento |

Consecuencia operativa: un `timeout` no justifica un cambio de estrategia con
la misma fuerza que un `error` de validación. `weighted_error` en
`resilience-report.sh` ya aplica estos pesos.

## 3. Ruido vs variabilidad funcional — regla de alerta

No toda varianza en el comportamiento de un agente es un bug. Explorar rutas
de razonamiento distintas ante el mismo prompt puede ser adaptativo.

`variance_class` (emitido por `scripts/resilience-report.sh`):

| class | condición | tratamiento |
|---|---|---|
| `nominal` | completed sin señales de error | normal |
| `exploratory` | completed con señales de error (se recuperó) | **NO es incidente** — variabilidad adaptativa |
| `dysfunctional` | aborted/timeout/error con señales de error previas | **incidente** — loops o alucinaciones persistentes |
| `external` | aborted/timeout/error sin señales de error previas | corte externo/infra, no del agente |

**Regla de alerta**: un dashboard/alerta DEBE disparar sobre `dysfunctional`
con `weighted_error > umbral`, NO sobre variación exploratoria. Sobre-alertar
la variabilidad normal apaga la capacidad de adaptación del sistema
(convergencia forzada → agente rígido).

## 4. Tiempo de recuperación (T_rec)

Además de contar fallos, medir cuánto tarda el sistema en volver a estado
funcional tras una perturbación. `resilience-report.sh` emite `t_rec_s` por
run (mediana del tiempo entre el inicio de una racha de errores y la siguiente
tool-call exitosa). Un T_rec alto o creciente es señal de degradación de la
capacidad de recuperación, independiente del error rate.

## 5. Instrumentos

- `scripts/agent-run-logger.sh` — registra `tool_events` con `ts` y
  `reliability` por tool-call.
- `scripts/resilience-report.sh` — `summary`/`detail`, `--json`, `--agent`.
- `scripts/layer-baseline-test.sh` — criterio 7, `--json`, `--cost-multiplier`.
- Evaluación periódica sugerida: `resilience-report.sh --json` como input de
  dashboards; `layer-baseline-test.sh` en el gate de specs de orquestación.
