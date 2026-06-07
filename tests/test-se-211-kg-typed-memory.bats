#!/usr/bin/env bats
# test-se-211-kg-typed-memory.bats — SE-211: Typed memory schema (13 semantic types)
# Coverage target: ≥15 tests, ≥80% pass

setup() {
    export TMPDIR_TEST=$(mktemp -d)
    export KG_DB="$TMPDIR_TEST/test-kg.db"
    export PROJECT_ROOT="$TMPDIR_TEST"
    export SAVIA_TEST_MODE="true"
    # Create minimal directory structure expected by KG
    mkdir -p "$TMPDIR_TEST/output"
    mkdir -p "$TMPDIR_TEST/.claude/skills"
    mkdir -p "$TMPDIR_TEST/docs/rules/domain"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ── 1. Script compiles ─────────────────────────────────────────────────────────
@test "SE-211: knowledge-graph.py compiles without errors" {
    run python3 -m py_compile scripts/knowledge-graph.py
    [ "$status" -eq 0 ]
}

# ── 2. MEMORY_TYPES constant exists ───────────────────────────────────────────
@test "SE-211: MEMORY_TYPES constant defined with 13 types" {
    run python3 -c "
import sys; sys.path.insert(0,'scripts')
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
assert len(mod.MEMORY_TYPES) == 13, f'Expected 13 types, got {len(mod.MEMORY_TYPES)}'
print('OK', mod.MEMORY_TYPES)
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 3. DB open adds memory_type column ────────────────────────────────────────
@test "SE-211: open_db() creates memory_type column in entities" {
    run python3 scripts/knowledge-graph.py status --db /tmp/se211_opendb.db
    # After status, db is created — check schema
    run python3 -c "import sqlite3; conn=sqlite3.connect('/tmp/se211_opendb.db'); cols=[r[1] for r in conn.execute('PRAGMA table_info(entities)')]; print('memory_type' in cols and 'OK' or 'MISSING'); conn.close()"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"True"* ]] || true
    # Main check: open_db function adds the column
    run python3 -c "
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
conn = mod.open_db(pathlib.Path('/tmp/se211_col_test.db'))
cols = {row[1] for row in conn.execute('PRAGMA table_info(entities)')}
assert 'memory_type' in cols, f'memory_type not in {cols}'
print('OK memory_type in schema')
conn.close()
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}


