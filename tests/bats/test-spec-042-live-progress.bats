#!/usr/bin/env bats
# tests/bats/test-spec-042-live-progress.bats — SPEC-042: Live Progress Feedback
# Tests for .opencode/hooks/live-progress-emitter.sh

HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/.opencode/hooks/live-progress-emitter.sh"

# ── helpers ───────────────────────────────────────────────────────────────────

run_hook() {
    local json="$1"
    shift
    echo "$json" | env "$@" bash "$HOOK"
}

run_hook_stderr() {
    local json="$1"
    shift
    echo "$json" | env "$@" bash "$HOOK" 2>&1 1>/dev/null
}

# ── test 1: master switch off → no output ─────────────────────────────────────
@test "SPEC-042: switch off → no stderr output" {
    local json='{"tool_name":"Bash","tool_input":{"description":"test cmd"},"duration_ms":100}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=off)
    [ -z "$result" ]
}

# ── test 2: switch on + Bash tool → correct format ────────────────────────────
@test "SPEC-042: switch on + Bash → [SAVIA-PROGRESS] format" {
    local json='{"tool_name":"Bash","tool_input":{"description":"run tests"},"duration_ms":250}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on SAVIA_AGENT_NAME=test-agent)
    [[ "$result" =~ ^\[SAVIA-PROGRESS\]\ test-agent:\ bash:\ .*\[[0-9]+ms\]$ ]]
}

# ── test 3: Edit tool → shows filename ───────────────────────────────────────
@test "SPEC-042: Edit tool → shows filename in action" {
    local json='{"tool_name":"Edit","tool_input":{"filePath":"/some/path/myfile.sh"},"duration_ms":50}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on SAVIA_AGENT_NAME=savia)
    [[ "$result" =~ "edit: myfile.sh" ]]
}

# ── test 4: elapsed ms from duration_ms field ────────────────────────────────
@test "SPEC-042: duration_ms appears in brackets" {
    local json='{"tool_name":"Read","tool_input":{"filePath":"/tmp/foo.md"},"duration_ms":333}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on)
    [[ "$result" =~ \[333ms\] ]]
}

# ── test 5: Write tool → correct action prefix ────────────────────────────────
@test "SPEC-042: Write tool → 'write:' prefix with filename" {
    local json='{"tool_name":"Write","tool_input":{"filePath":"/home/user/scripts/foo.py"},"duration_ms":10}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on)
    [[ "$result" =~ "write: foo.py" ]]
}

# ── test 6: Skill tool → shows skill name ────────────────────────────────────
@test "SPEC-042: Skill tool → shows skill name" {
    local json='{"tool_name":"Skill","tool_input":{"name":"sdd-spec-writer"},"duration_ms":500}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on SAVIA_AGENT_NAME=orchestrator)
    [[ "$result" =~ "skill: sdd-spec-writer" ]]
    [[ "$result" =~ "[SAVIA-PROGRESS] orchestrator:" ]]
}

# ── test 7: missing tool_name → no output ─────────────────────────────────────
@test "SPEC-042: missing tool_name → exits cleanly with no output" {
    local json='{"tool_input":{"description":"orphan"}}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on)
    [ -z "$result" ]
}

# ── test 8: default agent name fallback ───────────────────────────────────────
@test "SPEC-042: no SAVIA_AGENT_NAME → defaults to 'savia'" {
    local json='{"tool_name":"Grep","tool_input":{"pattern":"foo"},"duration_ms":20}'
    result=$(run_hook_stderr "$json" SAVIA_LIVE_PROGRESS=on)
    [[ "$result" =~ ^\[SAVIA-PROGRESS\]\ savia: ]]
}
