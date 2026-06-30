#!/usr/bin/env bats
# SE-224 — Tests for output-verbosity-sentinel.sh + output-effort-router.sh
# Ref: SE-224 Headroom effort routing + verbosity ladder
# Slices: 1 (sentinel) + 2 (effort-router)

SENTINEL=".opencode/hooks/output-verbosity-sentinel.sh"
ROUTER=".opencode/hooks/output-effort-router.sh"

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    # Clean env state
    unset SAVIA_VERBOSITY_SENTINEL SAVIA_EFFORT_ROUTER 2>/dev/null || true
    unset TOOL_NAME TOOL_OUTPUT TOOL_RESULT_IS_ERROR CLAUDE_PROJECT_DIR 2>/dev/null || true
    export CLAUDE_PROJECT_DIR="$BATS_TEST_DIRNAME/.."
}

teardown() {
    unset SAVIA_VERBOSITY_SENTINEL SAVIA_EFFORT_ROUTER 2>/dev/null || true
    unset TOOL_NAME TOOL_OUTPUT TOOL_RESULT_IS_ERROR CLAUDE_PROJECT_DIR 2>/dev/null || true
}

# ── Slice 1: output-verbosity-sentinel.sh ────────────────────────────────────

@test "sentinel: hook exists" {
    [[ -f "$SENTINEL" ]]
}

@test "sentinel: hook is executable" {
    [[ -x "$SENTINEL" ]]
}

@test "sentinel: has set -uo pipefail" {
    run grep -c 'set -uo pipefail' "$SENTINEL"
    [[ "$output" -ge 1 ]]
}

@test "sentinel: passes bash -n syntax check" {
    run bash -n "$SENTINEL"
    [ "$status" -eq 0 ]
}

@test "sentinel: SAVIA_VERBOSITY_SENTINEL=off exits 0 with no output" {
    SAVIA_VERBOSITY_SENTINEL=off run bash "$SENTINEL" <<< ""
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "sentinel: is_error=true classifies as ERROR — exits 0, no stdout output" {
    export TOOL_OUTPUT="something went wrong"
    export TOOL_RESULT_IS_ERROR="true"
    # ERROR: hook is observability-only, stdout must be empty
    run bash "$SENTINEL" <<< "" 2>/dev/null
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "sentinel: output containing ERROR: classifies as ERROR — exits 0" {
    export TOOL_NAME="Bash"
    export TOOL_OUTPUT="ERROR: command not found"
    export TOOL_RESULT_IS_ERROR="false"
    # Hook emits only to stderr, stdout must be empty
    run bash "$SENTINEL" <<< "" 2>/dev/null
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "sentinel: short success output (< 100 chars) classifies as MECHANICAL — exits 0" {
    export TOOL_NAME="Bash"
    export TOOL_OUTPUT="ok"
    export TOOL_RESULT_IS_ERROR="false"
    run bash "$SENTINEL" <<< ""
    [ "$status" -eq 0 ]
}

@test "sentinel: long output (>= 100 chars) classifies as NEW_ASK — exits 0" {
    export TOOL_NAME="Read"
    # Generate string > 100 chars
    export TOOL_OUTPUT="$(printf 'x%.0s' {1..120})"
    export TOOL_RESULT_IS_ERROR="false"
    run bash "$SENTINEL" <<< ""
    [ "$status" -eq 0 ]
}

@test "sentinel: always exits 0 regardless of input" {
    run bash "$SENTINEL" <<< "not valid json at all }"
    [ "$status" -eq 0 ]
}

@test "sentinel: telemetry dir absent — still exits 0 (no crash)" {
    export CLAUDE_PROJECT_DIR="/nonexistent_dir_se224_$$"
    run bash "$SENTINEL" <<< ""
    [ "$status" -eq 0 ]
}

# ── Slice 2: output-effort-router.sh ─────────────────────────────────────────

@test "effort-router: hook exists" {
    [[ -f "$ROUTER" ]]
}

@test "effort-router: hook is executable" {
    [[ -x "$ROUTER" ]]
}

@test "effort-router: has set -uo pipefail" {
    run grep -c 'set -uo pipefail' "$ROUTER"
    [[ "$output" -ge 1 ]]
}

@test "effort-router: passes bash -n syntax check" {
    run bash -n "$ROUTER"
    [ "$status" -eq 0 ]
}

@test "effort-router: SAVIA_EFFORT_ROUTER=off exits 0 with no output" {
    SAVIA_EFFORT_ROUTER=off run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "effort-router: Edit tool always exits 0 (allowlist — NEW_ASK, no hint)" {
    export TOOL_NAME="Edit"
    export TOOL_OUTPUT="ok"  # short — would be MECHANICAL if not allowlisted
    export TOOL_RESULT_IS_ERROR="false"
    run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
    # stdout must be empty (hint only goes to stderr)
    [[ -z "$output" ]]
}

@test "effort-router: Write tool is in allowlist — exits 0 no stdout" {
    export TOOL_NAME="Write"
    export TOOL_OUTPUT="x"
    run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "effort-router: Task tool is in allowlist — exits 0 no stdout" {
    export TOOL_NAME="Task"
    export TOOL_OUTPUT="done"
    run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "effort-router: is_error=true → ERROR classification, exits 0" {
    export TOOL_NAME="Bash"
    export TOOL_OUTPUT="build failed"
    export TOOL_RESULT_IS_ERROR="true"
    run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "effort-router: short success output → MECHANICAL, exits 0" {
    export TOOL_NAME="Bash"
    export TOOL_OUTPUT="ok"
    export TOOL_RESULT_IS_ERROR="false"
    run bash "$ROUTER" <<< ""
    [ "$status" -eq 0 ]
}

@test "effort-router: always exits 0 regardless of malformed input" {
    run bash "$ROUTER" <<< "{{{ broken json"
    [ "$status" -eq 0 ]
}
