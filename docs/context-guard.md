# Context Guard — Gestión automática de contexto agéntico

> **Estado:** Slice 2 completado (Slice 1: Monitor + Summarizer; Slice 2: MCP server + CLI + Recall + Flows).
> **Spec:** `docs/specs/SPEC-CONTEXT-GUARD.spec.md`
> **Decisión D-6:** Implementación Python. Bash solo envoltorio (Rule #26).

---

## Qué resuelve

Cuando un agente o flow acumula un contexto muy largo ocurren tres problemas:

1. El modelo pierde atención sobre instrucciones tempranas.
2. El coste por token sube linealmente con cada nodo del flow.
3. OpenCode acaba truncando de forma opaca, sin alineación con las convenciones Savia.

Context Guard introduce una capa propia que opera **antes** del truncamiento de OpenCode: cuando el contexto supera un umbral configurable, resume automáticamente los turnos antiguos, persiste el summary con metadata estructurada, y deja intactos los turnos recientes.

---

## Arquitectura

```
scripts/lib/context_guard/
  __init__.py       — API pública (Slice 1)
  monitor.py        — Mide tokens, decide cuándo disparar
  tokenizer.py      — Wrapper tiktoken con fallback word-count
  summarizer.py     — Invoca context-summarizer, valida summary_v1
  store.py          — Persiste summaries en output/context-guard/
  mcp_server.py     — MCP server savia-context-guard (Slice 2)
  cli.py            — CLI: recall / list / summarize

scripts/context-guard-recall.sh     — Bash wrapper (≤15 líneas)
.opencode/hooks/context-guard-monitor.{sh,ts}  — Hooks OpenCode
.opencode/agents/context-summarizer.md         — Agente de summarización
.opencode/skills/context-guard-recall/SKILL.md — Guía de uso recall
schemas/summary-v1.schema.json                 — JSON Schema del summary
```

---

## Configuración por agente

```yaml
---
name: long-running-researcher
context_guard:
  enabled: true
  threshold_pct: 75       # dispara al 75% del context window
  recent_turns: 5         # preserva últimos 5 turnos intactos
  summarizer_tier: fast   # fast | mid | heavy
  preserve_artifacts: true
---
```

**Hard floor:** `threshold_pct` mínimo 50%. Valores menores causan loops de summarización.

---

## Configuración por flow (con override por nodo)

```yaml
flow_id: long-research-flow
context_guard:
  enabled: true
  threshold_pct: 70
  recent_turns: 3
  summarizer_tier: fast
nodes:
  - id: deep-search
    kind: agent
    invoke: researcher
    context_guard: { recent_turns: 10 }   # override por nodo
```

---

## Formato summary_v1

Todos los summaries siguen la estructura canónica `summary_v1`. No es solo prosa — incluye metadata recuperable:

```yaml
summary_v1:
  turn_count: 12
  time_span:
    first_turn_at: "2026-05-09T10:00:00Z"
    last_turn_at: "2026-05-09T10:45:00Z"
  key_decisions:
    - "Elegido SQLAlchemy 2.0 async sobre Tortoise ORM"
  artifacts_produced:
    - { id: "spec-001", kind: "spec", location: "docs/specs/FOO.spec.md" }
  errors_encountered: []
  tools_invoked:
    - { name: "Read", count: 8 }
  prose_summary: |
    El agente analizó el codebase, seleccionó la capa de persistencia...
_meta:
  run_id: "my-flow-run-001"
  index: 1
  tier_used: "fast"
  retried: false
  tokens_before: 18400
  tokens_after: 312
  confidentiality: "N1"
  saved_at: "2026-05-09T10:46:00Z"
```

Schema completo: `schemas/summary-v1.schema.json`.

---

## Almacenamiento

```
output/context-guard/{run_id}/summary-001.yaml
output/context-guard/{run_id}/summary-002.yaml
output/context-guard/{run_id}/trace.jsonl
```

**Confidencialidad (Spec §2.8):** Si el flow es N4 o N4b, los summaries van bajo:

```
output/context-guard/N4/{run_id}/...
```

Los hooks de data-sovereignty existentes los protegen automáticamente.

---

## Confidencialidad — reglas de acceso

| Nivel caller | Accede N1 | Accede N2 | Accede N3 | Accede N4/N4b |
|---|---|---|---|---|
| N1 | Sí | No | No | No |
| N2 | Sí | Sí | No | No |
| N3 | Sí | Sí | Sí | No |
| N4 | Sí | Sí | Sí | Sí |
| N4b | Sí | Sí | Sí | Sí |

Violación devuelve `403 Forbidden`. Nunca silencioso.

---

## MCP Server — savia-context-guard

El servidor MCP expone dos tools:

### `summarize`

```json
{
  "turns": [...],
  "run_id": "mi-run",
  "threshold_pct": 75,
  "recent_turns": 5,
  "tier": "fast",
  "confidentiality": "N1",
  "caller_confidentiality": "N1",
  "force": false
}
```

Devuelve `triggered: true/false`, `summary_id`, tokens antes/después, y el summary completo.

### `recall_summary`

```json
{
  "run_id": "mi-run",
  "summary_id": "summary-001",
  "caller_confidentiality": "N1"
}
```

Devuelve el summary YAML completo. Si `summary_id` se omite, devuelve el más reciente.

**Arrancar el servidor:**

```bash
python3 -m scripts.lib.context_guard.mcp_server
```

---

## CLI

```bash
# Recuperar último summary de un run
python3 -m scripts.lib.context_guard.cli --base-dir output/context-guard recall mi-run

# Recuperar summary específico
python3 -m scripts.lib.context_guard.cli recall mi-run --summary-id summary-001 --caller-level N1

# Listar summaries de un run
python3 -m scripts.lib.context_guard.cli list mi-run

# Forzar summarización desde fichero JSON de turnos
python3 -m scripts.lib.context_guard.cli summarize mi-run --turns-file turns.json --force

# Wrapper Bash
bash scripts/context-guard-recall.sh mi-run [--summary-id summary-001] [--caller-level N1]
```

---

## Hooks OpenCode

Los hooks se instalan en `.opencode/hooks/`:

- `context-guard-monitor.sh` — Variante Bash (SPEC-127, portabilidad multi-frontend).
- `context-guard-monitor.ts` — Variante TypeScript para OpenCode v1.14+.

Ambos son no-bloqueantes: si el agente no declara `context_guard.enabled: true`, el hook sale sin hacer nada.

---

## Traza de eventos

Cada summarización escribe un evento en `trace.jsonl`:

```json
{
  "event": "context.summarized",
  "run_id": "mi-run",
  "summary_id": "summary-001",
  "tokens_before": 18400,
  "tokens_after": 312,
  "summarizer_tier": "fast",
  "retried": false,
  "confidentiality": "N1",
  "ts": "2026-05-09T14:30:00Z"
}
```

---

## Degradación controlada

| Condición | Comportamiento |
|---|---|
| `tiktoken` no instalado | Warning explícito + fallback word-count (±20%). Context Guard sigue funcionando. |
| `context-summarizer` devuelve YAML malformado | Reintento con tier elevado (fast→mid→heavy). Si falla de nuevo: `SummarizationError` explícito en stderr + traza. **Nunca silencioso.** |
| `threshold_pct < 50` | `ValueError` en validación del config. Hard floor para prevenir loops. |
| Summary N3 accedido desde N1 | `403 Forbidden`. Never silent. |

### Reintento por tier (escalado ante YAML malformado)

Cuando `context-summarizer` devuelve un bloque que no pasa la validación
`summary_v1` (schema `schemas/summary-v1.schema.json`), el `summarizer.py`
reintenta con el siguiente nivel de modelo:

```
Intento 1: tier configurado (ej. "fast")
Intento 2: "mid"   (si fast falló)
Intento 3: "heavy" (si mid  falló)
Intento 4: SummarizationError — mensaje en stderr + evento trace.jsonl con retried=true
```

El campo `_meta.retried` en el summary YAML indica si se escaló el tier.
El campo `_meta.tier_used` registra el tier que finalmente produjo el summary válido.

Este comportamiento es **siempre explícito**: nunca se persiste un summary
malformado ni se silencia el fallo. El agente upstream recibe el error y
puede decidir continuar sin summary o abortar el flow.

---

## Tests

```bash
# Pytest (48 tests: 29 Slice 1 + 19 Slice 2)
python3 -m pytest tests/python/test_context_guard*.py -q

# BATS (8 tests — wrappers Bash)
bats tests/context-guard-wrapper.bats
```

---

## Slices futuros

- Streaming de summarización incremental.
- Summary diff: detectar cambios entre summaries sucesivos.
- Auto-tuning de `threshold_pct` basado en histórico de runs.
- Integración OTel: span `savia.context.summarized` exportable (SPEC-FLOW-OBSERVABILITY).
- Soporte A2A: pasar summary a agentes externos sin exponer contexto completo.
