---
context_tier: L3
token_budget: 850
---

# Dormant Rules Review — Q2 2026

Revision trimestral de reglas dormant del workspace.
Spec: SE-103 | Fecha: 2026-06-24 | Herramienta: scripts/rule-usage-analyzer.sh

---

## Contexto

rule-usage-analyzer.sh detecta 193 reglas en tier dormant (sin consumers en
los ultimos 90 dias) sobre un total de 245 ficheros en docs/rules/domain/.

Esta revision Q2 cubre 26 reglas agrupadas por categoria. Criterio: reglas
con nombre descriptivo claro, sin referencias en commands/agents/skills activos.

---

## Reglas marcadas como usage: reference-only

### Agent Protocols (10 reglas)

| Regla | Decision | Justificacion |
|---|---|---|
| agent-context-budget.md | keep | Referencia budget tokens para futuros agentes |
| agent-dispatch-checklist.md | keep | Checklist dispatch — guia, no activamente importado |
| agent-handoff-protocol.md | keep | Handoff format documentado en SE-121; referencia origen |
| agent-hook-protocol.md | keep | Protocolo hooks — referencia para nuevos hooks |
| agent-idle-protocol.md | keep | Protocolo idle — referencia para modos autonomos |
| agent-memory-isolation.md | keep | Isolation memoria — necesario en escenario multi-agent |
| agent-memory-protocol.md | keep | Protocolo memoria — referencia base de savia-memory skill |
| agent-observability-patterns.md | keep | Patrones observabilidad — referencia para SE-219 abtop |
| agent-permission-levels.md | keep | Niveles permiso L0-L4 documentados aqui + en agentes |
| agent-prompt-xml-structure.md | keep | Estructura XML prompts — referencia para SE-068 |

### Context Management (5 reglas)

| Regla | Decision | Justificacion |
|---|---|---|
| context-budget.md | keep | Referencia base de SPEC-156 token budgets |
| context-aging.md | keep | Referencia para SE-163 dream cycle |
| context-condenser-protocol.md | keep | Referencia para context-rot-strategy skill |
| context-drop-after-use.md | keep | Referencia para SPEC-193 context provenance |
| context-health.md | keep | Referencia para workspace-integrity skill |

### Code Review (2 reglas)

| Regla | Decision | Justificacion |
|---|---|---|
| code-review-court.md | keep | Referencia para court-orchestrator agent |
| code-review-rules.md | keep | Referencia para code-reviewer agent |

### Command/Workflow (3 reglas)

| Regla | Decision | Justificacion |
|---|---|---|
| command-validation.md | keep | Referencia para pre-output hooks |
| component-marketplace.md | archive-candidate | Sin demanda Q2; revisar Q3 |
| eval-policy.md | keep | Referencia para evaluations-framework skill |

### Misc Reference (6 reglas)

| Regla | Decision | Justificacion |
|---|---|---|
| example-patterns.md | keep | Referencia para sdd-spec-writer |
| fork-agent-protocol.md | keep | Referencia para dag-scheduling skill |
| lightweight-eng-review.md | keep | Fast path referencia para code-reviewer |
| meeting-participant-etiquette.md | keep | Referencia para meeting-digest agent |
| nl-command-resolution.md | keep | Referencia para smart-routing skill |
| orchestration-protocol.md | keep | Referencia para dag-scheduling skill |

---

## Resumen

| Accion | Cantidad |
|---|---|
| Marcadas usage: reference-only | 26 |
| Decision keep | 25 |
| Decision archive-candidate (Q3) | 1 |
| Pendiente auditar (Q3) | ~167 |

---

Reviewed 2026-06-24
Spec SE-103 — Quarterly dormant rules review — Q2 2026
