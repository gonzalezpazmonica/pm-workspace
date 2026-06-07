#!/usr/bin/env bats
# tests/test-se-205-orchestration-protocol.bats
# SE-205: Orchestration Protocol tipado (patron Orca)
# Ref: docs/rules/domain/orchestration-protocol.md
# Ref: output/research/orca-savia-20260607.md §7.1

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/orchestration-protocol.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export SAVIA_ORCA_DB_DIR="${TMP_DIR}/orchestration"
  mkdir -p "$SAVIA_ORCA_DB_DIR"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}

# ── 1. Script existe y es ejecutable ─────────────────────────────────────────
@test "script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ── 2. set -uo pipefail presente ──────────────────────────────────────────────
@test "script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

# ── 3. SE-205 referenciado en el script ──────────────────────────────────────
@test "SE-205 is referenced in the script" {
  grep -q 'SE-205' "$SCRIPT"
}

# ── 4. task-create genera ID unico ───────────────────────────────────────────
@test "task-create generates unique IDs" {
  local id1 id2
  id1=$(bash "$SCRIPT" task-create --spec "Task one")
  id2=$(bash "$SCRIPT" task-create --spec "Task two")
  [[ -n "$id1" ]]
  [[ -n "$id2" ]]
  [[ "$id1" != "$id2" ]]
}

# ── 5. task-create crea fichero JSON ─────────────────────────────────────────
@test "task-create creates JSON file in storage dir" {
  local id
  id=$(bash "$SCRIPT" task-create --spec "Test spec")
  [[ -f "${SAVIA_ORCA_DB_DIR}/task-${id}.json" ]]
}

# ── 6. task-list funciona sin crash ──────────────────────────────────────────
@test "task-list runs without crash on empty store" {
  run bash "$SCRIPT" task-list
  [[ "$status" -eq 0 ]]
}

# ── 7. task-list muestra tasks creadas ───────────────────────────────────────
@test "task-list shows created tasks" {
  bash "$SCRIPT" task-create --spec "Visible task" > /dev/null
  run bash "$SCRIPT" task-list
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "pending" ]]
}

# ── 8. task-update cambia status ─────────────────────────────────────────────
@test "task-update changes task status" {
  local id
  id=$(bash "$SCRIPT" task-create --spec "Update me")
  bash "$SCRIPT" task-update --id "$id" --status "completed"
  run bash "$SCRIPT" task-list --status completed
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "completed" ]]
}

# ── 9. task-list filtra por status ───────────────────────────────────────────
@test "task-list --status filter returns only matching tasks" {
  local id1 id2
  id1=$(bash "$SCRIPT" task-create --spec "Task pending")
  id2=$(bash "$SCRIPT" task-create --spec "Task to complete")
  bash "$SCRIPT" task-update --id "$id2" --status "completed" > /dev/null

  run bash "$SCRIPT" task-list --status pending
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "$id1" ]]
  [[ ! "${output}" =~ "$id2" ]]
}

# ── 10. dispatch genera dispatch_id ──────────────────────────────────────────
@test "dispatch returns a dispatch_id" {
  local id dispatch_id
  id=$(bash "$SCRIPT" task-create --spec "Dispatch me")
  dispatch_id=$(bash "$SCRIPT" dispatch --task "$id" --to "test-agent")
  [[ -n "$dispatch_id" ]]
  [[ "$dispatch_id" =~ ^d ]]
}

# ── 11. dispatch actualiza estado a dispatched ───────────────────────────────
@test "dispatch sets task status to dispatched" {
  local id
  id=$(bash "$SCRIPT" task-create --spec "Dispatchable")
  bash "$SCRIPT" dispatch --task "$id" --to "some-agent" > /dev/null
  run bash "$SCRIPT" task-list --status dispatched
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "dispatched" ]]
}

# ── 12. send worker_done crea fichero JSON de mensaje ────────────────────────
@test "send worker_done creates a message JSON file" {
  local id dispatch_id msg_id
  id=$(bash "$SCRIPT" task-create --spec "Work to do")
  dispatch_id=$(bash "$SCRIPT" dispatch --task "$id" --to "worker-agent")
  msg_id=$(bash "$SCRIPT" send \
    --type worker_done \
    --task "$id" \
    --dispatch "$dispatch_id" \
    --summary "Did it. Found nothing. Nothing pending.")
  [[ -n "$msg_id" ]]
  [[ -f "${SAVIA_ORCA_DB_DIR}/msg-${msg_id}.json" ]]
}

