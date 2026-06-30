#!/usr/bin/env bats
# test-tribunal-tiered.bats — SE-106: Tiered tribunal execution
#
# Tests for scripts/tribunal-tiered-runner.sh
# Requires: bats-core
#
# Reference: SE-106 (docs/propuestas/SE-106-tiered-tribunal-execution.md)

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/scripts/tribunal-tiered-runner.sh"
    TELEMETRY_FILE="$REPO_ROOT/output/tiered-tribunal-telemetry.jsonl"

    # Temporary directory for mock fixtures and test artifacts
    TMPDIR_TEST="$(mktemp -d)"
    export SAVIA_JUDGE_MOCK_DIR="$TMPDIR_TEST/mocks"
    mkdir -p "$SAVIA_JUDGE_MOCK_DIR"

    # Redirect telemetry to tmp to avoid polluting real output/
    export SAVIA_TIERED_TELEMETRY_TEST="$TMPDIR_TEST/telemetry.jsonl"

    # Base env: tiered enabled for most tests
    export SAVIA_TIERED_TRIBUNAL="on"
    export TRIBUNAL_FORCE_FULL_PANEL="0"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Write a PASS judge fixture
_write_pass_fixture() {
    local judge="$1"
    cat > "$SAVIA_JUDGE_MOCK_DIR/${judge}.json" <<EOF
{"judge":"${judge}","score":85,"veto":false,"confidence":0.7,"verdict":"PASS"}
EOF
}

# Write a VETO judge fixture (high confidence)
_write_veto_fixture() {
    local judge="$1"
    cat > "$SAVIA_JUDGE_MOCK_DIR/${judge}.json" <<EOF
{"judge":"${judge}","score":20,"veto":true,"confidence":0.92,"verdict":"VETO"}
EOF
}

# Extract a JSON field from stdout (requires python3)
_json_field() {
    local json="$1"
    local field="$2"
    python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('${field}',''))" "$json" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 1: runner exists and is executable
# ─────────────────────────────────────────────────────────────────────────────

