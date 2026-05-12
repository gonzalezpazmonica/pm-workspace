#!/usr/bin/env bats
# tests/test-context-update-pipeline.bats
#
# Integration tests for /context-update CLI pipeline.
# Tests the bash wrapper + Python entrypoint end-to-end.
#
# SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §10.2 AC bats tests.

setup() {
  WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  SCRIPT="$WORKSPACE_ROOT/scripts/context-update.sh"
  MAIN_PY="$WORKSPACE_ROOT/scripts/context_update_main.py"
}

# ---------------------------------------------------------------------------
# Script existence and permissions
# ---------------------------------------------------------------------------

@test "context-update.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "context-update.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "context_update_main.py exists" {
  [ -f "$MAIN_PY" ]
}

# ---------------------------------------------------------------------------
# Python import smoke tests
# ---------------------------------------------------------------------------

@test "all pipeline modules import without error" {
  python3 - <<'EOF'
import sys
sys.path.insert(0, 'scripts')
from lib.context_update import discovery, store
from lib.context_update import f1 as f1_runner
from lib.context_update import f2 as f2_runner
from lib.context_update import f3 as f3_consolidator
from lib.context_update import f4 as f4_apply
from lib.context_update.mcp_server import _TOOLS
assert len(_TOOLS) == 6
print("OK")
EOF
}

@test "MCP server has 6 tools" {
  count=$(python3 - <<'EOF'
import sys; sys.path.insert(0, 'scripts')
from lib.context_update.mcp_server import _TOOLS
print(len(_TOOLS))
EOF
)
  [ "$count" -eq 6 ]
}

# ---------------------------------------------------------------------------
# dry-run: exits 0 and emits banner
# ---------------------------------------------------------------------------

@test "dry-run exits 0" {
  python3 "$MAIN_PY" --scope content --dry-run
}

@test "dry-run emits banner" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run 2>&1)
  echo "$output" | grep -q "context-update"
}

@test "dry-run reports files discovered" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run 2>&1)
  echo "$output" | grep -q "files discovered"
}

@test "dry-run reports F1 findings" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run 2>&1)
  echo "$output" | grep -q "F1"
}

@test "dry-run reports F3 composite_quality" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run 2>&1)
  echo "$output" | grep -q "composite_quality"
}

# ---------------------------------------------------------------------------
# --only structural
# ---------------------------------------------------------------------------

@test "--only structural exits 0" {
  python3 "$MAIN_PY" --scope content --only structural --dry-run
}

@test "--only structural skips F2/F3" {
  output=$(python3 "$MAIN_PY" --scope content --only structural --dry-run 2>&1)
  # Should NOT have F3 output
  if echo "$output" | grep -q "F3"; then
    echo "Expected no F3 output in --only structural mode"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# --json output
# ---------------------------------------------------------------------------

@test "--json outputs valid JSON" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run --json 2>/dev/null)
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

@test "--json output contains status ok" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run --json 2>/dev/null)
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data['status'] == 'ok', f'Expected ok, got {data[\"status\"]}'
"
}

@test "--json output contains run_id" {
  output=$(python3 "$MAIN_PY" --scope content --dry-run --json 2>/dev/null)
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'run_id' in data
"
}

# ---------------------------------------------------------------------------
# F1 jobs present in output
# ---------------------------------------------------------------------------

@test "F1 runs all 8 jobs" {
  python3 - <<'EOF'
import sys; sys.path.insert(0, 'scripts')
from lib.context_update import f1 as f1_runner
files = [{"path": "test.md", "content": "# Test", "age_days": 10, "conf_level": 1}]
result = f1_runner.run_all(files)
assert len(result["jobs"]) == 8, f"Expected 8 jobs, got {len(result['jobs'])}"
EOF
}

# ---------------------------------------------------------------------------
# F3 artefacts
# ---------------------------------------------------------------------------

@test "F3 produces F3_plan.md and F3_plan.json when not dry-run" {
  tmpdir=$(mktemp -d)
  python3 - "$tmpdir" <<'EOF'
import sys, json
from pathlib import Path
sys.path.insert(0, 'scripts')
from lib.context_update import f3 as f3_consolidator

store_dir = Path(sys.argv[1])
f1 = {"findings": [], "summary": {"total_files": 1}, "jobs": {}}
f2 = {"findings": [], "summary": {}}
f3_consolidator.consolidate(f1, f2, run_id="bats-test", store_dir=store_dir)
assert (store_dir / "F3_plan.md").exists()
assert (store_dir / "F3_plan.json").exists()
assert (store_dir / "consolidated.json").exists()
print("OK")
EOF
  rm -rf "$tmpdir"
}
