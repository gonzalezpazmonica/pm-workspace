#!/usr/bin/env bats
# SE-376 — savia-memory: lo que documenta la skill funciona tal cual y nunca toca la memoria
# real del usuario (~/.savia-memory) desde un test. Ref: .claude/skills/savia-memory/SKILL.md,
# SPEC-142 / SE-352 en docs/propuestas/.
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  S="$REPO_ROOT/scripts"
  TMP="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  export PROJECT_ROOT="$TMP" SAVIA_EMBED_AUTOSTART=false
  unset SAVIA_MEMORY_INDEX_FILE
  STORE="$TMP/output/.memory-store.jsonl"
  FACT="El ledger usa PostgreSQL 16 desde el commit abc123 porque SQLite bloqueaba escrituras concurrentes."
  cd "$TMP" || return 1
}

teardown() { cd "$REPO_ROOT" || true; }

save() { run bash "$S/memory-store.sh" save "$@"; }
index_fixture() { printf '# Memoria\n\n<!-- ENTRIES_START -->\n<!-- ENTRIES_END -->\n' > "$1"; }

@test "safety: memory-store, write-gate y backup declaran set -uo pipefail o strict" {
  grep -qE "set -[eu]*o pipefail" "$S/memory-write-gate.sh"
  grep -qE "set -[eu]*o pipefail" "$S/memory-backup-pm.sh"
  grep -qE "set -[eu]*o pipefail|set -uo" "$S/memory-index-rebuild.sh" || grep -q "exit 1" "$S/memory-index-rebuild.sh"
}

@test "save: la forma documentada (--type --title --content --source) guarda una entrada" {
  save --type decision --title ledger-db --content "$FACT" --source user:explicit
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$STORE")" -eq 1 ]
  python3 -c 'import json,sys; e=json.loads(open(sys.argv[1]).readline()); assert e["type"]=="decision" and e["title"]=="ledger-db", e' "$STORE"
}

@test "save: la forma posicional antigua se rechaza sin escribir (error)" {
  save decision "$FACT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--type, --title requeridos"* ]]
  [ ! -s "$STORE" ]
}

@test "save: --source session o skill:<n> se rechazan; tool:, file:, verified: y user:explicit valen" {
  save --type decision --title a --content "$FACT" --source session
  [ "$status" -ne 0 ]
  save --type decision --title b --content "$FACT" --source skill:savia-memory
  [ "$status" -ne 0 ]
  i=0
  for src in tool:pr-plan file:scripts/x.sh:3 verified:abc123 user:explicit; do
    i=$((i+1))
    save --type decision --title "t$i" --content "$FACT variante $i" --source "$src"
    [ "$status" -eq 0 ]
  done
  [ "$(wc -l < "$STORE")" -eq 4 ]
}

@test "save edge: el mismo contenido dos veces se omite como duplicado" {
  save --type decision --title uno --content "$FACT" --source user:explicit
  save --type pattern --title dos --content "$FACT" --source user:explicit
  [[ "$output" == *"Duplicado omitido"* ]]
  [ "$(wc -l < "$STORE")" -eq 1 ]
}

@test "search y recall encuentran lo guardado (modo grep, sin servidor de embeddings)" {
  save --type decision --title ledger-db --content "$FACT" --source user:explicit
  for verb in search recall; do
    run bash "$S/memory-store.sh" "$verb" PostgreSQL
    [ "$status" -eq 0 ]
    [[ "$output" == *"ledger-db"* ]]
  done
}

@test "search edge: sin store (nonexistent) falla con un mensaje que lo dice" {
  run bash "$S/memory-store.sh" search nada
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires a store file"* ]]
}

@test "índice: dentro de BATS nunca se escribe ~/.savia-memory real si no se pide un índice explícito" {
  real_home=$(getent passwd "$(id -un)" | cut -d: -f6)
  idx="$real_home/.savia-memory/auto/MEMORY.md"
  before=$( [ -f "$idx" ] && sha256sum "$idx" || echo ausente )
  save --type decision --title "zz-se376-no-debe-aparecer" --content "$FACT" --source user:explicit
  [ "$status" -eq 0 ]
  after=$( [ -f "$idx" ] && sha256sum "$idx" || echo ausente )
  [ "$before" = "$after" ]
}

@test "índice: con SAVIA_MEMORY_INDEX_FILE inserta la entrada y la reemplaza (no duplica) al re-guardar el topic" {
  idx="$TMP/MEMORY.md"
  index_fixture "$idx"
  SAVIA_MEMORY_INDEX_FILE="$idx" run bash "$S/memory-store.sh" save --type decision --title ledger-db --topic ledger/db --content "$FACT" --source user:explicit
  [ "$status" -eq 0 ]
  grep -qF "[ledger/db]" "$idx"
  SAVIA_MEMORY_INDEX_FILE="$idx" run bash "$S/memory-store.sh" save --type decision --title ledger-db-v2 --topic ledger/db --content "$FACT ampliado" --source user:explicit
  [ "$(grep -cF "[ledger/db]" "$idx")" -eq 1 ]
  grep -qF "ledger-db-v2" "$idx"
}

@test "write-gate: contenido empty o corto se rechaza (exit 1); uno estable y concreto pasa (exit 0)" {
  run bash "$S/memory-write-gate.sh" --content "x" --type decision --topic-key t --confidence 0.8 --concepts '["a"]'
  [ "$status" -eq 1 ]
  run bash "$S/memory-write-gate.sh" --content "$FACT" --type decision --topic-key ledger-db --confidence 0.8 --concepts '["ledger","postgres"]'
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "conflict-resolve propone un informe y no modifica el store" {
  save --type decision --title ledger-db --content "$FACT" --source user:explicit
  before=$(sha256sum "$STORE")
  run python3 "$S/memory-conflict-resolve.py" --store "$STORE" --output "$TMP/output/conf.json"
  [ "$status" -eq 0 ]
  [ -f "$TMP/output/conf.json" ]
  [ "$(sha256sum "$STORE")" = "$before" ]
}
