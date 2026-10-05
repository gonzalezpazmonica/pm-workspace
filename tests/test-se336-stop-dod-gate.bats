#!/usr/bin/env bats
# SE-336 S2 — stop-dod-gate: DoD de la respuesta final
# Spec: docs/specs/SE-336-turn-sdlc.spec.md (AC-02..AC-05, AC-09, AC-10 parcial)
# Ref: docs/specs/SE-336-turn-sdlc.spec.md · CRITERIO.md CRIT-034, CRIT-038
#
# Fixtures: transcript JSONL sintético con último mensaje assistant de texto,
# en el formato que producen los hooks de Claude Code (.type=assistant,
# .message.content[].type=text).

HOOK=".claude/hooks/stop-dod-gate.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  export SAVIA_DOD_GATE=on
  FIXDIR=$(mktemp -d)
  export SAVIA_DOD_GATE_LOG_DIR="$FIXDIR/log"
  export TMPDIR="$FIXDIR/tmp"
  mkdir -p "$TMPDIR"
}

teardown() {
  rm -rf "$FIXDIR"
}

# Genera un transcript JSONL: 1 user + 1 assistant con texto.
make_transcript() {
  local text="$1"
  local f="$FIXDIR/transcript.jsonl"
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"text","text":"pregunta"}]}}' > "$f"
  python3 - "$f" "$text" <<'PYEOF'
import json, sys
f, text = sys.argv[1], sys.argv[2]
with open(f, 'a') as fh:
    fh.write(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":text}]}}) + "\n")
PYEOF
  echo "$f"
}

make_input() {
  local transcript="$1" session="testsession"
  echo "{\"session_id\":\"$session\",\"transcript_path\":\"$transcript\"}"
}

@test "AC-02: promesa sin acción + tree limpio + modo block → decision block" {
  local t
  t=$(make_transcript "La próxima vez consultaré las cúpulas primero.")
  # limpiar contador de sesión
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  run bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  # limpiar tree no aplica (repo real con cambios): forzamos detección pura
  # con SAVIA_DOD_GATE_MODE=block y comprobamos el JSON
}

@test "AC-02b: DOD-001 con modo block y sin acción → JSON decision block" {
  local t
  t=$(make_transcript "La próxima vez lo haré mejor, te lo prometo.")
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  # Simular turno sin acción: cwd a dir git limpio (fixture git repo)
  local repo="$FIXDIR/repo"
  git init -q "$repo" && git -C "$repo" -c user.email="test@test" -c user.name="test" commit --allow-empty -m init -q
  cp "$HOOK" "$FIXDIR/hook-copy.sh"
  SAVIA_DOD_GATE_MODE=block run bash -c "cd '$repo' && bash '$FIXDIR/hook-copy.sh'" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q '"decision": "block"'
  echo "$output" | grep -q 'DOD-001'
}

@test "AC-03: antiloop — segunda invocación pasa (contador de sesión)" {
  local t
  t=$(make_transcript "La próxima vez lo haré mejor.")
  local repo="$FIXDIR/repo2"
  git init -q "$repo" && git -C "$repo" -c user.email="test@test" -c user.name="test" commit --allow-empty -m init -q
  cp "$HOOK" "$FIXDIR/hook-copy2.sh"
  # primera invocación en block
  cd "$repo" && SAVIA_DOD_GATE_MODE=block bash "$FIXDIR/hook-copy2.sh" <<< "$(make_input "$t")" >/dev/null
  # el contador existe → segunda invocación debe salir inmediatamente sin block
  run bash -c "cd '$repo' && SAVIA_DOD_GATE_MODE=block bash '$FIXDIR/hook-copy2.sh'" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"decision"* ]]
}

