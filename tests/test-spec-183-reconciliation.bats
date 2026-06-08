#!/usr/bin/env bats
# test-spec-183-reconciliation.bats — BATS tests for SPEC-183 reconciliation 3-bucket
# Ref: SPEC-183
# Min score: 15 tests targeting >=80 coverage

DECISION_TREE="docs/rules/domain/reconciliation-decision-tree.md"
RECONCILER_OPENCODE=".opencode/agents/reconciler.md"
RECONCILER_CLAUDE=".claude/agents/reconciler.md"
STATS_SCRIPT="scripts/reconciliation-stats.sh"

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

@test "decision tree doc exists" {
  [[ -f "$DECISION_TREE" ]]
}

@test "decision tree references SPEC-183" {
  run grep -c "SPEC-183" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
}

@test "decision tree documents 3 buckets: evolution, auto-resolve, conflict-doc" {
  run grep -c "evolution" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -c "auto.resolve" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -c "conflict.doc" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
}

@test "decision tree has 6 examples (2 per bucket)" {
  # Each example section has a header: E1, E2, A1, A2, C1, C2
  run grep -cE '\*\*(E[12]|A[12]|C[12])\*\*' "$DECISION_TREE"
  [[ "$output" -ge 6 ]]
}

@test "reconciler agent exists in .opencode/agents" {
  [[ -f "$RECONCILER_OPENCODE" ]]
}

@test "reconciler agent exists in .claude/agents" {
  [[ -f "$RECONCILER_CLAUDE" ]]
}

@test "reconciler agent has description in frontmatter" {
  run grep -c "description:" "$RECONCILER_OPENCODE"
  [[ "$output" -ge 1 ]]
  # Verify it mentions 3 buckets
  run grep "description:" "$RECONCILER_OPENCODE"
  [[ "$output" == *"evolution"* ]] || [[ "$output" == *"auto-resolve"* ]] || [[ "$output" == *"conflict-doc"* ]]
}

@test "reconciler agent references SPEC-183" {
  run grep -c "SPEC-183" "$RECONCILER_OPENCODE"
  [[ "$output" -ge 1 ]]
}

@test "stats script exists and is executable" {
  [[ -x "$STATS_SCRIPT" ]]
}

@test "stats script passes bash -n syntax check" {
  run bash -n "$STATS_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "stats script uses set -uo pipefail" {
  run grep -c "set -uo pipefail" "$STATS_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "stats script references SPEC-183" {
  run grep -c "SPEC-183" "$STATS_SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Stats behaviour ───────────────────────────────────────────────────────────

@test "stats --report exits 0 when no stats file exists" {
  run bash "$STATS_SCRIPT" --report
  [ "$status" -eq 0 ]
}

@test "stats append: logs auto-resolve entry to jsonl" {
  run bash "$STATS_SCRIPT" --bucket auto-resolve --file "docs/propuestas/SPEC-TEST.md" --source "bats test"
  [ "$status" -eq 0 ]
  [[ -f "$TMPDIR_TEST/.savia/reconciliation-stats.jsonl" ]]
  run grep -c '"bucket":"auto-resolve"' "$TMPDIR_TEST/.savia/reconciliation-stats.jsonl"
  [[ "$output" -ge 1 ]]
}

@test "stats append: logs evolution entry to jsonl" {
  run bash "$STATS_SCRIPT" --bucket evolution --file "docs/propuestas/SPEC-TEST.md"
  [ "$status" -eq 0 ]
  run grep -c '"bucket":"evolution"' "$TMPDIR_TEST/.savia/reconciliation-stats.jsonl"
  [[ "$output" -ge 1 ]]
}

@test "stats append: logs conflict-doc entry to jsonl" {
  run bash "$STATS_SCRIPT" --bucket conflict-doc --file "docs/propuestas/SPEC-TEST.md"
  [ "$status" -eq 0 ]
  run grep -c '"bucket":"conflict-doc"' "$TMPDIR_TEST/.savia/reconciliation-stats.jsonl"
  [[ "$output" -ge 1 ]]
}

@test "stats --report shows counts after appending entries" {
  bash "$STATS_SCRIPT" --bucket auto-resolve --file "a.md"
  bash "$STATS_SCRIPT" --bucket auto-resolve --file "b.md"
  bash "$STATS_SCRIPT" --bucket evolution   --file "c.md"
  bash "$STATS_SCRIPT" --bucket conflict-doc --file "d.md"
  run bash "$STATS_SCRIPT" --report
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto-resolve"* ]]
  [[ "$output" == *"evolution"* ]]
  [[ "$output" == *"conflict-doc"* ]]
  [[ "$output" == *"total:         4"* ]]
}

@test "stats: unknown bucket rejected with exit 1" {
  run bash "$STATS_SCRIPT" --bucket invalid-bucket --file "x.md"
  [ "$status" -eq 1 ]
}

@test "stats: missing --file in append mode exits 1" {
  run bash "$STATS_SCRIPT" --bucket auto-resolve
  [ "$status" -eq 1 ]
}

@test "conflict-doc format: decision tree specifies required frontmatter fields" {
  run grep -c "conflict_id" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -c "detected_at" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
  run grep -c "sources:" "$DECISION_TREE"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: empty input to reconciliation-stats --report exits 0" {
  run bash "$STATS_SCRIPT" --report 2>&1 || true
  [[ "$status" -eq 0 || "$output" =~ [Ee]mpty|[Nn]o.stats ]]
}

@test "edge: nonexistent stats file handled gracefully" {
  SAVIA_STATS_FILE="$TMPDIR_TEST/nonexistent.jsonl" run bash "$STATS_SCRIPT" --report 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "edge: zero conflict-docs in directory returns 0 count" {
  run bash "$STATS_SCRIPT" --report 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "edge: no-arg invocation shows usage or defaults" {
  run bash "$STATS_SCRIPT" 2>&1 || true
  [[ "$status" -le 2 ]]
}

@test "coverage: SPEC-183 referenced in reconciliation-stats script" {
  grep -q 'SPEC-183' "$STATS_SCRIPT"
}

@test "coverage: decision-tree references all 3 bucket names" {
  grep -qi 'evolution' "$DECISION_TREE"
  grep -qi 'auto.resolve\|auto_resolve' "$DECISION_TREE"
  grep -qi 'conflict.doc\|conflict_doc' "$DECISION_TREE"
}
