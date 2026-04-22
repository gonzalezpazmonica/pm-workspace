#!/usr/bin/env bats
# Tests for .claude/hooks/acm-enforcement.sh (SE-063 Slice 1)
# Ref: docs/propuestas/SE-063-acm-enforcement-pretool-hook.md
# Ref: SPEC-063 ACM enforcement pre-tool hook

SCRIPT="${BATS_TEST_DIRNAME}/../.claude/hooks/acm-enforcement.sh"
MARKER_SCRIPT="${BATS_TEST_DIRNAME}/../.claude/hooks/acm-turn-marker.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "enforcement hook missing"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export TMPDIR="$TMP_DIR"
  export CLAUDE_TURN_ID="test-turn-$$"
  export CLAUDE_PROJECT_DIR="$TMP_DIR/workspace"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/alpha/.agent-maps"
  : > "$CLAUDE_PROJECT_DIR/projects/alpha/.agent-maps/INDEX.acm"
  # Project without ACM for negative tests
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/beta"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "safety: script uses set -uo pipefail" {
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "empty stdin returns exit 0 (no-op)" {
  run bash "$SCRIPT" <<< ""
  [[ "$status" -eq 0 ]]
}

@test "non-Glob/Grep tool is ignored" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/foo"}}'
  [[ "$status" -eq 0 ]]
}

@test "positive: narrow Grep with path and type is allowed" {
  input='{"tool_name":"Grep","tool_input":{"pattern":"FooBar","path":"projects/alpha/src","type":"py"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: Glob with path restricted to project is allowed" {
  input='{"tool_name":"Glob","tool_input":{"pattern":"*.py","path":"projects/alpha/src"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: query on .claude infra is exempt" {
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":".claude"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: query on docs is exempt" {
  input='{"tool_name":"Grep","tool_input":{"pattern":"anything","path":"docs/rules"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: query on scripts is exempt" {
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"scripts"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: query on tests is exempt" {
  input='{"tool_name":"Glob","tool_input":{"pattern":"**/*.bats","path":"tests"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "positive: project without INDEX.acm is exempt (no enforcement)" {
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/beta"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "warn mode: wide Grep in project with ACM emits stderr but exit 0" {
  export SAVIA_ACM_ENFORCE=warn
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ACM enforcement"* ]]
}

@test "block mode: wide Grep in project with ACM exits 2" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"ACM enforcement"* ]]
  [[ "$output" == *"projects/alpha/.agent-maps/INDEX.acm"* ]]
}

