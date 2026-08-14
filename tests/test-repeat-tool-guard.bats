#!/usr/bin/env bats
# tests/test-repeat-tool-guard.bats — SE-326 S1: repeat-tool-guard (AC-S1).
# Ref: docs/propuestas/SE-326-harness-loop-hygiene.md

GUARD="scripts/repeat-tool-guard.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

guard() { # session tool args [turn]
  python3 "$GUARD" --session "$1" --tool "$2" --args "$3" --turn "${4:-turn1}" --state-dir "$TMPD/state" 2>"$TMPD/stderr.txt"
}

# ── AC-S1 ─────────────────────────────────────────────────────────────────

@test "S1.1: 3 llamadas idénticas seguidas → nudge genérico (AC-S1.1)" {
  guard s1 Read '{"file_path":"a.py"}' >/dev/null
  guard s1 Read '{"file_path":"a.py"}' >/dev/null
  run guard s1 Read '{"file_path":"a.py"}'
  grep -q "repeating the exact same tool call" "$TMPD/stderr.txt"
}

@test "S1.2: 5 llamadas idénticas → recordatorio detallado con tool y run length (AC-S1.2)" {
  for i in 1 2 3 4; do guard s2 Read '{"file_path":"a.py"}' >/dev/null; done
  run guard s2 Read '{"file_path":"a.py"}'
  grep -q "Repeated tool call detected" "$TMPD/stderr.txt"
  grep -q "tool: Read" "$TMPD/stderr.txt"
  grep -q "consecutive_calls: 5" "$TMPD/stderr.txt"
}

@test "S1.3: tool excluida no lava la cadena (AC-S1.3)" {
  guard s3 Grep '{"pattern":"x"}' >/dev/null
  python3 "$GUARD" --session s3 --tool todo_write --args '{"task":"x"}' --turn turn1 --exclude todo_write,todowrite --state-dir "$TMPD/state" >/dev/null 2>&1
  guard s3 Grep '{"pattern":"x"}' >/dev/null
  guard s3 Grep '{"pattern":"x"}' >/dev/null
  # 4ª llamada Grep (todo_write excluida no lava): aún no es threshold 5 → sin mensaje
  guard s3 Grep '{"pattern":"x"}' >/dev/null 2>"$TMPD/stderr3.txt"
  # 5ª llamada → threshold 5 → detalle con consecutive_calls: 5 (cadena NO se reinició)
  run guard s3 Grep '{"pattern":"x"}'
  grep -q "consecutive_calls: 5" "$TMPD/stderr.txt"
}

@test "S1.4: args en distinto orden cuentan como idénticas (AC-S1.4)" {
  guard s4 Bash '{"command":"ls","cwd":"/tmp"}' >/dev/null
  guard s4 Bash '{"cwd":"/tmp","command":"ls"}' >/dev/null
  guard s4 Bash '{"command":"ls","cwd":"/tmp"}' >/dev/null
  guard s4 Bash '{"cwd":"/tmp","command":"ls"}' >/dev/null
  run guard s4 Bash '{"command":"ls","cwd":"/tmp"}'
  grep -q "consecutive_calls: 5" "$TMPD/stderr.txt"
}

@test "S1.5: una llamada distinta resetea la cadena (AC-S1.5)" {
  guard s5 Read '{"file_path":"a.py"}' >/dev/null
  guard s5 Read '{"file_path":"b.py"}' >/dev/null
  guard s5 Read '{"file_path":"b.py"}' >/dev/null
  guard s5 Read '{"file_path":"b.py"}' >/dev/null
  guard s5 Read '{"file_path":"b.py"}' >/dev/null
  run guard s5 Read '{"file_path":"b.py"}'
  grep -q "consecutive_calls: 5" "$TMPD/stderr.txt"
}

@test "S1.6: el guard nunca bloquea — exit 0 siempre (AC-S1.6)" {
  for i in 1 2 3 4 5; do guard s6 Read '{"file_path":"a.py"}' >/dev/null; done
  guard s6 Read '{"file_path":"a.py"}' >/dev/null
  [[ $? -eq 0 ]]
  run python3 "$GUARD" --session s6 --tool Read --args '{"file_path":"a.py"}' --turn turn2 --state-dir "$TMPD/state"
  [[ $? -eq 0 ]]
}

@test "S1.7: cambio de turno resetea la cadena (AC-S1.1 + reset)" {
  guard s7 Read '{"file_path":"a.py"}' >/dev/null
  guard s7 Read '{"file_path":"a.py"}' >/dev/null
  guard s7 Read '{"file_path":"a.py"}' turn2 >/dev/null 2>"$TMPD/stderr2.txt"
  [[ ! -s "$TMPD/stderr2.txt" ]]
}

@test "S1.8: threshold configurable (--thresholds 2,4)" {
  python3 "$GUARD" --session s8 --tool Read --args '{"file_path":"a.py"}' --thresholds 2,4 --state-dir "$TMPD/state" 2>"$TMPD/e1" >/dev/null
  # 2ª llamada → threshold 2 (primero) → nudge genérico
  python3 "$GUARD" --session s8 --tool Read --args '{"file_path":"a.py"}' --thresholds 2,4 --state-dir "$TMPD/state" 2>"$TMPD/e2" >/dev/null
  grep -q "repeating the exact same tool call" "$TMPD/e2"
}
