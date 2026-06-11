#!/usr/bin/env bats
# test-se-219-s3-session-cleanup.bats — SE-219 S3: orphan process cleanup
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Coverage target: 8 tests, score SPEC-055 >= 80

# audit: score=0 hash=placeholder date=2026-06-11

SCRIPT="scripts/session-cleanup.sh"

setup() {
    export TMPDIR_TEST=$(mktemp -d)
    mkdir -p "$TMPDIR_TEST/output"
    export SESSION_ACTION_SESSION="cleanup-test-$$"
    export SAVIA_PIDS_FILE="$TMPDIR_TEST/output/.session-pids-${SESSION_ACTION_SESSION}.json"
}

teardown() {
    # Kill any stray test processes
    if [[ -n "${TEST_BG_PID:-}" ]]; then
        kill "$TEST_BG_PID" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR_TEST"
}

# ── 1. Script exists and is executable ───────────────────────────────────────
@test "SE-219-S3: script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── 2. set -uo pipefail on line 2 ────────────────────────────────────────────
@test "SE-219-S3: set -uo pipefail on line 2" {
    run sed -n '2p' "$SCRIPT"
    [[ "$output" == *"set -uo pipefail"* ]]
}

# ── 3. register --pid creates the JSON pids file ─────────────────────────────
@test "SE-219-S3: register --pid creates the pids registration file" {
    run bash "$SCRIPT" register --pid 99999 --label "test-process"
    [ "$status" -eq 0 ]
    [ -f "$SAVIA_PIDS_FILE" ]
    # Verify JSON structure with python3
    run python3 -c "
import json
with open('$SAVIA_PIDS_FILE') as f:
    data = json.load(f)
assert 'pids' in data, 'missing pids key'
assert any(e['pid'] == 99999 for e in data['pids']), 'pid 99999 not found'
print('OK register created file')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 4. list shows registered PIDs ────────────────────────────────────────────
@test "SE-219-S3: list shows registered PID with running/dead status" {
    bash "$SCRIPT" register --pid 99998 --label "listed-process"
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"99998"* ]]
}

# ── 5. cleanup kills live process and removes pids file ──────────────────────
@test "SE-219-S3: cleanup terminates live process and removes pids file" {
    # Start a real background process
    sleep 60 &
    export TEST_BG_PID=$!
    bash "$SCRIPT" register --pid "$TEST_BG_PID" --label "sleep-process"
    [ -f "$SAVIA_PIDS_FILE" ]
    run bash "$SCRIPT" cleanup
    [ "$status" -eq 0 ]
    # pids file should be gone
    [ ! -f "$SAVIA_PIDS_FILE" ]
    # process should be gone (allow brief grace period)
    sleep 0.5
    run kill -0 "$TEST_BG_PID" 2>&1 || true
    # kill -0 should fail (process dead)
    [[ "$status" -ne 0 ]] || [[ "$output" == *"No such process"* ]]
    unset TEST_BG_PID
}

# ── 6. cleanup with dead PID → exit 0, no crash ──────────────────────────────
@test "SE-219-S3: cleanup with already-dead PID exits 0 without crash" {
    # Register a PID we know is dead (PID 1 is not killable, use a fake high PID)
    bash "$SCRIPT" register --pid 9999999 --label "dead-process"
    run bash "$SCRIPT" cleanup
    [ "$status" -eq 0 ]
}

# ── 7. orphans without sessions returns empty output, exit 0 ─────────────────
@test "SE-219-S3: orphans without old pids files returns empty and exits 0" {
    run bash "$SCRIPT" orphans
    [ "$status" -eq 0 ]
    # output should be empty (no orphan files in TMPDIR)
    [[ -z "$output" ]]
}

# ── 8. edge: register with invalid PID exits 2 ───────────────────────────────
@test "SE-219-S3 edge: register with invalid PID (non-numeric) exits 2" {
    run bash "$SCRIPT" register --pid "not-a-pid"
    [ "$status" -eq 2 ]
}
