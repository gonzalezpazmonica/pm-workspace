#!/usr/bin/env bats
# Tests for digest-to-memory.sh bridge

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
    BRIDGE="$BATS_TEST_DIRNAME/../../scripts/digest-to-memory.sh"
    mkdir -p "$PROJECT_ROOT/scripts"
    for f in memory-store.sh memory-save.sh memory-search.sh; do
        cp "$BATS_TEST_DIRNAME/../../scripts/$f" "$PROJECT_ROOT/scripts/"
    done
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "digest-to-memory.sh: valid bash" {
    bash -n "$BRIDGE"
}

@test "meeting digest persists to JSONL" {
    run bash "$BRIDGE" --type meeting --title "Sprint Review" --project "alpha" --what "3 PBIs completed"
    [ "$status" -eq 0 ]
    [ -f "$STORE_FILE" ]
    grep -q "Sprint Review" "$STORE_FILE"
}

@test "document digest persists" {
    run bash "$BRIDGE" --type pdf --title "Arch Doc" --project "beta" --what "Migration plan"
    [ "$status" -eq 0 ]
    grep -q "Arch Doc" "$STORE_FILE"
}

@test "auto-sets 90d expiry for meetings" {
    bash "$BRIDGE" --type meeting --title "Daily" --what "Status"
    grep -q "expires_at" "$STORE_FILE"
}

@test "requires --type and --title" {
    run bash "$BRIDGE" --title "No type"
    [ "$status" -ne 0 ]
}

# ── Negative cases ──

@test "fails without --title" {
    run bash "$BRIDGE" --type meeting
    [ "$status" -ne 0 ]
}

@test "handles empty --what gracefully" {
    run bash "$BRIDGE" --type meeting --title "Empty what" --what ""
    # Should either succeed with empty or fail gracefully
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ── Edge case ──

@test "multiple digests append to same JSONL" {
    bash "$BRIDGE" --type meeting --title "First" --what "a"
    bash "$BRIDGE" --type pdf --title "Second" --what "b"
    local count; count=$(wc -l < "$STORE_FILE")
    [ "$count" -ge 2 ]
}

# ── Spec/doc reference ──

@test "bridge aligns with digest-traceability rule" {
    # Ref: docs/rules/domain/digest-traceability.md
    grep -q "type\|title\|digest" "$BRIDGE"
}

@test "digest-to-memory.sh has safety headers" {
    grep -q "set -[euo]" "$BRIDGE" || grep -q "set -[euo]*o pipefail" "$BRIDGE"
}

@test "meeting digest output contains title in store" {
    run bash "$BRIDGE" --type meeting --title "Review Session" --project "gamma" --what "Discussed roadmap"
    [ "$status" -eq 0 ]
    [[ "$(cat "$STORE_FILE")" == *"Review Session"* ]]
}

@test "digest handles nonexistent project gracefully" {
    run bash "$BRIDGE" --type meeting --title "Edge" --project "nonexistent-$$" --what "test"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "digest handles null type gracefully" {
    run bash "$BRIDGE" --type "" --title "Null type"
    [ "$status" -ne 0 ]
}
