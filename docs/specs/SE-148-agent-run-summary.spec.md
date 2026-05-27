# SE-148 — AgentRunSummary telemetry (schema v2)

**Status:** APPROVED
**Fecha:** 2026-05-27
**Área:** Telemetry / Agent observability
**Spike commit:** `03fb5b1c` — `spike/SE-148-agent-run-summary`

---

## Objetivo

Estandarizar la telemetría de ejecuciones de agentes en un schema JSONL v2
backward-compatible, con scripts de logging y reporting reutilizables.

---

## Contexto

El sistema actual no registra métricas de ejecución por agente de forma
estructurada. SE-148 define el contrato de datos y las herramientas para
producir y consumir esas métricas.

---

## Schema v2 (JSONL)

Cada línea es un objeto JSON con los siguientes campos:

| Campo | Tipo | Descripción |
|---|---|---|
| `schema_version` | `"2"` | Discriminador de versión |
| `run_id` | string | UUID de la ejecución |
| `agent` | string | Nombre del agente |
| `ts_start` | ISO-8601 | Timestamp de inicio |
| `ts_end` | ISO-8601 | Timestamp de fin |
| `tools_invoked` | string[] | Herramientas llamadas |
| `tools_unused` | string[] | Herramientas disponibles no usadas |
| `tool_status` | object | `{tool: "ok"|"error"|"timeout"}` |
| `models_used` | string[] | Modelos invocados |
| `tokens_in` | int | Tokens de entrada |
| `tokens_out` | int | Tokens de salida |
| `cost_usd` | float | Coste estimado en USD |
| `run_status` | string | `"ok"`, `"error"`, `"timeout"`, `"aborted"` |

**Backward-compat:** Registros v1 (sin `schema_version`) se leen como v1;
el report script los convierte on-the-fly al mostrar estadísticas.

---

## Scripts

### `scripts/agent-run-logger.sh`

```
agent-run-logger.sh log     --agent NAME --run-id UUID [opciones]
agent-run-logger.sh start   --agent NAME               → imprime run_id
agent-run-logger.sh finish  --run-id UUID --status ok|error|timeout|aborted
```

Escribe en `$AGENT_LOGS_DIR/{agent}-{YYYYMMDD}.jsonl`.

### `scripts/agent-run-report.sh`

```
agent-run-report.sh summary  [--agent NAME] [--since DATE]
agent-run-report.sh costs    [--agent NAME] [--since DATE]
agent-run-report.sh unused-tools [--top N]
agent-run-report.sh errors   [--since DATE]
```

Salida: tabla texto a stdout. Con `--json`: JSON estructurado.

---

## Acceptance Criteria

- AC-1: `agent-run-logger.sh log` escribe JSONL válido con todos los campos
  del schema v2 en la ruta `$AGENT_LOGS_DIR`.
- AC-2: `agent-run-logger.sh start` devuelve un UUID y `finish` cierra el
  registro con `run_status` correcto.
- AC-3: `agent-run-report.sh summary` agrega por agente: runs totales, tasa
  de error, tokens medios, coste acumulado.
- AC-4: `agent-run-report.sh costs` lista coste por agente ordenado desc.
- AC-5: `agent-run-report.sh unused-tools` identifica herramientas declaradas
  pero nunca invocadas en la ventana temporal.
- AC-6: El report lee ficheros v1 y v2 sin error; los v1 se procesan con
  campos ausentes como `null`.
- AC-7: Suite BATS ≥ 15 tests passing (estado spike: 15/15).

---

## OpenCode Implementation Plan

```yaml
spec: SE-148
type: telemetry-enhancement
risk: LOW
classification: additive — nuevos scripts, sin modificar código existente

slices:
  - id: S1
    name: schema-and-logger
    files:
      - scripts/agent-run-logger.sh
    ac: [AC-1, AC-2]
    effort: done (spike)

  - id: S2
    name: report-script
    files:
      - scripts/agent-run-report.sh
    ac: [AC-3, AC-4, AC-5, AC-6]
    effort: done (spike)

  - id: S3
    name: tests
    files:
      - tests/bats/SE-148-agent-run-summary.bats
    ac: [AC-7]
    effort: done (spike)

  - id: S4
    name: merge-to-main
    depends: [S1, S2, S3]
    action: >
      Merge spike/SE-148-agent-run-summary → main via PR.
      Verificar que AGENT_LOGS_DIR está en .gitignore.
    effort: 0.5h
```

---

## Referencias

- `docs/rules/domain/pm-config.md` → `AGENT_LOGS_DIR`, `AGENT_ACTUALS_LOG`
- `docs/rules/domain/autonomous-safety.md` → formato de audit logs
