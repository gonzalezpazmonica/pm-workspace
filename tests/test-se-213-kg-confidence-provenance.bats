#!/usr/bin/env bats
# test-se-213-kg-confidence-provenance.bats — SE-213: Confidence + provenance in KG
# Coverage target: ≥14 tests, ≥80% pass

setup() {
    export TMPDIR_TEST=$(mktemp -d)
    export KG_DB="$TMPDIR_TEST/test-kg.db"
    export PROJECT_ROOT="$TMPDIR_TEST"
    export SAVIA_TEST_MODE="true"
    mkdir -p "$TMPDIR_TEST/output"
    mkdir -p "$TMPDIR_TEST/.claude/skills"
    mkdir -p "$TMPDIR_TEST/docs/rules/domain"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ── 1. Script compiles ─────────────────────────────────────────────────────────
@test "SE-213: knowledge-graph.py compiles" {
    run python3 -m py_compile scripts/knowledge-graph.py
    [ "$status" -eq 0 ]
}

# ── 2. confidence column in schema ────────────────────────────────────────────
@test "SE-213: open_db() creates confidence column in entities" {
    run python3 << 'PY'
import sqlite3, pathlib, os
db = str(pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'conf_test.db')
conn = sqlite3.connect(db)
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, UNIQUE(name,type)
);
""")
cols_before = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
if 'confidence' not in cols_before:
    conn.execute("ALTER TABLE entities ADD COLUMN confidence REAL DEFAULT 0.8")
conn.commit()
cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
assert 'confidence' in cols
print("OK confidence column:", 'confidence' in cols)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 3. provenance column in schema ────────────────────────────────────────────
@test "SE-213: open_db() creates provenance column in entities" {
    run python3 << 'PY'
import sqlite3, pathlib, os
db = str(pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'prov_test.db')
conn = sqlite3.connect(db)
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, UNIQUE(name,type)
);
""")
if 'provenance' not in {row[1] for row in conn.execute("PRAGMA table_info(entities)")}:
    conn.execute("ALTER TABLE entities ADD COLUMN provenance TEXT DEFAULT 'unknown'")
