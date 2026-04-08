#!/usr/bin/env bats
# Tests for compile-agent-index.sh — Compiled agent reference index
# Ref: docs/propuestas/SPEC-097-compiled-agent-index.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/compile-agent-index.sh"
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
  INDEX_FILE="$REPO_ROOT/.claude/AGENTS-INDEX.md"

  # Backup existing index if present
  if [[ -f "$INDEX_FILE" ]]; then
    cp "$INDEX_FILE" "$INDEX_FILE.bak"
  fi
}

teardown() {
  # Restore backup
  if [[ -f "$INDEX_FILE.bak" ]]; then
    mv "$INDEX_FILE.bak" "$INDEX_FILE"
  fi
}

# ── 1. Script existence and structure ────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has safety flags (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script shows usage without arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. Compile ───────────────────────────────────────────────────────────────

@test "compile creates AGENTS-INDEX.md" {
  run bash "$SCRIPT" compile
  [ "$status" -eq 0 ]
  [ -f "$INDEX_FILE" ]
}

@test "compile output contains auto-generated header" {
  bash "$SCRIPT" compile
  grep -q "Auto-generated" "$INDEX_FILE"
}

@test "compile output contains hash" {
  bash "$SCRIPT" compile
  grep -q "Hash:" "$INDEX_FILE"
}

@test "compile output contains Quick Routing table" {
  bash "$SCRIPT" compile
  grep -q "Quick Routing" "$INDEX_FILE"
}

@test "compile output contains Flows section" {
  bash "$SCRIPT" compile
  grep -q "Flows" "$INDEX_FILE"
}

@test "compile output contains All Agents table" {
  bash "$SCRIPT" compile
  grep -q "All Agents" "$INDEX_FILE"
}

@test "compile reports agent count" {
  run bash "$SCRIPT" compile
  [ "$status" -eq 0 ]
  [[ "$output" == *"agents"* ]]
}

# ── 3. Check freshness ──────────────────────────────────────────────────────

@test "check passes after fresh compile" {
  bash "$SCRIPT" compile
  run bash "$SCRIPT" check
  [ "$status" -eq 0 ]
  [[ "$output" == *"FRESH"* ]]
}

@test "check fails when no index exists" {
  rm -f "$INDEX_FILE"
  run bash "$SCRIPT" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE"* ]]
}

# ── 4. Stats ─────────────────────────────────────────────────────────────────

@test "stats shows agent count" {
  run bash "$SCRIPT" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total agents"* ]]
}

@test "stats shows model distribution" {
  run bash "$SCRIPT" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"By model"* ]]
}

# ── 5. Show ──────────────────────────────────────────────────────────────────

@test "show displays index content" {
  bash "$SCRIPT" compile
  run bash "$SCRIPT" show
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent Index"* ]]
}

@test "show fails when no index exists" {
  rm -f "$INDEX_FILE"
  run bash "$SCRIPT" show
  [ "$status" -eq 1 ]
}

# ── 6. Content quality ──────────────────────────────────────────────────────

@test "compiled index lists architect agent" {
  bash "$SCRIPT" compile
  grep -q "architect" "$INDEX_FILE"
}

@test "compiled index lists dotnet-developer agent" {
  bash "$SCRIPT" compile
  grep -q "dotnet-developer" "$INDEX_FILE"
}

@test "compiled index has SDD flow" {
  bash "$SCRIPT" compile
  grep -q "SDD" "$INDEX_FILE"
}

# ── 7. Edge cases ────────────────────────────────────────────────────────────

@test "unknown command shows error" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 1 ]
}
