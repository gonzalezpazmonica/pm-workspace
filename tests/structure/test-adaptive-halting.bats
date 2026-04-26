#!/usr/bin/env bats
# Ref: SE-074 Slice 1.5 — adaptive-halting.sh (double-criterion halting)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/adaptive-halting.sh"
  WT=$(mktemp -d)
}

teardown() {
  rm -rf "$WT"
}

# Helper: write current halt-state.json
write_state() {
  local hash="$1" conf="$2" tests="$3" iter="${4:-1}"
  cat > "$WT/.halt-state.json" <<JSON
{"iter": ${iter}, "tree_hash": "${hash}", "confidence": ${conf}, "tests_passed": ${tests}}
JSON
}

# Helper: write previous halt-state.prev.json
write_prev() {
  local hash="$1" iter="${2:-0}"
  cat > "$WT/.halt-state.prev.json" <<JSON
{"iter": ${iter}, "tree_hash": "${hash}"}
JSON
}

@test "should-halt: missing state file → no-halt" {
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"state file missing"* ]]
}

@test "should-halt: first iteration (no prev) → no-halt + records baseline" {
  write_state "abc123" 0.9 true 1
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"first iteration"* ]]
  [ -f "$WT/.halt-state.prev.json" ]
}

@test "should-halt: tree changed → no-halt regardless of confidence" {
  write_prev "old_hash"
  write_state "new_hash" 0.95 true
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tree changed"* ]]
}

@test "should-halt: convergence + low confidence → no-halt" {
  write_prev "same_hash"
  write_state "same_hash" 0.50 true
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"confidence"* ]] && [[ "$output" == *"below"* ]]
}

@test "should-halt: convergence + high confidence + tests fail → no-halt" {
  write_prev "same_hash"
  write_state "same_hash" 0.95 false
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tests not passing"* ]]
}

@test "should-halt: convergence + high confidence + tests pass → HALT" {
  write_prev "same_hash"
  write_state "same_hash" 0.95 true
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"halt"* ]]
}

@test "should-halt: confidence at exactly default threshold (0.75) → halt" {
  write_prev "same_hash"
  write_state "same_hash" 0.75 true
  run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 0 ]
}

@test "should-halt: configurable confidence threshold via env" {
  write_prev "same_hash"
  write_state "same_hash" 0.85 true
  ADAPTIVE_HALT_CONFIDENCE=0.90 run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"below"* ]]
}

@test "should-halt: invalid confidence floor (0.40) rejected" {
  write_prev "same_hash"
  write_state "same_hash" 0.95 true
  ADAPTIVE_HALT_CONFIDENCE=0.40 run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be in"* ]]
}

@test "should-halt: invalid confidence floor (0.99) rejected" {
  ADAPTIVE_HALT_CONFIDENCE=0.99 run bash "$SCRIPT" should-halt "$WT"
  [ "$status" -eq 2 ]
}

@test "tree-hash: produces deterministic hash for same content" {
  echo "content a" > "$WT/file_a.txt"
  echo "content b" > "$WT/file_b.txt"
  local h1 h2
  h1=$(bash "$SCRIPT" tree-hash "$WT")
  h2=$(bash "$SCRIPT" tree-hash "$WT")
  [ "$h1" = "$h2" ]
  [[ "$h1" =~ ^[a-f0-9]{64}$ ]]
}

@test "tree-hash: changes when file content changes" {
  echo "v1" > "$WT/file.txt"
  local h1; h1=$(bash "$SCRIPT" tree-hash "$WT")
  echo "v2" > "$WT/file.txt"
  local h2; h2=$(bash "$SCRIPT" tree-hash "$WT")
  [ "$h1" != "$h2" ]
}

@test "tree-hash: ignores .git directory" {
  mkdir "$WT/.git"
  echo "ref" > "$WT/.git/HEAD"
  echo "code" > "$WT/file.txt"
  local h1; h1=$(bash "$SCRIPT" tree-hash "$WT")
  echo "different ref" > "$WT/.git/HEAD"
  local h2; h2=$(bash "$SCRIPT" tree-hash "$WT")
  [ "$h1" = "$h2" ]
}

@test "edge: missing worktree dir exits 1" {
  run bash "$SCRIPT" should-halt "/nonexistent-$$"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "edge: missing command argument exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "edge: unknown command exits 2" {
  run bash "$SCRIPT" foobar "$WT"
  [ "$status" -eq 2 ]
}

@test "spec ref: SE-074 + Kohli 2026 cited in script header" {
  grep -q "SE-074" "$SCRIPT"
  grep -q "Kohli" "$SCRIPT"
  grep -q "arXiv:2604.07822" "$SCRIPT"
}

@test "safety: adaptive-halting.sh has set -uo pipefail" {
  grep -q 'set -[uo]*o pipefail' "$SCRIPT"
}
