#!/usr/bin/env bats
# test-se-219-s1-session-status.bats — SE-219 S1: session-status snapshot
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Coverage target: 8 tests, score SPEC-055 >= 80

# audit: score=0 hash=placeholder date=2026-06-11

SCRIPT="scripts/session-status.sh"

setup() {
    export TMPDIR_TEST=$(mktemp -d)
    export SESSION_ACTION_LOG="$TMPDIR_TEST/session-action-log.jsonl"
    export SESSION_ACTION_SESSION="test-session-219"
    mkdir -p "$TMPDIR_TEST"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ── 1. Script exists and is executable ───────────────────────────────────────
@test "SE-219-S1: script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── 2. set -uo pipefail on line 2 ────────────────────────────────────────────
@test "SE-219-S1: set -uo pipefail on line 2" {
    run sed -n '2p' "$SCRIPT"
    [[ "$output" == *"set -uo pipefail"* ]]
}

# ── 3. --json with populated log → valid JSON with required fields ────────────
@test "SE-219-S1: --json with populated log produces valid JSON with required fields" {
    cat > "$SESSION_ACTION_LOG" <<'EOF'
{"ts":"2026-06-10T10:00:00Z","action":"pr-plan","target":"feat","result":"pass","detail":"","attempt":0,"session":"test-session-219"}
{"ts":"2026-06-10T10:01:00Z","action":"code-review","target":"feat","result":"pass","detail":"","attempt":0,"session":"test-session-219"}
{"ts":"2026-06-10T10:02:00Z","action":"deploy","target":"feat","result":"fail","detail":"err","attempt":1,"session":"test-session-219"}
EOF
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "
import sys, json
data = json.loads('''$output''')
required = ['session_id','actions_total','actions_pass','actions_fail','consecutive_failures','last_action']
missing = [k for k in required if k not in data]
assert not missing, f'Missing fields: {missing}'
assert data['actions_total'] == 3, f'Expected 3, got {data[\"actions_total\"]}'
assert data['actions_pass'] == 2, f'Expected pass=2, got {data[\"actions_pass\"]}'
assert data['actions_fail'] == 1, f'Expected fail=1, got {data[\"actions_fail\"]}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 4. --json with empty log → JSON with zeros ───────────────────────────────
@test "SE-219-S1: --json with empty log produces JSON with zero counts" {
    touch "$SESSION_ACTION_LOG"
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "
import sys, json
data = json.loads('''$output''')
assert data['actions_total'] == 0, f'Expected 0, got {data[\"actions_total\"]}'
assert data['actions_pass']  == 0
assert data['actions_fail']  == 0
assert data['consecutive_failures'] == 0
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 5. edge: --json without log file → valid JSON, no crash ──────────────────
@test "SE-219-S1 edge: --json without log file produces valid JSON, exit 0" {
    # No log file created
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "import json, sys; d=json.loads('''$output'''); print('OK valid JSON')"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 6. JSON contains session_id, actions_total, last_action ──────────────────
@test "SE-219-S1: JSON output contains session_id, actions_total and last_action" {
    echo '{"ts":"2026-06-10T09:00:00Z","action":"init","target":"x","result":"pass","detail":"","attempt":0,"session":"test-session-219"}' \
        > "$SESSION_ACTION_LOG"
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    # python3 assertion for json import
    run python3 -c "
import json
d = json.loads('''$output''')
assert 'session_id'    in d, 'missing session_id'
assert 'actions_total' in d, 'missing actions_total'
assert 'last_action'   in d, 'missing last_action'
assert d['last_action'].get('action') == 'init', f'unexpected last_action: {d[\"last_action\"]}'
print('OK fields present')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 7. --once exits with 0 ───────────────────────────────────────────────────
@test "SE-219-S1: --once exits with status 0" {
    run bash "$SCRIPT" --once
    [ "$status" -eq 0 ]
}

# ── 8. edge: log with malformed/invalid JSON lines → valid JSON, no crash ────
@test "SE-219-S1 edge: log with malformed lines produces valid JSON without crash" {
    cat > "$SESSION_ACTION_LOG" <<'EOF'
NOT VALID JSON AT ALL
{"ts":"2026-06-10T11:00:00Z","action":"ok-action","target":"t","result":"pass","detail":"","attempt":0,"session":"test-session-219"}
{broken json
{"ts":"2026-06-10T11:01:00Z","action":"fail-action","target":"t","result":"fail","detail":"","attempt":1,"session":"test-session-219"}
EOF
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "
import json
d = json.loads('''$output''')
# Should have parsed only the 2 valid lines
assert d['actions_total'] == 2, f'Expected 2, got {d[\"actions_total\"]}'
assert d['consecutive_failures'] == 1
print('OK malformed handled')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}
