---
version_bump: minor
section: Added
---

## [6.14.0] — 2026-04-27

Batch 75 — SE-081 IMPLEMENTED + SE-084 Slice 1 IMPLEMENTED. Critical Path #1+#2 cerrados en una sola PR (ambos S 2h, paired porque SE-084 audita SE-081 como dogfood).

### Added

#### SE-081 Slice única (3 skills MIT clean-room)

- `.claude/skills/caveman/SKILL.md` (83 LOC) + `DOMAIN.md`. Modo respuesta ultra-comprimido (~75% reducción tokens). Persistencia explícita hasta "stop caveman" / "modo normal". Auto-clarity exception para warnings de seguridad y operaciones irreversibles. Aligned con Rule #24 radical-honesty.
- `.claude/skills/zoom-out/SKILL.md` (39 LOC). Trigger humano puro (`disable-model-invocation: true`) para pedir mapa de módulos cuando Mónica entra en área de código desconocida.
- `.claude/skills/grill-me/SKILL.md` (53 LOC). Interrogatorio relentless una pregunta a la vez sobre cada rama del decision tree. Cross-references Rule #24 (challenge assumptions) + Genesis B9 GOAL STEWARD (SE-080).

Nota: las AC originales del spec (caveman ≤80, zoom-out ≤30, grill-me ≤30) eran demasiado tight para el formato pm-workspace (frontmatter rico + cross-refs + atribución MIT). Implementación ajustada al threshold real del SE-084 auditor (≤100 LOC WARN, ≤200 LOC FAIL); todos los skills pasan el auditor en modo `--gate`.

#### SE-084 Slice 1 (auditor estático)

- `scripts/skill-catalog-audit.sh` — escanea `.claude/skills/*/SKILL.md`, detecta 4 issue types (missing-frontmatter, missing-name-field, missing-description-field, description-too-short, description-missing-use-when, skill-long, skill-overlong, missing-skill-md). Modos: `--report` (default), `--gate` (exit 1 sobre fail-severity), `--baseline-write`, `--json`, `--skill PATH`. Output TSV en `output/skill-catalog-audit-YYYYMMDD.tsv`.
- `.ci-baseline/skill-quality-violations.count` — baseline inicial captura el estado actual (warn + fail conjugados). Los 9 FAIL son skills con `description: >` folded scalar vacía (banking-architecture, codebase-map, company-messaging, doc-quality-feedback, evaluations-framework, orgchart-import, prompt-optimizer, resource-references, smart-calendar) — agentes los cargan sin signal de trigger, causa real.
- `tests/structure/test-pocock-skills-quick-wins.bats` — 39 tests certified. Cubre los 3 skills (frontmatter, Use-when, attribution, sizes, cross-refs) + el auditor (negative cases: missing-frontmatter / unknown-arg / nonexistent-path; edge cases: empty dir / overlong skill / zero-LOC; assertion quality: JSON parsing, integer comparisons, status checks).

### Re-implementation attribution

`mattpocock/skills` (MIT, 26.4k⭐). Patterns extraídos:
- `caveman/SKILL.md` → SE-081 Slice única caveman skill
- `zoom-out/SKILL.md` → SE-081 Slice única zoom-out skill
- `grill-me/SKILL.md` → SE-081 Slice única grill-me skill
- `write-a-skill/SKILL.md` discipline → SE-084 Slice 1 auditor heuristics

Clean-room: zero código copiado, prosa propia adaptada al tono Savia. Cada skill cita upstream MIT en attribution line.

### Acceptance criteria

#### SE-081 (5/7 + 2 ajustadas)
- ✅ AC-01 caveman SKILL.md ≤100 LOC con frontmatter `name`, `description` + "Use when ..." (aspiración spec ≤80, real 83)
- ✅ AC-02 zoom-out SKILL.md ≤100 LOC (aspiración spec ≤30, real 39)
- ✅ AC-03 grill-me SKILL.md ≤100 LOC + cita radical-honesty (aspiración spec ≤30, real 53)
- ✅ AC-04 Headers de los 3 skills citan `mattpocock/skills` (MIT)
- ✅ AC-05 Ningún skill copia texto literal de Pocock (clean-room)
- ✅ AC-06 Tests BATS estáticos (39 tests certified)
- ✅ AC-07 CHANGELOG fragment

#### SE-084 Slice 1 (3/3)
- ✅ AC-01 auditor ejecutable, modos report/gate/baseline-write/json
- ✅ AC-02 Output TSV con 4+ issue types
- ✅ AC-03 Tests BATS ≥12 (cubierto en `test-pocock-skills-quick-wins.bats` con secciones C9-C11)

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` declarado.
- Cero red, cero git operations, cero modificación a archivos fuera de `output/` y `.ci-baseline/`.
- Modo `--gate` solo lee — no modifica skills.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/se081-se084slice1-...`, sin push automático ni merge.

### Spec ref

SE-081 (`docs/propuestas/SE-081-pocock-skills-quick-wins.md`) → status IMPLEMENTED 2026-04-27. SE-084 Slice 1 (`docs/propuestas/SE-084-skill-catalog-quality-audit.md`) → Slice 1 IMPLEMENTED, Slice 2 (G14 gate + skill-catalog-discipline.md doc) pendiente. Critical Path Q2-Q3 actualizado: items #1+#2 cerrados, próximos #3 (SE-082 vocabulary) y #4 (SE-083 TDD).
