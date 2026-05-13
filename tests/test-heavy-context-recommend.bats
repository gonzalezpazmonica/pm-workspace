#!/usr/bin/env bats
# tests/test-heavy-context-recommend.bats — SPEC-HEAVY-CONTEXT-CRITERIA

setup() {
    WORKSPACE_REAL="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    export TEST_HOME="$(mktemp -d)"
    export SAVIA_USAGE_DB="${TEST_HOME}/usage.db"
    export SCRIPT="${WORKSPACE_REAL}/scripts/heavy-context-recommend.py"
}

teardown() {
    rm -rf "${TEST_HOME}"
}

@test "TC-01: matrix returns recommend for systemic + mid" {
    run python3 "${SCRIPT}" --migrate
    [ "$status" -eq 0 ]
    # init turns table so prereqs pass
    python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); c.execute('CREATE TABLE IF NOT EXISTS turns (ts TEXT, message_id TEXT)'); c.execute(\"INSERT INTO turns VALUES ('2026-05-01T00:00:00Z','m1')\"); c.commit(); c.close()"
    run python3 "${SCRIPT}" systemic mid
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Decision: RECOMMEND"
}

@test "TC-02: matrix returns avoid for lookup + fast" {
    run python3 "${SCRIPT}" --migrate
    python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); c.execute('CREATE TABLE IF NOT EXISTS turns (ts TEXT, message_id TEXT)'); c.execute(\"INSERT INTO turns VALUES ('2026-05-01T00:00:00Z','m1')\"); c.commit(); c.close()"
    run python3 "${SCRIPT}" lookup fast
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Decision: AVOID"
}

@test "TC-03: heavy tier shows tentative flag when N<10" {
    run python3 "${SCRIPT}" --migrate
    python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); c.execute('CREATE TABLE IF NOT EXISTS turns (ts TEXT, message_id TEXT)'); c.execute(\"INSERT INTO turns VALUES ('2026-05-01T00:00:00Z','m1')\"); c.commit(); c.close()"
    run python3 "${SCRIPT}" systemic heavy
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "tentative"
}

@test "TC-04: advisory mode active when usage.db missing" {
    rm -f "${SAVIA_USAGE_DB}"
    run python3 "${SCRIPT}" systemic mid
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "ADVISORY MODE"
}

@test "TC-05: decision logged with outcome=unknown" {
    run python3 "${SCRIPT}" --migrate
    python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); c.execute('CREATE TABLE IF NOT EXISTS turns (ts TEXT, message_id TEXT)'); c.execute(\"INSERT INTO turns VALUES ('2026-05-01T00:00:00Z','m1')\"); c.commit(); c.close()"
    run python3 "${SCRIPT}" cross-module mid --project test-proj --tool agent-code-map
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Logged:"
    n=$(python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); r=c.execute(\"SELECT COUNT(*) FROM heavy_context_invocations WHERE outcome='unknown'\").fetchone()[0]; print(r)")
    [ "$n" -eq 1 ]
}

@test "TC-06: invalid scope returns error with valid list" {
    run python3 "${SCRIPT}" bogus mid
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "invalid scope"
}

@test "TC-07: invalid tier returns error with valid list" {
    run python3 "${SCRIPT}" systemic bogus
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "invalid tier"
}

@test "TC-08: --show-matrix prints all 4 scopes and 3 tiers" {
    run python3 "${SCRIPT}" --show-matrix
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "systemic"
    echo "$output" | grep -q "cross-module"
    echo "$output" | grep -q "single-file"
    echo "$output" | grep -q "lookup"
    echo "$output" | grep -q "fast"
    echo "$output" | grep -q "mid"
    echo "$output" | grep -q "heavy"
}

@test "TC-09: --migrate creates heavy_context_invocations table" {
    run python3 "${SCRIPT}" --migrate
    [ "$status" -eq 0 ]
    tbl=$(python3 -c "import sqlite3; c=sqlite3.connect('${SAVIA_USAGE_DB}'); r=c.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name='heavy_context_invocations'\").fetchone(); print(r[0] if r else 'none')")
    [ "$tbl" = "heavy_context_invocations" ]
}
