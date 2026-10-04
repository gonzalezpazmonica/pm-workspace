#!/usr/bin/env bats
# SE-376 — dag-scheduling: comportamiento real del motor scripts/wave-executor.sh.
# Contrato: docs/specs/SPEC-WAVE-DAG.spec.md (RN-01..RN-11). Concurrencia por wave,
# códigos de salida, timeouts con kill-after, validación de entrada, limpieza de
# procesos hijos al interrumpir el motor.
# Ref: .claude/skills/dag-scheduling/SKILL.md · docs/propuestas/SE-376-debt-inventory.tsv
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="scripts/wave-executor.sh"
  SCRIPT="$REPO_ROOT/$SCRIPT"
  WORK="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  cd "$WORK" || return 1
  export WAVE_KILL_AFTER=1
  unset SDD_MAX_PARALLEL_AGENTS SDD_DEFAULT_TIMEOUT_MIN
  # duración única por test: permite localizar SOLO nuestros procesos
  # (PID del test + RANDOM: dos tests de suites paralelas no comparten valor)
  NAP="2$((RANDOM % 9)).$(( $$ % 100000 ))$((RANDOM))7"
}

teardown() {
  pkill -KILL -x -f "sleep $NAP" 2>/dev/null || true
  cd "$REPO_ROOT" || true
}

graph() { printf '%s' "$1" > "$WORK/g.json"; }
we() { run bash "$SCRIPT" "$WORK/g.json" "$@"; }
# Aserción: una función que falla sí rompe el test; un `! cmd` intermedio en bats no.
no_orphans() {
  if pgrep -x -f "sleep $NAP" >/dev/null; then echo "quedan procesos sleep $NAP" >&2; return 1; fi
}

@test "safety: cargar la librería activa set -uo pipefail (nounset y pipefail on)" {
  run bash -c 'set +uo pipefail; source "$1"; [[ -o nounset && -o pipefail ]]' _ "$REPO_ROOT/scripts/wave-executor-lib.sh"
  [ "$status" -eq 0 ]
  # el motor no depende de -e: una variable no definida aborta en vez de seguir
  run bash -c 'source "$1"; echo "$NO_DEFINIDA_SE376"' _ "$REPO_ROOT/scripts/wave-executor-lib.sh"
  [ "$status" -ne 0 ]
}

# ── waves y paralelismo ─────────────────────────────────────────────────────

@test "compute_waves: diamante A→B,C→D da 3 waves y respeta el orden" {
  graph '{"tasks":[{"id":"A","command":"echo a >>order","depends_on":[]},
    {"id":"B","command":"echo b >>order","depends_on":["A"]},
    {"id":"C","command":"echo c >>order","depends_on":["A"]},
    {"id":"D","command":"echo d >>order","depends_on":["B","C"]}]}'
  we
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 3 and .waves[2].tasks[0].id == "D"'
  [ "$(head -1 order)" = "a" ]
  [ "$(tail -1 order)" = "d" ]
}

@test "paralelo: dos tareas de la misma wave corren a la vez, no en serie" {
  graph '{"tasks":[{"id":"x","command":"sleep 1","depends_on":[]},{"id":"y","command":"sleep 1","depends_on":[]}]}'
  local t0=$SECONDS
  we
  [ "$status" -eq 0 ]
  [ $((SECONDS - t0)) -le 2 ]
}

@test "max_parallel: 5 tareas con max 2 se parten en 3 sub-waves" {
  graph '{"max_parallel":2,"tasks":[{"id":"a","command":"true","depends_on":[]},{"id":"b","command":"true","depends_on":[]},
    {"id":"c","command":"true","depends_on":[]},{"id":"d","command":"true","depends_on":[]},{"id":"e","command":"true","depends_on":[]}]}'
  we
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 3 and ([.waves[].tasks | length] | max) == 2'
}

@test "max_parallel: sin campo en el grafo se usa SDD_MAX_PARALLEL_AGENTS" {
  export SDD_MAX_PARALLEL_AGENTS=1
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[]},{"id":"b","command":"true","depends_on":[]}]}'
  we
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 2'
}

@test "max_parallel: 0 o no numérico es invalid (exit 2), no un éxito sin ejecutar nada" {
  graph '{"max_parallel":0,"tasks":[{"id":"a","command":"touch ran","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
  [ ! -e ran ]
  graph '{"max_parallel":"x","tasks":[{"id":"a","command":"touch ran","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
  [ ! -e ran ]
}

# ── códigos de salida ───────────────────────────────────────────────────────

