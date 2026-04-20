#!/usr/bin/env bats
# BATS tests for scripts/agent-size-remediation-plan.sh (SE-052 Slice 1).
# Ref: SE-052, Rule #22
SCRIPT="scripts/agent-size-remediation-plan.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-052" { run grep -c 'SE-052' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references Rule #22" { run grep -c 'Rule #22' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget"* ]]
  [[ "$output" == *"top"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects non-integer --budget" { run bash "$SCRIPT" --budget abc; [ "$status" -eq 2 ]; }
@test "rejects --budget 0" { run bash "$SCRIPT" --budget 0; [ "$status" -eq 2 ]; }
@test "rejects non-integer --top" { run bash "$SCRIPT" --top xyz; [ "$status" -eq 2 ]; }
@test "rejects --top 0" { run bash "$SCRIPT" --top 0; [ "$status" -eq 2 ]; }

@test "runs against real agents dir" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"Budget:"* ]]
}

@test "output reports Total agents" {
  run bash "$SCRIPT"
  [[ "$output" == *"Total agents:"* ]]
}

@test "output reports Over budget" {
  run bash "$SCRIPT"
  [[ "$output" == *"Over budget:"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"total_agents\",\"over_budget\",\"total_bytes_over\",\"budget\",\"top_offenders\"]:
    assert k in d
assert isinstance(d[\"top_offenders\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json top_offenders entries have required fields" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --json --top 3 | python3 -c "
import json, sys
d = json.load(sys.stdin)
for o in d[\"top_offenders\"]:
    for k in [\"file\",\"size_bytes\",\"over_budget\",\"extractable_blocks\",\"estimated_savings_bytes\"]:
        assert k in o
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "total_agents > 0" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"total_agents\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: huge --budget hides all violations" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --budget 1000000 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"over_budget\"] == 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: tiny --budget makes all violations" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --budget 1 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"over_budget\"] == d[\"total_agents\"]
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: --top 1 returns single offender" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --top 1 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d[\"top_offenders\"]) <= 1
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: top_offenders sorted DESC by size" {
  run bash -c 'bash scripts/agent-size-remediation-plan.sh --top 10 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
sizes = [o[\"size_bytes\"] for o in d[\"top_offenders\"]]
assert sizes == sorted(sizes, reverse=True), f\"not sorted DESC: {sizes}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: nonexistent agents dir exits 2" {
  local root="$BATS_TEST_TMPDIR/no-agents"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/agent-size-remediation-plan.sh
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
}

@test "edge: zero agents (empty dir) = PASS" {
  local root="$BATS_TEST_TMPDIR/zero"
  mkdir -p "$root/.claude/agents" "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/agent-size-remediation-plan.sh --json
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [[ "$output" == *'"total_agents":0'* ]]
}

# ── Negative ────────────────────────────────────────────

@test "negative: bad budget rejects" { run bash "$SCRIPT" --budget -5; [ "$status" -eq 2 ]; }
@test "negative: bad top rejects" { run bash "$SCRIPT" --top -1; [ "$status" -eq 2 ]; }

# ── Coverage ────────────────────────────────────────────

@test "coverage: detect_blocks function" { run grep -c 'detect_blocks' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: estimate_savings function" { run grep -c 'estimate_savings' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: COMMON_BLOCKS array" { run grep -c 'COMMON_BLOCKS' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────────────────────────

@test "isolation: does not modify agents dir" {
  local h_before
  h_before=$(find .claude/agents -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find .claude/agents -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
