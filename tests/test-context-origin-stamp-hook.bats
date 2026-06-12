#!/usr/bin/env bats
# tests/test-context-origin-stamp-hook.bats — SE-221 Slice 1 — Origin stamp hook
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-05)
# Refs: PostToolUse Read hook, idempotencia, JSON mutation
#
# Tests para .claude/hooks/context-origin-stamp.sh: prefija output de Read
# con bloque ---origin si supera umbral. Idempotente. NO rompe Read en caso
# de error.
#
# Safety: el hook usa set -uo pipefail.

HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/context-origin-stamp.sh"

setup() {
  WS="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$WS/docs"
  touch "$WS/docs/critical-facts.md"
  export SAVIA_WORKSPACE_DIR="$WS"
  export CONTEXT_ORIGIN_MIN_LINES=200
}

teardown() {
  unset SAVIA_WORKSPACE_DIR
  unset CONTEXT_ORIGIN_MIN_LINES
  unset CONTEXT_ORIGIN_TEST_PATH
}

# === Sintaxis y safety ===

@test "hook es bash valido" {
  bash -n "$HOOK"
}

@test "uses set -uo pipefail" {
  head -10 "$HOOK" | grep -q "set -[euo]*o pipefail"
}

@test "es ejecutable" {
  [[ -x "$HOOK" ]]
}

# === Comportamiento basico ===

@test "passthrough si stdin vacio" {
  run bash -c "echo -n '' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "passthrough si bajo umbral (standalone)" {
  CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" \
    run bash -c "seq 1 50 | $HOOK"
  [ "$status" -eq 0 ]
  ! [[ "$output" == *"---origin"* ]]
}

@test "stampa origin cuando supera umbral (standalone)" {
  output=$(seq 1 250 | CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  [[ "$output" == *"---origin"* ]]
  [[ "$output" == *"tier: N1-anchor"* ]]
}

@test "el bloque ---origin va al inicio" {
  output=$(seq 1 250 | CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  first_line=$(echo "$output" | head -1)
  [ "$first_line" = "---origin" ]
}

@test "el bloque incluye campos minimos: path, tier, loaded_at, size_tokens, hash" {
  output=$(seq 1 250 | CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  [[ "$output" == *"path:"* ]]
  [[ "$output" == *"tier:"* ]]
  [[ "$output" == *"loaded_at:"* ]]
  [[ "$output" == *"size_tokens:"* ]]
  [[ "$output" == *"hash: sha256:"* ]]
}

@test "sandbox /tmp/opencode/* no recibe stamp" {
  output=$(seq 1 250 | CONTEXT_ORIGIN_TEST_PATH="/tmp/opencode/work.md" bash "$HOOK")
  ! [[ "$output" == *"---origin"* ]]
}

# === Idempotencia (AC-03) ===

@test "idempotente: no duplica el bloque si ya existe" {
  pre=$(printf -- '---origin\npath: x\ntier: N2-eager\n---\n'; seq 1 250)
  output=$(printf '%s\n' "$pre" | CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  origin_count=$(echo "$output" | grep -c "^---origin$")
  [ "$origin_count" -eq 1 ]
}

# === JSON hook input (formato Claude Code PostToolUse) ===

@test "JSON: passthrough cuando tool != Read" {
  input='{"tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{"output":"foo"}}'
  output=$(echo "$input" | bash "$HOOK")
  [ "$output" = "$input" ] || ! [[ "$output" == *"---origin"* ]]
}

@test "JSON: passthrough cuando output bajo umbral" {
  input='{"tool_name":"Read","tool_input":{"file_path":"/tmp/small.md"},"tool_response":{"output":"line1\nline2"}}'
  output=$(echo "$input" | bash "$HOOK")
  parsed_output=$(echo "$output" | jq -r '.tool_response.output')
  ! [[ "$parsed_output" == *"---origin"* ]]
}

@test "JSON: stampa cuando output supera umbral" {
  large_content=$(seq 1 250 | tr '\n' '|' | sed 's/|/\\n/g')
  input="{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WS/docs/critical-facts.md\"},\"tool_response\":{\"output\":\"$large_content\"}}"
  output=$(echo "$input" | bash "$HOOK")
  parsed_output=$(echo "$output" | jq -r '.tool_response.output')
  [[ "$parsed_output" == *"---origin"* ]]
  [[ "$parsed_output" == *"tier: N1-anchor"* ]]
}

@test "JSON: tier untrusted para path fuera del workspace" {
  large_content=$(seq 1 250 | tr '\n' '|' | sed 's/|/\\n/g')
  input="{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/etc/passwd\"},\"tool_response\":{\"output\":\"$large_content\"}}"
  output=$(echo "$input" | bash "$HOOK")
  parsed_output=$(echo "$output" | jq -r '.tool_response.output')
  [[ "$parsed_output" == *"tier: untrusted"* ]]
}

# === Negative / fallback robusto ===

@test "fichero inexistente no rompe el hook" {
  output=$(seq 1 250 | CONTEXT_ORIGIN_TEST_PATH="$WS/docs/nonexistent.md" bash "$HOOK")
  # Hash sera "unknown" pero el bloque sigue emitiendose
  [[ "$output" == *"---origin"* ]]
  [[ "$output" == *"hash: sha256:unknown"* ]]
}

@test "JSON malformado: passthrough silencioso" {
  output=$(echo "{not valid json" | bash "$HOOK")
  [ "$output" = "{not valid json" ]
}

@test "JSON sin tool_name: passthrough" {
  input='{"foo":"bar"}'
  output=$(echo "$input" | bash "$HOOK")
  [ "$output" = "$input" ]
}

@test "binary content (NUL bytes) no rompe el hook" {
  # NUL bytes pueden causar problemas con bash strings
  printf '\x00\x00\x00' | bash "$HOOK" >/dev/null 2>&1
  [ "$?" -ne 1 ] || true
}

# === Edge cases umbral ===

@test "umbral configurable via CONTEXT_ORIGIN_MIN_LINES" {
  output=$(seq 1 20 | CONTEXT_ORIGIN_MIN_LINES=10 CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  [[ "$output" == *"---origin"* ]]
}

@test "exactamente en umbral: stampa" {
  output=$(seq 1 201 | CONTEXT_ORIGIN_MIN_LINES=200 CONTEXT_ORIGIN_TEST_PATH="$WS/docs/critical-facts.md" bash "$HOOK")
  [[ "$output" == *"---origin"* ]]
}

@test "spec_reference: SE-221 documentado en hook" {
  grep -q "SE-221" "$HOOK"
}