@test "exit: una tarea fallida da exit 1 y las waves siguientes quedan skipped" {
  graph '{"tasks":[{"id":"bad","command":"exit 7","depends_on":[]},{"id":"next","command":"touch ran","depends_on":["bad"]}]}'
  we
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.status == "failed" and .waves[0].tasks[0].exit_code == 7'
  echo "$output" | jq -e '.waves[1].tasks[0].status == "skipped"'
  [ ! -e ran ]
}

@test "exit: una tarea que sale con 124 por sí misma es failed, no timeout" {
  graph '{"tasks":[{"id":"e","command":"exit 124","depends_on":[],"timeout_seconds":60}]}'
  we
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.waves[0].tasks[0].status == "failed" and .waves[0].tasks[0].exit_code == 124'
}

@test "exit: --report escribe el informe en el fichero y no en stdout" {
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[]}]}'
  we --report "$WORK/r.json"
  [ "$status" -eq 0 ]
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["status"]=="success"' "$WORK/r.json"
  [ -z "$output" ]
}

# ── timeouts y limpieza de procesos ─────────────────────────────────────────

@test "timeout: la tarea vencida da exit 3, estado timeout y no deja nietos vivos" {
  graph "{\"tasks\":[{\"id\":\"slow\",\"command\":\"sleep $NAP & sleep $NAP\",\"depends_on\":[],\"timeout_seconds\":1}]}"
  we
  [ "$status" -eq 3 ]
  echo "$output" | jq -e '.waves[0].tasks[0].status == "timeout"'
  sleep 0.3
  no_orphans
}

@test "timeout: una tarea que ignora SIGTERM no cuelga el motor (kill-after)" {
  graph "{\"tasks\":[{\"id\":\"stub\",\"command\":\"trap '' TERM; sleep $NAP\",\"depends_on\":[],\"timeout_seconds\":1}]}"
  local t0=$SECONDS
  run timeout 15 bash "$SCRIPT" "$WORK/g.json"
  [ "$status" -eq 3 ]
  [ $((SECONDS - t0)) -le 6 ]
  sleep 0.3
  no_orphans
}

@test "timeout: sin timeout_seconds se aplica SDD_DEFAULT_TIMEOUT_MIN (1 min = 60 s)" {
  # timeout instrumentado: registra sus argumentos y delega en el real
  local real; real=$(command -v timeout)
  mkdir -p "$WORK/bin"
  printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "timeout (GNU coreutils) stub"; exit 0; }\necho "$*" >> "%s/timeout.args"\nexec "%s" "$@"\n' "$WORK" "$real" > "$WORK/bin/timeout"
  chmod +x "$WORK/bin/timeout"
  export SDD_DEFAULT_TIMEOUT_MIN=1
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[]},{"id":"b","command":"true","depends_on":[],"timeout_seconds":7}]}'
  PATH="$WORK/bin:$PATH" we
  [ "$status" -eq 0 ]
  grep -qx -- '-k 1 60 bash -c true' "$WORK/timeout.args"
  grep -qx -- '-k 1 7 bash -c true' "$WORK/timeout.args"
  [ "$(wc -l < "$WORK/timeout.args")" -eq 2 ]
}

@test "timeout: SDD_DEFAULT_TIMEOUT_MIN=0 es invalid (no se lanza nada con timeout 0)" {
  export SDD_DEFAULT_TIMEOUT_MIN=0
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
}

@test "señal: si el motor recibe SIGTERM mata las tareas en curso (no quedan huérfanas)" {
  graph "{\"tasks\":[{\"id\":\"long\",\"command\":\"sleep $NAP & sleep $NAP\",\"depends_on\":[]}]}"
  bash "$SCRIPT" "$WORK/g.json" >/dev/null 2>&1 &
  local ep=$! i
  for i in $(seq 1 50); do pgrep -x -f "sleep $NAP" >/dev/null && break; sleep 0.1; done
  local t0=$SECONDS rc=0
  kill -TERM "$ep"
  wait "$ep" || rc=$?
  # matar, no esperar: las tareas duermen ~20 s; el motor debe salir en segundos
  [ $((SECONDS - t0)) -le 3 ]
  [ "$rc" -eq 143 ]
  sleep 0.5
  no_orphans
}

# ── validación de entrada (RN-01..RN-03 y contrato de campos) ───────────────

@test "validate_graph: id con espacios es invalid (no se parte en dos tareas)" {
  graph '{"tasks":[{"id":"a b","command":"touch ran","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
  [ ! -e ran ]
}

