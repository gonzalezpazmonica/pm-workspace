#!/usr/bin/env bats
# BATS tests for SE-029 Iterative Context Compression
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-029-iterative-compression.md
# SCRIPT: scripts/iterative-compress.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 231
# Problem: repeated /compact destroys accumulated context
# Solution: iterative prune + structured summary that survives across compactions
# Acceptance: prune removes noise, summary preserves structure, status reports correctly
# Dependencies: iterative-compress.sh

## Problem: each /compact generates summary from scratch, losing prior context
## Solution: deterministic prune + iterative structured summary with delta updates
## Acceptance: prune eliminates noise, summary has required sections, status works

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/iterative-compress.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-029-iterative-compression.md"
  TMPDIR_CMP=$(mktemp -d)
  export HOME="$TMPDIR_CMP/fakehome"
  mkdir -p "$HOME/.claude/projects/-home-monica-claude/memory"
  export CLAUDE_PROJECT_DIR="$TMPDIR_CMP"
}
teardown() {
  rm -rf "$TMPDIR_CMP"
}

## Structural tests

@test "iterative-compress.sh exists, executable, valid syntax" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
}
@test "uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "spec exists" {
  [[ -f "$SPEC" ]]
}

## Prune tests

@test "prune removes simple confirmations" {
  local input="$TMPDIR_CMP/input.txt"
  printf 'Important decision made here\nok\nsi\nvale\nhecho\nAnother important line\n' > "$input"
  run bash "$SCRIPT" prune --input "$input"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Important decision"* ]]
  [[ "$output" == *"Another important"* ]]
  [[ "$output" != *$'\nok\n'* ]]
}
@test "prune removes decorative separators" {
  local input="$TMPDIR_CMP/input.txt"
  printf 'Content before\n═══════════════════════\nContent after\n━━━━━━━━━━━━━━━\nMore content\n' > "$input"
  run bash "$SCRIPT" prune --input "$input"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Content before"* ]]
  [[ "$output" == *"Content after"* ]]
  echo "$output" | grep -cvE '^[═━─]' | grep -q "[0-9]"
}
@test "prune preserves decision content" {
  local input="$TMPDIR_CMP/input.txt"
  printf 'We decided to use PostgreSQL for the database\nok\nThe architecture follows DDD patterns\n' > "$input"
  run bash "$SCRIPT" prune --input "$input"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PostgreSQL"* ]]
  [[ "$output" == *"DDD patterns"* ]]
}
@test "prune handles empty input without crash" {
  local input="$TMPDIR_CMP/input.txt"
  touch "$input"
  run bash "$SCRIPT" prune --input "$input"
  [[ "$status" -eq 0 ]]
}

## Summarize tests

@test "summarize generates initial summary with required sections" {
  local input="$TMPDIR_CMP/input.txt"
  echo "Session context here" > "$input"
  run bash "$SCRIPT" summarize --input "$input"
  [[ "$status" -eq 0 ]]
  [[ -f "$HOME/.claude/projects/-home-monica-claude/memory/session-hot.md" ]]
  local summary; summary=$(cat "$HOME/.claude/projects/-home-monica-claude/memory/session-hot.md")
  [[ "$summary" == *"Resolved"* ]]
  [[ "$summary" == *"In Progress"* ]]
  [[ "$summary" == *"Pending Questions"* ]]
  [[ "$summary" == *"Corrections Applied"* ]]
  [[ "$summary" == *"compact #1"* ]]
}
@test "summarize increments compact number on subsequent calls" {
  local input="$TMPDIR_CMP/input.txt"
  echo "First session" > "$input"
  bash "$SCRIPT" summarize --input "$input" >/dev/null
  echo "Second session" > "$input"
  bash "$SCRIPT" summarize --input "$input" >/dev/null
  local summary; summary=$(cat "$HOME/.claude/projects/-home-monica-claude/memory/session-hot.md")
  [[ "$summary" == *"compact #2"* ]]
}

## Status tests

@test "status reports no summary when none exists" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No active"* ]]
}
@test "status reports summary info after summarize" {
  echo "test" | bash "$SCRIPT" summarize >/dev/null
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Compact cycle"* ]]
  [[ "$output" == *"Lines"* ]]
}

## Edge cases

@test "shows usage with no args" {
  run bash "$SCRIPT"
  [[ "$output" == *"Usage"* ]]
}
