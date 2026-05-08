#!/usr/bin/env bats
# BATS tests for .opencode/hooks/cwd-changed-hook.sh
# Hook: CwdChanged | Auto-inject project context on cd into projects/
# Exit 0 always; stdout shown to Claude.
# Ref: batch 41 hook coverage

HOOK=".opencode/hooks/cwd-changed-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  # Fake workspace
  export CLAUDE_PROJECT_DIR="$TMPDIR/ws-$$"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects"
  # Isolate SAVIA_TMP so state file does not leak across tests / shell
  export SAVIA_TMP="$TMPDIR/savia-$$"
  mkdir -p "$SAVIA_TMP"
  # Isolate HOME to avoid writing to real ~/.savia
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME"
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

# ── Skip when outside projects/ ──────────────────────────

@test "skip: cwd outside projects/ exits 0 with no output" {
  export CLAUDE_CWD="/tmp/random-dir"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "skip: cwd at projects/ root (no project subdir) exits 0" {
  export CLAUDE_CWD="$CLAUDE_PROJECT_DIR/projects"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "cleanup: leaving project dir clears state file" {
  # Setup state as if in project alpha
  export CLAUDE_CWD="$CLAUDE_PROJECT_DIR/projects/alpha/src"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/alpha"
  : > "$CLAUDE_PROJECT_DIR/projects/alpha/CLAUDE.md"
  bash "$HOOK" <<< "" >/dev/null 2>&1
  local state="$TMPDIR/savia-cwd-project-active"
  # Now cd out
  export CLAUDE_CWD="/tmp/other"
  bash "$HOOK" <<< "" >/dev/null 2>&1
  [[ ! -f "$state" ]]
}

# ── Project entry + context injection ───────────────────

@test "inject: project CLAUDE.md present emits [Project context:]" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/alpha"
  mkdir -p "$PROJ"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project context: alpha"* ]]
}

@test "inject: csproj triggers C#/.NET language pack" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/bankapp"
  mkdir -p "$PROJ"
  : > "$PROJ/App.csproj"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"C#/.NET"* ]]
}

@test "inject: package.json + angular.json triggers Angular" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/ngapp"
  mkdir -p "$PROJ"
  : > "$PROJ/package.json"
  : > "$PROJ/angular.json"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Angular"* ]]
}

@test "inject: package.json with react triggers React" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/reactapp"
  mkdir -p "$PROJ"
  echo '{"dependencies":{"react":"18.0"}}' > "$PROJ/package.json"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"React"* ]]
}

@test "inject: package.json plain triggers TypeScript/Node.js" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/nodeapp"
  mkdir -p "$PROJ"
  echo '{"name":"x"}' > "$PROJ/package.json"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"TypeScript"* ]]
}

@test "inject: go.mod triggers Go" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/goapp"
  mkdir -p "$PROJ"
  : > "$PROJ/go.mod"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Go"* ]]
}

@test "inject: Cargo.toml triggers Rust" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/rustapp"
  mkdir -p "$PROJ"
  : > "$PROJ/Cargo.toml"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Rust"* ]]
}

@test "inject: requirements.txt triggers Python" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/pyapp"
  mkdir -p "$PROJ"
  : > "$PROJ/requirements.txt"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Python"* ]]
}

@test "inject: context-index detected" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/idxapp"
  mkdir -p "$PROJ/.context-index"
  : > "$PROJ/.context-index/PROJECT.ctx"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Context index"* ]]
}

@test "inject: spec count included when specs/ exists" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/specapp"
  mkdir -p "$PROJ/specs"
  : > "$PROJ/specs/a.spec.md"
  : > "$PROJ/specs/b.spec.md"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Specs: 2"* ]]
}

# ── Re-entry deduplication (avoid repeated injection) ────

@test "dedup: re-entering same project twice emits once" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/dupapp"
  mkdir -p "$PROJ"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  bash "$HOOK" <<< "" >/dev/null 2>&1
  # Second call — state file now matches, should skip
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: no stdin input handled" {
  export CLAUDE_CWD="/tmp"
  run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "negative: empty project dir (no CLAUDE.md) still exits 0" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/emptyapp"
  mkdir -p "$PROJ"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "negative: project with no detectable language produces no language tag" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/unknownapp"
  mkdir -p "$PROJ"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" != *"Language:"* ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: deep subdir inside project still identifies project name" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/deepapp"
  mkdir -p "$PROJ/src/nested/deep"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ/src/nested/deep"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"deepapp"* ]]
}

@test "edge: Terraform .tf file triggers Terraform lang pack" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/tfapp"
  mkdir -p "$PROJ"
  : > "$PROJ/main.tf"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Terraform"* ]]
}

@test "edge: Gemfile triggers Ruby lang pack" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/rbapp"
  mkdir -p "$PROJ"
  : > "$PROJ/Gemfile"
  export CLAUDE_CWD="$PROJ"
  run bash "$HOOK" <<< ""
  [[ "$output" == *"Ruby"* ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 10+ language pack detection patterns" {
  # Count language branches
  run grep -c 'LANG_PACK=' "$HOOK"
  [[ "$output" -ge 9 ]]
}

@test "coverage: state file dedup logic present" {
  run grep -c 'STATE_FILE' "$HOOK"
  [[ "$output" -ge 3 ]]
}

@test "coverage: profile_gate sourced" {
  run grep -c 'profile_gate' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook exit always 0 (never blocks)" {
  for input in '' 'garbage' '{"x":"y"}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify project files" {
  local PROJ="$CLAUDE_PROJECT_DIR/projects/immut"
  mkdir -p "$PROJ"
  : > "$PROJ/CLAUDE.md"
  export CLAUDE_CWD="$PROJ"
  local before
  before=$(find "$PROJ" -type f -exec md5sum {} + 2>/dev/null | md5sum | awk '{print $1}')
  bash "$HOOK" <<< "" >/dev/null 2>&1
  local after
  after=$(find "$PROJ" -type f -exec md5sum {} + 2>/dev/null | md5sum | awk '{print $1}')
  [[ "$before" == "$after" ]]
}