@test "validate_graph: tarea sin command es invalid (exit 2)" {
  graph '{"tasks":[{"id":"a","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
}

@test "validate_graph: timeout_seconds no numérico o 0 es invalid (exit 2)" {
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[],"timeout_seconds":"x"}]}'
  we
  [ "$status" -eq 2 ]
  graph '{"tasks":[{"id":"a","command":"true","depends_on":[],"timeout_seconds":0}]}'
  we
  [ "$status" -eq 2 ]
}

@test "validate_graph: JSON sin array tasks es invalid, no un éxito vacío" {
  graph '{}'
  we
  [ "$status" -eq 2 ]
  graph '{"tasks":"x"}'
  we
  [ "$status" -eq 2 ]
}

@test "validate_graph: nivel superior que no es objeto ([], \"x\", 3, null) es invalid, no success" {
  local g
  for g in '[]' '"x"' '3' 'null' '[{"tasks":[]}]'; do
    graph "$g"
    we
    [ "$status" -eq 2 ]
    [[ "$output" != *success* ]]
    [[ "$output" == *"graph must be an object"* ]]
  done
}

@test "validate_graph: si jq falla en la validación de esquema el grafo es invalid (fail-closed)" {
  # jq instrumentado: rompe solo el filtro de esquema (p. ej. un jq antiguo sin un builtin)
  local real; real=$(command -v jq)
  mkdir -p "$WORK/bin"
  printf '#!/usr/bin/env bash\ncase "$*" in *"def posint"*) echo "jq: error: simulated" >&2; exit 5;; esac\nexec "%s" "$@"\n' "$real" > "$WORK/bin/jq"
  chmod +x "$WORK/bin/jq"
  graph '{"tasks":[{"id":"a","command":"touch ran","depends_on":[]}]}'
  PATH="$WORK/bin:$PATH" we
  [ "$status" -eq 2 ]
  [ ! -e ran ]
  [[ "$output" == *"schema check failed"* ]]
}

@test "validate_graph: fichero empty o con dos documentos JSON es invalid (exit 2), no success" {
  local g
  for g in '' '   ' '{"tasks":[]} {"tasks":[]}'; do
    graph "$g"
    we
    [ "$status" -eq 2 ]
    [[ "$output" != *success* ]]
  done
}

@test "validate_graph: depends_on ausente equivale a [] (wave 0)" {
  graph '{"tasks":[{"id":"a","command":"true"},{"id":"b","command":"true","depends_on":["a"]}]}'
  we
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 2 and .waves[0].tasks[0].id == "a"'
}

@test "validate_graph: ciclo, dependencia desconocida e id duplicado son exit 2 sin ejecutar" {
  graph '{"tasks":[{"id":"a","command":"touch ran","depends_on":["b"]},{"id":"b","command":"touch ran","depends_on":["a"]}]}'
  we
  [ "$status" -eq 2 ]
  [[ "$output" == *"cycle detected"* ]]
  graph '{"tasks":[{"id":"a","command":"touch ran","depends_on":["zz"]}]}'
  we
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown dependency: zz"* ]]
  graph '{"tasks":[{"id":"a","command":"touch ran","depends_on":[]},{"id":"a","command":"touch ran","depends_on":[]}]}'
  we
  [ "$status" -eq 2 ]
  [ ! -e ran ]
}

@test "verify_expected_files: fichero esperado ausente marca failed; con .. es invalid" {
  graph '{"tasks":[{"id":"g","command":"true","depends_on":[],"expected_files":["no-existe.txt"]}]}'
  we
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.waves[0].tasks[0].expected_files_present == false'
  graph '{"tasks":[{"id":"g","command":"true","depends_on":[],"expected_files":["../fuera.txt"]}]}'
  we
  [ "$status" -eq 2 ]
}

@test "args: --report sin valor y flag desconocido son error de uso (exit 2)" {
  graph '{"tasks":[]}'
  we --report
  [ "$status" -eq 2 ]
  [[ "$output" != *"sin asignar"* && "$output" != *"unbound"* ]]
  we --bogus
  [ "$status" -eq 2 ]
}

@test "edge: grafo empty da success con 0 waves (RN-11)" {
  graph '{"tasks":[]}'
  we
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "success" and .total_waves == 0'
}

@test "detect_timeout_cmd: el motor encuentra timeout de coreutils en Linux" {
  source "$REPO_ROOT/scripts/wave-executor-lib.sh"
  run detect_timeout_cmd
  [ "$status" -eq 0 ]
  [[ "$output" == *timeout ]]
}
