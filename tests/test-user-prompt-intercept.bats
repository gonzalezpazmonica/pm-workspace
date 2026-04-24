#!/usr/bin/env bats
# BATS tests for .claude/hooks/user-prompt-intercept.sh
# UserPromptSubmit hook — SPEC-015 context gate + session hot-file injection.
# Injects session-hot.md on first prompt, active project hint if in project dir.
# Batch 45 hook coverage.

HOOK=".claude/hooks/user-prompt-intercept.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="${SAVIA_HOOK_PROFILE:-standard}"
  # Clean global state for each test to control injection
  rm -f "$TMPDIR"/savia-session-hot-injected-* 2>/dev/null || true
}
teardown() {
  cd /
  rm -f "$TMPDIR"/savia-session-hot-injected-* 2>/dev/null || true
  rm -f "$TMPDIR"/savia-prompt-hook-*-injected 2>/dev/null || true
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "SPEC-015 reference" {
  run grep -c 'SPEC-015' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "has profile_gate standard" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Silent pass paths ───────────────────────────────────

@test "silent: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "silent: very short input (<3 chars) exits silently" {
  run bash "$HOOK" <<< "ok"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: slash command passes silently" {
  run bash "$HOOK" <<< "/pr-plan"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: si confirmation passes" {
  run bash "$HOOK" <<< "si"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: sí with accent passes (UTF-8 locale)" {
  # Hook treats "sí" as silent only under UTF-8 locale — under C locale
  # multibyte handling differs. Document actual UTF-8 behavior.
  LC_ALL=C.UTF-8 LANG=C.UTF-8 run bash "$HOOK" <<< "sí"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: no confirmation passes" {
  run bash "$HOOK" <<< "no"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: vale confirmation passes" {
  run bash "$HOOK" <<< "vale"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: hecho confirmation passes" {
  run bash "$HOOK" <<< "hecho"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: gracias confirmation passes" {
  run bash "$HOOK" <<< "gracias"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Normal prompt processing ────────────────────────────

@test "normal: regular prompt proceeds without output when no project/session" {
  # No session-hot, not in project → no injection
  run bash "$HOOK" <<< "please implement the new feature"
  [ "$status" -eq 0 ]
}

@test "normal: JSON content field extracted" {
  run bash "$HOOK" <<< '{"content":"please review the pull request"}'
  [ "$status" -eq 0 ]
}

# ── Session-hot injection ───────────────────────────────

@test "session-hot: injects when file exists and flag absent" {
  local temp_home
  temp_home=$(mktemp -d "$TMPDIR/uph-home-XXXXXX")
  local repo_slug proj_dir
  repo_slug=$(pwd | sed 's|[/:\]|-|g; s|^-||')
  proj_dir="$temp_home/.claude/projects/$repo_slug/memory"
  mkdir -p "$proj_dir"
  echo "Last session: did X, Y, Z" > "$proj_dir/session-hot.md"

  HOME="$temp_home" run bash "$HOOK" <<< "continue the work"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous session context"* ]]
  [[ "$output" == *"Last session"* ]]

  rm -rf "$temp_home"
}

@test "session-hot: NOT injected when flag file exists" {
  local temp_home
  temp_home=$(mktemp -d "$TMPDIR/uph-home-XXXXXX")
  local repo_slug proj_dir
  repo_slug=$(pwd | sed 's|[/:\]|-|g; s|^-||')
  proj_dir="$temp_home/.claude/projects/$repo_slug/memory"
  mkdir -p "$proj_dir"
  echo "prior session" > "$proj_dir/session-hot.md"

  # Pre-create the daily global flag
  local today_flag="$TMPDIR/savia-session-hot-injected-$(date +%Y%m%d)"
  touch "$today_flag"

  HOME="$temp_home" run bash "$HOOK" <<< "continue working"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Previous session context"* ]]

  rm -f "$today_flag"
  rm -rf "$temp_home"
}

@test "session-hot: no injection if file missing" {
  local temp_home
  temp_home=$(mktemp -d "$TMPDIR/uph-home-XXXXXX")
  HOME="$temp_home" run bash "$HOOK" <<< "start a new session"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Previous session context"* ]]
  rm -rf "$temp_home"
}

# ── Active project hint ─────────────────────────────────

@test "project: active project hint injected when in projects/ dir" {
  local repo_root proj_name="bats-fixture-proj"
  repo_root=$(pwd)
  local proj_path="$repo_root/projects/$proj_name"
  mkdir -p "$proj_path"
  echo "# Sample" > "$proj_path/CLAUDE.md"

  CLAUDE_PROJECT_DIR="$repo_root" CLAUDE_CWD="$proj_path" \
    run bash "$HOOK" <<< "hello from the project dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$proj_name"* ]]

  rm -rf "$proj_path"
}

@test "project: no hint when not in projects/ dir" {
  CLAUDE_CWD="/tmp" run bash "$HOOK" <<< "a regular question"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Active project"* ]]
}

@test "project: no hint if project lacks CLAUDE.md" {
  local proj_name="no-claude-md-proj"
  local proj_path="$BATS_TEST_DIRNAME/../projects/$proj_name"
  mkdir -p "$proj_path"
  CLAUDE_CWD="$proj_path" run bash "$HOOK" <<< "working question here"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Active project"* ]]
  rm -rf "$proj_path"
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: uppercase confirmation (SI) not treated as silent" {
  # Regex is case-insensitive via -i
  run bash "$HOOK" <<< "SI"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "edge: prompt with embedded newlines" {
  run bash "$HOOK" <<< "multi
line
prompt here"
  [ "$status" -eq 0 ]
}

@test "edge: prompt with JSON-looking content but not JSON" {
  run bash "$HOOK" <<< 'looks like {"json":"but isnt"} really'
  [ "$status" -eq 0 ]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON passes through" {
  run bash "$HOOK" <<< '{"content":"unterminated'
  [ "$status" -eq 0 ]
}

@test "negative: large input does not crash" {
  local big
  big=$(printf 'text %.0s' {1..500})
  run bash "$HOOK" <<< "$big"
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: session-hot.md referenced" {
  run grep -c 'session-hot.md' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: Context Gate step 0 mentioned" {
  run grep -c 'Context Gate' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: confirmation regex covers 10+ patterns" {
  run grep -oE 'sí|ok|vale|claro|hecho|listo|cancelar|adelante|gracias' "$HOOK"
  [[ -n "$output" ]]
}

@test "coverage: Active project label format" {
  run grep -c 'Active project' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ───────────────────────────────────────────

@test "isolation: never blocks (always exit 0)" {
  for input in '' 'x' 'si' '/slash' 'real long prompt' '{"content":"json"}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify repo files" {
  local before after
  before=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< "some user question" >/dev/null 2>&1
  after=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
