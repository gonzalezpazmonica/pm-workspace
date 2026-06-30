#!/usr/bin/env bats
# SE-246 — Network Recon — BATS tests

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    SCRIPT="$PWD/scripts/network-recon.sh"
    SKILL="$PWD/.opencode/skills/network-recon/SKILL.md"
    OUTPUT_DIR="$PWD/output/security"
    TEST_TARGET="test-recon-se246.local"
    AUTH_FILE="${OUTPUT_DIR}/authorization-${TEST_TARGET}.txt"
}

teardown() {
    rm -f "${OUTPUT_DIR}/authorization-${TEST_TARGET}.txt" 2>/dev/null || true
}

# Test 1: network-recon.sh exists and passes bash -n
@test "network-recon.sh exists and passes bash -n" {
    [[ -f "$SCRIPT" ]]
    bash -n "$SCRIPT"
}

# Test 2: network-recon/SKILL.md exists and <= 150 lines
@test "network-recon/SKILL.md exists and <= 150 lines" {
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

# Test 4: network-recon.sh accepts --target
@test "network-recon.sh accepts --target flag" {
    grep -q -- '--target' "$SCRIPT"
}

# Test 5: network-recon.sh accepts --ports
@test "network-recon.sh accepts --ports flag" {
    grep -q -- '--ports' "$SCRIPT"
}

# Test 6: network-recon.sh accepts --mode
@test "network-recon.sh accepts --mode flag" {
    grep -q -- '--mode' "$SCRIPT"
}

# Test 7: Discovery mode does not use aggressive nmap flags (-A, -O, --script)
@test "discovery mode does not include aggressive nmap flags" {
    # Must not have -A or -O as standalone nmap flags in the run_rustscan_nmap function
    # The safe args should only be -sV -T3 --open
    ! grep -E 'nmap_safe_args.*"-A"' "$SCRIPT"
    ! grep -E 'nmap_safe_args.*"-O"' "$SCRIPT"
    ! grep -E 'nmap_safe_args.*"--script=exploit"' "$SCRIPT"
}

# Test 8: With nmap not available, script has Docker fallback
@test "script has Docker fallback for nmap" {
    grep -q "instrumentisto/nmap" "$SCRIPT"
}

# Test 9: SKILL.md mentions authorization
@test "SKILL.md mentions authorization" {
    grep -qi "autorización\|authorization\|autorizar\|authorize" "$SKILL"
}

# Test 10: network-recon.sh has set -uo pipefail
@test "network-recon.sh has set -uo pipefail" {
    grep -q "set -uo pipefail" "$SCRIPT"
}
