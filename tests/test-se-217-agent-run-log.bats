#!/usr/bin/env bats
# test-se-217-agent-run-log.bats — SE-217 Slice 1: Agent Run Log
# Ref: docs/propuestas/SE-217-autoresearch-patterns.md
# Coverage target: ≥15 tests, score ≥80

SCRIPT="scripts/agent-run-log.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR_TEST="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  export AGENT_RUN_LOG_DIR="${TMPDIR_TEST}/output"
  export AGENT_RUN_LOG_FILE="${TMPDIR_TEST}/output/agent-run-log-test.tsv"
  mkdir -p "${TMPDIR_TEST}/output"
}

teardown() {
  rm -rf "${TMPDIR_TEST}" 2>/dev/null || true
}

# ── 1. Script existe y es ejecutable ────────────────────────────────────────
@test "SE-217: script exists" {
  [ -f "$SCRIPT" ]
}

@test "SE-217: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── 2. set -uo pipefail presente ────────────────────────────────────────────
@test "SE-217: set -uo pipefail present in script" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ── 3. TSV header correcto ───────────────────────────────────────────────────
@test "SE-217: TSV has correct header after first start" {
  bash "$SCRIPT" start \
    --run-id "run-001" \
    --task "fix-auth" \
    --hypothesis "Auth validator missing"
  local header
  header=$(head -1 "$AGENT_RUN_LOG_FILE")
  [[ "$header" == "run_id	task	status	score	metric	commit	elapsed_s	hypothesis	description	ts" ]]
}

# ── 4. start crea entrada con status=pending ─────────────────────────────────
@test "SE-217: start creates entry with status=pending" {
  bash "$SCRIPT" start \
    --run-id "run-001" \
    --task "fix-auth" \
    --hypothesis "Auth validator missing"
  grep -q "pending" "$AGENT_RUN_LOG_FILE"
  grep -q "run-001" "$AGENT_RUN_LOG_FILE"
  grep -q "fix-auth" "$AGENT_RUN_LOG_FILE"
}

# ── 5. keep actualiza status a keep con commit y score ───────────────────────
@test "SE-217: keep updates status to keep with commit and score" {
  bash "$SCRIPT" start \
    --run-id "run-002" \
    --task "add-validator" \
    --hypothesis "NationalId validator missing"
  bash "$SCRIPT" keep \
    --run-id "run-002" \
    --task "add-validator" \
    --commit "abc1234" \
    --score 87 \
    --metric "quality-score" \
    --description "14/14 tests pass"
  grep -q "keep" "$AGENT_RUN_LOG_FILE"
  grep -q "abc1234" "$AGENT_RUN_LOG_FILE"
  grep -q "87" "$AGENT_RUN_LOG_FILE"
}

# ── 6. discard actualiza status a discard con reason ─────────────────────────
@test "SE-217: discard updates status to discard with reason" {
  bash "$SCRIPT" start \
    --run-id "run-003" \
    --task "remove-cache" \
    --hypothesis "Cache degrading latency"
  bash "$SCRIPT" discard \
    --run-id "run-003" \
    --task "remove-cache" \
    --reason "Tests pass but score dropped"
  grep -q "discard" "$AGENT_RUN_LOG_FILE"
  grep -q "Tests pass but score dropped" "$AGENT_RUN_LOG_FILE"
}

# ── 7. crash actualiza status a crash con error ──────────────────────────────
@test "SE-217: crash updates status to crash with error" {
  bash "$SCRIPT" start \
    --run-id "run-004" \
    --task "refactor-handler" \
    --hypothesis "Auth handler needs refactor"
  bash "$SCRIPT" crash \
    --run-id "run-004" \
    --task "refactor-handler" \
    --error "build FAILED: type not found"
  grep -q "crash" "$AGENT_RUN_LOG_FILE"
  grep -q "build FAILED" "$AGENT_RUN_LOG_FILE"
}

# ── 8. summary muestra keep_rate y conteos ───────────────────────────────────
@test "SE-217: summary shows keep_rate and counts" {
  bash "$SCRIPT" start --run-id "run-sum" --task "task-a" --hypothesis "H1"
  bash "$SCRIPT" keep  --run-id "run-sum" --task "task-a" --commit "c1" --score 90 --metric "ci" --description "ok"
  bash "$SCRIPT" start --run-id "run-sum" --task "task-b" --hypothesis "H2"
  bash "$SCRIPT" discard --run-id "run-sum" --task "task-b" --reason "nope"
  bash "$SCRIPT" start --run-id "run-sum" --task "task-c" --hypothesis "H3"
  bash "$SCRIPT" crash  --run-id "run-sum" --task "task-c" --error "err"

  run bash "$SCRIPT" summary --run-id "run-sum"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total:"*"3"* ]]
  [[ "$output" == *"keep:"*"1"* ]]
  [[ "$output" == *"discard:"*"1"* ]]
  [[ "$output" == *"crash:"*"1"* ]]
  [[ "$output" == *"keep_rate:"*"33%"* ]]
}

