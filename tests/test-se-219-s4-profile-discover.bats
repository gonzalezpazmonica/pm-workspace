#!/usr/bin/env bats
# test-se-219-s4-profile-discover.bats — SE-219 S4: multi-profile discovery
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Coverage target: 8 tests, score SPEC-055 >= 80

# audit: score=0 hash=placeholder date=2026-06-11

SCRIPT="scripts/profile-discover.sh"

setup() {
    export TMPDIR_TEST=$(mktemp -d)
    export HOME="$TMPDIR_TEST"
    unset CLAUDE_PROJECT_DIR   || true
    unset CLAUDE_EXTRA_PROFILE_DIRS || true

    # Create two synthetic profiles following the convention
    mkdir -p "$TMPDIR_TEST/.claude/sessions"
    mkdir -p "$TMPDIR_TEST/.claude/projects"
    mkdir -p "$TMPDIR_TEST/.claude-work/sessions"
    mkdir -p "$TMPDIR_TEST/.claude-work/projects"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ── 1. Script exists and is executable ───────────────────────────────────────
@test "SE-219-S4: script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── 2. set -uo pipefail on line 2 ────────────────────────────────────────────
@test "SE-219-S4: set -uo pipefail on line 2" {
    run sed -n '2p' "$SCRIPT"
    [[ "$output" == *"set -uo pipefail"* ]]
}

# ── 3. list includes ~/.claude when it exists with sessions/ + projects/ ─────
@test "SE-219-S4: list includes default ~/.claude profile" {
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *".claude"* ]]
}

# ── 4. active returns a path or empty string, never crashes ──────────────────
@test "SE-219-S4: active subcommand returns path or empty without crash" {
    run bash "$SCRIPT" active
    [ "$status" -eq 0 ]
    # output is either a path or blank — both acceptable
}

# ── 5. --json produces valid JSON ────────────────────────────────────────────
@test "SE-219-S4: --json produces valid JSON array" {
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "
import json
data = json.loads('''$output''')
assert isinstance(data, list), f'Expected list, got {type(data)}'
print('OK valid JSON array len=' + str(len(data)))
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 6. JSON array entries have path field ────────────────────────────────────
@test "SE-219-S4: JSON entries contain path and status fields" {
    run bash "$SCRIPT" --json
    [ "$status" -eq 0 ]
    run python3 -c "
import json
data = json.loads('''$output''')
assert len(data) >= 1, 'Expected at least 1 profile'
for item in data:
    assert 'path'   in item, f'missing path in {item}'
    assert 'status' in item, f'missing status in {item}'
    assert item['status'] in ('active','inactive'), f'bad status: {item[\"status\"]}'
print('OK fields valid')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 7. Dir without sessions/ or projects/ is not detected as profile ─────────
@test "SE-219-S4: directory without sessions/ or projects/ is not a valid profile" {
    # Create an incomplete fake profile (missing projects/)
    mkdir -p "$TMPDIR_TEST/.claude-incomplete/sessions"
    # No projects/ → should NOT appear
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" != *".claude-incomplete"* ]]
}

# ── 8. edge: no .claude* directories → list returns empty, exit 0 ────────────
@test "SE-219-S4 edge: no .claude directories returns empty list and exit 0" {
    # Remove all synthetic profiles we created in setup
    rm -rf "$TMPDIR_TEST/.claude"
    rm -rf "$TMPDIR_TEST/.claude-work"
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    # Output must be empty or whitespace only
    [[ -z "$(echo "$output" | tr -d '[:space:]')" ]]
}
