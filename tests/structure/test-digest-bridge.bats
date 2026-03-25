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
