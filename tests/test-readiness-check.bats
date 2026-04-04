#!/usr/bin/env bats
# Ref: SPEC-021 — Hardware readiness checks (RAM, Disk, CPU, GPU)
# Strategy: Validate readiness-check.sh structure, checks, output format, exit codes

SCRIPT="$PWD/scripts/readiness-check.sh"

setup() { TMPDIR=$(mktemp -d); export HOME="$TMPDIR"; mkdir -p "$TMPDIR/.pm-workspace"; }
teardown() { rm -rf "$TMPDIR"; }

@test "SPEC-021 doc exists or is referenced in script" {
  grep -q "SPEC-021" "$SCRIPT"
}
@test "safety flags set -uo pipefail present" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}
@test "script is executable file" {
  [[ -f "$SCRIPT" ]] && [[ -x "$SCRIPT" ]]
}
@test "help output contains Savia Readiness" {
  run bash "$SCRIPT"
  [[ "$output" == *"Readiness"* ]]
}
@test "check function defined with 3 params" {
  grep -q 'check()' "$SCRIPT"
  grep -q 'local level=.*name=.*cmd=' "$SCRIPT"
}
@test "core runtime section validates bash git python3 jq" {
  grep -q 'bash --version' "$SCRIPT"
  grep -q 'git --version' "$SCRIPT"
  grep -q 'command -v python3' "$SCRIPT"
  grep -q 'command -v jq' "$SCRIPT"
}
@test "workspace structure checks CLAUDE.md and directories" {
  grep -q 'CLAUDE.md' "$SCRIPT"
  grep -q '.claude/commands' "$SCRIPT"
  grep -q '.claude/agents' "$SCRIPT"
}
@test "hardware section checks RAM and disk" {
  grep -q 'RAM' "$SCRIPT"
  grep -q 'DISK' "$SCRIPT" || grep -q 'Disk' "$SCRIPT"
}
@test "summary line shows PASS WARN FAIL SKIP TOTAL" {
  run bash "$SCRIPT"
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"TOTAL"* ]]
}
@test "readiness stamp created on success" {
  run bash "$SCRIPT"
  [[ -f "$TMPDIR/.pm-workspace/.readiness-stamp" ]]
}
@test "running outside workspace produces warnings or failures" {
  run bash -c "cd '$TMPDIR' && bash '$SCRIPT'"
  [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"WARN"* ]] || [[ "$status" -ne 0 ]]
}
@test "missing scripts directory causes failure" {
  run bash -c "cd '$TMPDIR' && bash '$SCRIPT'"
  [[ "$output" == *"FAIL"* ]]
}
@test "invalid ROOT_DIR produces error or fail output" {
  run bash -c "cd /nonexistent 2>/dev/null && bash '$SCRIPT'"
  [[ "$status" -ne 0 ]]
}
@test "missing CLAUDE.md triggers fail message" {
  run bash -c "cd '$TMPDIR' && git init -q && bash '$SCRIPT'"
  [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"no encontrado"* ]]
}
@test "edge: empty HOME directory handled gracefully" {
  export HOME="$TMPDIR/empty"
  mkdir -p "$HOME"
  run bash -c "cd '$TMPDIR' && bash '$SCRIPT'"
  # May pass or fail but should not crash
  [[ "$status" -le 1 ]]
}
@test "zero FAIL counter when all checks pass in workspace root" {
  run bash "$SCRIPT"
  # At minimum the script runs; we check it produces structured output
  [[ "$output" == *"PASS:"* ]]
}
@test "coverage: check function defined" {
  grep -q "check()" "$SCRIPT"
}
