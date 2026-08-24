#!/usr/bin/env bats
# BATS tests for scripts/operator-grant.sh (SE-343)
# Ref: SE-343, SPEC-186, autonomous-safety.md

SCRIPT="scripts/operator-grant.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMP_GRANTS="$(mktemp -d -t grants.XXXXXX)"
  export SAVIA_GRANTS_DIR="$TMP_GRANTS"
  # Deterministic expected grantor, decoupled from the real operator's identity
  # (active-user.md is gitignored; never put a real personal slug in repo files).
  ACTIVE_SLUG="${TEST_EXPECTED_GRANTOR:-test-operator}"
  # If a real active-user profile exists, use its slug so the integration test
  # matches reality; otherwise use the neutral deterministic fallback.
  if [[ -f ".claude/profiles/active-user.md" ]]; then
    REAL="$(grep -oP 'active_slug:\s*"\K[^"]+' .claude/profiles/active-user.md 2>/dev/null | head -1)"
    [[ -n "$REAL" ]] && ACTIVE_SLUG="$REAL"
  fi
}

teardown() {
  [[ -n "$TMP_GRANTS" && -d "$TMP_GRANTS" ]] && rm -rf "$TMP_GRANTS"
  cd /
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "passes bash -n syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── grant / check ──────────────────────────────────────────────────────

@test "grant creates a file and check returns 0" {
  run bash "$SCRIPT" grant --scope autonomy:overnight-sprint \
    --context "test request" --ttl-hours 1
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" check --scope autonomy:overnight-sprint
  [ "$status" -eq 0 ]
}

@test "check returns 3 when no grant" {
  run bash "$SCRIPT" check --scope merge
  [ "$status" -eq 3 ]
}

@test "check returns 1 when grant expired" {
  run bash "$SCRIPT" grant --scope autonomy:overnight-sprint \
    --context "expired test" --ttl-hours 0
  # ttl 0 -> expires immediately (epoch = now). Sleep 1 to be safe.
  sleep 1
  run bash "$SCRIPT" check --scope autonomy:overnight-sprint
  [ "$status" -eq 1 ]
}

@test "grantor is active user slug, never self" {
  run bash "$SCRIPT" grant --scope merge --context "test" --ttl-hours 1
  file="$(ls "$SAVIA_GRANTS_DIR"/merge.json)"
  grep -q "\"grantor\":\"$ACTIVE_SLUG\"" "$file"
  ! grep -q '"grantor":"self"' "$file"
  grep -q '"source":"express-request"' "$file"
}

@test "invalid scope rejected (exit 2)" {
  run bash "$SCRIPT" grant --scope autonomy:bogus --context x
  [ "$status" -eq 2 ]
}

@test "revoke removes grant (check 3)" {
  bash "$SCRIPT" grant --scope merge --context "revoke test" --ttl-hours 1
  bash "$SCRIPT" revoke --scope merge
  run bash "$SCRIPT" check --scope merge
  [ "$status" -eq 3 ]
}

@test "grant idempotent renews expiry" {
  bash "$SCRIPT" grant --scope autonomy:overnight-sprint --context "first" --ttl-hours 1
  bash "$SCRIPT" grant --scope autonomy:overnight-sprint --context "second" --ttl-hours 2
  run bash "$SCRIPT" check --scope autonomy:overnight-sprint
  [ "$status" -eq 0 ]
}

# ── integración con double-optin (SE-343) ───────────────────────────────

@test "double-optin passes with grant and WITHOUT env var" {
  # SE-343: emit the autonomy grant inside the test body (each test gets a
  # fresh SAVIA_GRANTS_DIR from setup). No env var needed for factor 1.
  run bash "$SCRIPT" grant --scope autonomy:overnight-sprint \
    --context "autonomous session" --ttl-hours 1
  [ "$status" -eq 0 ]
  run bash scripts/savia-double-optin-check.sh --skill overnight-sprint \
    --confirm-autonomous
  [ "$status" -eq 0 ]
}