#!/usr/bin/env bats
# Tests for SPEC-023 Phase 1 — training data generation

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/generate-training-data.py"
    OUTPUT="$PROJECT_ROOT/output/training/test-data.jsonl"
    mkdir -p "$PROJECT_ROOT/.claude/commands"
    echo -e "# Test command\nDoes something useful" > "$PROJECT_ROOT/.claude/commands/test-cmd.md"
    mkdir -p "$PROJECT_ROOT/.claude/rules/domain"
    echo -e "# Rule Test\nThis rule enforces quality standards for the project" > "$PROJECT_ROOT/.claude/rules/domain/test-rule.md"
    mkdir -p "$PROJECT_ROOT/.claude/skills/test-skill"
    printf -- '---\nname: test-skill\ndescription: "A test skill for validation"\n---\n# Test Skill\n' > "$PROJECT_ROOT/.claude/skills/test-skill/SKILL.md"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "generate-training-data.py: valid Python" {
    python3 -c "import ast; ast.parse(open('$SCRIPT').read())"
}

@test "generates JSONL output" {
    run python3 "$SCRIPT" --output "$OUTPUT"
    [ "$status" -eq 0 ]
    [ -f "$OUTPUT" ]
    [[ "$output" == *"Total:"* ]]
}

@test "output contains valid JSON on every line" {
    python3 "$SCRIPT" --output "$OUTPUT"
    run python3 -c "
import json
with open('$OUTPUT') as f:
    count = sum(1 for line in f if json.loads(line))
print(f'OK: {count} valid lines')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "each pair has instruction, response, source" {
    python3 "$SCRIPT" --output "$OUTPUT"
    run python3 -c "
import json
with open('$OUTPUT') as f:
    for line in f:
        obj = json.loads(line)
        assert 'instruction' in obj
        assert 'response' in obj
        assert 'source' in obj
print('OK')
"
    [ "$status" -eq 0 ]
}

@test "extracts from test command" {
    python3 "$SCRIPT" --output "$OUTPUT"
    grep -q "test-cmd" "$OUTPUT"
}

@test "extracts from test rule" {
    python3 "$SCRIPT" --output "$OUTPUT"
    grep -q "test.rule" "$OUTPUT"
}

@test "extracts from test skill" {
    python3 "$SCRIPT" --output "$OUTPUT"
    grep -q "test.skill" "$OUTPUT"
}

@test "no duplicate instructions" {
    python3 "$SCRIPT" --output "$OUTPUT"
    run python3 -c "
import json
seen, total = set(), 0
with open('$OUTPUT') as f:
    for line in f:
        total += 1
        seen.add(json.loads(line)['instruction'])
assert total == len(seen), f'{total} total vs {len(seen)} unique'
print('OK')
"
    [ "$status" -eq 0 ]
}
