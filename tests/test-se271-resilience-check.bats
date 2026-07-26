#!/usr/bin/env bats
# SE-271 S7 — BATS tests for corporate-resilience-check.sh
# Ref: docs/propuestas/SE-271-savia-corporate.md
# Slice 7: Local resilience — corporate down never blocks

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="${REPO_ROOT}/scripts/corporate/corporate-resilience-check.sh"
  TMPDIR_S7="$(mktemp -d)"
  export TMPDIR_S7

  # Set up a minimal corporate directory for testing
  CORPORATE_DIR_TEST="${TMPDIR_S7}/.claude/corporate"
  mkdir -p "${CORPORATE_DIR_TEST}/adopted"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client/ingestion"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client/attestations"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client/audit-trail"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client/murallas"
  mkdir -p "${CORPORATE_DIR_TEST}/clients/test-client/capacities"

  echo "# SE-271 Corporate Model" > "${CORPORATE_DIR_TEST}/model.md"
  echo "{}" > "${CORPORATE_DIR_TEST}/clients/test-client/ingestion/inventory.json"
  echo "{}" > "${CORPORATE_DIR_TEST}/clients/test-client/confidentiality-map.json"
  echo '{"walls":[{"wall":"tenant","client":"test-client"}]}' > "${CORPORATE_DIR_TEST}/clients/test-client/murallas/separation-proof.json"
  echo '{"capacities":[{"name":"compliance","active":true}]}' > "${CORPORATE_DIR_TEST}/clients/test-client/capacities/capacities-scope.json"
  echo "{}" > "${CORPORATE_DIR_TEST}/clients/test-client/attestations/2026-07-01.json"
  echo "{}" > "${CORPORATE_DIR_TEST}/clients/test-client/audit-trail/access-log.jsonl"
  echo '{"ts":"2026-01-01T00:00:00Z","client":"test-client","action":"purge"}' > "${CORPORATE_DIR_TEST}/clients/test-client/purge-log.jsonl"

  touch "${CORPORATE_DIR_TEST}/.sync-state"
  date -u +%Y-%m-%dT%H:%M:%SZ > "${CORPORATE_DIR_TEST}/.sync-state"

  echo '{"entry":"test"}' > "${CORPORATE_DIR_TEST}/adopted/corp-entry-01.json"

  export CORPORATE_DIR_TEST
}

teardown() {
  rm -rf "$TMPDIR_S7"
}

# ── Structural tests ──────────────────────────────────────────────────────────

@test "SE271-S7-01: script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "SE271-S7-02: script passes bash -n (syntax check)" {
  bash -n "$SCRIPT"
}

@test "SE271-S7-03: script uses set -uo pipefail" {
  head -5 "$SCRIPT" | grep -qE "set -uo pipefail"
}

# ── State detection: up_to_date ───────────────────────────────────────────────

@test "SE271-S7-04: detects up_to_date when sync is recent and model exists" {
  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"up_to_date"* ]]
}

# ── State detection: outdated ─────────────────────────────────────────────────

@test "SE271-S7-05: detects outdated when sync older than grace period" {
  date -u -d "10 days ago" "+%Y-%m-%dT%H:%M:%SZ" > "${CORPORATE_DIR_TEST}/.sync-state"

  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"outdated"* ]]
}

# ── State detection: corporate_unreachable ────────────────────────────────────

@test "SE271-S7-06: detects corporate_unreachable when no sync record" {
  rm -f "${CORPORATE_DIR_TEST}/.sync-state"

  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"corporate_unreachable"* ]]
}

# ── Active criterion always visible ───────────────────────────────────────────

@test "SE271-S7-07: active_criterion always present in output" {
  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Active criterion"* ]]
}

# ── JSON output mode ──────────────────────────────────────────────────────────

@test "SE271-S7-08: --json flag produces JSON with required fields" {
  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --json --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"state"'* ]]
  [[ "$output" == *'"materialized"'* ]]
  [[ "$output" == *'"connectivity"'* ]]
  [[ "$output" == *'"guarantees"'* ]]
  [[ "$output" == *'"no_expiry": true'* ]]
  [[ "$output" == *'"no_degradation": true'* ]]
}

# ── Guarantees never degraded ─────────────────────────────────────────────────

@test "SE271-S7-09: guarantees asserts no expiry and no degradation" {
  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --json --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *'no_expiry'* ]]
  [[ "$output" == *'no_degradation'* ]]
}

# ── Edge case: missing corporate dir ──────────────────────────────────────────

@test "SE271-S7-10: handles missing .claude/corporate gracefully" {
  export CORPORATE_DIR="${TMPDIR_S7}/nonexistent"
  export CORPORATE_REGISTRY_URL=""
  run bash "$SCRIPT" --grace-days 7

  [[ "$status" -eq 0 ]]
}

# ── Help flag ─────────────────────────────────────────────────────────────────

@test "SE271-S7-11: --help shows usage and exits 0" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── No expiry, no degradation invariant ───────────────────────────────────────

@test "SE271-S7-12: outdated state still reports no_expiry and no_degradation" {
  date -u -d "30 days ago" "+%Y-%m-%dT%H:%M:%SZ" > "${CORPORATE_DIR_TEST}/.sync-state"

  export CORPORATE_DIR="${CORPORATE_DIR_TEST}"
  export CORPORATE_REGISTRY_URL=""
  export CORPORATE_RESILIENCE_GRACE_DAYS=7
  run bash "$SCRIPT" --json --grace-days 7

  [[ "$status" -eq 0 ]]
  [[ "$output" == *'no_expiry": true'* ]]
  [[ "$output" == *'no_degradation": true'* ]]
  [[ "$output" == *'"outdated"'* ]]
}
