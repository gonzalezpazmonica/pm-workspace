#!/usr/bin/env bats
# test-meta-reflection.bats — calibración SE-376 de la skill meta-reflection.
# Ejercita los scripts reales del Criterion Simulation Layer que gobiernan
# FRAME_DOUBT / FRAME_REJECT: trigger-evaluator, historical-priors,
# operator-state-signals y reaffirmation-log.
# Ref: docs/propuestas/SPEC-194-criterion-simulation-layer.md
# Ref: .claude/skills/meta-reflection/SKILL.md

bats_require_minimum_version 1.5.0

SCRIPT="scripts/criterion-simulation/trigger-evaluator.py"
HOOK=".claude/hooks/criterion-simulation-challenge.sh"
CS_DIR="scripts/criterion-simulation"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR_T="$(mktemp -d)"
  WS="$TMPDIR_T/work space"          # ruta con espacios
  mkdir -p "$WS/output/criterion-simulation"
  export CLAUDE_PROJECT_DIR="$WS"
  export SAVIA_KG_DB="$WS/kg dir/graph.db"
  export SAVIA_CS_REAFFIRMATION_LOG="$WS/output/criterion-simulation/reaffirmations.jsonl"
  export HOME="$TMPDIR_T/home"
  mkdir -p "$HOME/.savia"
  unset SAVIA_CS_TRIGGER_THRESHOLD SAVIA_CS_LOOKBACK_DAYS SAVIA_CS_FATIGUE_HOUR_BAND
  cd "$REPO_ROOT"
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# Crea el KG con el esquema real (kg-schema-migrate-cs.py) y N filas.
# Uso: make_kg <dias_atras> <verdict> <tags> [repeticiones]
make_kg() {
  mkdir -p "$(dirname "$SAVIA_KG_DB")"
  python3 scripts/kg-schema-migrate-cs.py --db "$SAVIA_KG_DB" >/dev/null
  python3 - "$SAVIA_KG_DB" "$1" "$2" "$3" "${4:-1}" <<'PY'
import sqlite3, sys
from datetime import datetime, timedelta, timezone
db, days, verdict, tags, n = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], int(sys.argv[5])
conn = sqlite3.connect(db)
for i in range(n):
    ts = (datetime.now(tz=timezone.utc) - timedelta(days=days, minutes=i)).isoformat()
    conn.execute("INSERT INTO frame_reaffirmations(task_id, ts, reason, verdict_before, tags) VALUES (?,?,?,?,?)",
                 (f"TASK-{days}-{i}", ts, "frame revertido", verdict, tags))
conn.commit()
PY
}

# Carga un módulo con guion por ruta y evalúa una expresión.
pyeval() {
  python3 - "$REPO_ROOT/$CS_DIR/$1" "$2" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(json.dumps(eval(sys.argv[2], {"m": m})))
PY
}

json_get() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {'d': d}))" "$1"
}

# ── Seguridad del punto de entrada bash ───────────────────────────────────────

@test "hook de entrada declara set -uo pipefail" {
  run grep -c '^set -uo pipefail' "$HOOK"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── historical-priors.py (Q2) ─────────────────────────────────────────────────

@test "historical-priors: KG nonexistent devuelve count 0 y exit 0" {
  run python3 "$CS_DIR/historical-priors.py" --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "0" ]
}

@test "historical-priors: 3 reverts similares en 90 dias se citan (AC6)" {
  make_kg 5 FRAME_DOUBT "security,auth" 3
  run python3 "$CS_DIR/historical-priors.py" --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "3" ]
  [[ "$output" == *"TASK-5-0"* ]]
}

@test "historical-priors: --db con ruta con espacios y get_recent_failed_frames por stdin" {
  make_kg 1 FRAME_REJECT "production" 2
  run bash -c "echo '{\"touches_production\": true}' | python3 '$CS_DIR/historical-priors.py' --db '$SAVIA_KG_DB'"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "2" ]
}

@test "historical-priors: boundary de lookback excluye filas antiguas" {
  make_kg 100 FRAME_DOUBT "security" 2
  make_kg 10 FRAME_DOUBT "security" 1
  run python3 "$CS_DIR/historical-priors.py" --lookback 90 --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "1" ]
}

@test "historical-priors: reject FRAME_OK y tags ajenos" {
  make_kg 3 FRAME_OK "security" 2
  make_kg 3 FRAME_DOUBT "frontend" 2
  run python3 "$CS_DIR/historical-priors.py" --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "0" ]
}

