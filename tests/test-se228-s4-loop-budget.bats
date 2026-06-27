#!/usr/bin/env bats
# tests/test-se228-s4-loop-budget.bats
# SE-228 Slice 4 — Loop budget con kill switch
# Ref: docs/propuestas/SE-228-loop-engineering-patterns.md
# BATS >= 8 tests, auditor score >= 80

setup() {
  export TMPDIR_S4
  TMPDIR_S4="$(mktemp -d)"
  export LOOP_BUDGET_DIR="$TMPDIR_S4/loop-budget"

  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT
  SCRIPT="$PROJECT_ROOT/scripts/loop-budget-check.sh"
  export SCRIPT
  SCHEMA="$PROJECT_ROOT/docs/rules/domain/loop-budget-schema.md"
  export SCHEMA
  TEMPLATE="$PROJECT_ROOT/templates/loop-budget.md.template"
  export TEMPLATE

  mkdir -p "$LOOP_BUDGET_DIR"
}

teardown() {
  rm -rf "$TMPDIR_S4"
}

# Helper: write a minimal budget file for a skill
_write_budget() {
  local skill="$1"
  local cap="${2:-500000}"
  local used="${3:-0}"
  local pause="${4:-false}"
  local today
  today="$(date +%Y-%m-%d)"
  mkdir -p "$LOOP_BUDGET_DIR/$skill"
  cat > "$LOOP_BUDGET_DIR/$skill/loop-budget.md" <<EOF
skill: $skill
daily_token_cap: $cap
max_tasks_per_run: 20
max_attempts_per_task: 3
kill_if:
  - ci_red_3d
pause_on_weekend: $pause
last_reset: "$today"
tokens_used_today: $used
EOF
}

# ---------------------------------------------------------------------------
# T01 — script exists and is executable
# ---------------------------------------------------------------------------
@test "T01: loop-budget-check.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ---------------------------------------------------------------------------
# T02 — no args exits 2
# ---------------------------------------------------------------------------
@test "T02: no args exits 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# T03 — --help exits 0
# ---------------------------------------------------------------------------
@test "T03: --help exits 0" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T04 — budget OK exits 0
# ---------------------------------------------------------------------------
@test "T04: budget OK exits 0" {
  _write_budget "test-skill" 500000 100 false
  run bash "$SCRIPT" --skill test-skill
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BUDGET OK"* ]]
}

# ---------------------------------------------------------------------------
# T05 — tokens_used_today >= daily_token_cap exits 1
# ---------------------------------------------------------------------------
@test "T05: budget exceeded exits 1" {
  _write_budget "test-skill-over" 500000 500000 false
  run bash "$SCRIPT" --skill test-skill-over
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"BUDGET EXCEEDED"* ]]
}

# ---------------------------------------------------------------------------
# T06 — daily_token_cap: 0 (unlimited) exits 0 even when used > 0
# ---------------------------------------------------------------------------
@test "T06: unlimited cap (daily_token_cap=0) exits 0" {
  _write_budget "test-skill-unlimited" 0 9999999 false
  run bash "$SCRIPT" --skill test-skill-unlimited
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BUDGET OK"* ]]
}

# ---------------------------------------------------------------------------
# T07 — --update-tokens increments tokens_used_today
# ---------------------------------------------------------------------------
@test "T07: --update-tokens increments tokens_used_today" {
  _write_budget "test-skill-update" 500000 1000 false
  run bash "$SCRIPT" --skill test-skill-update --update-tokens 500
  [[ "$status" -eq 0 ]]
  local new_val
  new_val="$(grep "^tokens_used_today:" "$LOOP_BUDGET_DIR/test-skill-update/loop-budget.md" | sed 's/.*: *//')"
  [[ "$new_val" -eq 1500 ]]
}

# ---------------------------------------------------------------------------
# T08 — --report exits 0 and shows BUDGET OK when under cap
# ---------------------------------------------------------------------------
@test "T08: --report exits 0 and shows BUDGET OK when under cap" {
  _write_budget "test-skill-report" 500000 100 false
  run bash "$SCRIPT" --skill test-skill-report --report
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BUDGET OK"* ]]
}

# ---------------------------------------------------------------------------
# T09 — --report exits 0 and shows BUDGET EXCEEDED when over cap
# ---------------------------------------------------------------------------
@test "T09: --report exits 0 and shows BUDGET EXCEEDED when over cap" {
  _write_budget "test-skill-report-over" 500000 600000 false
  run bash "$SCRIPT" --skill test-skill-report-over --report
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BUDGET EXCEEDED"* ]]
}

# ---------------------------------------------------------------------------
# T10 — ci_red_3d kill condition triggers exit 1 when streak >= 3
# ---------------------------------------------------------------------------
@test "T10: ci_red_3d kill exits 1 when streak >= 3" {
  _write_budget "test-skill-ci" 500000 0 false
  echo "3" > "$LOOP_BUDGET_DIR/test-skill-ci/.loop-ci-red-streak"
  run bash "$SCRIPT" --skill test-skill-ci
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ci_red_3d"* ]]
}

# ---------------------------------------------------------------------------
# T11 — ci_red_3d does NOT trigger when streak < 3
# ---------------------------------------------------------------------------
@test "T11: ci_red_3d does not trigger when streak < 3" {
  _write_budget "test-skill-ci2" 500000 0 false
  echo "2" > "$LOOP_BUDGET_DIR/test-skill-ci2/.loop-ci-red-streak"
  run bash "$SCRIPT" --skill test-skill-ci2
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T12 — schema file exists
# ---------------------------------------------------------------------------
@test "T12: loop-budget-schema.md exists" {
  [[ -f "$SCHEMA" ]]
}

# ---------------------------------------------------------------------------
# T13 — template file exists
# ---------------------------------------------------------------------------
@test "T13: templates/loop-budget.md.template exists" {
  [[ -f "$TEMPLATE" ]]
}

# ---------------------------------------------------------------------------
# T14 — set -uo pipefail present in script
# ---------------------------------------------------------------------------
@test "T14: set -uo pipefail present in script" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ---------------------------------------------------------------------------
# T15 — --dry-run does not modify budget file
# ---------------------------------------------------------------------------
@test "T15: --dry-run does not modify budget file" {
  _write_budget "test-skill-dry" 500000 1000 false
  local before
  before="$(cat "$LOOP_BUDGET_DIR/test-skill-dry/loop-budget.md")"
  run bash "$SCRIPT" --skill test-skill-dry --update-tokens 999 --dry-run
  local after
  after="$(cat "$LOOP_BUDGET_DIR/test-skill-dry/loop-budget.md")"
  [[ "$before" == "$after" ]]
}
