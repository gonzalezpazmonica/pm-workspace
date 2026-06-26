# Agent Notes — Protocolo de Memoria Inter-Agente

> Inspirado en el modelo de Miguel Palacios: bitácoras como memoria persistente entre sesiones y entre agentes.

---

## Concepto

Cada agente que produce un entregable durante un flujo SDD (o cualquier flujo multi-agente) escribe un fichero en `agent-notes/` del proyecto. El siguiente agente en la cadena **DEBE** leer las notas previas antes de actuar.

Las agent-notes son la memoria compartida del equipo de agentes. Sin ellas, cada sesión empieza de cero.

---

## Estructura

```
projects/{proyecto}/agent-notes/
├── {ticket}-legacy-analysis-{fecha}.md       ← @miguel.legacy / business-analyst
├── {ticket}-architecture-decision-{fecha}.md ← architect
├── {ticket}-test-strategy-{fecha}.md         ← test-engineer
├── {ticket}-security-checklist-{fecha}.md    ← security-guardian
├── {ticket}-implementation-log-{fecha}.md    ← {lang}-developer
└── {ticket}-review-findings-{fecha}.md       ← code-reviewer
```

### Convención de nombres

```
{ticket}-{tipo}-{fecha}.md

ticket  = AB1234 | PBI5678 | SPIKE-003 (referencia Azure DevOps)
tipo    = legacy-analysis | architecture-decision | test-strategy |
          security-checklist | implementation-log | review-findings |
          pm-validation | sprint-summary
fecha   = YYYY-MM-DD
```

---

## Metadata YAML (obligatoria)

Cada agent-note comienza con frontmatter YAML:

```yaml
---
ticket: AB#1234
phase: 2
agent: architect
status: completed          # draft | in-progress | completed | superseded
depends_on:                # notas que este agente leyó antes de producir esta
  - AB1234-legacy-analysis-2026-02-27.md
tags: [architecture, adr, clean-architecture]
created: 2026-02-27
---
```

---

## Flujo SDD con Agent Notes

```
1. business-analyst → escribe: {ticket}-legacy-analysis-{fecha}.md
       ↓ (lee: PBI padre, backlog, código existente)
2. architect        → escribe: {ticket}-architecture-decision-{fecha}.md
       ↓ (lee: legacy-analysis)
3. security-guardian → escribe: {ticket}-security-checklist-{fecha}.md
       ↓ (lee: architecture-decision, spec)
4. test-engineer    → escribe: {ticket}-test-strategy-{fecha}.md
       ↓ (lee: architecture-decision, security-checklist, spec)
5. {lang}-developer → escribe: {ticket}-implementation-log-{fecha}.md
       ↓ (lee: TODAS las notas previas + spec)
6. code-reviewer    → escribe: {ticket}-review-findings-{fecha}.md
       ↓ (lee: implementation-log, spec, test-strategy)
```

Cada agente documenta: qué leyó, qué decidió, qué produjo, y qué queda pendiente.

---

## Cuándo escribir agent-notes

- **Siempre** en flujo SDD (spec-generate → agent-run → spec-review)
- **Siempre** en flujo de infraestructura (infra-detect → infra-plan → infra-estimate)
- **Siempre** en auditorías (project-audit, legacy-assess, security audit por feature)
- **Opcional** en operaciones rutinarias (sprint-status, report-hours)

---

## Cuándo leer agent-notes

Antes de ejecutar, cada agente busca notas previas del mismo ticket:

```bash
ls projects/{proyecto}/agent-notes/{ticket}-*.md 2>/dev/null
```

Si existen, las lee como contexto. Si no, procede con el contexto estándar (spec, código, reglas).

---

## Limpieza

Las agent-notes de sprints cerrados se archivan en `agent-notes/archive/{sprint}/` al final de cada sprint review. El PM puede archivar manualmente con `/agent-notes-archive`.

---

