#!/usr/bin/env bats
# tests/test-postponement-judge.bats
# BATS tests for .claude/hooks/postponement-judge.sh — Stop hook that
# forces continuation when the assistant proposes an unjustified deferral.
#
# Ref: .claude/rules/domain/hook-profiles.md (standard tier)
# Ref: SPEC-055 (test quality gate, score >=80)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/postponement-judge.sh"
  TMPDIR_TEST=$(mktemp -d)
  TRANSCRIPT="$TMPDIR_TEST/transcript.jsonl"
  SESSION_ID="bats-$BATS_TEST_NUMBER-$$"
  COUNTER="/tmp/postponement-judge-${SESSION_ID}.count"
  rm -f "$COUNTER"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$COUNTER"
}

# Helper: build the Stop-hook stdin JSON and invoke the hook
invoke() {
  local stop_active="${1:-false}"
  echo "{\"session_id\":\"$SESSION_ID\",\"transcript_path\":\"$TRANSCRIPT\",\"stop_hook_active\":$stop_active}" \
    | bash "$HOOK"
}

# Helper: write a single assistant text turn to transcript.
# Transcripts are JSONL — one object per line, no pretty-printing.
write_assistant_text() {
  local text="$1"
  jq -cn --arg t "$text" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' > "$TRANSCRIPT"
}

# ── Hook structure ────────────────────────────────────────────────────────

@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

@test "hook uses set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}

@test "hook is registered in settings.json Stop array" {
  grep -q "postponement-judge.sh" "$REPO_ROOT/.claude/settings.json"
}

# ── Loop prevention ───────────────────────────────────────────────────────

@test "exits 0 immediately when stop_hook_active=true" {
  write_assistant_text "Lo dejamos para mañana."
  run invoke "true"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "exits 0 when transcript_path is missing" {
  run bash -c "echo '{\"session_id\":\"x\",\"stop_hook_active\":false}' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "exits 0 when transcript_path does not exist" {
  run bash -c "echo '{\"session_id\":\"x\",\"transcript_path\":\"/nonexistent\",\"stop_hook_active\":false}' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "rate-limit cap: after MAX interventions, stop allowing" {
  write_assistant_text "Lo dejamos para mañana."
  # Prime counter at max
  echo 2 > "$COUNTER"
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ── Positive cases (should BLOCK) ─────────────────────────────────────────

@test "blocks Spanish 'lo dejamos para mañana'" {
  write_assistant_text "Ya hemos avanzado bastante. Lo dejamos para mañana."
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *"Postponement Judge"* ]]
}

@test "blocks Spanish 'mañana seguimos'" {
  write_assistant_text "Buen progreso. Mañana seguimos con lo siguiente."
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "blocks Spanish 'en otra sesión'" {
  write_assistant_text "Retomamos esto en otra sesión."
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "blocks English 'pick this up tomorrow'" {
  write_assistant_text "Good progress. Let's pick this up tomorrow."
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "blocks English 'we will continue later'" {
  write_assistant_text "We will continue later with the remaining items."
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "blocks 'por hoy lo dejamos'" {
  write_assistant_text "Por hoy lo dejamos, mañana más."
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "block output is valid JSON with decision and reason" {
  write_assistant_text "Lo dejamos para mañana."
  run invoke "false"
  echo "$output" | jq -e '.decision == "block"' >/dev/null
  echo "$output" | jq -e '.reason | length > 50' >/dev/null
}

@test "block increments the per-session counter" {
  write_assistant_text "Lo dejamos para mañana."
  run invoke "false"
  [[ -f "$COUNTER" ]]
  [[ "$(cat "$COUNTER")" == "1" ]]
}

# ── Negative cases (should ALLOW) ─────────────────────────────────────────

@test "allows when no postponement present" {
  write_assistant_text "Tarea completada. PR #562 creado y tests pasando."
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "allows when postponement is justified by 'code review E1 humano'" {
  write_assistant_text "PR abierto. Lo retomamos mañana cuando el code review E1 humano esté aprobado."
  run invoke "false"
  [[ -z "$output" ]]
}

@test "allows when waiting on CI" {
  write_assistant_text "Pushed. Waiting on CI to finish — will continue tomorrow when it passes."
  run invoke "false"
  [[ -z "$output" ]]
}

@test "allows when pending human approval" {
  write_assistant_text "Lo dejamos aquí, pending human approval required before proceeding."
  run invoke "false"
  [[ -z "$output" ]]
}

@test "allows when user explicitly requested stop" {
  write_assistant_text "El usuario pidió parar. Lo dejamos para mañana."
  run invoke "false"
  [[ -z "$output" ]]
}

@test "allows when task complete" {
  write_assistant_text "Task complete. Nothing left to do in this sprint."
  run invoke "false"
  [[ -z "$output" ]]
}

@test "allows when blocked on external dependency" {
  write_assistant_text "Blocked on external service. Let's continue later when it's back."
  run invoke "false"
  [[ -z "$output" ]]
}

# ── Multi-turn transcript ─────────────────────────────────────────────────

@test "picks last assistant text message, not earlier ones" {
  {
    jq -cn '{type:"assistant",message:{content:[{type:"text",text:"Empezando la tarea."}]}}'
    jq -cn '{type:"user",message:{content:"sigue"}}'
    jq -cn '{type:"assistant",message:{content:[{type:"text",text:"Hecho. Lo dejamos para mañana."}]}}'
  } > "$TRANSCRIPT"
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "ignores thinking and tool_use blocks" {
  jq -cn '{type:"assistant",message:{content:[{type:"thinking",thinking:"Lo dejamos para mañana"},{type:"text",text:"Tarea completada."}]}}' > "$TRANSCRIPT"
  run invoke "false"
  # "Lo dejamos para mañana" is only in the thinking block, real text is fine
  [[ -z "$output" ]]
}

# ── Edge cases (SPEC-055 c5_edge) ─────────────────────────────────────────

@test "edge: empty transcript file behaves gracefully" {
  : > "$TRANSCRIPT"
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: transcript with zero assistant messages returns empty" {
  jq -cn '{type:"user",message:{content:"only user"}}' > "$TRANSCRIPT"
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: nonexistent transcript path exits cleanly (no error)" {
  run bash -c "echo '{\"session_id\":\"x\",\"transcript_path\":\"/nonexistent/path.jsonl\",\"stop_hook_active\":false}' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: malformed JSON line in transcript does not crash" {
  # jq returns empty on malformed lines; hook should skip them
  printf 'not-a-json-line\n' > "$TRANSCRIPT"
  jq -cn '{type:"assistant",message:{content:[{type:"text",text:"Tarea completada."}]}}' >> "$TRANSCRIPT"
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: counter overflow (boundary above max) still allows" {
  write_assistant_text "Lo dejamos para mañana."
  # Counter far above cap: must still allow, never crash
  echo 999 > "$COUNTER"
  run invoke "false"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: large transcript (boundary — 100 assistant turns) picks latest" {
  for i in $(seq 1 99); do
    jq -cn --arg n "$i" '{type:"assistant",message:{content:[{type:"text",text:("turn " + $n + " progressing fine")}]}}'
  done > "$TRANSCRIPT"
  jq -cn '{type:"assistant",message:{content:[{type:"text",text:"Lo dejamos para mañana."}]}}' >> "$TRANSCRIPT"
  run invoke "false"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "edge: missing session_id falls back to default counter path" {
  write_assistant_text "Tarea completada."
  run bash -c "echo '{\"transcript_path\":\"$TRANSCRIPT\",\"stop_hook_active\":false}' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  # No postponement → allow, regardless of session_id
  [[ -z "$output" ]]
}
