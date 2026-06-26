#!/usr/bin/env bats
# SE-226 — overnight-sprint-loop.sh smoke tests

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    LOOP="$PWD/scripts/overnight-sprint-loop.sh"
    STATE="$PWD/scripts/overnight-sprint-state.sh"
}

@test "overnight-sprint-loop.sh exists and is executable" {
    [[ -x "$LOOP" ]]
}

@test "overnight-sprint-state.sh exists and is executable" {
    [[ -x "$STATE" ]]
}

@test "loop has set -uo pipefail" {
    grep -q "set -uo pipefail" "$LOOP"
}

@test "state has set -uo pipefail" {
    grep -q "set -uo pipefail" "$STATE"
}

@test "loop --help or no args exits non-zero with usage hint" {
    run bash "$LOOP"
    [[ "$status" -ne 0 ]] || [[ "$output" =~ [Uu]sage ]]
}

@test "state --self-test exits 0" {
    run bash "$STATE" --self-test
    [[ "$status" -eq 0 ]]
}

@test "loop handles missing sprint-id gracefully" {
    run bash "$LOOP" --tasks /tmp/nonexistent.json
    [[ "$status" -ne 0 ]]
}

@test "loop handles dry-run with synthetic tasks" {
    tmpdir=$(mktemp -d)
    echo '[{"id":1,"description":"test","status":"pending"}]' > "$tmpdir/tasks.json"
    run bash "$LOOP" --sprint-id "test-smoke" --tasks "$tmpdir/tasks.json" --max-tasks 1 --dry-run
    rm -rf "$tmpdir"
    # dry-run should succeed
    [[ "$status" -eq 0 ]]
}
