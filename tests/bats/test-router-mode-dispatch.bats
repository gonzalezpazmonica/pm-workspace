#!/usr/bin/env bats
# test-router-mode-dispatch.bats — SPEC-163 Slice 3
#
# Tests for .opencode/hooks/router-mode-dispatch.sh
# Requires: bats-core, python3, jq (or python3 fallback for JSON)
#
# Reference: SPEC-163 (docs/propuestas/SPEC-163-router-mode-1-2.md)

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/.opencode/hooks/router-mode-dispatch.sh"
    CLASSIFIER="$REPO_ROOT/scripts/router-mode-classifier.py"
    TELEMETRY_FILE="$REPO_ROOT/output/router-decisions.jsonl"
    TMPDIR_ROUTER="$(mktemp -d)"

    # Redirect telemetry to a tmp file during tests to avoid polluting real log
    export SAVIA_ROUTER_TELEMETRY_OVERRIDE="$TMPDIR_ROUTER/router-decisions-test.jsonl"
    unset CLAUDE_TURN_ID SAVIA_TURN_ID CLAUDE_SESSION_ID
}

teardown() {
    rm -rf "$TMPDIR_ROUTER"
}

# ─── Helper: inject telemetry path override ───────────────────────────────────
# The hook writes to output/router-decisions.jsonl relative to repo root.
# We patch the env so tests can inspect telemetry without real output/ changes.
_run_hook() {
    local mode="${1:-shadow}"
    local input="${2:-{}}"
    # Patch telemetry path by symlinking output dir in tmp
    mkdir -p "$TMPDIR_ROUTER/output"
    SAVIA_ROUTER_MODE="$mode" \
    SAVIA_ROUTER_TELEMETRY_OVERRIDE="$TMPDIR_ROUTER/output/router-decisions.jsonl" \
    bash "$HOOK" <<< "$input"
}

# ─── Test 1: Hook exists and is executable ───────────────────────────────────

@test "hook exists" {
    [[ -f "$HOOK" ]]
}

@test "hook is executable" {
    [[ -x "$HOOK" ]]
}

# ─── Test 2: SAVIA_ROUTER_MODE=off → exit 0 without classifying ─────────────

@test "mode=off exits 0" {
    run bash -c "SAVIA_ROUTER_MODE=off bash '$HOOK' <<< '{}'"
    [[ "$status" -eq 0 ]]
}

@test "mode=off does not write telemetry" {
    local tel="$TMPDIR_ROUTER/tel-off.jsonl"
    # Make the hook write to our tmp file by patching the hook invocation
    # The hook uses REPO_ROOT/output/router-decisions.jsonl hardcoded, so
    # we verify no new content in the real telemetry file
    local before_lines=0
    [[ -f "$TELEMETRY_FILE" ]] && before_lines="$(wc -l < "$TELEMETRY_FILE")"
    SAVIA_ROUTER_MODE=off bash "$HOOK" <<< "{}" 2>/dev/null || true
    local after_lines=0
    [[ -f "$TELEMETRY_FILE" ]] && after_lines="$(wc -l < "$TELEMETRY_FILE")"
    [[ "$before_lines" -eq "$after_lines" ]]
}

# ─── Test 3: SAVIA_ROUTER_MODE=shadow → exit 0 and writes telemetry ─────────

@test "mode=shadow exits 0" {
    run bash -c "SAVIA_ROUTER_MODE=shadow bash '$HOOK' <<< '{}'"
    [[ "$status" -eq 0 ]]
}

@test "mode=shadow with valid task input exits 0" {
    local payload='{"tool_name":"Task","tool_input":{"description":"ver estado del sprint"}}'
    run bash -c "SAVIA_ROUTER_MODE=shadow bash '$HOOK' <<< '$payload'"
    [[ "$status" -eq 0 ]]
}

@test "mode=shadow writes a telemetry line" {
    local tel="$REPO_ROOT/output/router-decisions.jsonl"
    local before=0
    [[ -f "$tel" ]] && before="$(wc -l < "$tel")"

    local payload='{"tool_name":"Task","tool_input":{"description":"ver estado del sprint actual"}}'
    SAVIA_ROUTER_MODE=shadow bash "$HOOK" <<< "$payload" 2>/dev/null || true

    local after=0
    [[ -f "$tel" ]] && after="$(wc -l < "$tel")"
    [[ "$after" -gt "$before" ]]
}