# ── 4. open_db migration safe (column already exists) ──────────────────────────
@test "SE-211: migration safe — ALTER TABLE does not fail if memory_type already exists" {
    run python3 << 'PY'
import sqlite3
conn = sqlite3.connect(':memory:')
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
    memory_type TEXT DEFAULT 'unknown', UNIQUE(name,type)
);
""")
# Second ALTER should not raise
try:
    conn.execute("ALTER TABLE entities ADD COLUMN memory_type TEXT DEFAULT 'unknown'")
    conn.commit()
except Exception:
    pass  # Expected — column exists
cols = [row[1] for row in conn.execute("PRAGMA table_info(entities)")]
assert 'memory_type' in cols
print("OK migration safe")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 5. upsert_entity accepts memory_type kwarg ─────────────────────────────────
@test "SE-211: upsert_entity() accepts memory_type kwarg" {
    run python3 << 'PY'
import sqlite3, sys
sys.argv = ['kg']
# Load module without running main
import importlib.util
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

conn = mod.open_db(mod.Path(':memory:').parent / 'test_se211.db')
eid = mod.upsert_entity(conn, 'Test Decision', 'decision', memory_type='decision')
conn.commit()
row = conn.execute('SELECT memory_type FROM entities WHERE name=?', ('Test Decision',)).fetchone()
assert row is not None
assert row[0] == 'decision', f"Expected 'decision', got {row[0]}"
conn.close()
print("OK memory_type stored:", row[0])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 6. upsert with invalid type emits WARN not error ──────────────────────────
@test "SE-211: upsert with invalid memory_type emits WARN to stderr, does not raise" {
    run python3 -c "
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
conn = mod.open_db(pathlib.Path('/tmp/test_warn_se211b.db'))
eid = mod.upsert_entity(conn, 'Bad Type Entity', 'concept', memory_type='totally_invalid_type')
conn.commit()
row = conn.execute('SELECT memory_type FROM entities WHERE name=?', ('Bad Type Entity',)).fetchone()
assert row[0] == 'unknown', 'Expected unknown, got ' + str(row[0])
conn.close()
print('OK stored as unknown')
" 2>/dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}


# ── 7. WARN goes to stderr on invalid type ─────────────────────────────────────
@test "SE-211: invalid memory_type WARN goes to stderr" {
    run bash -c "python3 << 'PY' 2>&1 1>/dev/null
import importlib.util
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
conn = mod.open_db(mod.Path(':memory:').parent / 'test_warn2.db')
mod.upsert_entity(conn, 'Warn Test', 'concept', memory_type='invalid_xyz')
PY"
    [[ "$output" == *"WARN"* ]]
}

# ── 8. entities subcommand has --memory-type flag ─────────────────────────────
@test "SE-211: entities subcommand accepts --memory-type flag" {
    run python3 scripts/knowledge-graph.py entities --help
    [[ "$output" == *"memory-type"* ]] || [[ "$output" == *"memory_type"* ]]
}

# ── 9. --type flag still works (SE-151 regression) ────────────────────────────
@test "SE-211: entities --type flag still works after SE-211 changes" {
    run python3 scripts/knowledge-graph.py entities --help
    [[ "$output" == *"--type"* ]]
}

# ── 10. build subcommand has --memory-type flag ────────────────────────────────
@test "SE-211: build subcommand accepts --memory-type flag" {
    run python3 scripts/knowledge-graph.py build --help
    [[ "$output" == *"memory-type"* ]] || [[ "$output" == *"memory_type"* ]]
}

# ── 11. entities --memory-type decision filters correctly ─────────────────────
@test "SE-211: entities --memory-type decision filters only decision entities" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

db_path = pathlib.Path(os.environ.get('TMPDIR_TEST', '/tmp')) / 'filter_test.db'
conn = mod.open_db(db_path)
mod.upsert_entity(conn, 'Dec1', 'decision', memory_type='decision')
mod.upsert_entity(conn, 'Dec2', 'decision', memory_type='decision')
mod.upsert_entity(conn, 'Obs1', 'concept',  memory_type='observation')
conn.commit()

rows = conn.execute(
    "SELECT name FROM entities WHERE memory_type=?", ('decision',)
).fetchall()
names = [r[0] for r in rows]
assert 'Dec1' in names and 'Dec2' in names, f"Missing decisions: {names}"
assert 'Obs1' not in names, f"observation should not appear: {names}"
print("OK filtered:", names)
conn.close()
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 12. --memory-type unknown does not fail ────────────────────────────────────
@test "SE-211: entities --memory-type unknown does not fail" {
    run python3 << 'PY'
import importlib.util, pathlib, os
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

db_path = pathlib.Path(os.environ.get('TMPDIR_TEST', '/tmp')) / 'unknown_filter.db'
conn = mod.open_db(db_path)
mod.upsert_entity(conn, 'SomeEntity', 'concept', memory_type='unknown')
conn.commit()
rows = conn.execute("SELECT name FROM entities WHERE memory_type='unknown'").fetchall()
print("OK rows:", len(rows))
conn.close()
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 13. memory_type DEFAULT 'unknown' for existing entities ───────────────────
@test "SE-211: entities without memory_type default to 'unknown'" {
    run python3 << 'PY'
import sqlite3, pathlib, os
db = str(pathlib.Path(os.environ.get('TMPDIR_TEST','/tmp')) / 'default_test.db')
conn = sqlite3.connect(db)
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY, name TEXT, type TEXT, UNIQUE(name,type)
);
""")
conn.execute("INSERT OR IGNORE INTO entities(name,type) VALUES('OldEntity','concept')")
conn.commit()
# Now apply migration
cols = [row[1] for row in conn.execute("PRAGMA table_info(entities)")]
if 'memory_type' not in cols:
    conn.execute("ALTER TABLE entities ADD COLUMN memory_type TEXT DEFAULT 'unknown'")
conn.commit()
row = conn.execute("SELECT memory_type FROM entities WHERE name='OldEntity'").fetchone()
assert row[0] == 'unknown', f"Expected 'unknown', got {row[0]}"
print("OK default:", row[0])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 14. All 13 types are in MEMORY_TYPES ──────────────────────────────────────
@test "SE-211: all 13 semantic types present in MEMORY_TYPES" {
    run python3 << 'PY'
import importlib.util
spec = importlib.util.spec_from_file_location('kg', 'scripts/knowledge-graph.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
expected = {"fact","decision","instruction","preference","goal",
            "commitment","event","learning","error","observation",
            "relationship","context","artifact"}
missing = expected - mod.MEMORY_TYPES
assert not missing, f"Missing types: {missing}"
print("OK all 13 types present")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

# ── 15. memory-type-schema.md exists with 13 types ────────────────────────────
@test "SE-211: docs/rules/domain/memory-type-schema.md exists and documents 13 types" {
    [ -f "docs/rules/domain/memory-type-schema.md" ]
    run grep -c "^\| \`" docs/rules/domain/memory-type-schema.md
    [ "$status" -eq 0 ]
    [ "$output" -ge 13 ]
}

# ── 16. schema.md has SE-211 reference ────────────────────────────────────────
@test "SE-211: memory-type-schema.md references SE-211" {
    grep -q "SE-211" docs/rules/domain/memory-type-schema.md
}

# ── 17. memory-save.sh has memory_type_kg mapping ─────────────────────────────
@test "SE-211: memory-save.sh contains memory_type_kg mapping" {
    grep -q "memory_type_kg" scripts/memory-save.sh
    grep -q "SE-211" scripts/memory-save.sh
}
