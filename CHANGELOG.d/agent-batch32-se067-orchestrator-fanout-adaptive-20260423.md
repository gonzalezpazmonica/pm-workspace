# Batch 32 — SE-067 orchestrator fan-out + feasibility-probe adaptive thinking

**Date:** 2026-04-23
**Version:** 5.79.0 (batch combinado 31-35)

## Summary

Opus 4.7 es mas judicious sobre delegar a subagents (vs 4.6). Orchestrators de Savia ya asumian spawn paralelo pero sin prompt explicito. Separadamente, feasibility-probe usaba `budget_tokens: 50000` fijo, deprecated en 4.7.

## Cambios

### A. Orchestrators con Fan-Out Policy
`Subagent Fan-Out Policy (SE-067)` block anadido a 3 orchestrators:
- dev-orchestrator
- court-orchestrator
- truth-tribunal-orchestrator

Instruccion: spawn multiples subagents en el MISMO turno cuando fanning-out across independent items. NO spawn para work completable en single response.

### B. feasibility-probe adaptive thinking
`.claude/skills/feasibility-probe/SKILL.md` — fila `budget_tokens` eliminada. Documenta adaptive thinking + hint phrases para steer rate ("Think carefully..." vs "Respond quickly...").

## Validacion

- `scripts/opus47-compliance-check.sh --fan-out --adaptive-thinking`: PASS
- 3/3 orchestrators marcados `SE-067`
- feasibility-probe SKILL.md sin fila `budget_tokens`