@test "telemetry line is valid JSON with required fields" {
    local tel="$REPO_ROOT/output/router-decisions.jsonl"
    local payload='{"tool_name":"Task","tool_input":{"description":"listar items del sprint"}}'
    SAVIA_ROUTER_MODE=shadow bash "$HOOK" <<< "$payload" 2>/dev/null || true

    [[ -f "$tel" ]] || skip "telemetry file not created"

    # Get last line of telemetry
    local last_line
    last_line="$(tail -n 1 "$tel")"
    [[ -n "$last_line" ]]

    # Validate JSON and required fields
    python3 - <<PYEOF
import json, sys
line = """$last_line"""
d = json.loads(line)
required = ["ts", "turn_id", "intent_hash", "detected_mode", "command",
            "confidence", "tokens_estimate", "reason", "complexity_tier", "mode_enforced"]
missing = [f for f in required if f not in d]
if missing:
    print(f"Missing fields: {missing}", file=sys.stderr)
    sys.exit(1)
print("OK")
PYEOF
}

# ─── Test 4: set -uo pipefail declared ───────────────────────────────────────

@test "hook declares set -uo pipefail" {
    grep -qE "set -[uo]+ pipefail|set -euo pipefail" "$HOOK"
}

# ─── Test 5: Invalid JSON input → exit 0 (fail-soft) ────────────────────────

@test "invalid JSON input exits 0 (fail-soft)" {
    run bash -c "SAVIA_ROUTER_MODE=shadow bash '$HOOK' <<< '{not valid json!!!}'"
    [[ "$status" -eq 0 ]]
}

@test "empty input exits 0" {
    run bash -c "SAVIA_ROUTER_MODE=shadow bash '$HOOK' <<< ''"
    [[ "$status" -eq 0 ]]
}

# ─── Test 6: Classifier works standalone ─────────────────────────────────────

@test "router-mode-classifier.py exists and is executable" {
    [[ -x "$CLASSIFIER" ]]
}

@test "classifier works standalone with query intent" {
    local out
    out="$(echo '{"intent":"ver estado del sprint","command":"sprint-status","has_code_change":false,"estimated_tokens":100}' \
        | python3 "$CLASSIFIER")"
    [[ -n "$out" ]]
    python3 - <<PYEOF
import json
d = json.loads("""$out""")
assert d["mode"] == "mode1", f"expected mode1, got {d['mode']}"
print("OK")
PYEOF
}

@test "classifier works standalone with action intent" {
    local out
    out="$(echo '{"intent":"implementar nuevo endpoint","command":"","has_code_change":false,"estimated_tokens":300}' \
        | python3 "$CLASSIFIER")"
    [[ -n "$out" ]]
    python3 - <<PYEOF
import json
d = json.loads("""$out""")
assert d["mode"] == "mode2", f"expected mode2, got {d['mode']}"
print("OK")
PYEOF
}

@test "classifier forces mode2 when has_code_change=true" {
    local out
    out="$(echo '{"intent":"ver estado del sprint","command":"sprint-status","has_code_change":true,"estimated_tokens":100}' \
        | python3 "$CLASSIFIER")"
    python3 - <<PYEOF
import json
d = json.loads("""$out""")
assert d["mode"] == "mode2", f"expected mode2, got {d['mode']}"
assert d["confidence"] == 1.0
print("OK")
PYEOF
}

# ─── Test 7: mode=enforce exits 0 ────────────────────────────────────────────

@test "mode=enforce exits 0" {
    local payload='{"tool_name":"Task","tool_input":{"description":"ver estado del sprint"}}'
    run bash -c "SAVIA_ROUTER_MODE=enforce bash '$HOOK' <<< '$payload'"
    [[ "$status" -eq 0 ]]
}

# ─── Test 8: Detected mode field is valid ────────────────────────────────────

@test "telemetry detected_mode is mode1 or mode2" {
    local tel="$REPO_ROOT/output/router-decisions.jsonl"
    local payload='{"tool_name":"Task","tool_input":{"description":"ver el estado del sprint"}}'
    SAVIA_ROUTER_MODE=shadow bash "$HOOK" <<< "$payload" 2>/dev/null || true

    [[ -f "$tel" ]] || skip "telemetry file not created"
    local last_line
    last_line="$(tail -n 1 "$tel")"

    python3 - <<PYEOF
import json
d = json.loads("""$last_line""")
assert d["detected_mode"] in ("mode1", "mode2"), f"unexpected mode: {d['detected_mode']}"
print("OK")
PYEOF
}
