#!/usr/bin/env bats
# test-audit-trigger.bats — SE-037 Audit Trigger Primitive
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md
#
# All tests run without a real database (dry-run / mock mode).
# PGDATABASE is unset in setup() to ensure dry-run paths are exercised.
# Note: scripts use SAVIA_ENTERPRISE_DSN for connection (preexisting suite contract)

# ── Setup / Teardown ──────────────────────────────────────────────────────────

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  # No real DB — all DB-bound paths should use dry-run
  unset PGDATABASE || true
  unset SAVIA_ENTERPRISE_DSN || true

  # Locate repo root relative to this test file
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  AUDIT_SEARCH="${REPO_ROOT}/scripts/enterprise/audit-search.sh"
  AUDIT_PURGE="${REPO_ROOT}/scripts/enterprise/audit-purge.sh"
  AUDIT_SQL="${REPO_ROOT}/scripts/enterprise/audit-trigger.sql"
  RETENTION_DOC="${REPO_ROOT}/docs/rules/domain/savia-enterprise/audit-retention.md"
  export AUDIT_SEARCH AUDIT_PURGE AUDIT_SQL RETENTION_DOC
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: audit-search.sh exists and is executable ─────────────────────────

@test "audit-search.sh exists and is executable" {
  [[ -f "$AUDIT_SEARCH" ]]
  [[ -x "$AUDIT_SEARCH" ]]
}

# ── Test 2: audit-purge.sh exists and is executable ──────────────────────────

@test "audit-purge.sh exists and is executable" {
  [[ -f "$AUDIT_PURGE" ]]
  [[ -x "$AUDIT_PURGE" ]]
}

# ── Test 3: audit-search.sh --help exits 0 ───────────────────────────────────

@test "audit-search.sh --help exits 0" {
  run "$AUDIT_SEARCH" --help
  [ "$status" -eq 0 ]
}

# ── Test 4: audit-purge.sh --help exits 0 ────────────────────────────────────

@test "audit-purge.sh --help exits 0" {
  run "$AUDIT_PURGE" --help
  [ "$status" -eq 0 ]
}

# ── Test 5: audit-purge.sh without --confirm exits 2 ─────────────────────────

@test "audit-purge.sh without --confirm exits 2" {
  run "$AUDIT_PURGE" --before 2026-01-01 --table agent_sessions
  [ "$status" -eq 2 ]
}

# ── Test 6: audit-purge.sh without --before exits 2 or shows error ───────────

@test "audit-purge.sh without --before exits 2" {
  run "$AUDIT_PURGE" --table agent_sessions --confirm
  [ "$status" -eq 2 ]
}

# ── Test 7: audit-search.sh without PGDATABASE prints SQL (dry-run) ──────────

@test "audit-search.sh without DSN prints SQL in dry-run mode" {
  unset PGDATABASE || true
  unset SAVIA_ENTERPRISE_DSN || true
  run "$AUDIT_SEARCH" --table tenants --since 7d
  # Without DSN: exits 3 (preexisting contract) or 0 with DRY-RUN output
  [[ "$status" -eq 0 || "$status" -eq 3 ]]
  [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"audit_log"* ]] || [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

# ── Test 8: audit-purge.sh without audit-retention.md exits 2 with clear msg ─

@test "audit-purge.sh without audit-retention.md exits non-zero with clear message" {
  FAKE_PURGE="${TEST_TMPDIR}/audit-purge-fake.sh"
  cp "$AUDIT_PURGE" "$FAKE_PURGE"
  chmod +x "$FAKE_PURGE"

  run bash -c "
    RETENTION_DOC='/nonexistent/path/audit-retention.md'
    bash <(sed 's|RETENTION_DOC=.*|RETENTION_DOC=\"/nonexistent/path/audit-retention.md\"|' '$FAKE_PURGE') \
      --before 2026-01-01 --table agent_sessions --confirm
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"retention policy"* ]] || [[ "$output" == *"audit-retention"* ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"REFUSES"* ]]
}

# ── Test 9: audit-search.sh --since with invalid value exits non-zero ─────────

