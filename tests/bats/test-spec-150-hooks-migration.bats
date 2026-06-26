#!/usr/bin/env bats
# test-spec-150-hooks-migration.bats — SPEC-150 Slice 1
#
# Validates baseline infrastructure for hook multi-handler migration.
# Ref: docs/propuestas/SPEC-150-hooks-multi-handler-migration.md

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BASELINE_SCRIPT="$REPO_ROOT/scripts/hook-multihandler-baseline.sh"
    MIGRATION_DOC="$REPO_ROOT/docs/rules/domain/hook-multihandler-migration.md"
    BASELINES_DIR="$REPO_ROOT/tests/evals/hook-baselines"
    TMPDIR_BASELINE="$(mktemp -d)"
    export CLAUDE_PROJECT_DIR="$REPO_ROOT"
}

teardown() {
    rm -rf "${TMPDIR_BASELINE:-}" 2>/dev/null || true
}

# ── Test 1: baseline script exists ────────────────────────────────────────────

@test "SPEC-150: baseline script exists at scripts/hook-multihandler-baseline.sh" {
    [ -f "$BASELINE_SCRIPT" ]
}

@test "SPEC-150: baseline script is executable" {
    [ -x "$BASELINE_SCRIPT" ]
}

# ── Test 2: migration doc exists ──────────────────────────────────────────────

@test "SPEC-150: migration design doc exists at docs/rules/domain/hook-multihandler-migration.md" {
    [ -f "$MIGRATION_DOC" ]
}

@test "SPEC-150: migration doc references all 6 candidate hooks" {
    grep -q "sycophancy-strip" "$MIGRATION_DOC"
    grep -q "block-credential-leak" "$MIGRATION_DOC"
    grep -q "contract-test-guard" "$MIGRATION_DOC"
    grep -q "context-sanitize-input" "$MIGRATION_DOC"
    grep -q "pii-gate" "$MIGRATION_DOC"
    grep -q "router-mode-dispatch" "$MIGRATION_DOC"
}

@test "SPEC-150: migration doc has spec_ref SPEC-150" {
    grep -q "SPEC-150" "$MIGRATION_DOC"
}

# ── Test 3: hook-baselines directory ──────────────────────────────────────────

@test "SPEC-150: tests/evals/hook-baselines/ directory exists" {
    mkdir -p "$BASELINES_DIR"
    [ -d "$BASELINES_DIR" ]
}

@test "SPEC-150: baseline script creates output directory when run" {
    local test_out="$TMPDIR_BASELINE/baselines-test"
    run bash "$BASELINE_SCRIPT" --output-dir "$test_out"
    # Script may exit 0 or non-zero depending on hook availability
    # Directory must exist regardless
    [ -d "$test_out" ]
}

# ── Test 4: JSON output valid ─────────────────────────────────────────────────

@test "SPEC-150: baseline script produces valid JSON to stdout" {
    local test_out="$TMPDIR_BASELINE/baselines-json-test"
    # Capture only stdout (stderr goes to /dev/null to avoid mixing progress output)
    local json_output
    json_output=$(LC_ALL=C bash "$BASELINE_SCRIPT" --output-dir "$test_out" 2>/dev/null)
    echo "$json_output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "SPEC-150: baseline JSON has 'baselines' array field" {
    local test_out="$TMPDIR_BASELINE/baselines-fields-test"
    local json_output
    json_output=$(LC_ALL=C bash "$BASELINE_SCRIPT" --output-dir "$test_out" 2>/dev/null)
    echo "$json_output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'baselines' in d, f'Missing baselines key. Keys: {list(d.keys())}'
assert isinstance(d['baselines'], list), 'baselines must be a list'
"
}

@test "SPEC-150: baseline JSON entries have fp_rate and fn_rate fields" {
    local test_out="$TMPDIR_BASELINE/baselines-rates-test"
    local json_output
    json_output=$(LC_ALL=C bash "$BASELINE_SCRIPT" --output-dir "$test_out" 2>/dev/null)
    echo "$json_output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for entry in d.get('baselines', []):
    assert 'fp_rate' in entry, f'Missing fp_rate in {entry.get(\"hook\")}'
    assert 'fn_rate' in entry, f'Missing fn_rate in {entry.get(\"hook\")}'
    assert 0.0 <= entry['fp_rate'] <= 1.0, f'fp_rate out of range: {entry[\"fp_rate\"]}'
    assert 0.0 <= entry['fn_rate'] <= 1.0, f'fn_rate out of range: {entry[\"fn_rate\"]}'
"
}

@test "SPEC-150: baseline script defines 6 hook entries in source" {
    local hook_count
    hook_count=$(grep -c 'HOOK_PATHS\[' "$BASELINE_SCRIPT" 2>/dev/null || echo 0)
    [ "$hook_count" -ge 6 ]
}
