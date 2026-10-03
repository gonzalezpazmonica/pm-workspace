#!/usr/bin/env bats
# test-bus-factor-analysis.bats — calibracion SE-376 de la skill bus-factor-analysis
# Ref: docs/rules/domain/bus-factor-protocol.md
# Ref: .claude/skills/bus-factor-analysis/DOMAIN.md (algoritmo CST + set cover 50%)
# Repos git sinteticos con autores y commits controlados: el bus factor
# esperado se conoce de antemano.

SCRIPT="scripts/bus-factor-scan.py"
SCAN_SH="scripts/bus-factor-scan.sh"
REPORT_SH="scripts/bus-factor-report.sh"
DIST_SH="scripts/bus-factor-distribute.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PY="$REPO_ROOT/$SCRIPT"
  TMPDIR_TEST="$(mktemp -d)"
  export BF_OUTPUT_DIR="$TMPDIR_TEST/out"
  export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/ws"
  mkdir -p "$BF_OUTPUT_DIR" "$CLAUDE_PROJECT_DIR"
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && rm -rf "$TMPDIR_TEST"
}

# mkrepo <dir>: repo vacio con rama main
mkrepo() {
  mkdir -p "$1"
  git -C "$1" init -q -b main
}

# commit_as <repo> <nombre> <email> <fichero> <lineas>
commit_as() {
  local repo="$1" name="$2" email="$3" file="$4" n="$5" i
  mkdir -p "$(dirname "$repo/$file")"
  for ((i = 1; i <= n; i++)); do echo "$name linea $i $RANDOM" >> "$repo/$file"; done
  git -C "$repo" add -A
  git -C "$repo" -c user.name="$name" -c user.email="$email" commit -q -m "cambio $file"
}

# scan <repo>: ejecuta el motor y deja el JSON en $TMPDIR_TEST/scan.json
scan() {
  python3 "$PY" "$@" > "$TMPDIR_TEST/scan.json"
}

# jq_py <expr>: evalua una expresion python sobre el JSON (variable d)
jq_py() {
  python3 -c "import json; d=json.load(open('$TMPDIR_TEST/scan.json')); print($1)"
}

# ── Contrato basico ──────────────────────────────────────────────────────────

@test "target scripts tienen set -uo pipefail" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCAN_SH"
  grep -q "set -uo pipefail" "$REPO_ROOT/$REPORT_SH"
  grep -q "set -uo pipefail" "$REPO_ROOT/$DIST_SH"
}

@test "un solo autor: modulo BF=1 CRITICAL con owner unico" {
  local r="$TMPDIR_TEST/solo"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/a.py 10
  commit_as "$r" Ana ana@corp.example src/m/b.py 10
  scan "$r"
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "1" ]
  [ "$(jq_py "d['modules'][0]['risk_level']")" = "CRITICAL" ]
  [ "$(jq_py "[o['dev'] for o in d['modules'][0]['owners']]")" = "['ana@corp.example']" ]
}

@test "definicion documentada: 4 ficheros con 4 owners distintos dan BF=2 (cubrir 50%)" {
  local r="$TMPDIR_TEST/cuatro"; mkrepo "$r"
  for p in a b c d; do commit_as "$r" "Dev$p" "$p@corp.example" "src/m/$p.py" 10; done
  scan "$r"
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "2" ]
  [ "$(jq_py "d['modules'][0]['risk_level']")" = "HIGH" ]
}

@test "boundary large: 8 ficheros con 8 owners dan BF=4 y riesgo LOW" {
  local r="$TMPDIR_TEST/ocho"; mkrepo "$r"
  for p in a b c d e f g h; do commit_as "$r" "Dev$p" "$p@corp.example" "src/m/$p.py" 3; done
  scan "$r"
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "4" ]
  [ "$(jq_py "d['summary']['low']")" = "1" ]
}

# ── Identidad de autores ────────────────────────────────────────────────────

@test "mailmap: dos emails de la misma persona cuentan como un solo autor" {
  local r="$TMPDIR_TEST/mailmap"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/a.py 10
  commit_as "$r" Ana ana.casa@home.example src/m/a.py 10
  commit_as "$r" Bob bob@corp.example src/m/a.py 15
  printf 'Ana <ana@corp.example> <ana.casa@home.example>\n' > "$r/.mailmap"
  git -C "$r" add .mailmap
  git -C "$r" -c user.name=Ana -c user.email=ana@corp.example commit -q -m mailmap
  scan "$r"
  # Ana suma 20 de 35 cambios (0.57): owner claro; sin mailmap ganaba Bob con 0.43
  [ "$(jq_py "[o['dev'] for m in d['modules'] if m['name']=='src/m' for f in m['files'] for o in f['owners']]")" = "['ana@corp.example']" ]
  [ "$(jq_py "[w for m in d['modules'] if m['name']=='src/m' for f in m['files'] for w in f['warnings']]")" = "[]" ]
}

