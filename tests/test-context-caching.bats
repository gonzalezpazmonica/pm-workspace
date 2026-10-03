#!/usr/bin/env bats
# test-context-caching.bats — skill context-caching (calibración SE-376)
# Ref: docs/specs/SE-371-cache-hygiene.spec.md
# Ref: docs/rules/domain/prompt-caching.md
# Ref: .claude/skills/context-caching/SKILL.md
# La skill es prosa (orden de carga en 4 niveles). Lo único ejecutable que la
# respalda es la medición: scripts/cache-metrics.sh (ledger local de usage del
# cache del provider). Sin medición fiable, los "hit %" de la skill son humo.
SCRIPT="scripts/cache-metrics.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  # Nunca tocar el ledger real de la operadora: ruta controlada con espacios
  mkdir -p "$TMP_DIR/dir con espacios"
  export SAVIA_CACHE_METRICS_DIR="$TMP_DIR/dir con espacios/metrics.jsonl"
  LEDGER="$SAVIA_CACHE_METRICS_DIR"
  cd "$REPO_ROOT"
}

teardown() {
  rm -rf "$TMP_DIR"
}

cm() { bash "$REPO_ROOT/$SCRIPT" "$@"; }

lines() { if [[ -f "$LEDGER" ]]; then grep -c . "$LEDGER"; else echo 0; fi; }

field() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }

# ── Seguridad del objetivo ────────────────────────────────────────────────────
@test "target script declares set -uo pipefail" {
  run grep -c '^set -uo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── record: positivos ─────────────────────────────────────────────────────────
@test "record: valid integers append one row to ledger in path with spaces" {
  run cm record --model glm --input 100 --cache-read 900 --cache-creation 50 --session s1
  [ "$status" -eq 0 ]
  [ "$(lines)" -eq 1 ]
  run bash -c "head -1 \"$LEDGER\" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r[\"input\"], r[\"cache_read\"], r[\"cache_creation\"], r[\"session\"])'"
  [ "$output" = "100 900 50 s1" ]
}

@test "record: usage-json with escaped quote in a string keeps the token counts" {
  run cm record --model glm --usage-json '{"input_tokens":3,"cache_read_input_tokens":40,"note":"a\"b"}'
  [ "$status" -eq 0 ]
  run bash -c "head -1 \"$LEDGER\" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r[\"input\"], r[\"cache_read\"])'"
  [ "$output" = "3 40" ]
}

@test "record: usage-json is data, never code (injection payload rejected)" {
  payload="{}''' if __import__('os').system('touch $TMP_DIR/PWNED') else '''{}"
  run cm record --model glm --usage-json "$payload"
  [ "$status" -eq 2 ]
  [ ! -e "$TMP_DIR/PWNED" ]
  [ "$(lines)" -eq 0 ]
}

# ── record: negativos ─────────────────────────────────────────────────────────
@test "record: invalid usage-json is rejected with exit 2 and no row" {
  run cm record --model glm --usage-json 'no-es-json'
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
  [ "$(lines)" -eq 0 ]
}

@test "record: usage-json that is not an object is rejected" {
  run cm record --model glm --usage-json '[1,2,3]'
  [ "$status" -eq 2 ]
  [ "$(lines)" -eq 0 ]
}

@test "record: es_ES thousands separator 1.000 is rejected, not stored as 1" {
  run cm record --model glm --input 1.000
  [ "$status" -eq 2 ]
  [ "$(lines)" -eq 0 ]
}

@test "record: es_ES decimal comma 1,5 is rejected with a clear error" {
  run cm record --model glm --input 1,5
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "record: negative token count is rejected" {
  run cm record --model glm --input 10 --cache-read -5
  [ "$status" -eq 2 ]
  [ "$(lines)" -eq 0 ]
}

@test "record: non numeric input is rejected" {
  run cm record --model glm --input abc
  [ "$status" -eq 2 ]
  [ "$(lines)" -eq 0 ]
}

@test "record: flag without value fails with usage error, not unbound variable" {
  run cm record --model
  [ "$status" -eq 2 ]
  [[ "$output" != *"unbound"* && "$output" != *"sin asignar"* ]]
}

@test "record: missing model is rejected" {
  run cm record --input 10
  [ "$status" -eq 2 ]
  [ "$(lines)" -eq 0 ]
}

# ── report ───────────────────────────────────────────────────────────────────
@test "report: hit ratio follows the documented formula R/(N+R)" {
  cm record --model glm --input 100 --cache-read 900 >/dev/null
  run cm report
  [ "$status" -eq 0 ]
  hr=$(echo "$output" | field "['cache_hit_ratio']")
  [ "$hr" = "0.9" ]
}

@test "report: empty ledger file reports zero ratio without crashing" {
  : > "$LEDGER"
  run cm report
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "['cache_hit_ratio']")" = "0.0" ]
}

@test "report: corrupt rows are skipped and counted, not a crash" {
  cm record --model glm --input 100 --cache-read 900 >/dev/null
  printf '[1,2]\n{"model":"m","input":"10","cache_read":0,"cache_creation":0}\nnot json\n' >> "$LEDGER"
  run cm report
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "['skipped_lines']")" = "3" ]
  [ "$(echo "$output" | field "['cache_hit_ratio']")" = "0.9" ]
}

