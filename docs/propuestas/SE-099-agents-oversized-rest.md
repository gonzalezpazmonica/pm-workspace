---
spec_id: SE-099
title: Split remaining 22 oversized agents (post top-5)
status: PARTIALLY_IMPLEMENTED
approved_by: operator (2026-05-27)
applied_at: 2026-06-24
lote_actual: 1
priority: P2
effort: L
estimated_time: 12h
depends_on: SE-098
---

# SE-099 — Split remaining oversized agents

Tras cerrar SE-098 (top-5), quedan 22 agents oversized. Mismo procedimiento, escala mayor.

## Solución

Lotes de 5 agents/semana hasta agotar la lista. Cada lote: plan → split → smoke test → CHANGELOG.

## Aceptación

- 0 agents oversized
- `agent-size-audit.sh` reporta violations=0
- Promedio catálogo <3500 B

## Progreso

### Lote 1 — 2026-06-24 (DONE)

| Agente | Antes | Después | Runbook skill |
|---|---|---|---|
| meeting-digest | 5958B | 2632B | meeting-digest-runbook |
| meeting-risk-analyst | 5954B | 2460B | meeting-risk-analyst-runbook |
| sdd-spec-writer | 5911B | 2558B | sdd-spec-writer-runbook |
| truth-tribunal-orchestrator | 5909B | 2757B | truth-tribunal-runbook |
| visual-digest | 5729B | 2219B | visual-digest-runbook |

### Pendiente — Lotes 2+

Agentes >4096B restantes: test-architect, dotnet-developer, business-analyst,
architect, terraform-developer, typescript-developer, frontend-developer,
word-digest, test-engineer, meeting-confidentiality-judge, y otros.
