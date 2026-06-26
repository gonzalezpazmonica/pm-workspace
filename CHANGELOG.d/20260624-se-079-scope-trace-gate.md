## SE-079 — G13 Scope-trace gate (Era 199)

### Added

- `scripts/scope-trace-gate.sh`: standalone G13 runner. Input: spec_id + file list. Output: JSON with gate, passed, files_in_scope, files_outside_scope, verdict. Always exits 0 (advisory only).
- `g13_scope_trace` function in `scripts/pr-plan-gates.sh`: wired as `gate "G13" "Scope-trace audit"` in `scripts/pr-plan.sh`. Detects spec refs from .pr-summary.md, commits, and branch name; matches changed files via whitelist, self-spec, path-hint, and token-overlap heuristics.
- `docs/rules/domain/pr-plan-gates.md`: new reference doc for all pr-plan gates with G13 detail section.
- `tests/bats/test-se-079-scope-gate.bats`: 7 BATS tests covering script existence, in-scope, out-of-scope, JSON validity, graceful no-spec skip, whitelist, and gate field.

### Pattern

Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR (docs/rules/domain/attention-anchor.md, SE-080).