@test "falso positivo de bot rechazado: email humano terminado en ci@ se cuenta" {
  local r="$TMPDIR_TEST/marci"; mkrepo "$r"
  commit_as "$r" Marci marci@corp.example src/m/a.py 10
  scan "$r"
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "1" ]
  [ "$(jq_py "d['modules'][0]['owners'][0]['dev']")" = "marci@corp.example" ]
}

@test "humano con email noreply de GitHub se cuenta y el bot dependabot se excluye" {
  local r="$TMPDIR_TEST/noreply"; mkrepo "$r"
  commit_as "$r" Gh "12345+gh@users.noreply.github.com" src/m/a.py 10
  commit_as "$r" "dependabot[bot]" "49699333+dependabot[bot]@users.noreply.github.com" src/m/a.py 50
  scan "$r"
  [ "$(jq_py "[o['dev'] for o in d['modules'][0]['files'][0]['owners']]")" = "['12345+gh@users.noreply.github.com']" ]
  [ "$(jq_py "d['modules'][0]['files'][0]['owners'][0]['score']")" = "1.0" ]
}

@test "merge: el autor del commit de merge no se convierte en owner" {
  local r="$TMPDIR_TEST/merge" wt="$TMPDIR_TEST/merge-wt"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/a.py 10
  git -C "$r" worktree add -q -b feat "$wt"
  commit_as "$wt" Bob bob@corp.example src/m/b.py 20
  commit_as "$r" Ana ana@corp.example src/m/c.py 5
  git -C "$r" -c user.name=Merger -c user.email=merger@corp.example merge -q --no-ff feat -m merge
  scan "$r"
  [ "$(jq_py "sorted({o['dev'] for f in d['modules'][0]['files'] for o in f['owners']})")" = "['ana@corp.example', 'bob@corp.example']" ]
}

# ── Rutas ───────────────────────────────────────────────────────────────────

@test "fichero renombrado conserva el historial del autor original" {
  local r="$TMPDIR_TEST/rename"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/viejo.py 30
  git -C "$r" mv src/m/viejo.py src/m/nuevo.py
  commit_as "$r" Bob bob@corp.example src/m/nuevo.py 5
  scan "$r"
  [ "$(jq_py "d['modules'][0]['files'][0]['owners'][0]['dev']")" = "ana@corp.example" ]
}

@test "rutas con espacios se agrupan y tienen historial" {
  local r="$TMPDIR_TEST/espacios"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example "src/mi modulo/a b.py" 10
  scan "$r"
  [ "$(jq_py "d['modules'][0]['name']")" = "src/mi modulo" ]
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "1" ]
}

@test "rutas no ASCII no se rompen por el quoting de git (invalid module name)" {
  local r="$TMPDIR_TEST/unicode"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example "src/m/ñandú.py" 10
  scan "$r"
  [ "$(jq_py "d['modules'][0]['name']")" = "src/m" ]
  [ "$(jq_py "d['modules'][0]['files'][0]['path']")" = "src/m/ñandú.py" ]
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "1" ]
}

@test "escanear un subdirectorio de un repo encuentra el historial" {
  local r="$TMPDIR_TEST/subdir"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example app/src/m/a.py 10
  scan "$r/app"
  [ "$(jq_py "d['modules'][0]['name']")" = "src/m" ]
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "1" ]
}

# ── Repos vacios y errores ──────────────────────────────────────────────────

@test "empty: repo sin commits devuelve JSON valido, exit 0 y no_tracked_files" {
  local r="$TMPDIR_TEST/vacio"; mkrepo "$r"
  run python3 "$PY" "$r"
  [ "$status" -eq 0 ]
  echo "$output" > "$TMPDIR_TEST/scan.json"
  [ "$(jq_py "d['warnings']")" = "['no_tracked_files']" ]
  [ "$(jq_py "d['summary']['total_modules']")" = "0" ]
}

@test "zero history: ficheros sin commits no se clasifican CRITICAL sino UNKNOWN" {
  local r="$TMPDIR_TEST/staged"; mkrepo "$r"
  mkdir -p "$r/src/m"; echo x > "$r/src/m/a.py"; git -C "$r" add -A
  scan "$r"
  [ "$(jq_py "d['modules'][0]['bus_factor']")" = "0" ]
  [ "$(jq_py "d['modules'][0]['risk_level']")" = "UNKNOWN" ]
  [ "$(jq_py "d['summary']['critical']")" = "0" ]
  [ "$(jq_py "d['summary']['unknown']")" = "1" ]
}