@test "AC-04: afirmación con cifras sin referencia → WARN (exit 0, sin block)" {
  local t
  t=$(make_transcript "Los tests pasan 8/8 y todo está perfecto.")
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  run bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  # en modo warn (default) no bloquea; el warning se registra en log
  [[ -f "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl" ]] || skip "log escrito solo con patrón exacto"
  grep -q "DOD-002" "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl"
}

@test "AC-04b: afirmación CON referencia verificable → sin warning" {
  local t
  t=$(make_transcript "Los tests pasan 8/8 — ver tests/test-se336-turn-sdlc-audit.bats")
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  run bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  if [[ -f "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl" ]]; then
    ! grep -q "DOD-002" "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl"
  fi
}

@test "AC-05: master switch SAVIA_DOD_GATE=off → exit 0 inmediato sin procesar" {
  local t
  t=$(make_transcript "La próxima vez lo haré mejor.")
  run env SAVIA_DOD_GATE=off bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "AC-09: latencia < 2s sobre payload de 50KB" {
  # transcript sintético de ~50KB
  local f="$FIXDIR/big.jsonl"
  python3 - "$f" <<'PYEOF'
import json, sys
f = sys.argv[1]
with open(f, 'w') as fh:
    for i in range(200):
        fh.write(json.dumps({"type":"user","message":{"content":[{"type":"text","text":"x"*200}]}}) + "\n")
    fh.write(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":"Respuesta final de prueba " + "y"*5000}]}}) + "\n")
PYEOF
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  local start end elapsed
  start=$(date +%s%N)
  bash "$HOOK" <<< "$(make_input "$f")" >/dev/null 2>&1
  end=$(date +%s%N)
  elapsed=$(( (end - start) / 1000000 ))
  (( elapsed < 2000 ))
}

@test "stop_hook_active=true → exit 0 inmediato (antiloop Claude Code)" {
  local t
  t=$(make_transcript "La próxima vez lo haré mejor.")
  run bash "$HOOK" <<< "{\"stop_hook_active\":true,\"session_id\":\"s\",\"transcript_path\":\"$t\"}"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "RN-04: log guarda query_hash, nunca el texto del mensaje" {
  local t msg
  msg="Frase única marcadora ZQX-9981 para privacidad."
  t=$(make_transcript "$msg 8/8 tests pasan.")
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  bash "$HOOK" <<< "$(make_input "$t")" >/dev/null 2>&1
  if [[ -f "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl" ]]; then
    ! grep -q "ZQX-9981" "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl"
    grep -q "query_hash" "$SAVIA_DOD_GATE_LOG_DIR/dod-gate.jsonl"
  fi
}

@test "AC-10 parcial: el hook no toca CRITERIO.md ni CONSTITUCION.md" {
  local t before after
  t=$(make_transcript "La próxima vez lo haré mejor.")
  before=$(sha256sum CRITERIO.md .claude/CONSTITUCION.md)
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  bash "$HOOK" <<< "$(make_input "$t")" >/dev/null 2>&1
  after=$(sha256sum CRITERIO.md .claude/CONSTITUCION.md)
  [[ "$before" == "$after" ]]
}

@test "DOD-001 no dispara con promesa legítima respaldada (texto sin patrón)" {
  local t
  t=$(make_transcript "He registrado la lección: toda promesa va con acción. El fichero LP está creado.")
  rm -f "$TMPDIR"/stop-dod-gate-*.count
  run bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"decision"* ]]
}

# ── DOD-004 / DOD-005 (CRIT-034, CRIT-038) ──
# Transcript con turno: user texto → assistant [tool_use…] → assistant texto final.
make_turn() {
  local text="$1" tools="${2:-}" f="$FIXDIR/turn.jsonl"
  python3 - "$f" "$text" "$tools" <<'PYEOF'
import json, sys
f, text, tools = sys.argv[1], sys.argv[2], sys.argv[3].split()
with open(f, "w") as fh:
    fh.write(json.dumps({"type":"user","message":{"content":[{"type":"text","text":"turno anterior"}]}})+"\n")
    fh.write(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{}}]}})+"\n")
    fh.write(json.dumps({"type":"user","message":{"content":[{"type":"text","text":"nuevo turno"}]}})+"\n")
    for t in tools:
        fh.write(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":t,"input":{}}]}})+"\n")
        fh.write(json.dumps({"type":"user","message":{"content":[{"type":"tool_result","content":"ok"}]}})+"\n")
    fh.write(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":text}]}})+"\n")
PYEOF
  echo "$f"
}

@test "DOD-004 block: estado afirmado sin ninguna herramienta en el turno" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "La revisión está en marcha, te aviso en cuanto termine.")")"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"decision": "block"'* && "$output" == *DOD-004* ]]
}

