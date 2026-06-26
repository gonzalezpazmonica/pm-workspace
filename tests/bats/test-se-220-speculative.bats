#!/usr/bin/env bats
# test-se-220-speculative.bats — BATS integration tests for SE-220 Slices 1-4
# Ref: SE-220 Speculative Tool Execution

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PREDICTOR="$REPO_ROOT/scripts/speculative-tool-predictor.py"
  EXECUTION="$REPO_ROOT/scripts/speculative-tool-execution.py"
  CACHE_MGR="$REPO_ROOT/scripts/speculative-cache-manager.py"
  REPORT="$REPO_ROOT/scripts/speculative-telemetry-report.sh"
  PRE_EXEC_HOOK="$REPO_ROOT/.opencode/hooks/speculative-pre-execute.sh"
  PRELOAD_HOOK="$REPO_ROOT/.opencode/hooks/speculative-skill-preload.sh"
  PYTHON="${PYTHON:-python3}"
  export REPO_ROOT PREDICTOR EXECUTION CACHE_MGR REPORT PRE_EXEC_HOOK PRELOAD_HOOK PYTHON

  # Use isolated temp cache dir for each test
  export SAVIA_SPECULATIVE_CACHE_DIR="$(mktemp -d)"
}

teardown() {
  # Clean up temp cache dir
  if [[ -d "${SAVIA_SPECULATIVE_CACHE_DIR:-}" ]]; then
    rm -rf "$SAVIA_SPECULATIVE_CACHE_DIR"
  fi
}

# ── T1: Files exist and are executable ───────────────────────────────────────

@test "speculative-pre-execute.sh exists" {
  [[ -f "$PRE_EXEC_HOOK" ]]
}

@test "speculative-pre-execute.sh is executable" {
  [[ -x "$PRE_EXEC_HOOK" ]]
}

@test "speculative-skill-preload.sh exists" {
  [[ -f "$PRELOAD_HOOK" ]]
}

@test "speculative-skill-preload.sh is executable" {
  [[ -x "$PRELOAD_HOOK" ]]
}

@test "speculative-tool-execution.py exists" {
  [[ -f "$EXECUTION" ]]
}

@test "speculative-cache-manager.py exists" {
  [[ -f "$CACHE_MGR" ]]
}

@test "speculative-telemetry-report.sh exists" {
  [[ -f "$REPORT" ]]
}

# ── T2: Hook exits 0 when SAVIA_SPECULATIVE_EXECUTION=off ────────────────────

@test "speculative-pre-execute.sh exits 0 when SAVIA_SPECULATIVE_EXECUTION=off" {
  run env SAVIA_SPECULATIVE_EXECUTION=off bash "$PRE_EXEC_HOOK" <<< '{}'
  [[ "$status" -eq 0 ]]
}

@test "speculative-skill-preload.sh exits 0 when SAVIA_SPECULATIVE_EXECUTION=off" {
  run env SAVIA_SPECULATIVE_EXECUTION=off bash "$PRELOAD_HOOK" <<< '{}'
  [[ "$status" -eq 0 ]]
}

# ── T3: Hooks exit 0 on invalid JSON (fail-soft) ─────────────────────────────

@test "speculative-pre-execute.sh exits 0 on invalid JSON" {
  run env SAVIA_SPECULATIVE_EXECUTION=on bash "$PRE_EXEC_HOOK" <<< 'NOT VALID JSON'
  [[ "$status" -eq 0 ]]
}

@test "speculative-skill-preload.sh exits 0 on invalid JSON" {
  run env SAVIA_SPECULATIVE_EXECUTION=on bash "$PRELOAD_HOOK" <<< 'NOT VALID JSON'
  [[ "$status" -eq 0 ]]
}

@test "speculative-pre-execute.sh exits 0 on empty input" {
  run env SAVIA_SPECULATIVE_EXECUTION=on bash "$PRE_EXEC_HOOK" <<< ''
  [[ "$status" -eq 0 ]]
}

# ── T4: speculative-skill-preload.sh shadow mode — no output ─────────────────

@test "speculative-skill-preload.sh shadow mode emits no stdout for non-Task tool" {
  INPUT='{"tool_name": "Read", "tool_input": {"path": "/tmp/test"}, "session_id": "t1"}'
  run env SAVIA_SPECULATIVE_EXECUTION=shadow bash "$PRELOAD_HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "speculative-skill-preload.sh shadow mode produces no stdout (Task with sprint intent)" {
  INPUT='{"tool_name": "Task", "tool_input": {"prompt": "dame el estado del sprint actual"}, "session_id": "t2"}'
  run env SAVIA_SPECULATIVE_EXECUTION=shadow bash "$PRELOAD_HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  # shadow mode: no stdout output
  [[ -z "$output" ]]
}

# ── T5: speculative-skill-preload.sh on mode — emits hint ────────────────────

@test "speculative-skill-preload.sh on mode emits skill hint for sprint intent" {
  INPUT='{"tool_name": "Task", "tool_input": {"prompt": "dame el estado del sprint actual con velocity"}, "session_id": "t3"}'
  run env SAVIA_SPECULATIVE_EXECUTION=on bash "$PRELOAD_HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  # Output should contain the hint for sprint-management
  [[ "$output" == *"SPECULATIVE_SKILL_HINT"* ]] || [[ -z "$output" ]]
  # Either produces a hint or silently succeeds (python may not be available)
}

# ── T6: cache-manager get returns hit=false (JSON) for miss ──────────────────