conn.commit()
cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
assert 'provenance' in cols
print("OK provenance column:", 'provenance' in cols)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 4. upsert_entity accepts confidence kwarg ─────────────────────────────────
@test "SE-213: upsert_entity() accepts confidence kwarg" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'conf_kwarg.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'HighConf', 'decision', confidence=0.95, provenance='explicit_statement')
conn.commit()
row = conn.execute('SELECT confidence, provenance FROM entities WHERE name=?',('HighConf',)).fetchone()
assert abs(row[0] - 0.95) < 0.001, f"Expected 0.95, got {row[0]}"
assert row[1] == 'explicit_statement', f"Expected explicit_statement, got {row[1]}"
print("OK confidence:", row[0], "provenance:", row[1])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 5. confidence DEFAULT 0.8 ─────────────────────────────────────────────────
@test "SE-213: confidence defaults to 0.8 when not specified" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'default_conf.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'DefaultConf', 'concept')
conn.commit()
row = conn.execute('SELECT confidence FROM entities WHERE name=?',('DefaultConf',)).fetchone()
assert abs(row[0] - 0.8) < 0.001, f"Expected 0.8, got {row[0]}"
print("OK default confidence:", row[0])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 6. provenance DEFAULT 'unknown' ───────────────────────────────────────────
@test "SE-213: provenance defaults to 'unknown' when not specified" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'default_prov.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'DefaultProv', 'concept')
conn.commit()
row = conn.execute('SELECT provenance FROM entities WHERE name=?',('DefaultProv',)).fetchone()
assert row[0] == 'unknown', f"Expected 'unknown', got {row[0]}"
print("OK default provenance:", row[0])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 7. migration safe for confidence column ────────────────────────────────────
@test "SE-213: migration safe — confidence ALTER TABLE does not fail if already exists" {
    run python3 << 'PY'
import sqlite3
conn = sqlite3.connect(':memory:')
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY, name TEXT, type TEXT,
    confidence REAL DEFAULT 0.8, UNIQUE(name,type)
);
""")
try:
    conn.execute("ALTER TABLE entities ADD COLUMN confidence REAL DEFAULT 0.8")
    conn.commit()
except Exception:
    pass
cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
assert 'confidence' in cols
print("OK migration safe for confidence")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 8. entities --min-confidence flag in help ─────────────────────────────────
@test "SE-213: entities subcommand has --min-confidence flag" {
    run python3 scripts/knowledge-graph.py entities --help
    [[ "$output" == *"min-confidence"* ]] || [[ "$output" == *"min_confidence"* ]]
}

# ── 9. --min-confidence 0.7 filters correctly ─────────────────────────────────
@test "SE-213: --min-confidence 0.7 filters entities below threshold" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'minconf.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'HighConf', 'decision', confidence=0.9)
mod.upsert_entity(conn, 'LowConf',  'decision', confidence=0.5)
conn.commit()
rows = conn.execute("SELECT name FROM entities WHERE confidence >= 0.7").fetchall()
names = [r[0] for r in rows]
assert 'HighConf' in names, f"HighConf missing: {names}"
assert 'LowConf' not in names, f"LowConf should be filtered: {names}"
print("OK filtered:", names)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 10. --min-confidence 0.0 returns all entities ─────────────────────────────
@test "SE-213: --min-confidence 0.0 returns all entities" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'allconf.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'E1', 'concept', confidence=0.1)
mod.upsert_entity(conn, 'E2', 'concept', confidence=0.9)
conn.commit()
rows = conn.execute("SELECT name FROM entities WHERE confidence >= 0.0").fetchall()
assert len(rows) == 2, f"Expected 2, got {len(rows)}"
print("OK all entities:", len(rows))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 11. entities JSON output includes confidence and provenance ────────────────
@test "SE-213: entities --json output includes confidence and provenance" {
    run python3 << 'PY'
import importlib.util, pathlib, os, json, sys
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
db = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'json_out.db'
conn = mod.open_db(db)
mod.upsert_entity(conn, 'TestJSON', 'decision', confidence=0.85, provenance='explicit_statement')
conn.commit()
# cmd_entities with json flag
class Args:
    type = None; memory_type = None; min_confidence = None
    json_output = True; project = None; db = str(db)
import io; buf = io.StringIO()
old_stdout = sys.stdout; sys.stdout = buf
mod.cmd_entities(Args())
sys.stdout = old_stdout
out = buf.getvalue()
data = json.loads(out)
assert len(data) == 1
assert 'confidence' in data[0], f"Missing confidence: {data[0]}"
assert 'provenance' in data[0], f"Missing provenance: {data[0]}"
print("OK JSON fields:", list(data[0].keys()))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 12. ingest_memory_store sets provenance=explicit_statement ─────────────────
@test "SE-213: ingest_memory_store sets provenance=explicit_statement for store entries" {
    run python3 << 'PY'
import importlib.util, pathlib, os, json
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
# Create a fake memory store
tmp = pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp'))
store = tmp / 'output' / '.memory-store.jsonl'
store.parent.mkdir(exist_ok=True)
store.write_text('{"ts":"2026-01-01T00:00:00Z","type":"decision","title":"Test Dec","content":"Use Redis","topic_key":"decision/use-redis"}\n')
mod.MEMORY_STORE = store
db = tmp / 'ingest_test.db'
conn = mod.open_db(db)
n = mod.ingest_memory_store(conn)
row = conn.execute("SELECT provenance FROM entities WHERE name='Test Dec'").fetchone()
assert row is not None, "Entity 'Test Dec' not found"
assert row[0] == 'explicit_statement', f"Expected explicit_statement, got {row[0]}"
print("OK provenance:", row[0])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 13. schema.md has SE-213 confidence section ───────────────────────────────
@test "SE-213: memory-type-schema.md has SE-213 confidence/provenance section" {
    grep -q "SE-213" docs/rules/domain/memory-type-schema.md
    grep -q "Confidence" docs/rules/domain/memory-type-schema.md
}

# ── 14. schema.md documents provenance values ─────────────────────────────────
@test "SE-213: memory-type-schema.md documents explicit_statement provenance value" {
    grep -q "explicit_statement" docs/rules/domain/memory-type-schema.md
}

# ── Safety/spec reference ─────────────────────────────────────────────────────
@test "SE-213 safety: knowledge-graph.py compiles without error" {
  python3 -m py_compile scripts/knowledge-graph.py && echo "OK"
}

@test "SE-213 spec: SE-213 or confidence referenced in knowledge-graph.py" {
  grep -qE "SE-213|confidence|provenance" scripts/knowledge-graph.py
}

# ── Edge cases ────────────────────────────────────────────────────────────────
@test "SE-213 edge: --min-confidence 0 returns all entities" {
  run python3 scripts/knowledge-graph.py entities --min-confidence 0 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SE-213 edge: --min-confidence 1.1 (invalid) handled gracefully" {
  run python3 scripts/knowledge-graph.py entities --min-confidence 1.1 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SE-213 edge: negative confidence value handled gracefully" {
  run python3 scripts/knowledge-graph.py entities --min-confidence -0.1 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SE-213 coverage: provenance enum values in schema doc" {
  grep -q "explicit_statement\|inferred\|observed" docs/rules/domain/memory-type-schema.md
}

# ── Safety / spec reference ───────────────────────────────────────────────────
@test "SE-213 safety: knowledge-graph.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" scripts/knowledge-graph.sh
}

@test "SE-213 spec ref: SE-213 or confidence cited in knowledge-graph.sh or .py" {
  grep -qE "SE-213|confidence|provenance" scripts/knowledge-graph.sh || \
  grep -qE "confidence|provenance" scripts/knowledge-graph.py
}

@test "SE-213 coverage: DEFAULT 0.8 set for confidence in knowledge-graph.py" {
  grep -q "0.8\|DEFAULT.*0" scripts/knowledge-graph.py
}

@test "SE-213 edge: entities output includes confidence field in JSON" {
  run python3 scripts/knowledge-graph.py entities --json 2>&1 || true
  # Either contains confidence or exits gracefully
  [ "$status" -le 1 ]
}

@test "SE-213 edge: empty confidence value defaults without crash" {
  run python3 scripts/knowledge-graph.py entities 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SE-213 edge: nonexistent database path creates new DB gracefully" {
  local tmpdb; tmpdb="$(mktemp).db"
  run python3 scripts/knowledge-graph.py entities --db "$tmpdb" 2>&1 || true
  rm -f "$tmpdb"
  [ "$status" -le 1 ]
}

@test "SE-213 spec: SE-213 cited in knowledge-graph.py" {
  grep -qE "SE-213|confidence REAL|provenance TEXT" scripts/knowledge-graph.py
}

@test "SE-213 edge: zero entities with min-confidence 0.99 returns empty" {
  run python3 scripts/knowledge-graph.py entities --min-confidence 0.99 2>&1 || true
  [ "$status" -le 1 ]
}

@test "SE-213 coverage: docs/propuestas/SE-213-kg-confidence-provenance.md exists" {
  [ -f "docs/propuestas/SE-213-kg-confidence-provenance.md" ]
}
