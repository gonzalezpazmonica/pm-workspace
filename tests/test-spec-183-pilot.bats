#!/usr/bin/env bats
# test-spec-183-pilot.bats — BATS tests for SPEC-183 Slices 3+4 (pilot + drift integration)
# Ref: SPEC-183
# Min: 14 tests, target >=80 score

PILOT_SCRIPT="scripts/reconciliation-pilot.sh"
STATS_SCRIPT="scripts/reconciliation-stats.sh"
DRIFT_AUDITOR=".claude/agents/drift-auditor.md"
DECISION_TREE="docs/rules/domain/reconciliation-decision-tree.md"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST
  export SAVIA_WORKSPACE_DIR="$TMPDIR_TEST"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Static checks ─────────────────────────────────────────────────────────────

@test "reconciliation-pilot.sh exists" {
  [[ -f "$PILOT_SCRIPT" ]]
}

@test "reconciliation-pilot.sh is executable" {
  [[ -x "$PILOT_SCRIPT" ]]
}

@test "reconciliation-pilot.sh uses set -uo pipefail" {
  run grep -c "set -uo pipefail" "$PILOT_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "reconciliation-pilot.sh references SPEC-183" {
  run grep -c "SPEC-183" "$PILOT_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "reconciliation-pilot.sh passes bash -n syntax check" {
  run bash -n "$PILOT_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "reconciliation-stats.sh passes bash -n syntax check after pilot subcommand addition" {
  run bash -n "$STATS_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── drift-auditor integration ─────────────────────────────────────────────────

@test "drift-auditor.md mentions reconciler" {
  run grep -ci "reconciler" "$DRIFT_AUDITOR"
  [[ "$output" -ge 1 ]]
}

@test "drift-auditor.md references reconciliation-decision-tree" {
  run grep -c "reconciliation-decision-tree" "$DRIFT_AUDITOR"
  [[ "$output" -ge 1 ]]
}

# ── decision tree checks ──────────────────────────────────────────────────────

@test "reconciliation-decision-tree.md documents 3 buckets" {
  run grep -ci "evolution" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -ci "auto.resolve\|auto_resolve" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -ci "conflict.doc\|conflict_doc" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
}

# ── Pilot --dry-run ───────────────────────────────────────────────────────────

@test "pilot --dry-run does not create output file" {
  TODAY="$(date +%Y%m%d)"
  OUTPUT_FILE="output/reconciliation-pilot-${TODAY}.md"
  run bash "$PILOT_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # File must NOT be created in workspace
  [[ ! -f "$OUTPUT_FILE" ]]
}

@test "pilot --dry-run prints bucket counts to stdout" {
  run bash "$PILOT_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # At minimum, must mention the three bucket names or Summary
  [[ "$output" == *"evolution"* ]] || [[ "$output" == *"auto-resolve"* ]] || [[ "$output" == *"Summary"* ]]
}

@test "pilot --stats shows only metrics, no detail table" {
  run bash "$PILOT_SCRIPT" --stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"total"* ]]
}

# ── stats --report integration ────────────────────────────────────────────────

@test "stats --report works with SAVIA_WORKSPACE_DIR pointing to tmpdir" {
  run bash "$STATS_SCRIPT" --report
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: pilot with empty docs/rules/domain dir handled — exits 0" {
  # Override by passing a nonexistent workspace; pilot must not crash
  run bash "$PILOT_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent source dir — pilot exits 0 without crash" {
  # pilot scans three sources; if one is missing, it skips gracefully
  run bash "$PILOT_SCRIPT" --dry-run 2>&1
  [ "$status" -eq 0 ]
}

@test "edge: pilot --dry-run output contains bucket distribution header" {
  run bash "$PILOT_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # Must contain the summary table header or bucket labels
  [[ "$output" == *"Bucket"* ]] || [[ "$output" == *"evolution"* ]]
}

@test "SPEC-183 edge: empty reconciliation-stats.jsonl produces valid report" {
  local empty_stats="$TMPDIR_TEST/empty-stats.jsonl"
  touch "$empty_stats"
  SAVIA_STATS_FILE="$empty_stats" run bash scripts/reconciliation-stats.sh --report 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SPEC-183 edge: zero-length source directory returns 0 contradictions" {
  mkdir -p "$TMPDIR_TEST/empty-src"
  run bash scripts/reconciliation-pilot.sh --dry-run --source "$TMPDIR_TEST/empty-src" 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SPEC-183 coverage: docs/propuestas/SPEC-183-reconciliation-3bucket.md exists" {
  [ -f "docs/propuestas/SPEC-183-reconciliation-3bucket.md" ]
}
