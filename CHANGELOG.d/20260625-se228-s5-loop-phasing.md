## SE-228-S5 — Loop Phasing L1→L3 checklist + loop_level field (2026-06-25)

### Added

- `docs/rules/domain/loop-phasing.md` — Definición canónica de niveles L0→L3 para
  skills autónomas. Incluye descripción de cada nivel, checklists de promoción
  L1→L2 y L2→L3, red flags que bloquean la promoción, y relación con
  `autonomous-safety.md`.

- `scripts/loop-phasing-audit.sh` — Auditor de nivel loop declarado vs inferido.
  Modos: sin args (todos los skills), `--skill <nombre>` (skill específico),
  `--json` (output estructurado). Gap: `OK | OVER | UNDER`.

- Campo `loop_level` en frontmatter de 4 SKILL.md:
  - `.opencode/skills/_template/SKILL.md` → `L0` (default)
  - `.opencode/skills/overnight-sprint/SKILL.md` → `L2`
  - `.opencode/skills/code-improvement-loop/SKILL.md` → `L2`
  - `.opencode/skills/tech-research-agent/SKILL.md` → `L1`

- `tests/test-se228-s5-loop-phasing.bats` — 34 tests, score 89/100, certified.

### Rationale

SE-228 Slice 5 establece el marco de madurez operativa para bucles autónomos.
Los niveles L0-L3 permiten auditar sistemáticamente si un skill declara un nivel
que sus artefactos de evidencia justifican. El campo `loop_level` en SKILL.md
es la fuente de verdad declarativa; `loop-phasing-audit.sh` es el verificador.

### Tests

- `bats tests/test-se228-s5-loop-phasing.bats`: 34/34 OK
- `bash scripts/test-auditor.sh tests/test-se228-s5-loop-phasing.bats`: score 89, certified

### Ref

- Spec: `docs/propuestas/SE-228-loop-engineering-patterns.md`
- Slices anteriores: S1 (PR #878), S2+S3 (PR #877)
- Regla complementaria: `docs/rules/domain/autonomous-safety.md`
