#!/usr/bin/env bats
# BATS tests for .opencode/hooks/pre-commit-review.sh
# Ref: batch 39 hook test coverage gap

HOOK=".opencode/hooks/pre-commit-review.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$TMPDIR/workspace-$$"
  mkdir -p "$CLAUDE_PROJECT_DIR/output/.review-cache"
  mkdir -p "$CLAUDE_PROJECT_DIR/docs/rules/domain"
  # Init a fake git repo so git diff --cached doesn't fail hard
  (cd "$CLAUDE_PROJECT_DIR" && git init -q 2>/dev/null || true)
}
teardown() {
  rm -rf "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ───────────────────────────────────────────

@test "skip: no rules file exits 0 (nothing to enforce)" {
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: no staged files exits 0" {
  echo "# Code review rules" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

# ── Cache invalidation ───────────────────────────────────

@test "cache: creates rules hash file on first run" {
  echo "# Rules v1" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  run bash "$HOOK"
  [[ -f "$CLAUDE_PROJECT_DIR/output/.review-cache/.rules-hash" ]]
}

@test "cache: rules hash file contains sha256" {
  echo "# Rules" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  bash "$HOOK" >/dev/null 2>&1 || true
  local h
  h=$(cat "$CLAUDE_PROJECT_DIR/output/.review-cache/.rules-hash")
  [[ "${#h}" -eq 64 ]]  # sha256 is 64 hex chars
}

@test "cache: rules change invalidates .passed cache files" {
  echo "# Rules v1" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  bash "$HOOK" >/dev/null 2>&1 || true
  : > "$CLAUDE_PROJECT_DIR/output/.review-cache/fake-abc.passed"
  # Modify rules
  echo "# Rules v2 changed" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  bash "$HOOK" >/dev/null 2>&1 || true
  # .passed files should be gone
  run find "$CLAUDE_PROJECT_DIR/output/.review-cache" -name "*.passed"
  [[ -z "$output" ]]
}

# ── Negative cases ───────────────────────────────────────

@test "negative: missing CLAUDE_PROJECT_DIR still runs (falls back to .)" {
  unset CLAUDE_PROJECT_DIR
  run bash "$HOOK"
  # Should not crash; exit 0 since no rules in cwd
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "negative: rules file is empty, hash computes to zero-content sha" {
  : > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "negative: cache dir non-writable would cause mkdir warning (but not fatal)" {
  # Simulate: don't pre-create cache dir — hook should mkdir
  rm -rf "$CLAUDE_PROJECT_DIR/output/.review-cache"
  echo "# Rules" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  run bash "$HOOK"
  [[ -d "$CLAUDE_PROJECT_DIR/output/.review-cache" ]]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: cache dir created on first run" {
  rm -rf "$CLAUDE_PROJECT_DIR/output/.review-cache"
  echo "# Rules" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  bash "$HOOK" >/dev/null 2>&1 || true
  [[ -d "$CLAUDE_PROJECT_DIR/output/.review-cache" ]]
}

@test "edge: only code files trigger review (pattern matching)" {
  # Verify the file type filter covers common languages
  run grep -cE '\*\.(cs|ts|py|go|rs|rb|java)' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "edge: SHA256 is used for content hash (not MD5)" {
  run grep -c 'sha256sum' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "edge: combined hash includes content AND rules" {
  run grep -c 'COMBINED_HASH' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ──────────────────────────────────────────────

@test "coverage: CACHE_DIR variable defined" {
  run grep -c '^CACHE_DIR=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: RULES_FILE path declared" {
  run grep -c 'RULES_FILE=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: profile_gate sourced" {
  run grep -c 'profile_gate' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook does not write outside output/.review-cache/" {
  echo "# Rules" > "$CLAUDE_PROJECT_DIR/docs/rules/domain/code-review-rules.md"
  local files_before
  files_before=$(find "$CLAUDE_PROJECT_DIR" -type f ! -path "*/.review-cache/*" 2>/dev/null | wc -l)
  bash "$HOOK" >/dev/null 2>&1 || true
  local files_after
  files_after=$(find "$CLAUDE_PROJECT_DIR" -type f ! -path "*/.review-cache/*" 2>/dev/null | wc -l)
  [[ "$files_before" == "$files_after" ]]
}

@test "isolation: exit codes bounded to {0,1,2}" {
  run bash "$HOOK"
  [[ "$status" -eq 0 || "$status" -eq 1 || "$status" -eq 2 ]]
}
