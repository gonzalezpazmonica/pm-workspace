#!/usr/bin/env bats
# tests/bats/test-memory-feedback.bats
# SPEC-164 — Memory Feedback Loop (BATS tests, >= 6)
#
# Tests for:
#   .opencode/hooks/memory-feedback-task.sh
#   scripts/memory-feedback-extractor.py
#   scripts/memory-feedback-compactor.py
#   scripts/memory-feedback-post-merge.sh

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
HOOK="$REPO_ROOT/.opencode/hooks/memory-feedback-task.sh"
EXTRACTOR="$REPO_ROOT/scripts/memory-feedback-extractor.py"
COMPACTOR="$REPO_ROOT/scripts/memory-feedback-compactor.py"
POST_MERGE="$REPO_ROOT/scripts/memory-feedback-post-merge.sh"

setup() {
    TMPDIR_MF="$(mktemp -d)"
    export HOME="$TMPDIR_MF"
    mkdir -p "$TMPDIR_MF/output"
    # Prevent actual memory writes in tests
    export SAVIA_TEST_MODE=true
    export CLAUDE_PROJECT_DIR="$REPO_ROOT"
}

teardown() {
    rm -rf "$TMPDIR_MF"
}

# ─── Test 1: hook file exists and is executable ──────────────────────────────

@test "memory-feedback-task.sh exists and is executable" {
    [[ -f "$HOOK" ]]
    [[ -x "$HOOK" ]]
}

# ─── Test 2: SAVIA_MEMORY_FEEDBACK=off → hook exits 0 without writing ────────

@test "SAVIA_MEMORY_FEEDBACK=off → hook exit 0 sin escribir" {
    local tel="$TMPDIR_MF/output/memory-feedback-telemetry.jsonl"
    local before=0
    [[ -f "$tel" ]] && before="$(wc -l < "$tel")"

    local payload='{"tool_name":"Task","tool_input":{"subagent_type":"test-runner"},"tool_result":"ERROR: test failed"}'
    run bash -c "SAVIA_MEMORY_FEEDBACK=off CLAUDE_PROJECT_DIR='$REPO_ROOT' bash '$HOOK' <<< '$payload'"

    [[ "$status" -eq 0 ]]
    # No telemetry line should have been written
    local after=0
    [[ -f "$tel" ]] && after="$(wc -l < "$tel")"
    [[ "$before" -eq "$after" ]]
}

# ─── Test 3: hook declares set -uo pipefail ───────────────────────────────────

@test "memory-feedback-task.sh tiene set -uo pipefail" {
    grep -qE "set -[uo]+ pipefail|set -euo pipefail" "$HOOK"
}

# ─── Test 4: extractor works standalone ──────────────────────────────────────

@test "memory-feedback-extractor.py funciona standalone con output de error" {
    local payload='{"tool_name":"Task","tool_input":{"subagent_type":"dotnet-developer"},"tool_result":"ERROR: build failed"}'
    local out
    out="$(printf '%s' "$payload" | python3 "$EXTRACTOR")"
    [[ -n "$out" ]]
    # Must be valid JSON
    python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert d['outcome']=='failure'" "$out"
}

@test "memory-feedback-extractor.py funciona standalone con output limpio" {
    local payload='{"tool_name":"Task","tool_input":{"subagent_type":"test-runner"},"tool_result":"All 50 tests passed. Coverage 95%."}'
    local out
    out="$(printf '%s' "$payload" | python3 "$EXTRACTOR")"
    [[ -n "$out" ]]
    python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert d['outcome']=='success'" "$out"
}

# ─── Test 5: compactor --dry-run no modifica nada ────────────────────────────

@test "compactor --dry-run no modifica MEMORY.md" {
    local mem_dir="$TMPDIR_MF/auto"
    mkdir -p "$mem_dir"
    local mem_file="$mem_dir/MEMORY.md"
    cat > "$mem_file" <<'EOF'
# MEMORY Index
<!-- ENTRIES_START -->
- outcome:failure agent:test-runner lesson:Tests failed [2026-06-01T12:00:00Z]
- outcome:failure agent:test-runner lesson:Tests failed [2026-06-02T12:00:00Z]
- outcome:failure agent:test-runner lesson:Tests failed [2026-06-03T12:00:00Z]
<!-- ENTRIES_END -->
EOF
    local before_md5
    before_md5="$(md5sum "$mem_file" | cut -d' ' -f1)"

    run python3 "$COMPACTOR" --dry-run --memory "$mem_file"
    [[ "$status" -eq 0 ]]

    local after_md5
    after_md5="$(md5sum "$mem_file" | cut -d' ' -f1)"
    [[ "$before_md5" = "$after_md5" ]]
}

# ─── Test 6: post-merge --manual funciona ────────────────────────────────────

@test "memory-feedback-post-merge.sh --manual funciona y exit 0" {
    run bash "$POST_MERGE" --manual --pr 864 --spec SPEC-164
    [[ "$status" -eq 0 ]]
}

# ─── Test 7: hook tool_name != Task → exits 0 (no-op) ───────────────────────

@test "hook non-Task tool_name → exits 0 sin procesar" {
    local payload='{"tool_name":"Edit","tool_input":{},"tool_result":"edited"}'
    run bash -c "SAVIA_MEMORY_FEEDBACK=on CLAUDE_PROJECT_DIR='$REPO_ROOT' bash '$HOOK' <<< '$payload'"
    [[ "$status" -eq 0 ]]
}

# ─── Test 8: extractor json output has required fields ───────────────────────

@test "extractor output JSON tiene campos requeridos" {
    local payload='{"tool_name":"Task","tool_input":{"subagent_type":"code-reviewer"},"tool_result":"All checks passed successfully with zero warnings."}'
    local out
    out="$(printf '%s' "$payload" | python3 "$EXTRACTOR")"
    python3 - "$out" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
required = ["outcome", "agent_name", "lesson", "entropy_score", "should_write"]
missing = [f for f in required if f not in d]
if missing:
    print(f"Missing fields: {missing}", file=sys.stderr)
    sys.exit(1)
print("OK")
PYEOF
}

# ─── Test 9: post-merge script has set -uo pipefail ──────────────────────────

@test "memory-feedback-post-merge.sh tiene set -uo pipefail" {
    grep -qE "set -[uo]+ pipefail|set -euo pipefail" "$POST_MERGE"
}

# ─── Test 10: compactor script has valid bash syntax ─────────────────────────

@test "memory-feedback-task.sh tiene sintaxis bash válida" {
    bash -n "$HOOK"
}

@test "memory-feedback-post-merge.sh tiene sintaxis bash válida" {
    bash -n "$POST_MERGE"
}
