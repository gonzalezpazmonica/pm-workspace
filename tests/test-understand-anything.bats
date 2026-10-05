#!/usr/bin/env bats
# test-understand-anything.bats — SE-376: calibración de la skill understand-anything
# contra su comportamiento real (scripts/ua-bridge.sh y el fallback scripts/knowledge-graph.py).
# Ref: docs/specs/SPEC-SE-088-UA-ADOPT.spec.md
# Ref: docs/rules/domain/knowledge-graph.md
#
# Todo corre en mktemp -d: UA simulado con UA_AGENTS_DIR, opencode con un stub en PATH,
# memoria sintética vía PROJECT_ROOT/HOME. Nunca toca ~/.savia ni datos de la operadora.

bats_require_minimum_version 1.5.0

SCRIPT="scripts/ua-bridge.sh"
KG="scripts/knowledge-graph.py"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BRIDGE="$REPO_ROOT/$SCRIPT"
  KGPY="$REPO_ROOT/$KG"
  TMP="$(mktemp -d)"
  STUB="$TMP/stub bin"
  mkdir -p "$STUB" "$TMP/home" "$TMP/root/output" "$TMP/root/docs"
  # PATH mínimo: sin opencode ni understand-anything reales.
  SAFE_PATH="$STUB:/usr/bin:/bin"
  # UA "instalado" = directorio de skills presente.
  UA_ON="$TMP/ua skills"
  mkdir -p "$UA_ON"
  UA_OFF="$TMP/no-ua"
  STORE="$TMP/root/output/.memory-store.jsonl"
}

teardown() {
  rm -rf "$TMP"
}

# ── helpers ──────────────────────────────────────────────────────────────────

bridge() { # bridge <UA_DIR> <args...>
  local ua="$1"; shift
  env PATH="$SAFE_PATH" UA_AGENTS_DIR="$ua" bash "$BRIDGE" "$@"
}

kg() {
  env HOME="$TMP/home" PROJECT_ROOT="$TMP/root" python3 "$KGPY" "$@"
}

sql() { # sql <db> <query> — una fila por línea, columnas separadas por |
  python3 -c 'import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
for r in c.execute(sys.argv[2]): print("|".join(str(x) for x in r))' "$1" "$2"
}

mk_repo() {
  REPO="$TMP/repo with spaces"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@example.invalid
  git -C "$REPO" config user.name t
  echo a > "$REPO/a.txt"
  git -C "$REPO" add a.txt
  git -C "$REPO" commit -qm init
}

stub_opencode() { # stub_opencode <exit-code>
  cat > "$STUB/opencode" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/opencode-args"
exit $1
EOF
  chmod +x "$STUB/opencode"
}

# ── ua-bridge.sh: estructura ─────────────────────────────────────────────────

