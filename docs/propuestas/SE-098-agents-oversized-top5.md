---
spec_id: SE-098
title: Split top-5 oversized agents (Rule #22 violations)
status: IMPLEMENTED
approved_by: operator (2026-05-27)
applied_at: "2026-06-24"
priority: P1
effort: M
estimated_time: 4h
depends_on: SE-052 (agent-size-audit)
source: output/20260527-auditoria-obsoleto-legado.md (Tier 2.6)
---

# SE-098 — Split top-5 oversized agents

## Problema

27/70 agents (38.5%) exceden el SLA de 4096 B (Rule #22). Top-5:

| Agent | Bytes | Tokens |
|---|---|---|
| code-reviewer | 6794 | 1672 |
| security-guardian | 6454 | 1437 |
| test-runner | 6440 | 1419 |
| commit-guardian | 6409 | 1454 |
| confidentiality-auditor | 6188 | 1531 |

Promedio del catálogo: 3953 B (al borde). Inflación general.

## Solución

Para cada uno de los 5:
1. `bash scripts/agent-size-remediation-plan.sh <agent>` — genera plan de split
2. Identificar bloques candidatos a extraer a skills auxiliares (decision-tree, runbook, checklists)
3. Implementar split: agente core + skill(s) `<agent>-runbook` o `<agent>-checklist`
4. Validar que el agente sigue funcional con ejemplos reales

## Aceptación

- 5 agents ≤4096 B
- Skills auxiliares con SKILL.md propio
- Test smoke de cada agente con caso real previo a cambio
- `agent-size-audit.sh` reporta 22 violaciones (no 27)

## Fuera de alcance

- Los 22 restantes → SE-099 (separado, prioridad P2)
