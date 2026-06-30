## SE-084 — Skill catalog quality audit (2026-06-24)

### Added
- `scripts/skill-catalog-audit.sh`: auditor with modes --report/--gate/--baseline-write/--json/--skill/--fix-report. Detects: description-missing-use-when, skill-long (WARN >100 LOC), skill-overlong (FAIL >200 LOC), missing-frontmatter, description-too-short.
- `docs/rules/domain/skill-catalog-discipline.md`: canonical rule doc (≤124 LOC) citing Pocock write-a-skill (MIT). Defines 5 enforcement rules (frontmatter/size/trigger/attribution/cross-refs).
- `.ci-baseline/skill-quality-violations.count`: baseline count for ratchet (155 warnings).
- G14 gate in `scripts/pr-plan-gates.sh`: filters to skills modified in the PR, runs auditor in --gate mode. Registered in `scripts/pr-plan.sh`.

### Metrics (baseline 2026-06-24)
- Skills audited: 106
- WARN: 172 (long ≤200 LOC, missing use-when)
- FAIL: 0

### Tests
- 49 BATS tests in `tests/test-skill-catalog-auditor.bats` + `tests/structure/test-skill-catalog-g14.bats` (all pass).

### Status
- SE-084 APPROVED → IMPLEMENTED
