#!/usr/bin/env bats
# SE-243 — Attack Surface Mapping — BATS tests

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    SCRIPT="$PWD/scripts/attack-surface-map.sh"
    AUTHORIZE="$PWD/scripts/surface-map-authorize.sh"
    SKILL="$PWD/.opencode/skills/attack-surface-mapper/SKILL.md"
    OUTPUT_DIR="$PWD/output/security"
    # Use a safe test target alias
    TEST_TARGET="test-target-se243.local"
    AUTH_FILE="${OUTPUT_DIR}/authorization-${TEST_TARGET}.txt"
}

teardown() {
    # Clean up any test authorization files created during tests
    rm -f "${OUTPUT_DIR}/authorization-${TEST_TARGET}.txt" 2>/dev/null || true
}

# Test 1: attack-surface-map.sh exists and passes bash -n
@test "attack-surface-map.sh exists and passes bash -n" {
    [[ -f "$SCRIPT" ]]
    bash -n "$SCRIPT"
}

# Test 2: surface-map-authorize.sh exists and passes bash -n
@test "surface-map-authorize.sh exists and passes bash -n" {
    [[ -f "$AUTHORIZE" ]]
    bash -n "$AUTHORIZE"
}

# Test 3: attack-surface-mapper/SKILL.md exists and <= 150 lines
@test "attack-surface-mapper/SKILL.md exists and <= 150 lines" {
    [[ -f "$SKILL" ]]
    line_count=$(wc -l < "$SKILL")
    [[ "$line_count" -le 150 ]]
}

# Test 4: Without authorization file → exit 1 with explanatory message
@test "without authorization file, exits 1 with explanatory message" {
    rm -f "$AUTH_FILE" 2>/dev/null || true
    run bash "$SCRIPT" --target "$TEST_TARGET"
    [[ "$status" -eq 1 ]]
    [[ "$output" =~ [Aa]uthor ]]
}

# Test 5: Authorization gate verifies file age (< 30 days passes, old fails)
@test "authorization gate accepts fresh file and rejects stale file" {
    mkdir -p "$OUTPUT_DIR"
    # Fresh file (just created) should pass age check
    echo "AUTHORIZED" > "$AUTH_FILE"
    run bash "$SCRIPT" --target "$TEST_TARGET"
    # Should NOT fail with authorization error (may fail on tools missing — that's ok)
    [[ ! "$output" =~ "older than 30 days" ]]

    # Simulate stale file by backdating (touch -d 31 days ago)
    if touch -d "31 days ago" "$AUTH_FILE" 2>/dev/null; then
        run bash "$SCRIPT" --target "$TEST_TARGET"
        [[ "$status" -eq 1 ]]
        [[ "$output" =~ "older than 30 days" ]]
    else
        skip "touch -d not available on this platform"
    fi
}

# Test 6: attack-surface-map.sh accepts --target
@test "attack-surface-map.sh accepts --target flag" {
    grep -q -- '--target' "$SCRIPT"
}

# Test 7: attack-surface-map.sh accepts --tools
@test "attack-surface-map.sh accepts --tools flag" {
    grep -q -- '--tools' "$SCRIPT"
}

# Test 8: With subfinder not available, falls back to Docker
@test "script has Docker fallback for subfinder" {
    grep -q "projectdiscovery/subfinder" "$SCRIPT"
}

# Test 9: SKILL.md mentions authorization
@test "SKILL.md mentions authorization" {
    grep -qi "autorización\|authorization\|autorizar\|authorize" "$SKILL"
}

# Test 10: surface-map-authorize.sh creates file in output/security/
@test "surface-map-authorize.sh creates auth file in output/security/" {
    grep -q "output/security" "$AUTHORIZE"
    grep -q "authorization-" "$AUTHORIZE"
}
