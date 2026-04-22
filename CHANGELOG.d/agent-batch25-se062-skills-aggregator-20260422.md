# Batch 25 — SE-062.3 skills aggregator + SE-063/064 coderlm propuestas

**Date:** 2026-04-22
**Branch:** `agent/batch25-se062-skills-aggregator-20260422`
**Version bump:** 5.73.0

## Summary

Cierre de SE-062.3 (Era 184 slice 3) mediante patrón aggregator. Investigación coderlm genera SE-063/064 como Era 185 PROPOSED.

## SE-062.3 Skills aggregator

**Problema**: 18 scripts huérfanos sin skill asociado. Crear 18 skill dirs = inflación sin valor.

**Solución**: 2 aggregator skills cubren la totalidad:

- `tier3-probes/` — 6 feasibility probes (SE-028/032/033/041/061 + SPEC-102/103/104)
- `workspace-integrity/` — 7 integrity auditors (SE-043/046/047/048/052/057)

Cada aggregator documenta:
- Inventario de scripts con spec origen y responsabilidad
- Invocación uniforme (contrato común)
- Exit codes estables (0/1/2)
- No-hacen explícitos
- Decision tree / casos de uso

**Ventaja**: documentación centralizada, single source, fácil de mantener. Re-usable para futuros probes/auditors que sigan el mismo patrón.

## SE-063 ACM enforcement pre-tool hook (nueva propuesta)

**Origen**: research coderlm (MIT). Veredicto ADOPTAR PATRÓN (no el código Rust).

**Gap**: agentes ignoran `.agent-maps/INDEX.acm` y hacen glob/grep masivo redundante. El sistema ACM existe pero sin enforcement.

**Scope**: 3 slices (4-6h total)
1. Hook detector — bloquea queries amplias sin ACM previo
2. Turn marker — trackea lectura de ACM per-turno
3. Bypass semántico — exenciones para workspace infra

**Prioridad**: Media. Entra en Era 185 cuando cierre Era 184.

## SE-064 ACM multi-host generator (nueva propuesta)

**Origen**: mismo research coderlm.

**Gap**: ACM solo consumible por Claude Code. Cursor/Windsurf/Copilot reinventan el índice.

**Scope**: 4 slices (8h) — export `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`, orchestrator.

**Prioridad**: Baja. On-demand — ejecutar solo si usuaria reporta uso real de IDEs non-Claude.

## Compliance

- Rule #24 Radical Honesty: SE-064 marcada como baja prioridad con justificación explícita (no hay demanda real)
- Memory feedback_terminology_fossl: research y propuestas usan "ADOPTAR PATRÓN", nunca "robar"
- Memory feedback_agent_maps_per_project: SE-063/064 respetan per-project, skip si no existe `.agent-maps/`
- Drift check: PASS post-update (skills=85 coincide CLAUDE.md ↔ filesystem)
- ROADMAP Era 185 añadida como PROPOSED

## Próximos slices Era 184

- SE-062.4 SE-053 changelog hook activation (3h)
- SE-062.5 SE-036 frontmatter slices 2-3 finale (3h)

## Referencias

- Research coderlm: `output/research-coderlm-20260421.md`
- SE-062 Era 184: `docs/propuestas/SE-062-era184-consolidation-hygiene.md`
- SE-063: `docs/propuestas/SE-063-acm-enforcement-pretool-hook.md`
- SE-064: `docs/propuestas/SE-064-acm-multihost-generator.md`
- Skill ACM base: `.claude/skills/agent-code-map/SKILL.md`
