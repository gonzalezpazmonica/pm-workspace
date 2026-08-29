---
id: SE-348
title: "SE-348 — Resiliencia de agentes y test de baseline para capas multiagente"
status: IMPLEMENTED
priority: media
---

# SE-348 — Resiliencia de agentes y test de baseline para capas multiagente

**Status:** PROPOSED
**Fecha:** 2026-08-28
**Area:** Observabilidad / Autonomía / Evals
**Branch sugerida:** `agent/se348-resiliencia-baseline`
**Estimacion total:** ~12h (4 slices)
**Inspiracion:** Análisis operativo 2026-08-28 — 4 ideas sobre bucle predicción→error→actualización, ruido vs variabilidad funcional, DEPD/T_rec como métrica de resiliencia, y criterio 7 de falsabilidad (baseline simple). Autor del análisis: Savia. Criterio humano aplicable: CRIT-001 (datos N3+ jamás salen a proveedor cloud).

---

## Contexto y evidencia (2026-08-28)

La operadora pidió analizar 4 ideas de ingeniería de resiliencia adaptativa y su
aplicación a Savia. Resultado del análisis (con verificación de código):

| Idea | Hallazgo en Savia | Veredicto |
|---|---|---|
| **1. η = f(P_error)** — pesar la corrección según fiabilidad de la señal de error | `scripts/agent-run-logger.sh` (SE-148) registra `tool_status` con statuses `ok|error|skipped|blocked|timeout|aborted`, pero **sin timestamp por evento y sin peso de fiabilidad**. Un timeout pesa igual que una validación de esquema fallida. | Útil como extensión de telemetría |
| **2. Ruido vs variabilidad funcional** | Fail-safe de autonomous-safety aborta tras "misma acción 3+ veces" sin distinguir loop disfuncional de exploración adaptativa. `agent-run-report.sh` calcula error rate pero no clasifica. | Gap real en reporte |
| **3. DEPD / T_rec** | Los audit logs (`output/agent-runs/*-audit.log`) tienen timestamp inicio/fin, pero **no existe T_rec** (tiempo de recuperación tras perturbación) porque `tool-call` no guarda `ts`. | Gap real en telemetría |
| **4. Criterio 7 — baseline simple** | `scripts/eval-ablation-run.sh` (SE-030-A) ya implementa ablatión para capas GraphRAG (`retrieval|reasoning|generation|graph`). **No existe un test de baseline genérico** para capas de coordinación multiagente (orquestadores, tribunales) ni política formal. | Gap real + política ausente |

**Dato clave**: `data/agent-actuals.jsonl` (log real de `agent-run-logger.sh`) no
existe aún en producción; solo el example. La extensión del schema es
backward-compatible y no rompe nada existente.

**CRIT-001**: todo el análisis y las métricas se computan en local
(`data/`, `output/`, scripts bash/python stdlib). No hay telemetría a proveedor
cloud. Si en el futuro el DEPD/T_rec se alimentara de un proveedor externo,
entra en conflicto directo con CRIT-001 y se descarta.

---

## Objetivo

Materializar las 4 ideas en telemetría local, reporte y política, sin añadir
dependencias ni salidas a cloud:

1. **S1 — Señal de error ponderada (idea 1)**: cada tool-call registra `ts`
   (timestamp) y `reliability` (fiabilidad de la señal de error según status).
   La tasa de corrección η = f(P_error) queda explícita: no reaccionar igual
   ante un timeout (posible ruido de infra) que ante un error de validación.
2. **S2 — Clasificación ruido vs variabilidad + T_rec (ideas 2 y 3)**: nuevo
   script `resilience-report.sh` que por run/agente emite error rate, errores
   consecutivos máximos, T_rec (recuperación), weighted error score y
   `variance_class` (nominal | exploratory | dysfunctional | external).
3. **S3 — Test de baseline de capa (criterio 7)**: nuevo script
   `layer-baseline-test.sh` genérico que decide si una capa de coordinación
   justifica su complejidad frente a un baseline más simple, con ajuste por
   coste. + política documental `docs/rules/domain/layer-baseline-test.md`.
4. **S4 — Integración**: doc de regla, actualización del spec a IMPLEMENTED,
   regeneración de `docs/propuestas/INDEX.md`, tests BATS.

