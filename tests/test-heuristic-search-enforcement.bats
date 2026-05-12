#!/usr/bin/env bats
# Tests for .opencode/hooks/heuristic-search-enforcement.sh
# Ref: docs/rules/domain/heuristic-self-learning.md
# Ref: ~/.savia/search-heuristic.md (5-tier search heuristic)

SCRIPT="${BATS_TEST_DIRNAME}/../.opencode/hooks/heuristic-search-enforcement.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "enforcement hook missing"
  command -v jq >/dev/null 2>&1 || skip "jq not available"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export TMPDIR="$TMP_DIR"
  export CLAUDE_TURN_ID="test-turn-$$-${BATS_TEST_NUMBER:-0}"
  export SAVIA_HEURISTIC_ENFORCE="block"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  unset SAVIA_HEURISTIC_ENFORCE
}

# ─────────────────────────── Smoke ───────────────────────────

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

@test "malformed JSON returns exit 0 (no-op)" {
  run bash "$SCRIPT" <<< 'not-json{'
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Tool filtering ───────────────────────────

@test "non-Bash tool is ignored (Read)" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/foo"}}'
  [[ "$status" -eq 0 ]]
}

@test "non-Bash tool is ignored (Grep direct)" {
  run bash "$SCRIPT" <<< '{"tool_name":"Grep","tool_input":{"pattern":"x","path":"projects/alpha"}}'
  [[ "$status" -eq 0 ]]
}

@test "Bash without command is ignored" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{}}'
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Command pattern matching ───────────────────────────

@test "non-grep bash command is allowed" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"ls projects/alpha"}}'
  [[ "$status" -eq 0 ]]
}

@test "non-recursive grep is allowed (no -r)" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep foo projects/alpha/file.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "recursive grep outside projects/ is allowed" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri foo /tmp/data"}}'
  [[ "$status" -eq 0 ]]
}

@test "recursive grep on docs/ is allowed (not projects/)" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -r foo docs/rules"}}'
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Enforcement (block mode) ───────────────────────────

@test "block: recursive grep on projects/<slug> without T1 marker → exit 2" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri foo projects/alpha"}}'
  [[ "$status" -eq 2 ]]
}

@test "block: recursive grep with -R also blocked" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -R pattern projects/alpha/src"}}'
  [[ "$status" -eq 2 ]]
}

@test "block: --recursive long flag also blocked" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep --recursive needle projects/alpha"}}'
  [[ "$status" -eq 2 ]]
}

@test "block message cites T1 indexes (members, GLOSSARY, STAKEHOLDERS)" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"members"* ]]
  [[ "$output" == *"GLOSSARY"* ]]
  [[ "$output" == *"STAKEHOLDERS"* ]]
}

# ─────────────────────────── Bypass mechanisms ───────────────────────────

@test "bypass: SAVIA_HEURISTIC_ENFORCE=0 disables enforcement" {
  export SAVIA_HEURISTIC_ENFORCE="0"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 0 ]]
}

@test "bypass: SAVIA_HEURISTIC_ENFORCE=off disables enforcement" {
  export SAVIA_HEURISTIC_ENFORCE="off"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 0 ]]
}

@test "bypass: warn mode → exit 0 with stderr message" {
  export SAVIA_HEURISTIC_ENFORCE="warn"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARN"* ]] || [[ "$output" == *"HEURISTIC"* ]]
}

@test "bypass: explicit '# heuristic-bypass:reason' allows command" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  cmd='grep -ri x projects/alpha # heuristic-bypass:legacy-discovery'
  run bash "$SCRIPT" <<< "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  [[ "$status" -eq 0 ]]
}

@test "bypass: targeted grep with --include + --exclude-dir is allowed (T4)" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  cmd='grep -ri foo projects/alpha --include="*.md" --exclude-dir=repos'
  run bash "$SCRIPT" <<< "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Marker integration ───────────────────────────

@test "marker presence: T1 marker → grep allowed" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  MARKER_DIR="${TMPDIR}/savia-turn-${CLAUDE_TURN_ID}"
  mkdir -p "$MARKER_DIR"
  : > "$MARKER_DIR/heuristic-t1-alpha"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 0 ]]
}

@test "marker scope: T1 marker for beta does NOT unlock alpha" {
  export SAVIA_HEURISTIC_ENFORCE="block"
  MARKER_DIR="${TMPDIR}/savia-turn-${CLAUDE_TURN_ID}"
  mkdir -p "$MARKER_DIR"
  : > "$MARKER_DIR/heuristic-t1-beta"
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"grep -ri x projects/alpha"}}'
  [[ "$status" -eq 2 ]]
}
