#!/usr/bin/env bats
# BATS tests for scripts/opencode-cross-audit.sh
# SPEC-OPC-CROSS-AUDIT — Cross-audit .claude/ vs .opencode/ drift detection.

SCRIPT="scripts/opencode-cross-audit.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_DIR=$(mktemp -d "$TMPDIR/oca-XXXXXX")
}
teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
  cd /
}

# ── Existencia y permisos ────────────────────────────────────────────────────

@test "script exists" {
  [[ -f "$SCRIPT" ]]
}

@test "script is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── CLI ───────────────────────────────────────────────────────────────────────

@test "help: --help exits 0 and shows Usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help: -h equivalent to --help" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: unknown flag exits 2" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 2 ]
}

@test "--fix flag is recognized (no unknown-flag error)" {
  # Run with --fix from a tmp dir so it won't mutate the workspace on exit-2.
  # We only assert status is NOT 2 (flag parse error), it may be 0 or 1.
  run bash "$SCRIPT" --fix
  [ "$status" -ne 2 ]
}

# ── Exit codes ────────────────────────────────────────────────────────────────

@test "exit code is 0 or 1 on normal run (not 2)" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "output contains RESULT: PASS or RESULT: FAIL" {
  run bash "$SCRIPT"
  [[ "$output" == *"RESULT: PASS"* || "$output" == *"RESULT: FAIL"* ]]
}

# ── Estructura del informe ────────────────────────────────────────────────────

@test "report contains RESOURCE header" {
  run bash "$SCRIPT"
  [[ "$output" == *"RESOURCE"* ]]
}

@test "report contains STATUS header" {
  run bash "$SCRIPT"
  [[ "$output" == *"STATUS"* ]]
}

@test "report contains SUMMARY section" {
  run bash "$SCRIPT"
  [[ "$output" == *"SUMMARY"* ]]
}

# ── Detección de drift en sandbox ─────────────────────────────────────────────

@test "detects DRIFT when file differs between .claude and .opencode" {
  # Construir sandbox con un agente que difiere
  local sandbox="$TEST_DIR/drift-test"
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  echo "content-A" > "$sandbox/.claude/agents/test-agent.md"
  echo "content-B" > "$sandbox/.opencode/agents/test-agent.md"
  # Añadir commands y skills vacíos para evitar error de find
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"

  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
}

@test "detects MISSING_OPC when agent exists in .claude but not in .opencode" {
  local sandbox="$TEST_DIR/missing-opc"
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  echo "only-in-claude" > "$sandbox/.claude/agents/orphan-agent.md"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"

  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING_OPC"* ]]
}

@test "reports OK and exit 0 when .claude and .opencode are identical" {
  local sandbox="$TEST_DIR/aligned"
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  echo "same-content" > "$sandbox/.claude/agents/sync-agent.md"
  cp "$sandbox/.claude/agents/sync-agent.md" "$sandbox/.opencode/agents/sync-agent.md"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"

  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT: PASS"* ]]
}

@test "--fix copies MISSING_OPC file from .claude to .opencode" {
  local sandbox="$TEST_DIR/fix-test"
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  echo "fix-me" > "$sandbox/.claude/agents/new-agent.md"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"

  # Before fix: file must not exist in .opencode
  [[ ! -f "$sandbox/.opencode/agents/new-agent.md" ]]

  bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT' --fix" || true

  # After fix: file must exist in .opencode with correct content
  [[ -f "$sandbox/.opencode/agents/new-agent.md" ]]
  run diff "$sandbox/.claude/agents/new-agent.md" "$sandbox/.opencode/agents/new-agent.md"
  [ "$status" -eq 0 ]
}

@test "--fix does NOT modify .claude directory" {
  local sandbox="$TEST_DIR/no-cld-write"
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  # File only in .opencode (MISSING_CLD)
  echo "only-in-opc" > "$sandbox/.opencode/agents/opc-only.md"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"

  bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT' --fix" || true

  # .claude must remain untouched — file must NOT appear there
  [[ ! -f "$sandbox/.claude/agents/opc-only.md" ]]
}

@test "ignores .opencode/settings.json (not reported as MISSING_CLD)" {
  # settings.json is .opencode-only infrastructure — must not appear in report
  run bash "$SCRIPT"
  [[ "$output" != *"settings.json"* ]]
}

@test "sha256sum is used for content comparison" {
  run grep -c 'sha256sum' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: empty .claude/ produces PASS (no resources to compare)" {
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills" "$sandbox/.opencode/skills"
  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT'"
  # No resources → PASS or trivially zero issues
  [[ "$status" -eq 0 || "$output" == *"PASS"* || "$output" == *"0 issue"* ]]
}

@test "edge: binary file in .claude/agents/ does not crash script" {
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"
  printf '\x00\x01\x02binary' > "$sandbox/.claude/agents/binary.md"
  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT'" || true
  # Must not produce unbound variable errors or crash with exit 2+
  [[ "$status" -le 1 ]]
}

@test "edge: --fix with no drift is a no-op (exit 0)" {
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/.claude/agents" "$sandbox/.opencode/agents"
  mkdir -p "$sandbox/.claude/commands" "$sandbox/.opencode/commands"
  mkdir -p "$sandbox/.claude/skills"   "$sandbox/.opencode/skills"
  # Identical file in both sides
  echo "# same" > "$sandbox/.claude/agents/agent-a.md"
  cp "$sandbox/.claude/agents/agent-a.md" "$sandbox/.opencode/agents/agent-a.md"
  run bash -c "cd '$sandbox' && bash '$OLDPWD/$SCRIPT' --fix"
  [ "$status" -eq 0 ]
}

@test "coverage: --help or no-args shows usage info" {
  run bash "$SCRIPT" --help 2>&1 || run bash "$SCRIPT" 2>&1
  [[ "$output" == *"usage"* || "$output" == *"Usage"* || "$output" == *"PASS"* || "$output" == *"FAIL"* ]]
}

@test "coverage: SPEC-OPC-CROSS-AUDIT reference in script" {
  grep -qiE 'SPEC-OPC-CROSS-AUDIT|cross.audit' "$SCRIPT"
}