@test "block mode: wide Glob without path is exempt (no project scope)" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Glob","tool_input":{"pattern":"**/*.md"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "block mode: Grep pattern wildcard in project blocked" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":"**","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
}

@test "marker bypass: if ACM already read this turn, wide query allowed" {
  export SAVIA_ACM_ENFORCE=block
  MARKER_DIR="$TMP_DIR/savia-turn-$CLAUDE_TURN_ID"
  mkdir -p "$MARKER_DIR"
  : > "$MARKER_DIR/acm-read-alpha"
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "SAVIA_ACM_ENFORCE=0 disables hook globally" {
  export SAVIA_ACM_ENFORCE=0
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "SAVIA_ACM_ENFORCE=off disables hook globally" {
  export SAVIA_ACM_ENFORCE=off
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "negative: malformed JSON input returns exit 0 (fail open)" {
  run bash "$SCRIPT" <<< "not valid json"
  [[ "$status" -eq 0 ]]
}

@test "negative: missing tool_name exits 0" {
  run bash "$SCRIPT" <<< '{"tool_input":{"pattern":".*"}}'
  [[ "$status" -eq 0 ]]
}

@test "edge: empty pattern treated as wide" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":"","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
}

@test "edge: nonexistent project path has no INDEX.acm → exempt" {
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/nonexistent"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
}

@test "edge: deeply nested project subpath resolves to project name" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha/src/deep/nested"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
}

@test "logging: enforcement event appended to output/acm-enforcement.log" {
  export SAVIA_ACM_ENFORCE=warn
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ -f "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log" ]]
  run grep -q "project=alpha" "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log"
  [[ "$status" -eq 0 ]]
}

@test "isolation: TMP_DIR is scoped per-test" {
  [[ -n "${TMP_DIR:-}" ]]
  [[ -d "$TMP_DIR" ]]
}

@test "safety: hook does not modify project files" {
  ACM_BEFORE=$(md5sum "$CLAUDE_PROJECT_DIR/projects/alpha/.agent-maps/INDEX.acm" | awk '{print $1}')
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  ACM_AFTER=$(md5sum "$CLAUDE_PROJECT_DIR/projects/alpha/.agent-maps/INDEX.acm" | awk '{print $1}')
  [[ "$ACM_BEFORE" == "$ACM_AFTER" ]]
}

@test "assertion: stderr message contains SE-063 reference" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$output" == *"SE-063"* ]]
}

@test "assertion: exit codes are in {0, 2} (never 1)" {
  export SAVIA_ACM_ENFORCE=block
  for payload in \
    '{"tool_name":"Read","tool_input":{}}' \
    '{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}' \
    ''; do
    run bash "$SCRIPT" <<< "$payload"
    [[ "$status" -eq 0 || "$status" -eq 2 ]]
  done
}

@test "companion: marker hook exists and is executable" {
  [[ -x "$MARKER_SCRIPT" ]]
}

@test "marker hook creates marker when reading INDEX.acm" {
  export CLAUDE_TURN_ID="marker-test-$$"
  input='{"tool_name":"Read","tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/projects/alpha/.agent-maps/INDEX.acm"}}'
  run bash "$MARKER_SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ -f "$TMPDIR/savia-turn-$CLAUDE_TURN_ID/acm-read-alpha" ]]
}

@test "marker hook ignores non-Read tools" {
  export CLAUDE_TURN_ID="marker-noread-$$"
  input='{"tool_name":"Write","tool_input":{"file_path":"projects/alpha/.agent-maps/INDEX.acm"}}'
  run bash "$MARKER_SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$TMPDIR/savia-turn-$CLAUDE_TURN_ID/acm-read-alpha" ]]
}

@test "marker hook ignores non-agent-maps paths" {
  export CLAUDE_TURN_ID="marker-other-$$"
  input='{"tool_name":"Read","tool_input":{"file_path":"docs/rules/something.md"}}'
  run bash "$MARKER_SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$TMPDIR/savia-turn-$CLAUDE_TURN_ID/acm-read-alpha" ]]
}

# ── Slice 3 — per-project opt-out + log verbosity ──────────────────────────

@test "slice3: per-project opt-out skip file bypasses enforcement" {
  export SAVIA_ACM_ENFORCE=block
  : > "$CLAUDE_PROJECT_DIR/projects/alpha/.agent-maps/.acm-enforce-skip"
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"ACM enforcement"* ]]
}

@test "slice3: opt-out in one project does not affect another" {
  export SAVIA_ACM_ENFORCE=block
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/gamma/.agent-maps"
  : > "$CLAUDE_PROJECT_DIR/projects/gamma/.agent-maps/INDEX.acm"
  : > "$CLAUDE_PROJECT_DIR/projects/gamma/.agent-maps/.acm-enforce-skip"
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
}

@test "slice3: LOG_LEVEL=silent suppresses stderr in warn mode" {
  export SAVIA_ACM_ENFORCE=warn
  export SAVIA_ACM_LOG_LEVEL=silent
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "slice3: LOG_LEVEL=silent suppresses stderr in block mode but still exits 2" {
  export SAVIA_ACM_ENFORCE=block
  export SAVIA_ACM_LOG_LEVEL=silent
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
  [[ -z "$output" ]]
}

@test "slice3: LOG_LEVEL=silent does not write to acm-enforcement.log" {
  export SAVIA_ACM_ENFORCE=warn
  export SAVIA_ACM_LOG_LEVEL=silent
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ ! -f "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log" ]]
}

@test "slice3: LOG_LEVEL=debug writes verbose line with turn and marker_dir" {
  export SAVIA_ACM_ENFORCE=warn
  export SAVIA_ACM_LOG_LEVEL=debug
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ -f "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log" ]]
  run grep -q "level=debug" "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log"
  [[ "$status" -eq 0 ]]
}

@test "slice3: LOG_LEVEL=debug log line mentions turn id" {
  export SAVIA_ACM_ENFORCE=warn
  export SAVIA_ACM_LOG_LEVEL=debug
  export CLAUDE_TURN_ID="debug-turn-xyz"
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ -f "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log" ]]
  run grep -q "turn=debug-turn-xyz" "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log"
  [[ "$status" -eq 0 ]]
}

@test "slice3: default LOG_LEVEL (warn) preserves Slice 1 format" {
  export SAVIA_ACM_ENFORCE=warn
  unset SAVIA_ACM_LOG_LEVEL
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 0 ]]
  [[ -f "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log" ]]
  # Default format does NOT carry level= prefix
  run grep -q "level=debug" "$CLAUDE_PROJECT_DIR/output/acm-enforcement.log"
  [[ "$status" -ne 0 ]]
}

@test "slice3: opt-out message in block guidance mentions .acm-enforce-skip" {
  export SAVIA_ACM_ENFORCE=block
  input='{"tool_name":"Grep","tool_input":{"pattern":".*","path":"projects/alpha"}}'
  run bash "$SCRIPT" <<< "$input"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *".acm-enforce-skip"* ]]
}
