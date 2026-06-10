#!/usr/bin/env bats
# tests/test-se-216-agent-gate.bats — SE-216 Slice 2: inherited quality gates
# Ref: docs/propuestas/SE-216-evo-patterns.md

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------
setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${REPO_ROOT}/scripts/agent-gate.sh"
  export REPO_ROOT SCRIPT

  # Work inside a temp dir so .evo state is isolated per test
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  # Override working directory: the script resolves .evo relative to CWD
  cd "$TMPDIR"
}

teardown() {
  [[ -n "${TMPDIR:-}" && "$TMPDIR" == /tmp/* ]] && rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# T01: script exists and is executable
# ---------------------------------------------------------------------------
@test "T01: script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ---------------------------------------------------------------------------
# T02: set -uo pipefail is present
# ---------------------------------------------------------------------------
@test "T02: set -uo pipefail is present in script" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

# ---------------------------------------------------------------------------
# T03: add without --branch creates a global gate in gates.json
# ---------------------------------------------------------------------------
@test "T03: add without --branch creates a global gate (branch=null)" {
  run bash "$SCRIPT" add \
    --run-id "run-001" \
    --name "lint-check" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  [[ "$status" -eq 0 ]]

  local gates_file="${TMPDIR}/.evo/run-001/gates.json"
  [[ -f "$gates_file" ]]

  # branch must be null for a global gate
  result=$(python3 -c "
import json
with open('${gates_file}') as f:
    data = json.load(f)
gates = data['gates']
assert len(gates) == 1, f'expected 1 gate, got {len(gates)}'
assert gates[0]['branch'] is None, f\"expected branch=null, got {gates[0]['branch']}\"
assert gates[0]['name'] == 'lint-check'
print('OK')
")
  [[ "$result" == "OK" ]]
}

# ---------------------------------------------------------------------------
# T04: add with --branch creates a branch-specific gate in gates.json
# ---------------------------------------------------------------------------
@test "T04: add with --branch creates a branch-specific gate" {
  run bash "$SCRIPT" add \
    --run-id "run-002" \
    --name "security-scan" \
    --phase post \
    --cmd "true" \
    --on-fail warn \
    --branch "agent/fix-auth"

  [[ "$status" -eq 0 ]]

  local gates_file="${TMPDIR}/.evo/run-002/gates.json"
  result=$(python3 -c "
import json
with open('${gates_file}') as f:
    data = json.load(f)
gates = data['gates']
assert len(gates) == 1
assert gates[0]['branch'] == 'agent/fix-auth', f\"got {gates[0]['branch']}\"
assert gates[0]['name'] == 'security-scan'
print('OK')
")
  [[ "$result" == "OK" ]]
}

# ---------------------------------------------------------------------------
# T05: run with a passing gate (cmd exit 0) returns exit 0
# ---------------------------------------------------------------------------
@test "T05: run with passing gate (cmd=true) exits 0" {
  bash "$SCRIPT" add \
    --run-id "run-003" \
    --name "always-pass" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  run bash "$SCRIPT" run \
    --run-id "run-003" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T06: run with a block gate that fails returns exit 1 + "GATE FAILED" message
# ---------------------------------------------------------------------------
@test "T06: run with block gate that fails exits 1 with GATE FAILED message" {
  bash "$SCRIPT" add \
    --run-id "run-004" \
    --name "always-fail" \
    --phase pre \
    --cmd "false" \
    --on-fail block

  run bash "$SCRIPT" run \
    --run-id "run-004" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -eq 1 ]]
  # Message must appear on stderr (captured in $output by bats with status!=0)
  [[ "$output" == *"GATE FAILED"* ]]
  [[ "$output" == *"always-fail"* ]]
}

# ---------------------------------------------------------------------------
# T07: run with a warn gate that fails returns exit 0, WARNING on stderr
# ---------------------------------------------------------------------------
@test "T07: run with warn gate that fails exits 0 and emits WARNING" {
  bash "$SCRIPT" add \
    --run-id "run-005" \
    --name "warn-gate" \
    --phase pre \
    --cmd "false" \
    --on-fail warn

  run bash "$SCRIPT" run \
    --run-id "run-005" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARNING"* ]]
}

# ---------------------------------------------------------------------------
# T08: run with a skip gate that fails returns exit 0 with no output for that gate
# ---------------------------------------------------------------------------
@test "T08: run with skip gate that fails exits 0 silently" {
  bash "$SCRIPT" add \
    --run-id "run-006" \
    --name "skip-gate" \
    --phase pre \
    --cmd "false" \
    --on-fail skip

  run bash "$SCRIPT" run \
    --run-id "run-006" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -eq 0 ]]
  # Must not contain "GATE FAILED" or "WARNING"
  [[ "$output" != *"GATE FAILED"* ]]
  [[ "$output" != *"WARNING"* ]]
}

# ---------------------------------------------------------------------------
# T09: run --phase pre does not execute post gates, and vice versa
# ---------------------------------------------------------------------------
@test "T09: run phase=pre does not execute post gates" {
  # Add a post gate that would fail with block
  bash "$SCRIPT" add \
    --run-id "run-007" \
    --name "post-blocker" \
    --phase post \
    --cmd "false" \
    --on-fail block

  # Running with phase=pre should succeed (no pre gates defined)
  run bash "$SCRIPT" run \
    --run-id "run-007" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -eq 0 ]]
  [[ "$output" != *"GATE FAILED"* ]]
}

@test "T09b: run phase=post does not execute pre gates" {
  bash "$SCRIPT" add \
    --run-id "run-007b" \
    --name "pre-blocker" \
    --phase pre \
    --cmd "false" \
    --on-fail block

  run bash "$SCRIPT" run \
    --run-id "run-007b" \
    --branch "any-branch" \
    --phase post

  [[ "$status" -eq 0 ]]
  [[ "$output" != *"GATE FAILED"* ]]
}

# ---------------------------------------------------------------------------
# T10: global gates appear in run for any branch (inheritance)
# ---------------------------------------------------------------------------
@test "T10: global gate (no branch) is executed for any branch" {
  # Add a global gate that fails with block
  bash "$SCRIPT" add \
    --run-id "run-008" \
    --name "global-blocker" \
    --phase pre \
    --cmd "false" \
    --on-fail block

  # Running from a completely different branch should still hit the global gate
  run bash "$SCRIPT" run \
    --run-id "run-008" \
    --branch "agent/some-feature" \
    --phase pre

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"GATE FAILED"* ]]
  [[ "$output" == *"global-blocker"* ]]
}

# ---------------------------------------------------------------------------
# T11: status prints a table with correct fields
# ---------------------------------------------------------------------------
@test "T11: status prints table with gate, phase, on-fail, branch columns" {
  bash "$SCRIPT" add \
    --run-id "run-009" \
    --name "my-gate" \
    --phase pre \
    --cmd "true" \
    --on-fail warn

  bash "$SCRIPT" add \
    --run-id "run-009" \
    --name "branch-gate" \
    --phase post \
    --cmd "true" \
    --on-fail skip \
    --branch "agent/feature"

  run bash "$SCRIPT" status --run-id "run-009"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"my-gate"* ]]
  [[ "$output" == *"branch-gate"* ]]
  [[ "$output" == *"warn"* ]]
  [[ "$output" == *"skip"* ]]
  [[ "$output" == *"global"* || "$output" == *"(global)"* ]]
  [[ "$output" == *"agent/feature"* ]]
}

# ---------------------------------------------------------------------------
# T12: add without --run-id exits with error
# ---------------------------------------------------------------------------
@test "T12: add without --run-id exits with error" {
  run bash "$SCRIPT" add \
    --name "lint" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  [[ "$status" -ne 0 ]]
  [[ "$output" == *"run-id"* ]]
}

# ---------------------------------------------------------------------------
# T13: add without --name exits with error
# ---------------------------------------------------------------------------
@test "T13: add without --name exits with error" {
  run bash "$SCRIPT" add \
    --run-id "run-010" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  [[ "$status" -ne 0 ]]
  [[ "$output" == *"name"* ]]
}

# ---------------------------------------------------------------------------
# T14: run with non-existent run_id exits with clear error
# ---------------------------------------------------------------------------
@test "T14: run with non-existent run_id exits with clear error" {
  run bash "$SCRIPT" run \
    --run-id "run-does-not-exist" \
    --branch "any-branch" \
    --phase pre

  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not found"* || "$output" == *"run-does-not-exist"* ]]
}

# ---------------------------------------------------------------------------
# T15: gates.json is valid JSON after add
# ---------------------------------------------------------------------------
@test "T15: gates.json is valid JSON after add" {
  bash "$SCRIPT" add \
    --run-id "run-011" \
    --name "json-test-gate" \
    --phase pre \
    --cmd "echo hello" \
    --on-fail block

  local gates_file="${TMPDIR}/.evo/run-011/gates.json"
  [[ -f "$gates_file" ]]

  run python3 -c "import json; json.load(open('${gates_file}')); print('valid')"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"valid"* ]]
}

# ---------------------------------------------------------------------------
# T16: two add calls on the same run_id accumulate gates (no overwrite)
# ---------------------------------------------------------------------------
@test "T16: two adds to same run_id accumulate gates, not overwrite" {
  bash "$SCRIPT" add \
    --run-id "run-012" \
    --name "gate-one" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  bash "$SCRIPT" add \
    --run-id "run-012" \
    --name "gate-two" \
    --phase post \
    --cmd "true" \
    --on-fail warn

  local gates_file="${TMPDIR}/.evo/run-012/gates.json"
  result=$(python3 -c "
import json
with open('${gates_file}') as f:
    data = json.load(f)
gates = data['gates']
assert len(gates) == 2, f'expected 2 gates, got {len(gates)}'
names = {g['name'] for g in gates}
assert 'gate-one' in names, 'gate-one missing'
assert 'gate-two' in names, 'gate-two missing'
print('OK')
")
  [[ "$result" == "OK" ]]
}

# ---------------------------------------------------------------------------
# T17: .evo/{run_id}/ directory is created automatically by add
# ---------------------------------------------------------------------------
@test "T17: .evo/run_id/ directory is created automatically" {
  local run_id="run-auto-dir"
  [[ ! -d "${TMPDIR}/.evo/${run_id}" ]]

  bash "$SCRIPT" add \
    --run-id "$run_id" \
    --name "autodir-gate" \
    --phase pre \
    --cmd "true" \
    --on-fail block

  [[ -d "${TMPDIR}/.evo/${run_id}" ]]
}