@test "historical-priors: tag con guion bajo no actua como comodin LIKE" {
  make_kg 3 FRAME_DOUBT "humanXsafety" 2
  run pyeval historical-priors.py 'm._extract_tags({"touches_human_safety": True})'
  [[ "$output" == *"human_safety"* ]]
  run python3 "$CS_DIR/historical-priors.py" --task-json '{"touches_human_safety": true}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "0" ]
}

@test "historical-priors: invalid SAVIA_CS_LOOKBACK_DAYS degrada con graceful default" {
  make_kg 5 FRAME_DOUBT "security" 1
  SAVIA_CS_LOOKBACK_DAYS=abc run --separate-stderr python3 "$CS_DIR/historical-priors.py" --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"SAVIA_CS_LOOKBACK_DAYS"* ]]
  [ "$(echo "$output" | json_get 'd["count"]')" = "1" ]
}

@test "historical-priors: KG corrupto devuelve empty sin error" {
  mkdir -p "$(dirname "$SAVIA_KG_DB")"
  printf 'esto no es sqlite' > "$SAVIA_KG_DB"
  run --separate-stderr python3 "$CS_DIR/historical-priors.py" --task-json '{}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["count"]')" = "0" ]
  [[ "$stderr" == *"KG no legible"* ]]
}

# ── trigger-evaluator.py: integración real de señales ─────────────────────────

@test "trigger: _load_sibling carga historical-priors y should_activate integra priors (>=2 reverts +20)" {
  make_kg 2 FRAME_DOUBT "security" 2
  run python3 "$SCRIPT" --task-json '{"tags":["security"]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["priors"]["count"]')" = "2" ]
  [[ "$output" == *"2 similar reverts"* ]]
}

@test "trigger: should_activate integra operator state real (override_rate)" {
  for i in 1 2 3; do
    python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task "T$i" --reason "revisado con dependencias y riesgos" >/dev/null
  done
  run python3 "$SCRIPT" --task-json '{}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["operator_state"]["override_rate"]')" = "20" ]
}

@test "trigger: security + human_safety cap at 100 y activa" {
  run python3 "$SCRIPT" --task-json '{"touches_security":true,"touches_human_safety":true,"touches_production":true,"estimated_hours":40}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["score"]')" = "100" ]
  [ "$(echo "$output" | json_get 'd["activate"]')" = "True" ]
}

@test "trigger: main rechaza JSON no objeto con error JSON y sin traceback" {
  run bash -c "echo '[1,2]' | python3 '$SCRIPT'"
  [ "$status" -ne 0 ]
  [[ "$output" == *'"error"'* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "trigger: JSON invalid devuelve exit 1 y activate false" {
  run python3 "$SCRIPT" --task-json '{no json'
  [ "$status" -eq 1 ]
  [ "$(echo "$output" | json_get 'd["activate"]')" = "False" ]
}

@test "trigger: _env_int con invalid SAVIA_CS_TRIGGER_THRESHOLD no rompe y usa 50" {
  SAVIA_CS_TRIGGER_THRESHOLD=alto run --separate-stderr python3 "$SCRIPT" --task-json '{"touches_security":true,"touches_production":true}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["activate"]')" = "True" ]
}

@test "trigger: empty context con estimated_hours no numerico da score bajo" {
  run python3 "$SCRIPT" --task-json '{"estimated_hours":"mucho"}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["activate"]')" = "False" ]
}

# ── operator-state-signals.py (Q3) ────────────────────────────────────────────

@test "operator-state: _compute_override_rate zero cuando solo hay reframes" {
  for i in 1 2 3; do
    python3 "$CS_DIR/reaffirmation-log.py" reframe --task "T$i" --new-statement "acotar al servicio de auth" >/dev/null
  done
  run python3 "$CS_DIR/operator-state-signals.py"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["override_rate"]')" = "0" ]
}

@test "operator-state: override_rate proporcional reaffirm frente a reframe" {
  python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task A --reason "revisado con dependencias y riesgos" >/dev/null
  python3 "$CS_DIR/reaffirmation-log.py" reframe --task B --new-statement "nuevo enunciado acotado" >/dev/null
  run pyeval operator-state-signals.py 'm._compute_override_rate()'
  [ "$output" = "10" ]
}

@test "operator-state: override_rate ignora entradas fuera de 90 dias" {
  printf '{"type":"reaffirm","ts":"2020-01-01T00:00:00+00:00"}\n' > "$SAVIA_CS_REAFFIRMATION_LOG"
  run pyeval operator-state-signals.py 'm._compute_override_rate()'
  [ "$output" = "0" ]
}

@test "operator-state: _compute_fatigue_score transicion cruza medianoche (boundary)" {
  export SAVIA_CS_FATIGUE_HOUR_BAND="01:00-03:00"
  run pyeval operator-state-signals.py 'm._compute_fatigue_score(23)'
  [ "$output" = '[15, "transition"]' ]
  run pyeval operator-state-signals.py 'm._compute_fatigue_score(2)'
  [ "$output" = '[30, "atypical"]' ]
  run pyeval operator-state-signals.py 'm._compute_fatigue_score(12)'
  [ "$output" = '[0, "normal"]' ]
}

@test "operator-state: _parse_hour_band invalid cae a 22-06 y _is_in_hour_band envuelve" {
  run pyeval operator-state-signals.py 'm._parse_hour_band("basura")'
  [ "$output" = "[22, 6]" ]
  run pyeval operator-state-signals.py '[m._is_in_hour_band(h, 22, 6) for h in (23, 3, 12)]'
  [ "$output" = "[true, true, false]" ]
}

@test "operator-state: _read_deadline_proximity acepta coma decimal es_ES y comentario" {
  printf 'deadline_proximity: 0,5  # sprint cierra el viernes\n' > "$HOME/.savia/preferences.yaml"
  run python3 "$CS_DIR/operator-state-signals.py"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_get 'd["pressure_score"]')" = "10" ]
}

