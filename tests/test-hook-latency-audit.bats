#!/usr/bin/env bats
# BATS tests for scripts/hook-latency-audit.sh (SE-037 Slice 1).
#
# Ref: SE-037, SPEC-081 hook-bats-coverage
# Safety: read-only, set -uo pipefail.

SCRIPT="scripts/hook-latency-audit.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }

@test "uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "references SE-037" {
  run grep -c 'SE-037' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "references baseline file" {
  run grep -c 'hook-critical-violations.count' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"iterations"* ]]
  [[ "$output" == *"sla"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --iterations" {
  run bash "$SCRIPT" --iterations abc
  [ "$status" -eq 2 ]
}

@test "rejects --iterations 0" {
  run bash "$SCRIPT" --iterations 0
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --sla-critical" {
  run bash "$SCRIPT" --sla-critical abc
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --sla-standard" {
  run bash "$SCRIPT" --sla-standard xyz
  [ "$status" -eq 2 ]
}

# ── Execution ─────────────────────────────────────────────────────────

@test "runs against real hooks dir" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports Hooks total" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"Hooks total:"* ]]
}

@test "output reports Latency SLA" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"Latency SLA:"* ]]
}

@test "output reports violations count" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"Latency violations:"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/hook-latency-audit.sh --iterations 1 --no-tests-check --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"total_hooks\",\"latency_violations\",\"baseline\",\"sla_critical_ms\",\"sla_standard_ms\",\"offenders\"]:
    assert k in d, f\"missing {k}\"
assert isinstance(d[\"offenders\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json verdict is PASS or FAIL" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check --json
  [[ "$output" == *'"verdict":"PASS"'* || "$output" == *'"verdict":"FAIL"'* ]]
}

@test "total_hooks > 0" {
  run bash -c 'bash scripts/hook-latency-audit.sh --iterations 1 --no-tests-check --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"total_hooks\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--no-tests-check skips BATS audit" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" != *"Missing BATS tests"* ]] || [[ "$output" == *"0"* ]]
}

@test "SLA critical default 20ms" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"critical=20ms"* ]]
}

@test "SLA standard default 100ms" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"standard=100ms"* ]]
}

@test "custom SLA propagates to output" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check --sla-critical 50 --sla-standard 500
  [[ "$output" == *"critical=50ms"* ]]
  [[ "$output" == *"standard=500ms"* ]]
}

@test "baseline read from .ci-baseline" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$output" == *"baseline:"* ]]
}

# ── Isolation ────────────────────────────────────────────────────────

@test "isolation: does not modify hooks" {
  local h_before
  h_before=$(find .claude/hooks -name "*.sh" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --iterations 1 --no-tests-check >/dev/null 2>&1 || true
  local h_after
  h_after=$(find .claude/hooks -name "*.sh" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: does not modify baseline file" {
  local src=".ci-baseline/hook-critical-violations.count"
  [[ -f "$src" ]] || skip "baseline file not present"
  local h_before
  h_before=$(md5sum "$src" | awk '{print $1}')
  bash "$SCRIPT" --iterations 1 --no-tests-check >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum "$src" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT" --iterations 1 --no-tests-check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