@test "report: missing ledger is not an error" {
  run cm report
  [ "$status" -eq 0 ]
  [[ "$output" == *"inexistente"* ]]
}

# ── validate ─────────────────────────────────────────────────────────────────
@test "validate: non object line is flagged as BAD with exit 1, no traceback" {
  cm record --model glm --input 1 >/dev/null
  echo '[1,2]' >> "$LEDGER"
  run cm --validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"BAD linea 2"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "validate: boolean or negative counts are invalid" {
  echo '{"model":"m","input":true,"cache_read":0,"cache_creation":0}' > "$LEDGER"
  echo '{"model":"m","input":5,"cache_read":-1,"cache_creation":0}' >> "$LEDGER"
  run cm --validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"BAD linea 1"* ]]
  [[ "$output" == *"BAD linea 2"* ]]
}

# ── ledger path y concurrencia ────────────────────────────────────────────────
@test "ledger: SAVIA_CACHE_METRICS_DIR pointing to a directory writes inside it" {
  export SAVIA_CACHE_METRICS_DIR="$TMP_DIR/dir con espacios"
  run cm record --model glm --input 7
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/dir con espacios/cache-metrics.jsonl" ]
}

@test "ledger: 20 concurrent records produce 20 valid lines (large boundary)" {
  for i in $(seq 1 20); do
    cm record --model glm --input "$i" --session "s$i" >/dev/null &
  done
  wait
  [ "$(lines)" -eq 20 ]
  run cm --validate
  [ "$status" -eq 0 ]
}

# ── ingest-opencode ───────────────────────────────────────────────────────────
@test "ingest: non integer --days is rejected with exit 2" {
  python3 -c "import sqlite3,sys; sqlite3.connect(sys.argv[1]).close()" "$TMP_DIR/oc.db"
  run cm ingest-opencode --db "$TMP_DIR/oc.db" --days abc
  [ "$status" -eq 2 ]
  [[ "$output" != *"Traceback"* ]]
}

@test "ingest: db without session table fails with a clear error, no traceback" {
  python3 -c "import sqlite3,sys; sqlite3.connect(sys.argv[1]).execute('create table t(x)')" "$TMP_DIR/oc.db"
  run cm ingest-opencode --db "$TMP_DIR/oc.db"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "ingest: missing db is a warning with exit 0 (session-end hook must not fail)" {
  run cm ingest-opencode --db "$TMP_DIR/no-existe.db"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}

# ── CLI ──────────────────────────────────────────────────────────────────────
@test "cli: --help exits 0 and unknown subcommand exits 2" {
  run cm --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"record"* ]]
  run cm foo
  [ "$status" -eq 2 ]
}
