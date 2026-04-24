# SPEC-120 Spec template alignment con github/spec-kit — IMPLEMENTED

**Date:** 2026-04-24
**Version:** 5.97.0

## Summary

SPEC-120 completado. Infrastructure mayor pre-existia (canonical template + docs + 26 tests certified 81). Completado los 2 project templates duplicados con pointer headers a la fuente canonica.

## Cambios

### A. Canonical template (pre-existente, verified)

`.claude/skills/spec-driven-development/references/spec-template.md`:
- `spec_kit_compatible: true` marker (linea 6)
- `## Spec-Kit Alignment` section con mapping table 4 secciones ↔ Savia extended
- Savia-exclusive sections preservadas (Developer Type, Effort Estimation, Ficheros, Iteration)

### B. Documentation (pre-existente, verified)

`docs/agent-teams-sdd.md` §Spec-Kit Alignment (SPEC-120):
- Mapping table: What & Why → Contexto, Requirements → Contrato+Reglas, Technical Design → Código, Acceptance Criteria → Test Scenarios
- Referencia explicita a `tests/spec-template-compliance.bats`
- Savia-exclusive sections listadas (no mapeables a spec-kit)

### C. Tests (pre-existente, verified)

`tests/test-spec-template-compliance.bats`:
- 26 tests certified, auditor score **81**
- Cubre: safety, positive (markers, sections, mappings), Savia-exclusive preservation, docs cross-reference, negative cases (broken templates detectable), edge cases (sizes, numbering)

### D. Project template duplicates (this PR)

`projects/proyecto-alpha/specs/templates/spec-template.md`:
- Added: spec_kit_compatible marker + link a fuente canonica
- Content preservado (project customizations mantenidas)

`projects/proyecto-beta/specs/templates/spec-template.md`:
- Same: spec_kit_compatible marker + canonical reference

`.claude/commands/references/spec-template.md`:
- Ya era pointer (no content duplication), no cambios necesarios

### E. SPEC-120 status: APPROVED → IMPLEMENTED

Resolution section anadida con breakdown pre-existente vs this PR. 7/7 AC cumplidos.

## Validacion

- `bats tests/test-spec-template-compliance.bats`: 26/26 PASS
- Auditor score: 81 certified
- Manual check: spec_kit_compatible marker grep across 3 templates (canonical + 2 projects) → all found
- `scripts/readiness-check.sh`: PASS

## Progreso backlog APPROVED

Post-merge de este PR:
- APPROVED: **6 → 5** (-1 SPEC-120 resolved)
- IMPLEMENTED: **58 → 59** (+1)

Queue APPROVED restante (5):
- SE-028 oumi (GPU-blocked)
- SE-042 Voice training pipeline (GPU-blocked)
- **SE-070** Opus 4.7 calibration scorecard
- SPEC-023 Savia LLM Trainer (GPU-blocked)
- SPEC-080 Unsloth training (GPU-blocked)

**Sin GPU ejecutables: solo SE-070** (1 restante). 4 GPU-blocked en espera de hardware.

## Referencias

- SPEC-120: `docs/propuestas/SPEC-120-spec-kit-alignment.md`
- Canonical template: `.claude/skills/spec-driven-development/references/spec-template.md`
- Doctrine doc: `docs/agent-teams-sdd.md` §Spec-Kit Alignment (SPEC-120)
- [github/spec-kit](https://github.com/github/spec-kit) — SDD toolkit externo
- Tests: `tests/test-spec-template-compliance.bats`