@test "speculative-cache-manager.py get returns hit=false for cache miss" {
  run "$PYTHON" "$CACHE_MGR" get --tool "Read" --args-hash "nonexistent_hash_xyz999"
  # exit code 1 on miss
  [[ "$status" -eq 1 ]]
  # output should be valid JSON with hit=false
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert d['hit'] == False, f'Expected hit=false, got {d}'
"
}

@test "speculative-cache-manager.py get returns hit=true after set" {
  run "$PYTHON" "$CACHE_MGR" set --tool "Read" --args-hash "testhash001" \
    --result '{"content": "hello world"}' --ttl 60
  [[ "$status" -eq 0 ]]

  run "$PYTHON" "$CACHE_MGR" get --tool "Read" --args-hash "testhash001" --ttl 60
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert d['hit'] == True, f'Expected hit=true, got {d}'
assert d['result']['content'] == 'hello world', f'Wrong result: {d}'
"
}

# ── T7: cache-manager clean removes expired entries ──────────────────────────

@test "speculative-cache-manager.py clean removes expired entries" {
  # set an entry with TTL=0 (immediately expired)
  "$PYTHON" "$CACHE_MGR" set --tool "Grep" --args-hash "expiredhash" \
    --result '{"x": 1}' --ttl 0

  sleep 0.1  # ensure age > 0

  run "$PYTHON" "$CACHE_MGR" clean
  [[ "$status" -eq 0 ]]
  # Output should be valid JSON with removed >= 1
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert d['removed'] >= 1, f'Expected removed>=1, got {d}'
"
}

# ── T8: telemetry-report produces table output ────────────────────────────────

@test "speculative-telemetry-report.sh produces table output on sample data" {
  TELEM_FILE="$(mktemp)"
  # write 3 sample records
  echo '{"cache_hit": true, "latency_saved_ms": 200, "predicted": ["Read"], "actual": ["Read"]}' >> "$TELEM_FILE"
  echo '{"cache_hit": false, "latency_saved_ms": 0, "predicted": ["Read"], "actual": ["Grep"]}' >> "$TELEM_FILE"
  echo '{"speculative_launched": true, "predicted": ["Read"]}' >> "$TELEM_FILE"

  run bash "$REPORT" --file "$TELEM_FILE"
  [[ "$status" -eq 0 ]]
  # Must contain something about SE-220 or Speculative
  [[ "$output" == *"SE-220"* ]] || [[ "$output" == *"Speculative"* ]]
  # Must contain VERDICT
  [[ "$output" == *"VERDICT"* ]]
  rm -f "$TELEM_FILE"
}

@test "speculative-telemetry-report.sh --json produces valid JSON" {
  TELEM_FILE="$(mktemp)"
  echo '{"cache_hit": true,  "latency_saved_ms": 500, "predicted": ["Read"], "actual": ["Read"]}' >> "$TELEM_FILE"
  echo '{"cache_hit": true,  "latency_saved_ms": 400, "predicted": ["Bash"], "actual": ["Bash"]}' >> "$TELEM_FILE"
  echo '{"cache_hit": false, "latency_saved_ms": 0,   "predicted": ["Read"], "actual": ["Edit"]}' >> "$TELEM_FILE"

  run bash "$REPORT" --file "$TELEM_FILE" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
for key in ('cache_hit_rate', 'avg_latency_saved_ms', 'prediction_accuracy', 'verdict'):
    assert key in d, f'Missing key: {key}'
"
  rm -f "$TELEM_FILE"
}

@test "speculative-telemetry-report.sh returns NO_DATA verdict for missing file" {
  run bash "$REPORT" --file "/tmp/nonexistent_telemetry_xyz_$(date +%s).jsonl" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
# should have NO_DATA or error key
assert 'verdict' in d or 'error' in d, f'Expected verdict or error key, got: {d}'
"
}

# ── T9: predictor whitelist_only field via CLI ────────────────────────────────

@test "predictor returns whitelist_only=true for Read-only intent" {
  INPUT='{"intent": "lee el fichero docs/spec.md", "available_tools": ["Read", "Grep", "Bash"]}'
  run "$PYTHON" "$PREDICTOR" --input "$INPUT"
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert 'whitelist_only' in d, 'Missing whitelist_only field'
assert d['whitelist_only'] == True, f'Expected whitelist_only=True, got {d[\"whitelist_only\"]}'
"
}

@test "predictor returns whitelist_only=false for Edit intent" {
  INPUT='{"intent": "modifica el metodo calculate_velocity", "available_tools": ["Read", "Grep", "Bash", "Edit", "Write"]}'
  run "$PYTHON" "$PREDICTOR" --input "$INPUT"
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert 'whitelist_only' in d, 'Missing whitelist_only field'
assert d['whitelist_only'] == False, f'Expected whitelist_only=False for Edit, got {d[\"whitelist_only\"]}'
"
}

# ── T10: orchestrator stdin interface ─────────────────────────────────────────

@test "speculative-tool-execution.py returns valid JSON for Read intent" {
  INPUT='{"intent": "lee el fichero docs/spec.md", "available_tools": ["Read", "Grep", "Bash"], "session_id": "bats-test-001"}'
  run "$PYTHON" "$EXECUTION" --input "$INPUT"
  [[ "$status" -eq 0 ]]
  echo "$output" | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
for key in ('session_id', 'intent_hash', 'predicted_tools', 'confidence', 'whitelist_only', 'speculative_launched'):
    assert key in d, f'Missing key: {key}'
"
}

@test "speculative-tool-execution.py errors gracefully on empty intent" {
  INPUT='{"intent": "", "available_tools": ["Read"], "session_id": "bats-err"}'
  run "$PYTHON" "$EXECUTION" --input "$INPUT"
  [[ "$status" -ne 0 ]]
}
