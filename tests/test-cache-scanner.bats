#!/usr/bin/env bats
# tests/test-cache-scanner.bats
# SPEC-CACHE-HIT-TRACKING v2 — scanner BATS suite.
#
# Cubre:
#   1. Schema creado correctamente (tablas + user_version=1)
#   2. Solo procesa role=assistant (descarta user/tool/invalid JSON)
#   3. Incremental sync — segunda pasada inserta 0
#   4. --force-full reprocesa sin duplicar (PRIMARY KEY)
#   5. Tolerancia a JSON inválido (no crash, no insert)
#   6. Mapping correcto agent/model/cache_read/cache_write
#   7. scan_state acumula messages_seen
#   8. ERROR claro si source no existe

FIXTURE="tests/fixtures/opencode-mini.db"
SCANNER="scripts/cache-scanner.py"

setup() {
  if [ ! -f "$FIXTURE" ]; then
    python3 tests/fixtures/generate-opencode-mini.py
  fi
  TMPDIR_TEST="$(mktemp -d)"
  export USAGE_DB="$TMPDIR_TEST/usage.db"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "scanner crea schema con tablas y user_version=1" {
  run python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  [ "$status" -eq 0 ]
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
tables = {r[0] for r in c.execute(\"SELECT name FROM sqlite_master WHERE type='table'\")}
assert {'turns','sessions','scan_state'}.issubset(tables), tables
assert c.execute('PRAGMA user_version').fetchone()[0] == 1
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "scanner solo procesa role=assistant (30 de 50 messages)" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
n = c.execute('SELECT COUNT(*) FROM turns').fetchone()[0]
assert n == 30, f'expected 30 got {n}'
print(n)
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"30"* ]]
}

@test "scanner sincroniza 3 sessions" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
n = c.execute('SELECT COUNT(*) FROM sessions').fetchone()[0]
assert n == 3, n
print(n)
"
  [ "$status" -eq 0 ]
}

@test "incremental sync — segunda pasada inserta 0 turns" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  run python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turns inserted  : 0"* ]]
}

@test "--force-full reprocesa sin duplicar (PRIMARY KEY message_id)" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --force-full --quiet
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
n = c.execute('SELECT COUNT(*) FROM turns').fetchone()[0]
assert n == 30, f'duplicates! got {n}'
print(n)
"
  [ "$status" -eq 0 ]
}

@test "JSON inválido tolerado (no crash, no insert)" {
  # Si el JSON inválido se intentara insertar, count > 30
  run python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  [ "$status" -eq 0 ]
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
ids = [r[0] for r in c.execute(\"SELECT message_id FROM turns WHERE message_id='msg_invalid'\")]
assert ids == [], f'invalid JSON leaked: {ids}'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "mapping correcto agent/model/cache (azure-operator/haiku)" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
row = c.execute('''SELECT COUNT(*), SUM(cache_read), SUM(cache_write), MAX(model)
                   FROM turns WHERE agent=?''', ('azure-operator',)).fetchone()
n, cr, cw, model = row
assert n == 8, n
assert cr == 8 * 12000, cr
assert cw == 8 * 100, cw
assert model == 'claude-haiku-4-5', model
print('OK', n, cr, cw, model)
"
  [ "$status" -eq 0 ]
}

@test "scan_state.messages_seen acumula entre runs" {
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --quiet
  python3 "$SCANNER" --source "$FIXTURE" --db "$USAGE_DB" --force-full --quiet
  run python3 -c "
import sqlite3
c = sqlite3.connect('$USAGE_DB')
seen = c.execute(\"SELECT messages_seen FROM scan_state WHERE source='opencode'\").fetchone()[0]
# Run 1: +30; Run 2 force-full: +30 → 60
assert seen == 60, f'expected 60, got {seen}'
print(seen)
"
  [ "$status" -eq 0 ]
}

@test "ERROR si source no existe (exit 2)" {
  run python3 "$SCANNER" --source /nonexistent/opencode.db --db "$USAGE_DB" --quiet
  [ "$status" -eq 2 ]
  [[ "$output" == *"source not found"* ]]
}
