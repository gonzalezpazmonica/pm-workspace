#!/usr/bin/env bats
# test-se354-permission-mode.bats — BATS tests for SE-354 Read-Only Permission Mode
# Ref: SE-354 — denegación estructural de tools de mutación en sesión read-only

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/permission-mode-gate.sh"
  export HOOK
}

# helper: run hook with given JSON input and mode
run_hook() {
  local mode="$1" json="$2"
  run env SAVIA_PERMISSION_MODE="$mode" bash "$HOOK" <<< "$json"
}

# ── T1: tools de mutación directas bloqueadas en read-only ────────────────────

@test "read-only: Write bloqueada (exit 2)" {
  run_hook read-only '{"tool_name":"Write","tool_input":{"path":"/tmp/x"}}'
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"SE-354"* ]]
}

@test "read-only: Edit bloqueada (exit 2)" {
  run_hook read-only '{"tool_name":"Edit","tool_input":{"path":"/tmp/x"}}'
  [[ "$status" -eq 2 ]]
}

@test "read-only: MultiEdit bloqueada (exit 2)" {
  run_hook read-only '{"tool_name":"MultiEdit","tool_input":{"path":"/tmp/x"}}'
  [[ "$status" -eq 2 ]]
}

# ── T2: Bash read-safe permitido en read-only ─────────────────────────────────

@test "read-only: git status permitido (exit 0)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  [[ "$status" -eq 0 ]]
}

@test "read-only: git diff permitido (exit 0)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"git diff --stat"}}'
  [[ "$status" -eq 0 ]]
}

@test "read-only: ls permitido (exit 0)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [[ "$status" -eq 0 ]]
}

@test "read-only: cat permitido (exit 0)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"cat file.txt"}}'
  [[ "$status" -eq 0 ]]
}

# ── T3: Bash de mutación bloqueado en read-only ───────────────────────────────

@test "read-only: git push bloqueado (exit 2)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"SE-354"* ]]
}

@test "read-only: git commit bloqueado (exit 2)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
  [[ "$status" -eq 2 ]]
}

@test "read-only: git merge bloqueado (exit 2)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"git merge feature/x"}}'
  [[ "$status" -eq 2 ]]
}

@test "read-only: mv bloqueado (exit 2)" {
  run_hook read-only '{"tool_name":"Bash","tool_input":{"command":"mv a.txt b.txt"}}'
  [[ "$status" -eq 2 ]]
}

# ── T4: modo full no bloquea nada ─────────────────────────────────────────────

@test "full: Write permitida (exit 0)" {
  run_hook full '{"tool_name":"Write","tool_input":{"path":"/tmp/x"}}'
  [[ "$status" -eq 0 ]]
}

@test "full: git push permitido (exit 0)" {
  run_hook full '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  [[ "$status" -eq 0 ]]
}

# ── T5: fail-soft ─────────────────────────────────────────────────────────────

@test "JSON inválido → exit 0 (fail-soft)" {
  run env SAVIA_PERMISSION_MODE=read-only bash "$HOOK" <<< "NOT JSON"
  [[ "$status" -eq 0 ]]
}

@test "modo vacío → exit 0 (default full)" {
  run env SAVIA_PERMISSION_MODE= bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"path":"/tmp/x"}}'
  [[ "$status" -eq 0 ]]
}

@test "input vacío → exit 0" {
  run env SAVIA_PERMISSION_MODE=read-only bash "$HOOK" <<< ""
  [[ "$status" -eq 0 ]]
}