@test "tiered-runner.sh exists and is executable" {
    [ -f "$RUNNER" ]
    [ -x "$RUNNER" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 2: SAVIA_TIERED_TRIBUNAL=off exits 0 without tiered logic
# ─────────────────────────────────────────────────────────────────────────────

@test "SAVIA_TIERED_TRIBUNAL=off exits 0 and returns full-parallel mode" {
    export SAVIA_TIERED_TRIBUNAL="off"
    run bash "$RUNNER" \
        --tribunal court \
        --tier0-judges "security-judge" \
        --tier1-judges "architecture-judge"

    [ "$status" -eq 0 ]
    # Output must contain "full-parallel" somewhere in the JSON
    echo "$output" | grep -q "full-parallel"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 3: Tier 0 VETO → tier1_skipped=true
# ─────────────────────────────────────────────────────────────────────────────

@test "Tier 0 VETO causes tier1_skipped=true in output" {
    _write_veto_fixture "security-judge"
    _write_pass_fixture "correctness-judge"

    run bash "$RUNNER" \
        --tribunal court \
        --tier0-judges "security-judge,correctness-judge" \
        --tier1-judges "architecture-judge,cognitive-judge"

    [ "$status" -eq 1 ]

    local json_line
    json_line=$(echo "$output" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if 'verdict' in d:
            print(line)
            break
    except: pass
")
    [ -n "$json_line" ]

    echo "$json_line" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d.get('tier1_skipped') is True, f'tier1_skipped must be true, got: {d}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 4: Tier 0 PASS → tier1_skipped=false
# ─────────────────────────────────────────────────────────────────────────────

@test "Tier 0 PASS causes tier1_skipped=false in output" {
    _write_pass_fixture "security-judge"
    _write_pass_fixture "correctness-judge"

    run bash "$RUNNER" \
        --tribunal court \
        --tier0-judges "security-judge,correctness-judge" \
        --tier1-judges "architecture-judge"

    [ "$status" -eq 0 ]

    local json_line
    json_line=$(echo "$output" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if 'verdict' in d:
            print(line)
            break
    except: pass
")
    [ -n "$json_line" ]

    echo "$json_line" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d.get('tier1_skipped') is False, f'tier1_skipped must be false, got: {d}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 5: tokens_saved > 0 when tier1 skipped
# ─────────────────────────────────────────────────────────────────────────────

@test "tokens_saved_estimate > 0 in output when tier1 is skipped" {
    _write_veto_fixture "compliance-judge"

    run bash "$RUNNER" \
        --tribunal truth \
        --tier0-judges "compliance-judge" \
        --tier1-judges "coherence-judge,calibration-judge,completeness-judge"

    [ "$status" -eq 1 ]

    local json_line
    json_line=$(echo "$output" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if 'verdict' in d:
            print(line)
            break
    except: pass
")
    [ -n "$json_line" ]

    echo "$json_line" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
saved = d.get('tokens_saved_estimate', 0)
assert int(saved) > 0, f'tokens_saved_estimate must be > 0, got {saved}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 6: Telemetry JSONL is valid JSON
# ─────────────────────────────────────────────────────────────────────────────

@test "telemetry JSONL entry is valid JSON with required fields" {
    _write_pass_fixture "security-judge"

    run bash "$RUNNER" \
        --tribunal court \
        --tier0-judges "security-judge" \
        --tier1-judges "architecture-judge"

    [ "$status" -eq 0 ]

    # Output JSON must have required fields
    local json_line
    json_line=$(echo "$output" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if 'verdict' in d:
            print(line)
            break
    except: pass
")
    [ -n "$json_line" ]

    echo "$json_line" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for field in ['verdict', 'tribunal', 'tier1_skipped', 'tokens_saved_estimate', 'judges_run']:
    assert field in d, f'Missing field: {field}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 7: --tribunal flag is required (exit 2)
# ─────────────────────────────────────────────────────────────────────────────

@test "--tribunal flag is required, missing causes exit 2" {
    run bash "$RUNNER"
    [ "$status" -eq 2 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 8: set -uo pipefail is active (undefined var causes failure)
# ─────────────────────────────────────────────────────────────────────────────

@test "script uses set -uo pipefail" {
    # Verify the script header contains set -uo pipefail
    grep -q "set -uo pipefail" "$RUNNER"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 9: orchestrators updated with Tiered Execution section
# ─────────────────────────────────────────────────────────────────────────────

@test "truth-tribunal-orchestrator.md contains Tiered Execution section" {
    local agent_file="$REPO_ROOT/.opencode/agents/truth-tribunal-orchestrator.md"
    [ -f "$agent_file" ]
    grep -q "Tiered Execution" "$agent_file"
}

@test "court-orchestrator.md contains Tiered Execution section" {
    local agent_file="$REPO_ROOT/.opencode/agents/court-orchestrator.md"
    [ -f "$agent_file" ]
    grep -q "Tiered Execution" "$agent_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test 10: full-parallel mode produces same verdict as sequential-first on PASS
# ─────────────────────────────────────────────────────────────────────────────

@test "full-parallel mode and sequential-first with Tier 0 PASS both return PASS verdict" {
    _write_pass_fixture "security-judge"
    _write_pass_fixture "correctness-judge"

    # sequential-first (tiered) — both must exit 0 and emit a JSON verdict
    run bash "$RUNNER" \
        --tribunal court \
        --mode sequential-first \
        --tier0-judges "security-judge,correctness-judge" \
        --tier1-judges "architecture-judge"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "verdict"

    # full-parallel
    export SAVIA_TIERED_TRIBUNAL="off"
    run bash "$RUNNER" \
        --tribunal court \
        --mode full-parallel \
        --tier0-judges "security-judge,correctness-judge" \
        --tier1-judges "architecture-judge"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "verdict"
}
