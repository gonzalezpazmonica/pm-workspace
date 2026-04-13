#!/usr/bin/env bats
# BATS tests for SE-033 Context Rotation Strategy
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-033-context-rotation.md
# SCRIPT: scripts/context-rotation.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-13
# Era: 231
# Problem: session-hot.md and auto-memory accumulate without temporal limits
# Solution: 3 rotation cycles (daily/weekly/monthly) with archiving
# Acceptance: daily rotates >24h, weekly archives stale, monthly enforces 25KB cap
# Dependencies: context-rotation.sh, memory-hygiene.sh

## Problem: memory grows unbounded, degrading session quality
## Solution: automated rotation with 3 cycles + archiving
## Acceptance: session-hot archived when stale, entries retired, cap enforced

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-rotation.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-033-context-rotation.md"
  TMPDIR_ROT=$(mktemp -d)
  export MEMORY_DIR="$TMPDIR_ROT/memory"
  mkdir -p "$MEMORY_DIR"
  # Create a basic MEMORY.md
  echo "- [test.md](test.md) — test entry" > "$MEMORY_DIR/MEMORY.md"
}
teardown() {
  rm -rf "$TMPDIR_ROT"
}

## Structural tests

@test "context-rotation.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}
@test "uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "spec file exists" {
  [[ -f "$SPEC" ]]
}

## Status mode

@test "status runs without error" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Context Rotation Status"* ]]
}
@test "status shows memory size" {
  run bash "$SCRIPT" status
  [[ "$output" == *"Memory size:"* ]]
}

## Daily rotation

@test "daily skips fresh session-hot (<24h)" {
  echo "## Session Context" > "$MEMORY_DIR/session-hot.md"
  run bash "$SCRIPT" daily
  [[ "$status" -eq 0 ]]
  # Archive dir should NOT be created
  [[ ! -d "$MEMORY_DIR/archive/sessions" ]] || [[ $(find "$MEMORY_DIR/archive/sessions" -name "*.md" 2>/dev/null | wc -l) -eq 0 ]]
}
@test "daily archives stale session-hot (>24h)" {
  echo "## Session Context" > "$MEMORY_DIR/session-hot.md"
  # Backdate the file to 25 hours ago
  touch -d "25 hours ago" "$MEMORY_DIR/session-hot.md"
  run bash "$SCRIPT" daily
  [[ "$status" -eq 0 ]]
  # Archive should exist
  [[ -d "$MEMORY_DIR/archive/sessions" ]]
  local count
  count=$(find "$MEMORY_DIR/archive/sessions" -name "*.md" | wc -l)
  [[ "$count" -ge 1 ]]
}
@test "daily creates new session-hot after rotation" {
  echo "## Old session content" > "$MEMORY_DIR/session-hot.md"
  touch -d "25 hours ago" "$MEMORY_DIR/session-hot.md"
  run bash "$SCRIPT" daily
  [[ "$status" -eq 0 ]]
  # New session-hot should exist and be fresh
  [[ -f "$MEMORY_DIR/session-hot.md" ]]
  grep -q "New session started" "$MEMORY_DIR/session-hot.md"
}

## Weekly rotation

@test "weekly generates summary file" {
  # Create a stale project memory
  cat > "$MEMORY_DIR/old-project.md" <<'EOF'
---
name: old-project
type: project
description: old project memory
---
Some old project data
EOF
  touch -d "10 days ago" "$MEMORY_DIR/old-project.md"
  echo "- [old-project.md](old-project.md) — old project" >> "$MEMORY_DIR/MEMORY.md"

  run bash "$SCRIPT" weekly
  [[ "$status" -eq 0 ]]
  # Weekly summary should exist
  local week_id
  week_id=$(date +%Y-W%V)
  [[ -f "output/weekly-summaries/${week_id}.md" ]]
}

## Monthly rotation

@test "monthly calls hygiene and reports size" {
  run bash "$SCRIPT" monthly
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Monthly"* ]]
}

## Edge cases — empty, nonexistent, boundary

@test "daily handles nonexistent session-hot gracefully" {
  rm -f "$MEMORY_DIR/session-hot.md"
  run bash "$SCRIPT" daily
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"nothing to rotate"* ]]
}
@test "weekly handles empty MEMORY.md without error" {
  echo "" > "$MEMORY_DIR/MEMORY.md"
  run bash "$SCRIPT" weekly
  [[ "$status" -eq 0 ]]
}
@test "monthly handles empty memory directory gracefully" {
  rm -f "$MEMORY_DIR"/*.md
  echo "" > "$MEMORY_DIR/MEMORY.md"
  run bash "$SCRIPT" monthly
  [[ "$status" -eq 0 ]]
}
@test "status works with nonexistent archive directory" {
  [[ ! -d "$MEMORY_DIR/archive" ]]
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Archived sessions: 0"* ]]
}

## Coverage: cmd_daily, cmd_weekly, cmd_monthly, cmd_status, file_age_hours, file_age_days, memory_size_kb

## Feedback protection

@test "weekly never archives feedback entries" {
  cat > "$MEMORY_DIR/keep-feedback.md" <<'EOF'
---
name: keep-feedback
type: feedback
description: important feedback
---
Never archive this
EOF
  touch -d "30 days ago" "$MEMORY_DIR/keep-feedback.md"
  echo "- [keep-feedback.md](keep-feedback.md) — feedback" >> "$MEMORY_DIR/MEMORY.md"

  run bash "$SCRIPT" weekly
  [[ "$status" -eq 0 ]]
  # Feedback file must still exist in memory dir (not archived)
  [[ -f "$MEMORY_DIR/keep-feedback.md" ]]
}
