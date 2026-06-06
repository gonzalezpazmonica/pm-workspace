#!/usr/bin/env bats
# tests/test-se-086-ubiquitous-language.bats — SE-086 Ubiquitous Language extractor
# Tests: script existence, --help, --export-glossary, --sync-graph, output format
# Ref: docs/rules/domain/ubiquitous-language.md, scripts/extract-domain-entities.py

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/extract-domain-entities.py"
ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR
    # Minimal input file with repeatable domain terms
    INPUT_FILE="$TMP_DIR/input.md"
    cat > "$INPUT_FILE" <<'EOF'
# Test Domain Document

The Sprint is the core cadence. Each Sprint contains PBIs decomposed into Slices.
An Era groups several Sprints around a theme. Each PBI has Acceptance Criteria (AC).
The Sprint velocity is measured in story points. Slices map to vertical cuts of a PBI.
The Era ends with a retrospective. AC items are verified before closing a Sprint.
EOF
    export INPUT_FILE
    export OUTPUT_DIR="$TMP_DIR/output"
    export CONTEXT_PATH="$TMP_DIR/projects/test-proj/CONTEXT.md"
    export GRAPH_DB="$TMP_DIR/test-graph.db"
}

teardown() {
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Test 1: script file exists ────────────────────────────────────────────────

@test "script exists at scripts/extract-domain-entities.py" {
    [[ -f "$SCRIPT" ]]
}

# ── Test 2: script is valid Python syntax ─────────────────────────────────────

@test "script passes python3 syntax check" {
    python3 -m py_compile "$SCRIPT"
}

# ── Test 3: --help exits 0 ────────────────────────────────────────────────────

@test "--help exits with code 0" {
    run python3 "$SCRIPT" --help
    [ "$status" -eq 0 ]
}

# ── Test 4: --help output contains expected flags ─────────────────────────────

@test "--help mentions --export-glossary and --sync-graph" {
    run python3 "$SCRIPT" --help
    [[ "$output" == *"--export-glossary"* ]]
    [[ "$output" == *"--sync-graph"* ]]
}

# ── Test 5: --export-glossary generates CONTEXT.md ───────────────────────────

@test "--export-glossary generates projects/{slug}/CONTEXT.md" {
    run python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --export-glossary \
        --context "$CONTEXT_PATH" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2
    [ "$status" -eq 0 ]
    [[ -f "$CONTEXT_PATH" ]]
}

# ── Test 6: generated CONTEXT.md has valid markdown table ────────────────────

@test "exported CONTEXT.md contains a markdown table with Term column" {
    python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --export-glossary \
        --context "$CONTEXT_PATH" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2 >/dev/null 2>&1
    [[ -f "$CONTEXT_PATH" ]]
    grep -q "| Term" "$CONTEXT_PATH"
}

# ── Test 7: generated CONTEXT.md contains heading ────────────────────────────

@test "exported CONTEXT.md starts with '# Domain Glossary'" {
    python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --export-glossary \
        --context "$CONTEXT_PATH" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2 >/dev/null 2>&1
    head -1 "$CONTEXT_PATH" | grep -q "# Domain Glossary"
}

# ── Test 8: report output file is generated ──────────────────────────────────

@test "running extractor generates a report in output-dir" {
    run python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2
    [ "$status" -eq 0 ]
    # At least one report file created
    ls "$OUTPUT_DIR"/domain-entity-report-test-proj-*.md 2>/dev/null | grep -q .
}

# ── Test 9: --sync-graph exits 0 (does not crash) ────────────────────────────

@test "--sync-graph exits with code 0" {
    run python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --sync-graph \
        --graph-db "$GRAPH_DB" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2
    [ "$status" -eq 0 ]
}

# ── Test 10: --sync-graph creates the SQLite DB file ─────────────────────────

@test "--sync-graph creates knowledge-graph DB file" {
    python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --sync-graph \
        --graph-db "$GRAPH_DB" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2 >/dev/null 2>&1
    [[ -f "$GRAPH_DB" ]]
}

# ── Test 11: --export-glossary and --sync-graph can run together ──────────────

@test "--export-glossary combined with --sync-graph exits 0" {
    run python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --export-glossary \
        --sync-graph \
        --context "$CONTEXT_PATH" \
        --graph-db "$GRAPH_DB" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2
    [ "$status" -eq 0 ]
}

# ── Test 12: --auto-update without --export-glossary does not overwrite ───────

@test "--auto-update appends to existing CONTEXT.md without destroying it" {
    mkdir -p "$(dirname "$CONTEXT_PATH")"
    printf '# Domain Glossary — test-proj\n\n| Term | Definition | Status |\n|------|------------|--------|\n| Era | Existing definition. | stable |\n' > "$CONTEXT_PATH"
    python3 "$SCRIPT" \
        --project test-proj \
        --input "$INPUT_FILE" \
        --auto-update \
        --context "$CONTEXT_PATH" \
        --output-dir "$OUTPUT_DIR" \
        --min-mentions 2 >/dev/null 2>&1
    # Original entry must still be present
    grep -q "Existing definition" "$CONTEXT_PATH"
}