## Cuándo usar agent-notes vs handoff-as-function

SPEC-121 introduce `handoff-as-function` como protocolo ligero para transiciones simples E1→E2→E3→E4:

| Situación | Protocolo | Documento |
|---|---|---|
| Handoff simple con artefactos claros (≤7 campos) | **handoff-as-function** | `docs/rules/domain/agent-handoff-protocol.md` |
| Research multi-turn, decisión compleja, discusión | **agent-notes** (este doc) | `docs/agent-notes-protocol.md` |
| Broadcasting a múltiples agentes | **agent-notes** (este doc) | `docs/agent-notes-protocol.md` |

**Regla práctica**: si el handoff cabe en 7 campos YAML, usa `handoff-as-function`. Si necesitas párrafos explicativos, análisis de contexto o múltiples receptores, usa agent-notes.

Validación de handoff-as-function: `bash scripts/validate-handoff.sh --file handoff.yaml`.

---

## Message Schema (SPEC-056)

Agent messages exchanged via the Task tool can optionally be structured as
typed `AgentMessage` objects for auditability, routing, and multimodal support.

**Schema validator**: `scripts/agent-message-schema.py`

```bash
# Validate a JSON message file
python3 scripts/agent-message-schema.py --validate msg.json   # exit 0 if valid

# Print the full JSON Schema
python3 scripts/agent-message-schema.py --schema

# Print a valid example message
python3 scripts/agent-message-schema.py --example
```

### Example valid message

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "sender": "dotnet-developer",
  "receiver": "code-reviewer",
  "role": "assistant",
  "content_blocks": [
    {
      "type": "text",
      "content": "Implementation complete. 3 files modified.",
      "metadata": {}
    },
    {
      "type": "result",
      "content": "42/42 tests passed",
      "metadata": {"tool": "dotnet test", "status": "pass"}
    },
    {
      "type": "code",
      "content": "public class UserService { ... }",
      "metadata": {"language": "csharp", "path": "src/UserService.cs"}
    }
  ],
  "ts": "2026-03-30T10:00:00Z",
  "session_id": "session-abc-123"
}
```

### ContentBlock types

| Type | Use case |
|------|----------|
| `text` | General communication |
| `code` | Code snippets with language metadata |
| `result` | Test results, build output, tool results |
| `error` | Structured error reporting with suggestion |
| `decision` | Architecture or design decisions |

When an agent produces output that will be passed to another agent, wrapping
it in an `AgentMessage` enables automated audit trail reconstruction and
cross-agent type safety. Use for flows with ≥3 agents or when the output
includes mixed content (code + test results + decision).

---

## Integracion con Orchestration Protocol (SE-205)

Para flujos con 4+ agentes en paralelo (court-orchestrator, dev-orchestrator
coordinando multiples workers), las agent-notes de texto libre son insuficientes.
Usar `scripts/orchestration-protocol.sh` como capa de mensajeria tipada.

| Dimension | Agent Notes | Orchestration Protocol (SE-205) |
|---|---|---|
| Formato | Markdown libre con frontmatter YAML | JSON tipado, schema fijo |
| Persiste entre sesiones | Si (ficheros en `agent-notes/`) | Si (`.savia/orchestration/`) |
| Circuit breaker | No | Si: 3 fallos -> task=failed |
| Task states verificables | No | Si: pending/dispatched/completed/failed/blocked |
| Heartbeat para tareas largas | No | Si: tipo `heartbeat` |
| Para uso en | Documentacion de decisiones | Coordinacion runtime de agentes paralelos |

Flujo combinado recomendado:
1. Agente escribe agent-note con contexto y decisiones (persistencia larga)
2. Coordinador usa `orchestration-protocol.sh send --type worker_done` para senalar completitud (runtime)

Referencia completa: `docs/rules/domain/orchestration-protocol.md`
CLI: `bash scripts/orchestration-protocol.sh --help`
