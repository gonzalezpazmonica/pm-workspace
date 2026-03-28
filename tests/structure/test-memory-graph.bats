#!/usr/bin/env bats
# Tests for SPEC-027 Phase 1 — Memory Graph (entity-relation extraction)

setup() {
    export SAVIA_TEST_MODE=true
    export PROJECT_ROOT=$(mktemp -d)
    export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
    GRAPH_SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-graph.py"
    STORE_SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"
    mkdir -p "$PROJECT_ROOT/output"
    # Seed test data
    bash "$STORE_SCRIPT" save --type decision --title "Use PostgreSQL" --content "Chose PostgreSQL for better JSON support" --concepts "database,sql"
    bash "$STORE_SCRIPT" save --type bug --title "Redis Timeout" --content "Connection pool exhausted under load" --concepts "cache,performance"
    bash "$STORE_SCRIPT" save --type architecture --title "GraphQL for Frontend" --content "REST too granular for dashboard" --concepts "api,frontend"
    bash "$STORE_SCRIPT" save --type pattern --title "Circuit Breaker" --content "Polly circuit breaker for external calls" --concepts "resilience"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "memory-graph.py: valid Python" {
    python3 -c "import ast; ast.parse(open('$GRAPH_SCRIPT').read())"
}

@test "build: generates graph JSON" {
    run python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"entities"* ]]
    GRAPH="${STORE_FILE%.jsonl}-graph.json"
    [ -f "$GRAPH" ]
}

@test "build: graph has entities and relations" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    GRAPH="${STORE_FILE%.jsonl}-graph.json"
    run python3 -c "
import json
g = json.load(open('$GRAPH'))
assert len(g['entities']) > 0, 'no entities'
assert len(g['relations']) > 0, 'no relations'
print(f'OK: {len(g[\"entities\"])} entities, {len(g[\"relations\"])} relations')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "build: extracts technology entities" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    GRAPH="${STORE_FILE%.jsonl}-graph.json"
    run python3 -c "
import json
g = json.load(open('$GRAPH'))
names = [e['name'].lower() for e in g['entities']]
assert any('postgresql' in n for n in names), f'PostgreSQL not found in {names}'
print('OK')
"
    [ "$status" -eq 0 ]
}

@test "build: extracts concept entities from fields" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    GRAPH="${STORE_FILE%.jsonl}-graph.json"
    run python3 -c "
import json
g = json.load(open('$GRAPH'))
names = [e['name'].lower() for e in g['entities']]
assert 'database' in names, f'database concept not found in {names}'
print('OK')
"
    [ "$status" -eq 0 ]
}

@test "build: creates relations between co-occurring entities" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    GRAPH="${STORE_FILE%.jsonl}-graph.json"
    run python3 -c "
import json
g = json.load(open('$GRAPH'))
types = [r['type'] for r in g['relations']]
assert 'decided' in types, f'no decided relation in {types}'
print('OK')
"
    [ "$status" -eq 0 ]
}

@test "search: finds entities by name" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    run python3 "$GRAPH_SCRIPT" search "PostgreSQL" --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PostgreSQL"* ]] || [[ "$output" == *"postgresql"* ]]
}

@test "search: returns related entities" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    run python3 "$GRAPH_SCRIPT" search "Redis" --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"related"* ]]
}

@test "status: shows graph info" {
    python3 "$GRAPH_SCRIPT" build --store "$STORE_FILE"
    run python3 "$GRAPH_SCRIPT" status --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"entities"* ]]
}

@test "status: detects missing graph" {
    run python3 "$GRAPH_SCRIPT" status --store "$STORE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT BUILT"* ]]
}

@test "memory-store.sh: build-graph subcommand works" {
    run bash "$STORE_SCRIPT" build-graph
    [ "$status" -eq 0 ]
    [[ "$output" == *"entities"* ]]
}

@test "memory-store.sh: graph-status subcommand works" {
    bash "$STORE_SCRIPT" build-graph
    run bash "$STORE_SCRIPT" graph-status
    [ "$status" -eq 0 ]
    [[ "$output" == *"entities"* ]]
}
