---
context_tier: L2
token_budget: 700
se: SE-205
created: 2026-06-07
source: output/research/orca-savia-20260607.md §7.1
usage: reference-only
dormant_since: "2026-06-24"
review_note: "Quarterly review 2026-Q2"
---

# Orchestration Protocol — SE-205

Protocolo de mensajería tipada para coordinación multi-agente. Reemplaza handoffs de texto libre en flujos con 4+ agentes paralelos (court-orchestrator, dev-orchestrator).

CLI: `bash scripts/orchestration-protocol.sh <subcommand>`

---

## Tipos de mensaje

| Tipo | Cuándo usarlo |
|---|---|
| `worker_done` | El agente completa su tarea asignada. Siempre incluye `filesModified` y `summary_3sentences`. |
| `escalation` | El agente encuentra un bloqueo que no puede resolver solo. Requiere intervención del coordinador o humano. |
| `heartbeat` | Para tareas >15 min: señal de vida cada 10 min. Evita que el coordinador asuma timeout. |
| `decision_gate` | El DAG necesita una decisión (técnica o humana) antes de continuar. Bloquea el pipeline hasta respuesta. |
| `handoff` | Transferencia de contexto entre agentes sin esperar respuesta (broadcasting). |

---

## Formato canónico worker_done

```json
{
  "msgId": "<m-hex8>",
  "type": "worker_done",
  "taskId": "<hex8>",
  "dispatchId": "<d-hex8>",
  "summary": "Sentence 1: qué hice. Sentence 2: qué encontré. Sentence 3: qué queda pendiente.",
  "filesModified": ["path/to/file.ts", "path/to/other.ts"],
  "status": "completed",
  "read": false,
  "createdAt": "2026-06-07T09:00:00Z"
}
```

**Regla**: `summary` exactamente 3 frases. Sin más, sin menos.

---

## Ciclo de vida de una task

```
pending → dispatched → completed
                     → failed      (manual o circuit breaker)
                     → blocked     (decision_gate sin respuesta)
```

---

## Circuit breaker

Tras **3 mensajes `worker_done` con `status: failed`** sobre el mismo `taskId`, la task se marca automáticamente `failed`. El coordinador recibe notificación `CIRCUIT_BREAKER` en stdout.

Equivalente al `AGENT_MAX_CONSECUTIVE_FAILURES=3` de `autonomous-safety.md` pero a nivel de mensaje tipado, no de proceso.

---

## Almacenamiento

Ficheros JSON en `.savia/orchestration/`:
- `task-{id}.json` — estado de cada task
- `msg-{id}.json` — mensajes enviados

Override en tests: `SAVIA_ORCA_DB_DIR=/tmp/...`

---

## Integración con DAG scheduling

`dag-scheduling/SKILL.md` usa waves (cohortes paralelas). Cada wave puede usar este protocolo:
1. Coordinador crea tasks con `--deps`
2. Dispatcha a agentes
3. Espera con `check --wait --types worker_done,escalation`
4. Avanza cuando todos los `worker_done` de la wave están presentes

---

## Diferencia con agent-notes

| Situación | Protocolo |
|---|---|
| Handoff simple ≤7 campos | `agent-handoff-protocol.md` |
| Research multi-turn, docs | `agent-notes-protocol.md` |
| Coordinación paralela 4+ agentes | **Este protocolo** (SE-205) |