# ── 13. send escalation crea mensaje de tipo escalation ──────────────────────
@test "send escalation creates escalation message" {
  local id dispatch_id msg_id
  id=$(bash "$SCRIPT" task-create --spec "Escalatable task")
  dispatch_id=$(bash "$SCRIPT" dispatch --task "$id" --to "blocked-agent")
  msg_id=$(bash "$SCRIPT" send \
    --type escalation \
    --task "$id" \
    --dispatch "$dispatch_id" \
    --summary "Blocked. Need human decision. Cannot proceed.")
  local msg_file="${SAVIA_ORCA_DB_DIR}/msg-${msg_id}.json"
  [[ -f "$msg_file" ]]
  grep -q '"type".*"escalation"' "$msg_file"
}

# ── 14. check retorna mensajes pendientes ────────────────────────────────────
@test "check returns unread messages" {
  local id dispatch_id
  id=$(bash "$SCRIPT" task-create --spec "Check this")
  dispatch_id=$(bash "$SCRIPT" dispatch --task "$id" --to "check-agent")
  bash "$SCRIPT" send \
    --type worker_done \
    --task "$id" \
    --dispatch "$dispatch_id" \
    --summary "Done. All good. No pending." > /dev/null

  run bash "$SCRIPT" check
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "worker_done" ]]
}

# ── 15. status muestra resumen de orchestration ──────────────────────────────
@test "status shows orchestration summary" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "SE-205" ]]
  [[ "${output}" =~ "Tasks total" ]]
}

# ── 16. task-create con --deps registra dependencias ─────────────────────────
@test "task-create with --deps records dependencies in JSON" {
  local id_dep id
  id_dep=$(bash "$SCRIPT" task-create --spec "Dependency task")
  id=$(bash "$SCRIPT" task-create --spec "Dependent task" --deps "$id_dep")
  local task_file="${SAVIA_ORCA_DB_DIR}/task-${id}.json"
  [[ -f "$task_file" ]]
  grep -q "$id_dep" "$task_file"
}

# ── 17. Circuit breaker: 3 fallos -> task=failed ─────────────────────────────
@test "circuit breaker: 3 failed worker_done messages set task to failed" {
  local id dispatch_id
  id=$(bash "$SCRIPT" task-create --spec "Will fail 3 times")
  dispatch_id=$(bash "$SCRIPT" dispatch --task "$id" --to "flaky-agent")

  # First failure — should NOT trigger circuit breaker yet
  bash "$SCRIPT" send \
    --type worker_done --task "$id" --dispatch "$dispatch_id" \
    --summary "Failed once. Error X. Retry pending." \
    --status failed > /dev/null

  # Second failure
  bash "$SCRIPT" send \
    --type worker_done --task "$id" --dispatch "$dispatch_id" \
    --summary "Failed twice. Error X. Retry pending." \
    --status failed > /dev/null

  # Third failure — circuit breaker fires
  run bash "$SCRIPT" send \
    --type worker_done --task "$id" --dispatch "$dispatch_id" \
    --summary "Failed three times. Error X. No more retries." \
    --status failed
  [[ "$status" -eq 0 ]]
  [[ "${output}" =~ "CIRCUIT_BREAKER" ]]

  # Verify task is now failed
  run bash "$SCRIPT" task-list --status failed
  [[ "${output}" =~ "failed" ]]
}

# ── 18. docs/rules/domain/orchestration-protocol.md existe ───────────────────
@test "protocol doc exists" {
  local doc
  doc="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/docs/rules/domain/orchestration-protocol.md"
  [[ -f "$doc" ]]
}

# ── 19. agent-notes-protocol.md menciona SE-205 ──────────────────────────────
@test "agent-notes-protocol.md references SE-205" {
  local doc
  doc="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/docs/agent-notes-protocol.md"
  [[ -f "$doc" ]]
  grep -q 'SE-205' "$doc"
}

# ── 20. edge: ID inexistente manejado con error ──────────────────────────────
@test "edge: unknown task ID returns error" {
  run bash "$SCRIPT" task-update --id "nonexistent" --status "completed"
  [[ "$status" -ne 0 ]]
  [[ "${output}" =~ "not found" ]] || [[ "${lines[*]}" =~ "not found" ]]
}

# ── 21. edge: --wait con timeout no cuelga ───────────────────────────────────
@test "edge: check --wait exits within timeout when no messages present" {
  local start elapsed
  start=$(date +%s)
  run bash "$SCRIPT" check --wait --timeout 3
  elapsed=$(( $(date +%s) - start ))
  [[ "$status" -eq 0 ]]
  # Must complete in under 10s (timeout is 3s + overhead)
  [[ $elapsed -lt 10 ]]
}
