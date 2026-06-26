---
spec_id: SE-099
title: Split remaining 22 oversized agents (post top-5)
status: IMPLEMENTED
approved_by: operator (2026-05-27)
implemented_at: 2026-06-24
priority: P2
effort: L
estimated_time: 12h
depends_on: SE-098
source: output/20260527-auditoria-obsoleto-legado.md (Tier 3.8)
---

# SE-099 — Split remaining oversized agents

Tras cerrar SE-098 (top-5), quedan 22 agents oversized. Mismo procedimiento, escala mayor.

## Solución

Lotes de 5 agents/semana hasta agotar la lista. Cada lote: plan → split → smoke test → CHANGELOG.

## Aceptación

- 0 agents oversized
- `agent-size-audit.sh` reporta violations=0
- Promedio catálogo <3500 B
