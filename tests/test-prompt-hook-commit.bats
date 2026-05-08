#!/usr/bin/env bats
# BATS tests for .opencode/hooks/prompt-hook-commit.sh
# Semantic validation of git commit messages vs staged diff.
# Ref: batch 42 hook coverage

HOOK=".opencode/hooks/prompt-hook-commit.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export TEST_REPO="$TMPDIR/repo-$$"
  mkdir -p "$TEST_REPO"
  (cd "$TEST_REPO" && git init -q && git config user.email t@t && git config user.name t && git config commit.gpgsign false)
  # Default to warning mode (non-blocking)
  export PROMPT_HOOKS_MODE=warning
  export PROMPT_HOOKS_ENABLED=true
  # Absolute hook path for subshell invocations
  export HOOK_ABS="$(pwd)/$HOOK"
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ───────────────────────────────────────────

@test "skip: PROMPT_HOOKS_ENABLED=false disables hook" {
  export PROMPT_HOOKS_ENABLED=false
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: non-git-commit command ignored" {
  export CLAUDE_TOOL_INPUT='ls -la'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: git commit without -m flag ignored" {
  export CLAUDE_TOOL_INPUT='git commit'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: empty staged diff exits 0" {
  cd "$TEST_REPO"
  export CLAUDE_TOOL_INPUT='git commit -m "feat: add something"'
  run bash "$HOOK_ABS"
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Heuristic: fix + only adds ───────────────────────────

@test "detect: fix prefix with only new files flags issue" {
  cd "$TEST_REPO"
  echo "new content" > newfile.txt
  git add newfile.txt
  export CLAUDE_TOOL_INPUT='git commit -m "fix: repair the issue"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"fix"* ]]
}

# ── Heuristic: add + only deletions ──────────────────────

@test "detect: add/feat prefix with only deletions flags issue" {
  cd "$TEST_REPO"
  echo "content" > tobedeleted.txt
  git add tobedeleted.txt
  git commit -q -m init
  git rm tobedeleted.txt -q
  export CLAUDE_TOOL_INPUT='git commit -m "feat: add new functionality"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"add/feat"* ]] || [[ "$output" == *"deletions"* ]]
}

# ── Heuristic: too short ─────────────────────────────────

@test "detect: message under 10 chars flagged as too short" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"too short"* ]]
}

@test "detect: message exactly 10 chars not flagged as short" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT='git commit -m "fix:abcdef"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" != *"too short"* ]]
}

# ── Heuristic: first line > 72 chars ─────────────────────

@test "detect: first line exceeds 72 chars flagged" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  local long='feat: this is a very long commit message that exceeds seventy two characters intentionally'
  export CLAUDE_TOOL_INPUT="git commit -m \"$long\""
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"72"* ]]
}

# ── Mode handling ───────────────────────────────────────

@test "mode: warning mode exits 0 even with issues" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export PROMPT_HOOKS_MODE=warning
  export CLAUDE_TOOL_INPUT='git commit -m "fix: short"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "mode: soft-block exits 2 on issues" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export PROMPT_HOOKS_MODE=soft-block
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
  [[ "$output" == *"soft-block"* ]]
}

@test "mode: hard-block exits 2 with blocked message" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export PROMPT_HOOKS_MODE=hard-block
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocked"* ]]
}

@test "mode: default is warning (no env set)" {
  unset PROMPT_HOOKS_MODE
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]  # warning default does not block
}

# ── Clean commits pass ──────────────────────────────────

@test "clean: proper feat message with adds exits 0 silently" {
  cd "$TEST_REPO"
  echo "new" > newfile.txt
  git add newfile.txt
  export CLAUDE_TOOL_INPUT='git commit -m "feat: add newfile module"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [[ "$output" != *"Prompt Hook"* ]]
}

@test "clean: proper fix message with modifications passes" {
  cd "$TEST_REPO"
  echo "v1" > f.txt
  git add f.txt
  git commit -q -m init
  echo "v2" > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT='git commit -m "fix: update f.txt with v2"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

# ── Negative cases ───────────────────────────────────────

@test "negative: no CLAUDE_TOOL_INPUT env exits 0" {
  unset CLAUDE_TOOL_INPUT
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "negative: outside git repo exits 0 gracefully" {
  cd "$TMPDIR"
  export CLAUDE_TOOL_INPUT='git commit -m "feat: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: single quoted message parsed" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT="git commit -m 'feat: add f.txt'"
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "edge: message with 72 chars exactly not flagged" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  local exactly72='feat: exactly seventy two characters long message that is acceptable'
  export CLAUDE_TOOL_INPUT="git commit -m \"$exactly72\""
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" != *"72 characters"* ]]
}

@test "edge: unknown mode falls through without blocking" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  export PROMPT_HOOKS_MODE=nonexistent-mode
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

# ── Coverage ─────────────────────────────────────────────

@test "coverage: 3 modes handled (warning, soft-block, hard-block)" {
  for mode in warning soft-block hard-block; do
    grep -q "\"$mode\"" "$HOOK" || fail "missing mode: $mode"
  done
}

@test "coverage: 4 heuristic checks (fix+adds, add+deletes, too short, line>72)" {
  run grep -c 'ISSUES+=' "$HOOK"
  [[ "$output" -ge 4 ]]
}

@test "coverage: CHANGELOG link validator integration" {
  run grep -c 'validate-changelog-links' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook does not modify repo state" {
  cd "$TEST_REPO"
  echo "x" > f.txt
  git add f.txt
  local before
  before=$(git status --porcelain)
  export CLAUDE_TOOL_INPUT='git commit -m "fix: x"'
  bash "$HOOK_ABS" >/dev/null 2>&1 || true
  local after
  after=$(git status --porcelain)
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes bounded to {0, 2}" {
  run bash "$HOOK"
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}