## Out of scope

- NO crear dashboards Grafana/Prometheus nuevos — se emite JSON consumible por
  cualquier dashboard existente.
- NO tocar `agent-run-report.sh` (se mantiene; el reporte de resiliencia es
  complementario).
- NO modificar el schema v1 legacy (`spec_id` records) — coexistencia intacta.
- NO instrumentar hooks nuevos en `.opencode/hooks/` — solo scripts invocables.
- NO tocar la detección de loops existente (`auto-loop-gate.sh`,
  `loop-budget-check.sh`, `repeat-tool-guard.py`).
- NO reescribir `eval-ablation-run.sh` — `layer-baseline-test.sh` es un
  complemento genérico, no un reemplazo.

---

## Diseno

### S1 — Señal de error ponderada en agent-run-logger

Fichero modificado: `scripts/agent-run-logger.sh`.

Extender `cmd_tool_call` para que, además de `tools_invoked` y `tool_status`
(que se mantienen intactos para backward-compat), registre:

- `tool_events`: array append-only de eventos, preservando orden temporal.
  Cada evento: `{"tool": "<t>", "status": "<s>", "ts": "<ISO8601Z>", "reliability": <n>}`.
- `error_reliability`: mapa estático por status (fiabilidad de la señal de error):

| status | reliability | razón |
|---|---|---|
| `ok` | `0.0` | no es señal de error |
| `skipped` | `0.0` | decisión deliberada, no error |
| `error` | `0.9` | señal más fiable de fallo real |
| `blocked` | `0.5` | señal de política — a veces legítima |
| `timeout` | `0.2` | puede ser ruido de infraestructura |
| `aborted` | `0.2` | corte de seguridad, no fallo de razonamiento |

En el `start` se añade `tool_events: []` al record inicial.

Backward-compat: los records existentes sin `tool_events` siguen siendo válidos;
`resilience-report.sh` trata la ausencia como "sin eventos temporales".

### S2 — resilience-report.sh

Fichero nuevo: `scripts/resilience-report.sh` (bash + jq; sin deps externas).

Subcomandos:
- `summary` — tabla por agente: runs, calls, error_rate, weighted_error,
  max_consec_errors, t_rec_s (mediana), variance_class dominante.
- `detail <run_id>` — todas las métricas de un run + desglose por tool.
- `--json` — output JSON (para dashboards/grafana).
- `--agent <nombre>` — filtro.

Métricas por run (definiciones exactas):

| métrica | definición |
|---|---|
| `calls` | `length(tool_events)` si existe; si no, `tools_invoked` total |
| `error_rate` | nº de eventos con `status != ok && status != skipped` / `calls` |
| `weighted_error` | Σ `reliability` de eventos no-ok / `calls` (rango 0..0.9) |
| `max_consec_errors` | racha máxima de eventos no-ok consecutivos (sin un `ok` entre medias) |
| `t_rec_s` | mediana sobre rachas: por cada racha de ≥1 no-ok seguida de un `ok`, tiempo `ts(ok) − ts(primer no-ok de la racha)` en segundos. `null` si no hay eventos con `ts` o no hay recuperación |
| `recovered` | `true` si `run_status == completed` y hubo ≥1 no-ok y ≥1 `ok` posterior |
| `variance_class` | `nominal` si completed sin no-ok; `exploratory` si completed con no-ok (se recuperó — variabilidad adaptativa); `dysfunctional` si run aborted/timeout/error con ≥1 no-ok previo; `external` si aborted/timeout/error sin no-ok previo |

Regla de alerta derivada (idea 2): un run `exploratory` NO es incidente; un run
`dysfunctional` sí. Los dashboards deben alertar sobre `dysfunctional` +
`weighted_error > umbral`, no sobre variación de rutas.

Exit code: 0 siempre (informativo). Error de input → exit 2.

### S3 — layer-baseline-test.sh + política

Fichero nuevo: `scripts/layer-baseline-test.sh`.

