#!/usr/bin/env bats
# tests/test-project-isolation-gate.bats — SE-220 Trust Zones
#
# Spec: docs/propuestas/SE-220-jailbreak-defenses.md (AC-08, AC-09)
# Ref: SE-093 Zero Project Leakage, SPEC-093, informe jailbreak §3.4
#
# Verifica que project-isolation-gate.sh BLOQUEA refs cross-project,
# y que el override SAVIA_ALLOW_CROSS_PROJECT=1 lo permite con audit log.
#
# Defensa #2.4 del informe jailbreak (trust zones / capability isolation):
# trust zones aplican el principio de privilege separation entre proyectos.
#
# Safety: el hook target usa set -uo pipefail (verificado en test propio).

HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/project-isolation-gate.sh"

setup() {
  WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$WORKSPACE/projects/proj-a" "$WORKSPACE/projects/proj-b" "$WORKSPACE/.savia" "$WORKSPACE/output"
  echo "proj-a" > "$WORKSPACE/.savia/active-project"
  export SAVIA_WORKSPACE_DIR="$WORKSPACE"
  unset SAVIA_ACTIVE_PROJECT SAVIA_ALLOW_CROSS_PROJECT
}

teardown() {
  unset SAVIA_WORKSPACE_DIR SAVIA_ACTIVE_PROJECT SAVIA_ALLOW_CROSS_PROJECT
}

@test "hook is bash valido" {
  bash -n "$HOOK"
}

@test "uses set -uo pipefail" {
  head -15 "$HOOK" | grep -q "set -[euo]*o pipefail"
}

@test "sin proyecto activo → exit 0" {
  rm -f "$WORKSPACE/.savia/active-project"
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-b/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "ref al proyecto activo → exit 0" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-a/file.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "cross-project ref sin override → BLOQUEA (exit 2)" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-b/secret.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
  [[ "$output" == *"proj-b"* ]]
  [[ "$output" == *"proj-a"* ]]
}

@test "cross-project ref CON override → permite (exit 0)" {
  export SAVIA_ALLOW_CROSS_PROJECT=1
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-b/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"override allowed"* ]]
}

@test "override → escribe audit log" {
  export SAVIA_ALLOW_CROSS_PROJECT=1
  bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-b/x.md\"}}' | bash '$HOOK'" >/dev/null
  [[ -f "$WORKSPACE/output/cross-project-audit.jsonl" ]]
  grep -q '"override":true' "$WORKSPACE/output/cross-project-audit.jsonl"
  grep -q '"cross_ref":"proj-b"' "$WORKSPACE/output/cross-project-audit.jsonl"
  grep -q '"active":"proj-a"' "$WORKSPACE/output/cross-project-audit.jsonl"
}

@test "savia-web es excepcion (siempre permitido)" {
  mkdir -p "$WORKSPACE/projects/savia-web"
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/savia-web/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "input vacio → exit 0 sin error" {
  run bash -c "echo '' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "ref a non-project path → exit 0" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"docs/rules/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "SAVIA_ACTIVE_PROJECT env var precede a fichero" {
  echo "wrong-project" > "$WORKSPACE/.savia/active-project"
  export SAVIA_ACTIVE_PROJECT=proj-a
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/proj-b/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"proj-a"* ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "EDGE: empty stdin (no input) — exit 0 silently" {
  run bash -c "echo -n '' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "EDGE: nonexistent projects directory — exit 0 (graceful)" {
  rm -rf "$WORKSPACE/projects"
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"projects/anything/x.md\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "EDGE: large stdin (no overflow, no timeout)" {
  big=$(printf '%s' "{\"data\":\"$(yes "padding" | head -c 50000)\"}")
  run bash -c "echo '$big' | bash '$HOOK'"
  # Cualquier estado; no debe crashear ni colgar
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "EDGE: malformed JSON input — does not crash hook" {
  run bash -c "echo '{not valid json' | bash '$HOOK'"
  # No crash → status 0 ó 2 (segun matching textual)
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "BOUNDARY: timeout on stdin read does not stall (2s timeout)" {
  start=$(date +%s)
  # Pipe vacío + close inmediato; debe procesar y exit en <3s
  run bash -c "true | bash '$HOOK'"
  end=$(date +%s)
  elapsed=$((end - start))
  [ "$elapsed" -lt 3 ]
}

@test "EDGE: multiple cross-project refs in same input — bloquea con primer match" {
  run bash -c "echo '{\"projects\":[\"projects/proj-b/a.md\",\"projects/proj-b/b.md\"]}' | bash '$HOOK'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"proj-b"* ]]
}