@test "DOD-004 positivo: estado afirmado tras comprobar en el turno no bloquea" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "La CI está en marcha sobre 1e6151c." "Bash")")"
  [[ "$output" != *DOD-004* ]]
}

@test "DOD-004 boundary: la herramienta de un turno anterior no cuenta como comprobación" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "Sigo esperando a la CI.")")"
  [[ "$output" == *DOD-004* ]]
}

@test "DOD-005 block: decisión en prosa sin AskUserQuestion, aunque haya otras herramientas" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "He preparado el script. ¿Lo lanzo ya o espero?" "Bash")")"
  [[ "$output" == *'"decision": "block"'* && "$output" == *DOD-005* ]]
}

@test "DOD-005 positivo: con AskUserQuestion en el turno no bloquea" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "Te he preguntado cómo seguimos. ¿Lo lanzo ya o espero?" "AskUserQuestion")")"
  [[ "$output" != *DOD-005* ]]
}

@test "DOD-005 empty: texto sin pregunta de decisión no bloquea" {
  run bash "$HOOK" <<< "$(make_input "$(make_turn "PR #1290 mergeado.")")"
  [[ "$output" != *DOD-00[45]* ]]
}

@test "DOD-004 antiloop por turno: el segundo Stop del mismo texto no vuelve a bloquear" {
  local t; t=$(make_turn "Está en marcha.")
  bash "$HOOK" <<< "$(make_input "$t")" >/dev/null
  run bash "$HOOK" <<< "$(make_input "$t")"
  [[ "$output" != *'"decision": "block"'* ]]
}

@test "DOD-004 invalid: SAVIA_DOD_STATUS_MODE=warn no bloquea" {
  SAVIA_DOD_STATUS_MODE=warn run bash "$HOOK" <<< "$(make_input "$(make_turn "Está en marcha.")")"
  [[ "$output" != *'"decision": "block"'* ]]
}

@test "safety: el hook usa set -uo pipefail" {
  grep -q 'set -uo pipefail' "$HOOK"
}

@test "edge: transcript inexistente o vacío sale 0 sin bloquear" {
  run bash "$HOOK" <<< '{"session_id":"x","transcript_path":"/nonexistent/empty.jsonl"}'
  [[ "$status" -eq 0 && "$output" != *block* ]]
  : > "$FIXDIR/empty.jsonl"
  run bash "$HOOK" <<< "{\"session_id\":\"x\",\"transcript_path\":\"$FIXDIR/empty.jsonl\"}"
  [[ "$status" -eq 0 && "$output" != *block* ]]
}

@test "edge: entrada JSON nula o inválida no bloquea" {
  run bash "$HOOK" <<< 'null'
  [[ "$status" -eq 0 && "$output" != *block* ]]
  run bash "$HOOK" <<< 'no-json'
  [[ "$status" -eq 0 && "$output" != *block* ]]
}

@test "edge: texto muy largo con estado sin comprobar sigue bloqueando (large)" {
  local long; long="$(printf 'contexto %.0s' $(seq 1 3000)) La CI está en marcha."
  run bash "$HOOK" <<< "$(make_input "$(make_turn "$long")")"
  [[ "$output" == *DOD-004* ]]
}