@test "bridge: script declara set -uo pipefail" {
  run grep -c '^set -uo pipefail' "$BRIDGE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── check ────────────────────────────────────────────────────────────────────

@test "check: UA ausente -> exit 1 y 'UA not installed'" {
  run bridge "$UA_OFF" check
  [ "$status" -eq 1 ]
  [ "$output" = "UA not installed" ]
}

@test "check: directorio de UA presente -> exit 0" {
  run bridge "$UA_ON" check
  [ "$status" -eq 0 ]
  [ "$output" = "UA available" ]
}

# ── diff ─────────────────────────────────────────────────────────────────────

@test "diff --count: cuenta ficheros staged (contrato del SKILL.md)" {
  mk_repo
  echo b > "$REPO/b.txt"; git -C "$REPO" add b.txt
  cd "$REPO"
  run bridge "$UA_ON" diff --count
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "diff --count: staged y unstaged del mismo fichero cuentan una vez (boundary)" {
  mk_repo
  echo b > "$REPO/b.txt"; git -C "$REPO" add b.txt
  echo c >> "$REPO/b.txt"
  echo z >> "$REPO/a.txt"
  cd "$REPO"
  run bridge "$UA_ON" diff --count
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "diff --count: árbol limpio devuelve zero" {
  mk_repo
  cd "$REPO"
  run bridge "$UA_ON" diff --count
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "diff --count: fuera de un repo git devuelve 0 y avisa en stderr" {
  mkdir -p "$TMP/norepo"; cd "$TMP/norepo"
  run --separate-stderr bridge "$UA_ON" diff --count
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
  [[ "$stderr" == *"not a git"* ]]
}

@test "diff --count: si git diff falla dentro del repo -> error, no recuento parcial" {
  mk_repo
  printf '#!/usr/bin/env bash\nif [ "$1" = diff ]; then echo boom >&2; exit 128; fi\nexec /usr/bin/git "$@"\n' > "$STUB/git"
  chmod +x "$STUB/git"
  cd "$REPO"
  run --separate-stderr bridge "$UA_ON" diff --count
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"git diff failed"* ]]
}

@test "diff --count: UA ausente devuelve 0 sin mirar git" {
  mk_repo
  echo b > "$REPO/b.txt"; git -C "$REPO" add b.txt
  cd "$REPO"
  run bridge "$UA_OFF" diff --count
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "diff sin --count: impacto pequeño sale con exit 0 (no exit 1 por el WARN)" {
  mk_repo
  echo z >> "$REPO/a.txt"
  cd "$REPO"
  run bridge "$UA_ON" diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"~1 files changed"* ]]
  [[ "$output" != *"WARN"* ]]
}

@test "diff sin --count: más de 50 ficheros (large) emite WARN y exit 0" {
  mk_repo
  for i in $(seq 1 51); do echo "$i" > "$REPO/f$i.txt"; done
  git -C "$REPO" add .
  cd "$REPO"
  run bridge "$UA_ON" diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN: >50"* ]]
}

@test "diff: argumento desconocido se rechaza con error" {
  run bridge "$UA_ON" diff --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# ── analyze / domain / onboard / chat ────────────────────────────────────────

@test "analyze: UA ausente -> exit 0 y mensaje 'not installed'" {
  run bridge "$UA_OFF" analyze "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UA not installed"* ]]
}

@test "analyze: nunca ejecuta knowledge-graph.py con bash (reject: Python como shell)" {
  # Si el bridge pasa el .py a bash, la línea 'import argparse' invoca el
  # binario 'import' (ImageMagick captura la pantalla). El stub lo delata.
  printf '#!/usr/bin/env bash\ntouch "%s/import-called"\n' "$TMP" > "$STUB/import"
  chmod +x "$STUB/import"
  run bridge "$UA_ON" analyze "$TMP"
  [ ! -e "$TMP/import-called" ]
}

@test "analyze: UA instalado sin opencode -> error explícito y exit no cero" {
  run bridge "$UA_ON" analyze "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"opencode not found"* ]]
}

@test "analyze: opencode falla -> exit no cero (no falso éxito)" {
  stub_opencode 3
  run bridge "$UA_ON" analyze "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed"* ]]
}

@test "analyze: opencode ok -> exit 0 y recibe la ruta con espacios intacta" {
  stub_opencode 0
  mkdir -p "$TMP/my project"
  run bridge "$UA_ON" analyze "$TMP/my project"
  [ "$status" -eq 0 ]
  run cat "$TMP/opencode-args"
  [ "${lines[0]}" = "run" ]
  [ "${lines[1]}" = "/ua-analyze $TMP/my project" ]
}

@test "analyze: ruta inexistente con UA instalado -> error exit 1 (invalid)" {
  stub_opencode 0
  run bridge "$UA_ON" analyze "$TMP/does-not-exist"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Path not found"* ]]
  [ ! -e "$TMP/opencode-args" ]
}

@test "domain: opencode falla -> exit no cero y sin flag --domain inexistente" {
  stub_opencode 1
  run bridge "$UA_ON" domain "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" != *"--domain"* ]]
}

@test "onboard: opencode ok -> exit 0" {
  stub_opencode 0
  run bridge "$UA_ON" onboard "$TMP"
  [ "$status" -eq 0 ]
  grep -q "/ua-onboard $TMP" "$TMP/opencode-args"
}

