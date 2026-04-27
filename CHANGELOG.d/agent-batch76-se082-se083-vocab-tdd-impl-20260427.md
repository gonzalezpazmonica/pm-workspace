---
version_bump: minor
section: Added
---

## [6.15.0] — 2026-04-27

Batch 76 — SE-082 IMPLEMENTED + SE-083 IMPLEMENTED. Critical Path #3+#4 cerrados en una sola PR (M 4h + S 2h, paired porque comparten tema "discipline multipliers" y SE-083 cross-references SE-082 vocabulary).

### Added

#### SE-082 Slice única — Architectural vocabulary discipline (M 4h)

- `docs/rules/domain/architectural-vocabulary.md` — vocabulario canónico Module / Interface / Implementation / Seam / Adapter / Depth / Locality + Leverage. Cada término con `_Avoid_:` explícito (rejection set). 4 principios ratchet: deletion test, interface = test surface, one adapter = hypothetical seam, depth is property of interface. Atribución MIT clean-room a `mattpocock/skills/improve-codebase-architecture/LANGUAGE.md`.
- Cross-references añadidas en 3 sitios:
  - `docs/rules/domain/attention-anchor.md` (SE-080) — sección "Vocabulario relacionado" + ref en "Referencias"
  - `.claude/agents/architect.md` — sección "Architectural Vocabulary (SE-082)" en system prompt
  - `.claude/agents/architecture-judge.md` — sección "Architectural Vocabulary (SE-082)" tras Reporting Policy
- `scripts/architectural-vocabulary-audit.sh` — auditor estático sobre outputs recientes de `architect` y `architecture-judge` (`output/architect-*.md`, `output/architecture-*.md`, `output/agent-runs/architect-*/*.md`). Detecta términos prohibidos (boundary, component, service, api) en prosa NO en código. Skip de fenced code blocks + inline backticks (identifiers como `BoundaryService` siguen permitidos en code, prose-only enforcement). Modos: `--report` (default warning-only, exit 0), `--gate` (exit 1 sobre violations, hook-up para Slice 2 SE-084 G14), `--json`, `--file PATH`.

#### SE-083 Slice única — TDD vertical-slices skill (S 2h)

- `.claude/skills/tdd-vertical-slices/SKILL.md` — codifica el anti-pattern de **horizontal slicing** ("escribir todos los tests primero, luego todo el código produce tests-de-mentira") y la disciplina vertical (1 test → 1 implementation → repeat). Incluye workflow 4-pasos (planning, tracer bullet, incremental loop, refactor) + per-cycle checklist. Atribución MIT clean-room a `mattpocock/skills/tdd/SKILL.md`.
- `.claude/skills/tdd-vertical-slices/DOMAIN.md` — secciones convención pm-workspace (Por qué existe, Conceptos de dominio, Reglas de negocio, Relación con otras skills, Decisiones clave, Limitaciones).
- Cross-reference en `.claude/agents/test-architect.md` — sección "TDD Vertical Slices (SE-083)" tras Constraints. NO modifica `test-engineer` ni `test-runner` (son ejecutores, no discípulos del pattern).

#### Tests

- `tests/structure/test-architectural-vocabulary.bats` — 31 tests certified. Cubre SE-082 (vocabulary doc structure × 4, cross-refs × 3, auditor positive × 8, auditor negative × 2, auditor edge × 4) + SE-083 (skill structure × 4, cross-refs × 2) + spec ref reinforcement.

### Re-implementation attribution

`mattpocock/skills` (MIT, 26.4k⭐). Patterns extraídos:
- `improve-codebase-architecture/LANGUAGE.md` → SE-082 architectural-vocabulary doc + auditor heurística
- `tdd/SKILL.md` → SE-083 tdd-vertical-slices skill (anti-horizontal-slicing es la contribución central)

Clean-room: zero código copiado, prosa propia adaptada al tono Savia. Cada artefacto cita upstream MIT en attribution line.

### Acceptance criteria

#### SE-082 (8/8)
- ✅ AC-01 architectural-vocabulary.md ≤200 LOC, define 6 términos con _Avoid_
- ✅ AC-02 Atribución MIT a Pocock LANGUAGE.md en header
- ✅ AC-03 Cross-reference añadida en attention-anchor.md
- ✅ AC-04 architect agent referencia el doc canónico
- ✅ AC-05 architecture-judge agent referencia el doc canónico
- ✅ AC-06 architectural-vocabulary-audit.sh ejecutable, output warning-only por defecto + modo gate listo
- ✅ AC-07 Tests BATS ≥10 estáticos
- ✅ AC-08 CHANGELOG fragment

#### SE-083 (6/6)
- ✅ AC-01 SKILL.md ≤120 LOC con frontmatter `name`, `description` que incluye "Use when ..."
- ✅ AC-02 Anti-pattern de horizontal slicing nombrado explícitamente con "DO NOT" / "NO escribas todos"
- ✅ AC-03 Atribución MIT a Pocock tdd/SKILL.md
- ✅ AC-04 Cross-reference añadida en test-architect.md
- ✅ AC-05 Tests BATS ≥8 estáticos
- ✅ AC-06 CHANGELOG fragment

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` declarado en el auditor.
- Cero red, cero git operations, cero modificación a archivos fuera de `output/` (TSV).
- Modo `--gate` solo lee — no modifica outputs auditados.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/se082-se083-...`, sin push automático ni merge.

### Spec ref

SE-082 (`docs/propuestas/SE-082-architectural-vocabulary-discipline.md`) → IMPLEMENTED 2026-04-27. SE-083 (`docs/propuestas/SE-083-tdd-vertical-slice-skill.md`) → IMPLEMENTED 2026-04-27. Critical Path Q2-Q3 actualizado: items #3+#4 cerrados, próximos #5 (SE-084 Slice 2: G14 gate + skill-catalog-discipline.md doc) y #6 (SPEC-SE-037 P1 audit JSONB compliance).
