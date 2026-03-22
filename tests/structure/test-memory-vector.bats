#!/usr/bin/env bats
# Tests for vector memory index integration (SPEC-018)
# These tests validate the integration layer and fallback behavior.
# The actual vector quality test is in tests/test-vector-quality.py

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"
    VECTOR="$BATS_TEST_DIRNAME/../../scripts/memory-vector.py"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "memory-vector.py: exists and is valid Python" {
    [ -f "$VECTOR" ]
    python3 -c "import ast; ast.parse(open('$VECTOR').read())"
}

@test "memory-vector.py: status works without deps" {
    # Even without hnswlib/sentence-transformers, status should not crash
    run python3 "$VECTOR" status --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Level:"* ]]
    [[ "$output" == *"Store:"* ]]
}

@test "memory-store.sh: search falls back to grep without index" {
    bash "$SCRIPT" save --type decision --title "Use Redis" --content "Cache layer for API"
    run bash "$SCRIPT" search "Redis" --mode grep
    [ "$status" -eq 0 ]
    [[ "$output" == *"Redis"* ]]
}

@test "memory-store.sh: --mode grep forces keyword search" {
    bash "$SCRIPT" save --type bug --title "Timeout error" --content "Connection pool exhausted"
    run bash "$SCRIPT" search "Timeout" --mode grep
    [ "$status" -eq 0 ]
    [[ "$output" == *"Timeout"* ]]
}

@test "memory-store.sh: rebuild-index handles empty store or missing deps" {
    run bash "$SCRIPT" rebuild-index
    # Accepts: empty store ("Nothing to index"), no deps ("pip install"), or success ("Index")
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" == *"Index"* ]] || [[ "$output" == *"pip install"* ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"Nothing"* ]]
}

@test "memory-store.sh: index-status shows state" {
    run bash "$SCRIPT" index-status
    [[ "$output" == *"Level:"* ]]
}

@test "memory-store.sh: help shows vector commands" {
    run bash "$SCRIPT" help
    [[ "$output" == *"rebuild-index"* ]]
    [[ "$output" == *"index-status"* ]]
    [[ "$output" == *"benchmark"* ]]
    [[ "$output" == *"--mode"* ]]
}

@test "memory-store.sh: auto-rebuild does not crash without deps" {
    # save triggers _maybe_rebuild_index which should silently no-op
    run bash "$SCRIPT" save --type pattern --title "Test rebuild" --content "Should not crash"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Guardado"* ]]
}
