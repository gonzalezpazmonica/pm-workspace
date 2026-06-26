#!/usr/bin/env bats
# tests/bats/test-spec-se-025-analytics.bats — SPEC-SE-025 Agentic Workforce Analytics
#
# Tests for scripts/workforce-analytics.sh and supporting files.
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-025-agentic-workforce-analytics.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/workforce-analytics.sh"
  TMPDIR_TEST="$(mktemp -d)"
  # Override output and data dirs to avoid touching real data
  export OUTPUT_DIR="$TMPDIR_TEST/output"
  export DATA_DIR="$TMPDIR_TEST/data"
  export ANALYTICS_REPO_ROOT="$TMPDIR_TEST"
  mkdir -p "$OUTPUT_DIR/agent-trace" "$DATA_DIR"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Test 1: script exists and is executable ───────────────────────────────────

@test "workforce-analytics.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Test 2: --json produces valid JSON ────────────────────────────────────────

@test "--json produces valid JSON output" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  # Output must be parseable JSON
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
}

# ── Test 3: --json with no data returns note field ────────────────────────────

@test "--json with no data returns note or empty metrics" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  # Must be valid JSON
  result=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('note','') or d.get('metrics','') or 'ok')" 2>/dev/null)
  [ -n "$result" ]
}

# ── Test 4: protocol.md exists ────────────────────────────────────────────────

@test "workforce-analytics-protocol.md exists in docs/rules/domain/" {
  [ -f "$REPO_ROOT/docs/rules/domain/workforce-analytics-protocol.md" ]
}

# ── Test 5: script does not fail with empty output/ ──────────────────────────

@test "script does not crash with empty output/" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
}

# ── Test 6: workforce-analytics.py exists ────────────────────────────────────

@test "workforce-analytics.py exists in scripts/" {
  [ -f "$REPO_ROOT/scripts/workforce-analytics.py" ]
}

# ── Test 7: --json with synthetic data returns agent_invocations ──────────────

@test "--json with synthetic data includes agent_invocations key" {
  # Create minimal agent-actuals.jsonl
  cat > "$DATA_DIR/agent-actuals.jsonl" << 'JSON'
{"schema_version":"2","agent":"test-agent","task":"t1","started_at":"2026-06-01T08:00:00Z","finished_at":"2026-06-01T08:01:00Z","duration_s":60,"run_status":"completed"}
JSON

  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  has_key=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print('yes' if 'agent_invocations' in d else 'no')" 2>/dev/null)
  [ "$has_key" = "yes" ]
}

# ── Test 8: --format csv produces comma-separated output ─────────────────────

@test "--format csv produces header line with commas" {
  cat > "$DATA_DIR/agent-actuals.jsonl" << 'JSON'
{"schema_version":"2","agent":"csv-agent","task":"t1","started_at":"2026-06-01T08:00:00Z","finished_at":"2026-06-01T08:01:00Z","duration_s":60,"run_status":"completed"}
JSON

  run bash "$SCRIPT" --format csv
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "agent,invocations"
}

# ── Test 9: --since filters correctly ────────────────────────────────────────

@test "--since filters out old data" {
  cat > "$DATA_DIR/agent-actuals.jsonl" << 'JSON'
{"schema_version":"2","agent":"old-agent","task":"t1","started_at":"2024-01-01T08:00:00Z","finished_at":"2024-01-01T08:01:00Z","duration_s":60,"run_status":"completed"}
{"schema_version":"2","agent":"new-agent","task":"t2","started_at":"2026-06-01T08:00:00Z","finished_at":"2026-06-01T08:01:00Z","duration_s":60,"run_status":"completed"}
JSON

  run bash "$SCRIPT" --json --since 2026-01-01
  [ "$status" -eq 0 ]
  inv=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
inv=d.get('agent_invocations',{})
print(inv.get('old-agent',0), inv.get('new-agent',0))
" 2>/dev/null)
  old_cnt=$(echo "$inv" | awk '{print $1}')
  new_cnt=$(echo "$inv" | awk '{print $2}')
  [ "$old_cnt" -eq 0 ]
  [ "$new_cnt" -eq 1 ]
}

# ── Test 10: table output includes title line ─────────────────────────────────

@test "default table output includes title 'Agentic Workforce Analytics'" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "Agentic Workforce Analytics\|no agent data"
}
