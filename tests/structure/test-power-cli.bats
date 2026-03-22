#!/usr/bin/env bats
# Tests for SPEC-022 Power Features CLI (F1-F4)

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    BUDGET="$BATS_TEST_DIRNAME/../../scripts/budget-guard.sh"
    KEYS="$BATS_TEST_DIRNAME/../../docs/pm-keybindings.json"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# --- F3: PM Keybindings ---

@test "F3: keybindings file exists" {
    [ -f "$KEYS" ]
}

@test "F3: keybindings is valid JSON" {
    python3 -c "import json; json.load(open('$KEYS'))"
}

@test "F3: keybindings has required shortcuts" {
    run python3 -c "
import json
data = json.load(open('$KEYS'))
keys = [k['key'] for k in data['keybindings']]
assert 'ctrl+shift+s' in keys, 'missing sprint-status'
assert 'ctrl+shift+b' in keys, 'missing board-flow'
assert 'ctrl+shift+p' in keys, 'missing compact'
print('OK: all required keybindings present')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "F3: each keybinding has description" {
    run python3 -c "
import json
data = json.load(open('$KEYS'))
for k in data['keybindings']:
    assert 'description' in k, f'missing description for {k[\"key\"]}'
print('OK')
"
    [ "$status" -eq 0 ]
}

# --- F1: Budget Guard ---

@test "F1: budget-guard.sh exists and is valid bash" {
    [ -f "$BUDGET" ]
    bash -n "$BUDGET"
}

@test "F1: budget_check returns healthy at 0%" {
    export CLAUDE_CONTEXT_PERCENT=0
    run bash "$BUDGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"healthy"* ]]
}

@test "F1: budget_check returns warning at 55%" {
    export CLAUDE_CONTEXT_PERCENT=55
    run bash "$BUDGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning"* ]]
}

@test "F1: budget_check returns high at 75%" {
    export CLAUDE_CONTEXT_PERCENT=75
    run bash "$BUDGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"high"* ]]
}

@test "F1: budget_check returns critical at 90%" {
    export CLAUDE_CONTEXT_PERCENT=90
    run bash "$BUDGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"critical"* ]]
}

@test "F1: budget_check --block fails at critical" {
    export CLAUDE_CONTEXT_PERCENT=90
    run bash "$BUDGET" --block
    [ "$status" -eq 1 ]
}

@test "F1: budget_check --block passes at healthy" {
    export CLAUDE_CONTEXT_PERCENT=20
    run bash "$BUDGET" --block
    [ "$status" -eq 0 ]
}

@test "F1: budget_banner silent when healthy" {
    export CLAUDE_CONTEXT_PERCENT=20
    run bash -c "source $BUDGET && budget_banner"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "F1: budget_banner shows message when high" {
    export CLAUDE_CONTEXT_PERCENT=80
    run bash -c "source $BUDGET && budget_banner"
    [[ "$output" == *"necesario"* ]]
}

# --- F2: Semantic Compact ---

@test "F2: semantic-compact.sh exists and valid bash" {
    [ -f "$BATS_TEST_DIRNAME/../../scripts/semantic-compact.sh" ]
    bash -n "$BATS_TEST_DIRNAME/../../scripts/semantic-compact.sh"
}

@test "F2: semantic-compact produces output" {
    run bash "$BATS_TEST_DIRNAME/../../scripts/semantic-compact.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session context"* ]]
    [[ "$output" == *"Branch:"* ]]
    [[ "$output" == *"Preserve:"* ]]
}

@test "F2: pre-compact hook calls semantic-compact" {
    local hook="$BATS_TEST_DIRNAME/../../.claude/hooks/pre-compact-backup.sh"
    grep -q "semantic-compact" "$hook"
}

# --- F4: PR Context Loader ---

@test "F4: pr-context-loader.sh exists and valid bash" {
    [ -f "$BATS_TEST_DIRNAME/../../scripts/pr-context-loader.sh" ]
    bash -n "$BATS_TEST_DIRNAME/../../scripts/pr-context-loader.sh"
}

@test "F4: pr_context_summary handles missing project gracefully" {
    run bash "$BATS_TEST_DIRNAME/../../scripts/pr-context-loader.sh" --project nonexistent
    [ "$status" -eq 0 ]
    [[ "$output" == *"No project context"* ]]
}

@test "F4: pr_context_summary loads project with rules" {
    mkdir -p "$PROJECT_ROOT/projects/testproj"
    echo -e "| Nombre | Rol |\n|---|---|\n| Alice | Dev |" > "$PROJECT_ROOT/projects/testproj/equipo.md"
    echo -e "- RN-001: No duplicar pedidos" > "$PROJECT_ROOT/projects/testproj/reglas-negocio.md"
    run bash "$BATS_TEST_DIRNAME/../../scripts/pr-context-loader.sh" --project testproj
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR Context"* ]]
    [[ "$output" == *"Business rules"* ]]
    [[ "$output" == *"Team"* ]]
}