Formaliza el criterio 7 ("si el sistema complejo no supera a un baseline más
simple, no aporta valor") como test reutilizable:

```
layer-baseline-test.sh --full-metrics FULL.json --baseline-metrics BASE.json \
  [--cost-multiplier N] [--min-delta X] [--json]
```

- `--full-metrics`: métricas del sistema completo (con la capa).
- `--baseline-metrics`: métricas del baseline simple (agente único, sin capa,
  capa ablated).
- Computa delta medio `full − baseline` sobre las métricas numéricas comunes a
  ambos ficheros (ignora `null`/strings).
- `--cost-multiplier` (default `1.0`): el umbral efectivo es
  `min_delta × cost_multiplier`. Justifica latencia/coste extra de la capa:
  si la capa cuesta 2x, debe ganar 2x.
- Decisión: `JUSTIFIED` si `avg_delta ≥ threshold_effective` (exit 0);
  `UNJUSTIFIED` si no (exit 1); error de input → exit 2.
- `--json` emite `{avg_delta, threshold, status, deltas:[...]}`.

Fichero nuevo: `docs/rules/domain/layer-baseline-test.md` — política que exige:
- Toda capa de coordinación nueva (orquestador, tribunal, skill multiagente)
  DEBE pasar el test de baseline antes de aprobarse (gate en spec).
- Define la tabla de fiabilidad de señales de error (η = f(P_error)).
- Define la clasificación de variabilidad (nominal/exploratory/dysfunctional/
  external) y la regla de alerta (solo `dysfunctional` + umbral es incidente).
- CRIT-001: métricas y evals siempre en local.

### S4 — Integración y registro

- Actualizar `docs/propuestas/SE-348-*.md` a `status: IMPLEMENTED` al cerrar.
- Regenerar `docs/propuestas/INDEX.md` (`bash scripts/propuestas-index-gen.sh`).
- Sin hooks nuevos → no tocar `.claude/settings.json` ni `docs/hooks-coverage-matrix.md`.

---

## Criterios de aceptacion

### AC-S1: Señal ponderada

- [ ] AC-S1.1: `tool-call <run_id> bash error` produce evento en `tool_events` con `ts` ISO8601Z y `reliability == 0.9`.
- [ ] AC-S1.2: `tool-call <run_id> bash timeout` produce `reliability == 0.2`.
- [ ] AC-S1.3: `tool-call <run_id> read ok` produce `reliability == 0.0` y no cuenta como error.
- [ ] AC-S1.4: `start` inicializa `tool_events: []`.
- [ ] AC-S1.5: `tools_invoked` y `tool_status` se mantienen (backward-compat).
- [ ] AC-S1.6: el orden de `tool_events` refleja el orden de invocación.

### AC-S2: resilience-report

- [ ] AC-S2.1: run `completed` con `error;ok` → `variance_class == exploratory`, `recovered == true`, `t_rec_s != null`.
- [ ] AC-S2.2: run `error` (finish) con `error` previo → `variance_class == dysfunctional`.
- [ ] AC-S2.3: run `aborted` sin no-ok previo → `variance_class == external`.
- [ ] AC-S2.4: run completed sin errores → `nominal`, `recovered == false`.
- [ ] AC-S2.5: `weighted_error` calcula Σ reliability / calls (ej: 1 error + 1 ok → 0.45).
- [ ] AC-S2.6: `max_consec_errors` detecta rachas (ej: ok,error,error,ok → 2).
- [ ] AC-S2.7: `--json` emite JSON parseable con los campos del schema.
- [ ] AC-S2.8: log vacío → exit 0 con output vacío/sin rows.
- [ ] AC-S2.9: records legacy (sin `tool_events`) no rompen el reporte.

### AC-S3: layer-baseline-test

- [ ] AC-S3.1: full=0.80, baseline=0.70, min-delta=0.05 → `JUSTIFIED` (delta 0.10 ≥ 0.05), exit 0.
- [ ] AC-S3.2: full=0.72, baseline=0.70, min-delta=0.05 → `UNJUSTIFIED` (delta 0.02 < 0.05), exit 1.
- [ ] AC-S3.3: con `--cost-multiplier 2.0`, full=0.80/baseline=0.70 y min-delta 0.05 → `UNJUSTIFIED` (umbral efectivo 0.10, delta 0.10 < 0.10? → borderline: usar umbral estricto `>`; test fija delta 0.11 → JUSTIFIED y delta 0.10 → UNJUSTIFIED).
- [ ] AC-S3.4: ficheros inexistentes → exit 2 con mensaje.
- [ ] AC-S3.5: `--json` emite `{avg_delta, threshold, status, deltas}`.
- [ ] AC-S3.6: métricas con `null` se ignoran (no rompen el cálculo).

### AC-S4: Integración

- [ ] AC-S4.1: `docs/rules/domain/layer-baseline-test.md` existe y referencia los 3 scripts.
- [ ] AC-S4.2: spec pasa a `status: IMPLEMENTED` y `docs/propuestas/INDEX.md` regenerado.
- [ ] AC-S4.3: sección `## OpenCode Implementation Plan` presente en la spec (ver abajo).

---

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `scripts/agent-run-logger.sh` (extendido) | bash, igual | bash, igual |
| `scripts/resilience-report.sh` (nuevo) | bash + jq | bash + jq |
| `scripts/layer-baseline-test.sh` (nuevo) | bash + python3 stdlib | bash + python3 stdlib |
| `docs/rules/domain/layer-baseline-test.md` (nuevo) | doc | doc |
| tests BATS | `tests/` | `tests/` |

### Verification protocol

- [ ] Funciona en runtime OpenCode (scripts bash independientes del motor — sin hooks)
- [ ] Tests BATS pasan (`bash tests/run-all.sh` o ficheros individuales)
- [ ] No añade hooks → no requiere registro en plugin `savia-gates`

### Portability classification

- [x] **PURE_BASH**: lógica en bash + python3 stdlib, sin bindings de frontend,
      runs idéntico en cualquier motor.

---

## Ref

- Savia: `scripts/agent-run-logger.sh` (SE-148), `scripts/agent-run-report.sh`,
  `tests/test-agent-run-logger.bats`, `scripts/eval-ablation-run.sh` (SE-030-A),
  `docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md`,
  `docs/rules/domain/autonomous-safety.md` (fail-safes de loop).
- Conceptos: bucle predicción→error→actualización (ReAct/reflection),
  DEPD (detector de error dinámico: persistencia, autocorrelación, T_rec),
  criterio 7 de falsabilidad de sistemas complejos.

---

## Plan de implementación propuesto

| Slice | Prioridad | Depende de | Estimación |
|---|---|---|---|
| S1 señal ponderada | alta | — | 2h |
| S2 resilience-report | alta | S1 | 4h |
| S3 baseline-test + política | media | — | 3h |
| S4 integración + tests | media | S1-S3 | 3h |

Orden: S1 → S2 → S3 → S4. Tests BATS en `tests/test-resilience-report.bats`,
`tests/test-layer-baseline-test.bats`, extensión de
`tests/test-agent-run-logger.bats`.

## Implementación (2026-08-28)

- `scripts/agent-run-logger.sh` — `tool_events` (append-only con `ts` ISO8601Z
  y `reliability` por status: error 0.9, blocked 0.5, timeout/aborted 0.2,
  ok/skipped 0.0) + `_reliability_for()`. Backward-compat: `tools_invoked` y
  `tool_status` intactos; records legacy sin `tool_events` siguen válidos.
- `scripts/resilience-report.sh` — `summary`/`detail <run_id>`, `--json`,
  `--agent`. Emite error_rate, weighted_error, max_consec_errors, t_rec_s,
  recovered (booleano), variance_class (nominal/exploratory/dysfunctional/
  external/in_progress). Exit 0 informativo, 2 input error.
- `scripts/layer-baseline-test.sh` — criterio 7: JUSTIFIED si avg_delta
  STRICTO > min_delta × cost_multiplier; `--json`; ignora métricas null/strings.
- `docs/rules/domain/layer-baseline-test.md` — política (criterio 7 como gate
  en specs, tabla de fiabilidad η = f(P_error), regla de alerta
  ruido-vs-variabilidad, T_rec).
- Tests BATS: 10 nuevos en `test-agent-run-logger.bats`, 11 en
  `test-resilience-report.bats`, 6 en `test-layer-baseline-test.bats`.
  **43/43 verdes** (bats-core 1.11.0 local en /tmp).
- CRIT-001: todo local (`data/`, `scripts/`, `docs/`), sin telemetría cloud.
