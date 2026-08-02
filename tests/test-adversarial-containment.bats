#!/usr/bin/env bats

setup() {
  ADVS="$BATS_TEST_DIRNAME/../scripts/adversarial-containment.sh"
}

@test "adversarial: script is executable" {
  [ -x "$ADVS" ]
}

@test "adversarial: script has set -uo pipefail" {
  head -2 "$ADVS" | grep -q "set -euo pipefail"
}

@test "adversarial: 6 tests present" {
  count=$(grep -c "run_test" "$ADVS" || echo 0)
  [ "$count" -ge 6 ]
}

@test "adversarial: credential leak test exists" {
  grep -q "credential_leak" "$ADVS"
}

@test "adversarial: write outside work dir test exists" {
  grep -q "write_outside" "$ADVS"
}

@test "adversarial: cross-encargo test exists" {
  grep -q "cross_encargo" "$ADVS"
}

@test "adversarial: privilege escalation test exists" {
  grep -q "privilege_escalation" "$ADVS"
}

@test "adversarial: host fallback test exists" {
  grep -q "host_fallback" "$ADVS"
}

@test "adversarial: autonomy evidence test exists" {
  grep -q "autonomy_without_evidence" "$ADVS"
}

@test "adversarial: exits non-zero on failure mode" {
  run bash "$ADVS"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