@test "error: directorio que no es repo git falla con exit 1" {
  mkdir -p "$TMPDIR_TEST/plain"
  run python3 "$PY" "$TMPDIR_TEST/plain"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no es un repositorio git"* ]]
}

@test "error: directorio inexistente falla con exit 1" {
  run python3 "$PY" "$TMPDIR_TEST/no-existe"
  [ "$status" -eq 1 ]
}

@test "sin DeprecationWarning en stderr y generated_at en UTC con sufijo Z" {
  local r="$TMPDIR_TEST/ts"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/a.py 3
  run python3 -W error::DeprecationWarning "$PY" "$r"
  [ "$status" -eq 0 ]
  echo "$output" > "$TMPDIR_TEST/scan.json"
  [[ "$(jq_py "d['generated_at']")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$ ]]
}

# ── Wrapper scan.sh ─────────────────────────────────────────────────────────

@test "scan.sh rechaza --format distinto de json (invalid)" {
  local r="$TMPDIR_TEST/fmt"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example a.py 1
  run bash "$REPO_ROOT/$SCAN_SH" --project "$r" --format xml
  [ "$status" -eq 1 ]
}

@test "scan.sh propaga el fallo del motor y no anuncia un output inexistente" {
  local r="$TMPDIR_TEST/fail"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example a.py 1
  touch "$TMPDIR_TEST/soy-fichero"
  run bash "$REPO_ROOT/$SCAN_SH" --project "$r" --output "$TMPDIR_TEST/soy-fichero/x.json"
  [ "$status" -ne 0 ]
  [[ "$output" != *"output escrito"* ]]
}

# ── report.sh y distribute.sh ───────────────────────────────────────────────

@test "report rechaza usar el scan de otro proyecto (no fallback cruzado)" {
  echo '{"project":"otro","modules":[],"summary":{}}' > "$BF_OUTPUT_DIR/otro-20261003T000000Z.json"
  run bash "$REPO_ROOT/$REPORT_SH" --project "$TMPDIR_TEST/foo" --format json
  [ "$status" -eq 1 ]
  [[ "$output" != *'"otro"'* ]]
}

@test "report no confunde app con app-backend (prefijo comun)" {
  echo '{"project":"app","modules":[],"summary":{}}' > "$BF_OUTPUT_DIR/app-20261001T000000Z.json"
  echo '{"project":"app-backend","modules":[],"summary":{}}' > "$BF_OUTPUT_DIR/app-backend-20261003T000000Z.json"
  touch -d '2026-10-01' "$BF_OUTPUT_DIR/app-20261001T000000Z.json"
  run bash "$REPO_ROOT/$REPORT_SH" --project "$TMPDIR_TEST/app" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"project": "app"'* ]]
}

@test "report falla con exit != 0 ante JSON invalido" {
  echo 'no es json' > "$BF_OUTPUT_DIR/roto-20261003T000000Z.json"
  run bash "$REPO_ROOT/$REPORT_SH" --project "$TMPDIR_TEST/roto"
  [ "$status" -ne 0 ]
}

@test "report rechaza un --format desconocido" {
  echo '{"project":"ok","modules":[],"summary":{}}' > "$BF_OUTPUT_DIR/ok-20261003T000000Z.json"
  run bash "$REPO_ROOT/$REPORT_SH" --project "$TMPDIR_TEST/ok" --format pdf
  [ "$status" -eq 1 ]
}

@test "distribute falla con exit != 0 ante JSON invalido" {
  echo '{roto' > "$BF_OUTPUT_DIR/roto-20261003T000000Z.json"
  run bash "$REPO_ROOT/$DIST_SH" --project "$TMPDIR_TEST/roto" --target ana@corp.example
  [ "$status" -ne 0 ]
}

@test "pipeline real: scan.sh + report.sh muestran UNKNOWN y CRITICAL por separado" {
  local r="$TMPDIR_TEST/pipe"; mkrepo "$r"
  commit_as "$r" Ana ana@corp.example src/m/a.py 5
  mkdir -p "$r/lib/x"; echo y > "$r/lib/x/b.py"; git -C "$r" add -A
  run bash "$REPO_ROOT/$SCAN_SH" --project "$r"
  [ "$status" -eq 0 ]
  run bash "$REPO_ROOT/$REPORT_SH" --project "$r" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"unknown": 1'* ]]
  [[ "$output" == *'"critical": 1'* ]]
}
