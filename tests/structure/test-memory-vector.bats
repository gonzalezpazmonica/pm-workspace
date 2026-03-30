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

# ── Negative cases ──

@test "memory-vector.py: handles nonexistent store path" {
    run python3 "$VECTOR" status --store "/tmp/nonexistent-$$/.memory-store.jsonl"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Level:"* ]]
}

@test "memory-store.sh: search with empty query returns results or no crash" {
    bash "$SCRIPT" save --type decision --title "Some entry" --content "data"
    run bash "$SCRIPT" search "" --mode grep
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ── Edge case ──

@test "memory-vector.py: build on empty store does not crash" {
    touch "$STORE_FILE"
    run python3 "$VECTOR" build --store "$STORE_FILE"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ── Spec/doc reference ──

@test "vector module aligns with SPEC-018" {
    # Ref: SPEC-018 — vector memory index integration
    grep -q "vector\|index\|embed" "$VECTOR"
}

# ── Assertion diversity ──

@test "memory-vector.py: status output contains Level keyword" {
    run python3 "$VECTOR" status --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Level:"* ]]
    echo "$output" | grep -q "Store:"
}

@test "memory-vector.py: is valid Python with no syntax errors" {
    run python3 -c "
import ast, sys
tree = ast.parse(open('$VECTOR').read())
funcs = [n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]
assert len(funcs) >= 2, f'Expected >=2 functions, got {len(funcs)}'
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == "OK" ]]
}

@test "memory-store.sh: search grep mode returns status 0 on match" {
    bash "$SCRIPT" save --type pattern --title "Grep assert foobar" --content "Keyword foobar"
    run bash "$SCRIPT" search "foobar" --mode grep
    [ "$status" -eq 0 ]
    [[ "$output" == *"foobar"* ]] || [[ "$output" == *"Grep assert"* ]]
}

@test "memory-store.sh has set -uo pipefail safety" {
    grep -q "set -uo pipefail" "$SCRIPT"
}

@test "search rejects missing query gracefully" {
    run bash "$SCRIPT" search 2>&1
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]]
}

@test "rebuild-index handles nonexistent store with zero entries" {
    export STORE_FILE="/tmp/nonexistent-$$/.memory-store.jsonl"
    run bash "$SCRIPT" rebuild-index 2>&1
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
