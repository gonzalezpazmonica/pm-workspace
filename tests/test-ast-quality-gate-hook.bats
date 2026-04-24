#!/usr/bin/env bats
# BATS tests for .claude/hooks/ast-quality-gate-hook.sh
# PostToolUse async (Edit|Write). Runs quality gate against modified code file.
# Never blocks (async advisory only). Exit 0 always.
# Ref: batch 41 hook coverage

HOOK=".claude/hooks/ast-quality-gate-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths (no input / non-code files) ───────────────

@test "skip: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "skip: missing file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{}}'
  [ "$status" -eq 0 ]
}

@test "skip: .md file ignored (not source code)" {
  local F="$TMPDIR/doc-$$.md"
  echo "# doc" > "$F"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  rm -f "$F"
}

@test "skip: .json file ignored" {
  local F="$TMPDIR/config-$$.json"
  echo '{}' > "$F"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  rm -f "$F"
}

@test "skip: nonexistent source file exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/nonexistent/x.py"}}'
  [ "$status" -eq 0 ]
}

# ── Source code extension detection ─────────────────────

@test "trigger: .cs file recognized as source" {
  run grep -c 'cs|' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "trigger: .ts, .tsx, .py, .go, .rs, .rb, .java all in supported list" {
  for ext in ts tsx py go rs rb java; do
    grep -q "$ext" "$HOOK" || fail "ext $ext not in supported list"
  done
}

@test "trigger: .tf (Terraform) in supported list" {
  run grep -c 'tf|tfvars' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "trigger: COBOL extensions (.cob, .cbl, .cpy) included" {
  run grep -cE 'cob|cbl|cpy' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Graceful degradation ─────────────────────────────────

@test "graceful: missing ast-quality-gate.sh exits 0 silently" {
  # Use a temp dir with source file; hook walks up looking for scripts/ast-quality-gate.sh.
  # In /tmp there is no scripts/ dir, so graceful fallback path triggers.
  local WSROOT="$TMPDIR/ws-noscript-$$"
  mkdir -p "$WSROOT"
  local F="$WSROOT/test.py"
  echo "print('hi')" > "$F"
  # Capture cwd to restore afterwards; use absolute $HOOK path
  local HOOK_ABS="$(pwd)/$HOOK"
  cd "$WSROOT"
  run bash "$HOOK_ABS" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  rm -rf "$WSROOT"
}

# ── Negative cases ───────────────────────────────────────

@test "negative: malformed JSON exits 0" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: null file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":null}}'
  [ "$status" -eq 0 ]
}

@test "negative: file_path is directory exits 0" {
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TMPDIR\"}}"
  [ "$status" -eq 0 ]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: file with no extension exits 0" {
  local F="$TMPDIR/noext-$$"
  echo "content" > "$F"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  rm -f "$F"
}

@test "edge: hidden file with .py exits as expected" {
  local F="$TMPDIR/.hidden-$$.py"
  echo "x = 1" > "$F"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  rm -f "$F"
}

@test "edge: csproj (xml-like project file) is code extension" {
  run grep -c 'csproj' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ─────────────────────────────────────────────

@test "coverage: ast-quality-gate.sh script path referenced" {
  run grep -c 'ast-quality-gate.sh' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: output/quality-gates directory declared" {
  run grep -c 'output/quality-gates' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: latest.json alias defined" {
  run grep -c 'latest.json' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: --advisory flag passed to gate" {
  run grep -c '\-\-advisory' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook exit always 0 (async never blocks)" {
  for input in '' 'garbage' '{}' '{"tool_input":{"file_path":"x.md"}}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: non-code file input does not invoke gate script" {
  # .md doesn't match any supported extension → early exit, no gate invoked
  local F="$TMPDIR/x-$$.md"
  echo "# foo" > "$F"
  # Track if gate was called by checking if output/quality-gates has new files
  local before
  before=$(find output/quality-gates -name "*.json" 2>/dev/null | wc -l || echo 0)
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  local after
  after=$(find output/quality-gates -name "*.json" 2>/dev/null | wc -l || echo 0)
  [[ "$before" == "$after" ]]
  rm -f "$F"
}
