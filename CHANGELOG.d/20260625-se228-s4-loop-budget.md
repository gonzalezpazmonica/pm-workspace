## SE-228 S4 — Loop budget con kill switch (2026-06-25)

**Spec:** SE-228 Slice 4  
**Type:** feat  
**Scope:** scripts, docs, templates, tests

### Added

- `docs/rules/domain/loop-budget-schema.md` — canonical schema for `loop-budget.md`
  per-skill declaration files; documents all fields, kill conditions, and
  integration points.
- `scripts/loop-budget-check.sh` — gate script that reads a skill's
  `loop-budget.md` and exits 1 when daily token cap is exceeded, a kill
  condition fires, or weekend pause is active; `--update-tokens N` updates
  the running counter with automatic day-boundary reset; `--report` prints
  summary without side-effects; `--dry-run` mode for inspection.
- `templates/loop-budget.md.template` — bootstrap template with defaults
  (500k tokens/day, 20 tasks/run, 3 attempts/task, weekend pause enabled).

### Tests

- `tests/test-se228-s4-loop-budget.bats` — 15 tests, all passing, certified.
  Covers: executable check, no-args exit 2, --help, budget-OK,
  budget-exceeded, unlimited cap, --update-tokens, --report variants,
  ci_red_3d trigger and non-trigger, schema/template existence,
  set -uo pipefail, --dry-run idempotency.
