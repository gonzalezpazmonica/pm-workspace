#!/usr/bin/env bats
# test-se251-pre-tribunal-gates.bats — SE-251: deterministic pre-tribunal gates tests
#
# Acceptance criteria from SE-251:
# 1. Script exists and is executable
# 2. set -uo pipefail present
# 3. --help exits 0
# 4. --decision missing exits 1
# 5. spec_status=PROPOSED -> G1 BLOCK (exit 1)
# 6. spec_status=APPROVED -> no G1 block
# 7. risk_score=0.9 -> G3 BLOCK (exit 1) with RISK_GATE_THRESHOLD=0.8
# 8. risk_score=0.5 -> no G3 block
# 9. source_branch=feature/foo target=main -> G4 BLOCK (exit 1)
# 10. source_branch=nido/se248 target=main -> no G4 block
# 11. PRETRIBUNAL_GATES_ENABLED=false -> always exit 0
# 12. Unknown decision type -> SKIP (exit 2)
# 13. JSON output has "gate" and "verdict" fields
# 14. PASS output has verdict=PASS

SCRIPT="scripts/pre-tribunal-gates.sh"

setup() {
  cd "${BATS_TEST_DIRNAME}/.."
}

# ── Structure tests ──────────────────────────────────────────────────────────

@test "SE-251-T01: script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "SE-251-T02: set -uo pipefail is present" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ── Invocation tests ─────────────────────────────────────────────────────────

@test "SE-251-T03: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "SE-251-T04: --decision missing exits 1" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

# ── G1: Spec Approval Gate ───────────────────────────────────────────────────

@test "SE-251-T05: spec_status=PROPOSED -> G1 BLOCK" {
  run bash "$SCRIPT" --decision merge \
    --context '{"spec_status":"PROPOSED","source_branch":"nido/test","target_branch":"main"}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"G1"* ]]
  [[ "$output" == *"BLOCK"* ]]
}

@test "SE-251-T06: spec_status=APPROVED -> no G1 block" {
  run bash "$SCRIPT" --decision merge \
    --context '{"spec_status":"APPROVED","source_branch":"nido/test","target_branch":"main"}'
  # Must not produce a G1 BLOCK (may still PASS or block on other gates)
  [[ "$output" != *'"gate":"G1"'* ]] || [[ "$output" != *"BLOCK"* ]]
}

# ── G3: Risk Score Gate ──────────────────────────────────────────────────────

@test "SE-251-T07: risk_score=0.9 -> G3 BLOCK with threshold=0.8" {
  run env RISK_GATE_THRESHOLD=0.8 bash "$SCRIPT" --decision deploy \
    --context '{"risk_score":0.9}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"G3"* ]]
  [[ "$output" == *"BLOCK"* ]]
}

@test "SE-251-T08: risk_score=0.5 -> no G3 block" {
  run env RISK_GATE_THRESHOLD=0.8 bash "$SCRIPT" --decision deploy \
    --context '{"risk_score":0.5}'
  # Must not block on G3
  [[ "$output" != *'"gate":"G3"'* ]] || [[ "$output" != *"BLOCK"* ]]
  [ "$status" -ne 1 ] || [[ "$output" != *"G3"* ]]
}

# ── G4: Branch Safety Gate ───────────────────────────────────────────────────

@test "SE-251-T09: source_branch=feature/foo target=main -> G4 BLOCK" {
  run bash "$SCRIPT" --decision merge \
    --context '{"source_branch":"feature/foo","target_branch":"main"}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"G4"* ]]
  [[ "$output" == *"BLOCK"* ]]
}

@test "SE-251-T10: source_branch=nido/se248 target=main -> no G4 block" {
  run bash "$SCRIPT" --decision merge \
    --context '{"spec_status":"APPROVED","source_branch":"nido/se248","target_branch":"main"}'
  # Must not produce a G4 BLOCK
  if [ "$status" -eq 1 ]; then
    [[ "$output" != *'"gate":"G4"'* ]]
  fi
}

# ── Environment gates ────────────────────────────────────────────────────────

@test "SE-251-T11: PRETRIBUNAL_GATES_ENABLED=false -> always exit 0" {
  run env PRETRIBUNAL_GATES_ENABLED=false bash "$SCRIPT" --decision merge \
    --context '{"spec_status":"PROPOSED","risk_score":0.99,"source_branch":"feature/x","target_branch":"main"}'
  [ "$status" -eq 0 ]
}

@test "SE-251-T12: unknown decision type -> SKIP exit 2" {
  run bash "$SCRIPT" --decision unknown-type
  [ "$status" -eq 2 ]
  [[ "$output" == *"SKIP"* ]]
}

# ── JSON output structure ────────────────────────────────────────────────────

@test "SE-251-T13: JSON output contains 'gate' and 'verdict' fields" {
  run bash "$SCRIPT" --decision deploy \
    --context '{"risk_score":0.9}'
  [[ "$output" == *'"gate"'* ]]
  [[ "$output" == *'"verdict"'* ]]
}

@test "SE-251-T14: PASS output has verdict=PASS" {
  run bash "$SCRIPT" --decision deploy \
    --context '{"risk_score":0.1}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"verdict":"PASS"'* ]]
}