@test "operator-state: _compute_pressure_score cap at 20 y null da cero" {
  run pyeval operator-state-signals.py '[m._compute_pressure_score(None), m._compute_pressure_score(7), m._compute_pressure_score(-1)]'
  [ "$output" = "[0, 20, 0]" ]
}

@test "operator-state: compute_operator_state sin red ni preferencias" {
  run pyeval operator-state-signals.py 'sorted(m.compute_operator_state("x").keys())'
  [ "$output" = '["fatigue_score", "override_rate", "pressure_score", "time_band"]' ]
}

# ── reaffirmation-log.py (protocolo de replacement) ───────────────────────────

@test "reaffirm: cmd_reaffirm valido escribe JSONL y exit 0" {
  run python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task T-1 --reason "he revisado el encuadre con el equipo"
  [ "$status" -eq 0 ]
  run python3 -c "import json,sys; e=json.loads(open(sys.argv[1]).read().splitlines()[0]); assert e['type']=='reaffirm' and e['task_id']=='T-1'" "$SAVIA_CS_REAFFIRMATION_LOG"
  [ "$status" -eq 0 ]
}

@test "reaffirm: reject razon de solo espacios (empty tras strip) con exit 2" {
  run python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task T-1 --reason "                         "
  [ "$status" -eq 2 ]
  [ ! -s "$SAVIA_CS_REAFFIRMATION_LOG" ]
}

@test "reaffirm: reject razon corta rellenada con espacios (boundary 20)" {
  run python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task T-1 --reason "vale              ok"
  [ "$status" -eq 2 ]
}

@test "reaffirm: reject task id empty con exit 2" {
  run python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task "  " --reason "una razon suficientemente larga aqui"
  [ "$status" -eq 2 ]
  run python3 "$CS_DIR/reaffirmation-log.py" reframe --task "" --new-statement "nuevo enunciado"
  [ "$status" -eq 2 ]
}

@test "reframe: cmd_reframe valido y sin subcomando falla con exit 1" {
  run python3 "$CS_DIR/reaffirmation-log.py" reframe --task T-2 --new-statement "acotar a auth"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reframe"'* ]]
  run python3 "$CS_DIR/reaffirmation-log.py"
  [ "$status" -eq 1 ]
}

@test "reaffirm: large concurrencia de 20 escrituras deja 20 lineas JSON validas" {
  pids=()
  for i in $(seq 1 20); do
    python3 "$CS_DIR/reaffirmation-log.py" reaffirm --task "C$i" --reason "razon deliberada numero $i con contexto" >/dev/null &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p"; done
  run python3 -c "import json,sys; ls=open(sys.argv[1]).read().splitlines(); [json.loads(l) for l in ls]; print(len(ls))" "$SAVIA_CS_REAFFIRMATION_LOG"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]
}
