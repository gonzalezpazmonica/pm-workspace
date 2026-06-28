#!/usr/bin/env bats
# SE-245 — Dynamic Web Security Testing — BATS tests

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    SCRIPT="$PWD/scripts/dynamic-web-security-test.sh"
    SKILL="$PWD/.opencode/skills/dynamic-web-tester/SKILL.md"
    OUTPUT_DIR="$PWD/output/security"
    TEST_HOST="localhost"
    TEST_TARGET="http://localhost:19999"
    AUTH_FILE="${OUTPUT_DIR}/authorization-${TEST_HOST}.txt"
}

teardown() {
    rm -f "${OUTPUT_DIR}/authorization-${TEST_HOST}.txt" 2>/dev/null || true
}

# Test 1: dynamic-web-security-test.sh exists and passes bash -n
@test "dynamic-web-security-test.sh exists and passes bash -n" {
    [[ -f "$SCRIPT" ]]
    bash -n "$SCRIPT"
}

# Test 2: dynamic-web-tester/SKILL.md exists and <= 150 lines
@test "dynamic-web-tester/SKILL.md exists and <= 150 lines" {
    [[ -f "$SKILL" ]]
    line_count=$(wc -l < "$SKILL")
    [[ "$line_count" -le 150 ]]
}

# Test 3: Without authorization file → exit 1
@test "without authorization file, exits 1" {
    rm -f "$AUTH_FILE" 2>/dev/null || true
    run bash "$SCRIPT" --target "$TEST_TARGET"
    [[ "$status" -eq 1 ]]
    [[ "$output" =~ [Aa]uthor ]]
}

# Test 4: dynamic-web-security-test.sh accepts --target
@test "dynamic-web-security-test.sh accepts --target flag" {
    grep -q -- '--target' "$SCRIPT"
}

# Test 5: --safe mode is default (on)
@test "safe mode is default (SAFE=true on startup)" {
    grep -q 'SAFE="true"' "$SCRIPT"
}

# Test 6: dynamic-web-security-test.sh accepts --tools
@test "dynamic-web-security-test.sh accepts --tools flag" {
    grep -q -- '--tools' "$SCRIPT"
}

# Test 7: sqlmap uses --level 1 --risk 1 --batch (non-aggressive)
@test "sqlmap invocation uses --level 1 --risk 1 --batch" {
    grep -q -- '"--level"' "$SCRIPT" || grep -q -- '--level' "$SCRIPT"
    grep -q -- '"--risk"' "$SCRIPT" || grep -q -- '--risk' "$SCRIPT"
    grep -q -- '"--batch"' "$SCRIPT" || grep -q -- '--batch' "$SCRIPT"
    # Verify the values are 1
    grep -q '"1"' "$SCRIPT"
}

# Test 8: Report goes to output/security/
@test "report is written to output/security/" {
    grep -q 'output/security' "$SCRIPT"
}

# Test 9: SKILL.md mentions authorization
@test "SKILL.md mentions authorization" {
    grep -qi "autorización\|authorization\|autorizar\|authorize" "$SKILL"
}

# Test 10: dynamic-web-security-test.sh has set -uo pipefail
@test "dynamic-web-security-test.sh has set -uo pipefail" {
    grep -q "set -uo pipefail" "$SCRIPT"
}