# ── 9. list muestra run_ids ──────────────────────────────────────────────────
@test "SE-217: list shows run_ids" {
  bash "$SCRIPT" start --run-id "run-list-a" --task "task-1" --hypothesis "H1"
  bash "$SCRIPT" start --run-id "run-list-b" --task "task-2" --hypothesis "H2"
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"run-list-a"* ]]
  [[ "$output" == *"run-list-b"* ]]
}

# ── 10. TSV parseable con python3 csv ────────────────────────────────────────
@test "SE-217: TSV is parseable with python3 csv.DictReader" {
  bash "$SCRIPT" start --run-id "run-py" --task "py-task" --hypothesis "Python test"
  bash "$SCRIPT" keep  --run-id "run-py" --task "py-task" --commit "def5678" \
    --score 95 --metric "test-coverage" --description "All good"
  run python3 -c "
import csv, sys
rows = list(csv.DictReader(open('${AGENT_RUN_LOG_FILE}'), delimiter='\t'))
assert len(rows) >= 1
assert 'run_id' in rows[0]
assert 'status' in rows[0]
print('ok: ' + str(len(rows)) + ' rows')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok:"* ]]
}

# ── 11. Escritura atómica: dos start simultáneos no corrompen ─────────────────
@test "SE-217: concurrent start calls do not corrupt TSV (AC-07)" {
  # Fire 10 concurrent starts
  for i in $(seq 1 10); do
    bash "$SCRIPT" start \
      --run-id "run-concurrent" \
      --task "task-${i}" \
      --hypothesis "Hypothesis ${i}" &
  done
  wait

  # Header must appear exactly once
  local header_count
  header_count=$(grep -c "^run_id	task	status" "$AGENT_RUN_LOG_FILE" || true)
  [ "$header_count" -eq 1 ]

  # All 10 task entries must be present (pending)
  local pending_count
  pending_count=$(grep -c "run-concurrent" "$AGENT_RUN_LOG_FILE" || true)
  [ "$pending_count" -eq 10 ]
}

# ── 12. --run-id inexistente en keep → error claro ───────────────────────────
@test "SE-217: keep with nonexistent run-id gives clear error (AC-08)" {
  run bash "$SCRIPT" keep \
    --run-id "nonexistent-xyz" \
    --task "no-such-task" \
    --commit "000" --score 0 --metric "ci" --description "nope"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$stderr" == *"ERROR"* ]] || \
    run bash "$SCRIPT" keep --run-id "nonexistent-xyz" --task "no-such-task" --commit "000" --score 0 --metric "ci" --description "nope" 2>&1
  [[ "$output" == *"ERROR"* || "$output" == *"No pending"* ]]
}

# ── 13. start sin --hypothesis → falla con mensaje ───────────────────────────
@test "SE-217: start without --hypothesis fails with message" {
  run bash "$SCRIPT" start --run-id "r1" --task "t1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hypothesis"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ── 14. start sin --task → falla con mensaje ─────────────────────────────────
@test "SE-217: start without --task fails with message" {
  run bash "$SCRIPT" start --run-id "r1" --hypothesis "H1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"task"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ── 15. elapsed_s positivo cuando hay start previo ───────────────────────────
@test "SE-217: elapsed_s is non-negative after keep with prior start" {
  bash "$SCRIPT" start --run-id "run-elapsed" --task "t-elapsed" --hypothesis "timing test"
  sleep 1
  bash "$SCRIPT" keep \
    --run-id "run-elapsed" \
    --task "t-elapsed" \
    --commit "e1a2b3" \
    --score 80 \
    --metric "quality-score" \
    --description "elapsed check"

  # Extract elapsed_s column (7th field)
  local elapsed
  elapsed=$(grep "run-elapsed" "$AGENT_RUN_LOG_FILE" | grep "keep" | awk -F'\t' '{print $7}')
  # Must be a non-negative integer
  [[ "$elapsed" =~ ^[0-9]+$ ]]
  [ "$elapsed" -ge 0 ]
}

# ── 16. output/ creado automáticamente si no existe ──────────────────────────
@test "SE-217: output dir created automatically if missing" {
  rm -rf "${TMPDIR_TEST}/output"
  bash "$SCRIPT" start --run-id "run-mkdir" --task "t-mkdir" --hypothesis "dir creation"
  [ -d "${TMPDIR_TEST}/output" ]
}

# ── 17. bash -n syntax check ─────────────────────────────────────────────────
@test "SE-217: bash -n syntax check passes" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 18. Ref SE-217 en el header del script ───────────────────────────────────
@test "SE-217: SE-217 spec reference present in script header" {
  grep -q "SE-217" "$SCRIPT"
}