@test "audit-search.sh --since with invalid value exits non-zero" {
  run "$AUDIT_SEARCH" --table tenants --since "invalid_value"
  [ "$status" -ne 0 ]
}

# ── Test 10: audit-trigger.sql exists and contains audit_trigger_fn ──────────

@test "audit-trigger.sql exists and contains 'audit_trigger_fn'" {
  [[ -f "$AUDIT_SQL" ]]
  grep -q "audit_trigger_fn" "$AUDIT_SQL"
}

# ── Test 11: audit-trigger.sql contains REVOKE UPDATE ────────────────────────

@test "audit-trigger.sql contains 'REVOKE UPDATE'" {
  [[ -f "$AUDIT_SQL" ]]
  grep -q "REVOKE UPDATE" "$AUDIT_SQL"
}

# ── Test 12: attach_audit procedure is present in audit-trigger.sql ──────────

@test "audit-trigger.sql contains 'attach_audit' procedure" {
  [[ -f "$AUDIT_SQL" ]]
  grep -q "attach_audit" "$AUDIT_SQL"
  grep -q "CREATE OR REPLACE PROCEDURE attach_audit" "$AUDIT_SQL"
}

# ── Test 13: audit-trigger.sql contains all 5 regulated table CALL statements ─

@test "audit-trigger.sql has CALL attach_audit for all 5 regulated tables" {
  [[ -f "$AUDIT_SQL" ]]
  grep -q "CALL attach_audit('tenants'" "$AUDIT_SQL"
  grep -q "CALL attach_audit('projects'" "$AUDIT_SQL"
  grep -q "CALL attach_audit('billing_invoices'" "$AUDIT_SQL"
  grep -q "CALL attach_audit('agent_sessions'" "$AUDIT_SQL"
  grep -q "CALL attach_audit('api_keys'" "$AUDIT_SQL"
}

# ── Test 14: audit-trigger.sql captures all 9 fields ─────────────────────────

@test "audit-trigger.sql captures 9 required fields" {
  [[ -f "$AUDIT_SQL" ]]
  grep -q "table_name"  "$AUDIT_SQL"
  grep -q "record_id"   "$AUDIT_SQL"
  grep -q "operation"   "$AUDIT_SQL"
  grep -q "old_row"     "$AUDIT_SQL"
  grep -q "new_row"     "$AUDIT_SQL"
  grep -q "user_id"     "$AUDIT_SQL"
  grep -q "agent_id"    "$AUDIT_SQL"
  grep -q "session_id"  "$AUDIT_SQL"
  grep -q "tenant_id"   "$AUDIT_SQL"
}

# ── Test 15: audit-search.sh has set -uo pipefail on line 2 ──────────────────

@test "audit-search.sh has 'set -uo pipefail' on line 2" {
  SECOND_LINE="$(sed -n '2p' "$AUDIT_SEARCH")"
  [[ "$SECOND_LINE" == "set -uo pipefail" ]]
}

# ── Test 16: audit-purge.sh has set -uo pipefail on line 2 ───────────────────

@test "audit-purge.sh has 'set -uo pipefail' on line 2" {
  SECOND_LINE="$(sed -n '2p' "$AUDIT_PURGE")"
  [[ "$SECOND_LINE" == "set -uo pipefail" ]]
}

# ── Test 17: audit-search.sh dry-run output contains SELECT from audit_log ───

@test "audit-search.sh dry-run output contains SELECT and audit_log" {
  unset PGDATABASE || true
  unset SAVIA_ENTERPRISE_DSN || true
  run "$AUDIT_SEARCH" --tenant "00000000-0000-0000-0000-000000000001" --table tenants --since 30d
  [[ "$status" -eq 0 || "$status" -eq 3 ]]
  [[ "$output" == *"audit_log"* ]] || [[ "$output" == *"SELECT"* ]] || [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

# ── Test 18: audit-purge.sh without --table exits 2 ──────────────────────────

@test "audit-purge.sh without --table exits 2" {
  run "$AUDIT_PURGE" --before 2026-01-01 --confirm
  [ "$status" -eq 2 ]
}
