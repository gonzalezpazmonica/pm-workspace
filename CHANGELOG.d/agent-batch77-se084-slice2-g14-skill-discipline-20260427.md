---
version_bump: minor
section: Added
---

## [6.16.0] — 2026-04-27

Batch 77 — SE-084 Slice 2 IMPLEMENTED. G14 skill catalog gate activado en pr-plan + regla canónica `skill-catalog-discipline.md`. Critical Path #5 cerrado.

### Added

#### Regla canónica enforced

- `docs/rules/domain/skill-catalog-discipline.md` — define 5 reglas obligatorias para todo `SKILL.md` nuevo o modificado:
  1. **Frontmatter obligatorio**: `name:` + `description:` ≥30 caracteres con patrón "Use when ..."
  2. **Tamaño**: WARN > 100 LOC, FAIL > 200 LOC (progressive disclosure recomendado)
  3. **Description trigger discipline**: capability sentence + Use-when trigger
  4. **Atribución upstream** clean-room cuando aplica (zero código copiado)
  5. **Cross-references** a SE-082 architectural-vocabulary, SE-083 tdd-vertical-slices, autonomous-safety
- Atribución MIT a `mattpocock/skills/write-a-skill/SKILL.md` (pattern source).

#### Pr-plan gate

- `scripts/pr-plan-gates.sh` — añadida función `g14_skill_catalog`. Filtra `git diff origin/main..HEAD --diff-filter=AM` a `^\.claude/skills/[^/]+/SKILL\.md$`, invoca `scripts/skill-catalog-audit.sh --gate --skill <dir>` para cada skill modificado, parsea JSON output y agrega FAIL/WARN counts.
- `scripts/pr-plan.sh` — registro G14 tras G13: `gate "G14" "Skill catalog audit" g14_skill_catalog`.
- Comportamiento:
  - **Skipped** si no hay SKILL.md modificado en el diff
  - **WARN-only** si el auditor está ausente (graceful degradation cuando SE-084 Slice 1 no esté en branch)
  - **FAIL** si algún skill modificado tiene severity FAIL (missing-frontmatter / missing-name / missing-description / description-too-short / skill-overlong)
  - WARN-severity (skill-long, missing-use-when) NO bloquea — ratchet only-going-forward

### Tests

- `tests/structure/test-skill-catalog-g14.bats` — 19 tests certified. Cubre rule doc structure (×4), G14 function structure + safety (×5), G14 behavior (×3), auditor negative cases (×2), edge cases (×3), spec ref + assertion quality reinforcement (×2).

### Re-implementation attribution

`mattpocock/skills/write-a-skill/SKILL.md` (MIT, 26.4k⭐) — meta-discipline source. Clean-room: zero código copiado, prosa propia adaptada al tono Savia + integración con G14 enforcement.

### Acceptance criteria

#### SE-084 Slice 2 (6/7)
- ✅ AC-04 `.ci-baseline/skill-quality-violations.count` ya existente desde Slice 1 batch 75
- ✅ AC-05 `docs/rules/domain/skill-catalog-discipline.md` ≤120 LOC, cita Pocock MIT
- ✅ AC-06 pr-plan G14 activa el gate en modo `--gate` filtrando a skills cambiados en el PR
- ✅ AC-07 No regression: skills modificados no aumentan violations (G14 skipped en este PR — no se modifica ningún SKILL.md, dogfood pasa)
- ✅ AC-08 Tests BATS = 19 certified
- ✅ AC-09 CHANGELOG fragment con baseline counts (155 inicial — 146 WARN + 9 FAIL — desde batch 75)
- 〰 AC: G14 wireado a `Slice 2` aspecto del spec — DONE

### Hard safety boundaries (autonomous-safety.md)

- G14 SOLO lee `git diff` y archivos especificados — no modifica nada
- WARN-severity NO bloquea (ratchet) — evita regresión accidental sobre skills antiguos
- FAIL-severity bloquea explícitamente con instrucciones de remediation
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/se084-slice2-...`, sin push automático ni merge.

### Spec ref

SE-084 (`docs/propuestas/SE-084-skill-catalog-quality-audit.md`) → Slice 1 IMPLEMENTED batch 75, Slice 2 IMPLEMENTED batch 77. Critical Path Q2-Q3 actualizado: items #1-5 cerrados, próximo #6 (SPEC-SE-037 P1 audit JSONB compliance — Era 232).