@test "chat: query vacía se rechaza con uso aunque UA no esté (empty)" {
  run bridge "$UA_OFF" chat
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── dispatch ─────────────────────────────────────────────────────────────────

@test "help explícito sale con exit 0" {
  run bridge "$UA_OFF" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Subcommands"* ]]
}

@test "sin argumentos (empty) -> uso y exit 1" {
  run bridge "$UA_OFF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "subcomando desconocido -> error exit 1" {
  run bridge "$UA_OFF" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand: frobnicate"* ]]
}

# ── knowledge-graph.py (fallback documentado) ────────────────────────────────

@test "kg build: líneas JSONL no-objeto y topic no-string no tumban el build" {
  printf '%s\n' '"just a string"' '[1,2]' 'null' '{"topic":5,"content":"x"}' \
    '{"topic":"ok-topic","content":"SPEC-101"}' > "$STORE"
  run kg build --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  run sql "$TMP/kg.db" "select count(*) from entities where name='ok-topic'"
  [ "$output" = "1" ]
}

@test "kg build: entrada con topic vacío no crea entidad de nombre empty" {
  printf '%s\n' '{"content":"SPEC-102 foo"}' '{"topic":"   ","content":"x"}' > "$STORE"
  run kg build --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  run sql "$TMP/kg.db" "select count(*) from entities where trim(name)=''"
  [ "$output" = "0" ]
}

@test "kg build: tipo 'bug' del store se mapea a memory_type error" {
  printf '%s\n' '{"topic":"crash-x","type":"bug","content":"x"}' \
    '{"topic":"pat-y","type":"pattern","content":"y"}' > "$STORE"
  kg build --db "$TMP/kg.db" >/dev/null
  run sql "$TMP/kg.db" "select memory_type from entities where name='crash-x'"
  [ "$output" = "error" ]
  run sql "$TMP/kg.db" "select memory_type from entities where name='pat-y'"
  [ "$output" = "learning" ]
}

@test "kg build --memory-type: sobrescribe el memory_type de lo ingerido" {
  printf '%s\n' '{"topic":"t2","type":"decision","content":"SPEC-103"}' > "$STORE"
  kg build --db "$TMP/kg.db" --memory-type goal >/dev/null
  run sql "$TMP/kg.db" "select distinct memory_type from entities"
  [ "$output" = "goal" ]
}

@test "kg build --memory-type inválido -> error exit 2 sin tocar la DB" {
  run kg build --db "$TMP/kg.db" --memory-type nonsense
  [ "$status" -eq 2 ]
  [ ! -e "$TMP/kg.db" ]
}

@test "kg build: la ingesta de ROADMAP no borra provenance explícita del store" {
  printf '%s\n' '{"topic":"SPEC-300","type":"spec","content":"x"}' > "$STORE"
  echo "- SPEC-300 roadmap item" > "$TMP/root/docs/ROADMAP.md"
  kg build --db "$TMP/kg.db" >/dev/null
  run sql "$TMP/kg.db" "select provenance from entities where name='SPEC-300'"
  [ "$output" = "explicit_statement" ]
}

@test "kg build: sin WARN espurio por memory_type 'unknown' interno" {
  printf '%s\n' '{"topic":"t3","type":"decision","content":"SPEC-104 opencode"}' > "$STORE"
  run --separate-stderr kg build --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  [[ "$stderr" != *"WARN"* ]]
}

@test "kg query: --limit 0 o negativo se rechaza (boundary)" {
  printf '%s\n' '{"topic":"t4","type":"decision","content":"SPEC-105"}' > "$STORE"
  kg build --db "$TMP/kg.db" >/dev/null
  run kg query t --limit 0 --db "$TMP/kg.db"
  [ "$status" -eq 2 ]
  run kg query t --limit -1 --db "$TMP/kg.db"
  [ "$status" -eq 2 ]
}

@test "kg impact: --depth negativo se rechaza (invalid)" {
  printf '%s\n' '{"topic":"t5","type":"decision","content":"SPEC-106"}' > "$STORE"
  kg build --db "$TMP/kg.db" >/dev/null
  run kg impact t5 --depth -1 --db "$TMP/kg.db"
  [ "$status" -eq 2 ]
}

@test "kg query: '%' y '_' se tratan como literales, no comodines" {
  printf '%s\n' '{"topic":"t6","type":"decision","content":"SPEC-107"}' > "$STORE"
  kg build --db "$TMP/kg.db" >/dev/null
  run kg query % --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No results for '%'"* ]]
  run kg impact _ --db "$TMP/kg.db"
  [ "$status" -eq 1 ]
}

@test "kg impact --project: no encuentra entidades de otro proyecto (reject)" {
  printf '%s\n' '{"topic":"alpha-topic","type":"decision","content":"SPEC-108"}' > "$STORE"
  kg build --db "$TMP/kg.db" --project projA >/dev/null
  run kg impact alpha-topic --project projB --db "$TMP/kg.db"
  [ "$status" -eq 1 ]
  run kg impact alpha-topic --project projA --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SPEC-108"* ]]
}

@test "kg status --project: relaciones por tipo filtradas por proyecto" {
  printf '%s\n' '{"topic":"beta-topic","type":"decision","content":"SPEC-109"}' > "$STORE"
  kg build --db "$TMP/kg.db" --project projA >/dev/null
  run kg status --project projZ --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  [[ "$output" != *"mentions"* ]]
}

@test "kg build: ruta de DB con espacios y locale es_ES con texto no ASCII" {
  printf '%s\n' '{"topic":"diseño-ñandú","type":"decision","content":"SPEC-110 versión 1,5"}' > "$STORE"
  run env LC_ALL=es_ES.UTF-8 HOME="$TMP/home" PROJECT_ROOT="$TMP/root" \
    python3 "$KGPY" build --db "$TMP/db dir/kg.db"
  [ "$status" -eq 0 ]
  run sql "$TMP/db dir/kg.db" "select count(*) from entities where name='diseño-ñandú'"
  [ "$output" = "1" ]
}

@test "kg build: store large (3000 líneas) ingiere todo" {
  python3 -c 'import json
for i in range(3000): print(json.dumps({"topic": f"topic-{i}", "type": "decision", "content": f"SPEC-{i%900+100}"}))' > "$STORE"
  run kg build --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  run sql "$TMP/kg.db" "select count(*) from entities where type='decision'"
  [ "$output" = "3000" ]
}

@test "kg build: builds concurrentes sobre una DB nueva no fallan (WAL + migración)" {
  # Regresión: dos procesos abriendo una DB nueva chocaban en PRAGMA
  # journal_mode=WAL («database is locked») y en el ALTER TABLE de la
  # migración («duplicate column name»). 5 rondas x 6 procesos.
  printf '%s\n' '{"topic":"c1","type":"decision","content":"SPEC-111"}' > "$STORE"
  local fails=0 round i p
  for round in 1 2 3 4 5; do
    local pids=()
    for i in 1 2 3 4 5 6; do
      kg build --db "$TMP/conc-$round.db" > "$TMP/b-$round-$i.out" 2>&1 &
      pids+=("$!")
    done
    for p in "${pids[@]}"; do
      wait "$p" || fails=$((fails + 1))
    done
  done
  if [ "$fails" -ne 0 ]; then
    cat "$TMP"/b-*.out | grep -i error | sort | uniq -c >&2
  fi
  [ "$fails" -eq 0 ]
  run sql "$TMP/conc-5.db" "select count(*) from entities where name='c1'"
  [ "$output" = "1" ]
}

@test "kg impact --project: el recorrido no cruza a entidades de otro proyecto" {
  printf '%s\n' '{"topic":"gamma-topic","type":"decision","content":"SPEC-112"}' > "$STORE"
  kg build --db "$TMP/kg.db" --project projA >/dev/null
  # Retag del destino a otro proyecto: la relación gamma-topic -> SPEC-112 cruza proyectos.
  python3 -c 'import sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.execute("UPDATE entities SET project_id=? WHERE name=?",("projB","SPEC-112")); c.commit()' "$TMP/kg.db"
  run kg impact gamma-topic --project projA --db "$TMP/kg.db"
  [ "$status" -eq 0 ]
  [[ "$output" != *"SPEC-112"* ]]
  run kg impact gamma-topic --db "$TMP/kg.db"
  [[ "$output" == *"SPEC-112"* ]]
}
