---
spec_id: SE-095
title: Commands counter drift — pm-workflow.md says 513, real is 553
status: IMPLEMENTED
implemented_at: 2026-05-27
implemented_by: opencode-claude-opus-4.7
approved_by: operator (2026-05-27)
priority: P0
effort: XS
estimated_time: 15 min
depends_on: none
source: output/20260527-auditoria-obsoleto-legado.md (Tier 1.3)
---

# SE-095 — Commands counter drift

## Problema

`docs/rules/domain/pm-workflow.md` documenta "513 comandos" pero el filesystem tiene 553. Drift de 40 comandos sin reflejar en la doc operativa. `claude-md-drift-check.sh` valida CLAUDE.md pero no pm-workflow.md.

## Solución

### Slice 1: Fix manual (~5 min)
- Actualizar contador en `pm-workflow.md` a 553
- Verificar que la categorización por familia sigue siendo correcta

### Slice 2: Extender drift check (~10 min)
- Añadir verificación de `pm-workflow.md` al script `claude-md-drift-check.sh` (o crear `pm-workflow-drift-check.sh`)
- Integrar en `readiness-check.sh` para bloquear merge si drift

## Aceptación

- [x] pm-workflow.md refleja 558 comandos (canónico, no 553)
- [x] CLAUDE.md fixed (553 -> 558)
- [x] scripts/count-commands.sh creado como source of truth
- [x] claude-md-drift-check.sh ahora usa .claude/commands/ (no .opencode/commands/ vacío) y valida pm-workflow.md
