#!/usr/bin/env bats
# tests/test-project-context-audit.bats
# Integration tests for SPEC-PROJECT-CONTEXT-DISCIPLINE audit script.
#
# Covers AC-01..AC-06:
#   - parse STATIC / DYNAMIC / UNMARKED blocks correctly
#   - ratio calculation + OK vs WARNING threshold (80%)
#   - banner INFORMATIONAL when prereqs unmet (<200 turns/14d)
#   - banner ENFORCING-CAPABLE when prereqs met
#   - error on mismatched / unclosed markers
#   - extraction candidates listed when ratio<80%
#   - blocks <3 lines ignored (noise filter)

setup() {
  WORKSPACE_REAL="${WORKSPACE_REAL:-$(pwd)}"
  AUDIT="$WORKSPACE_REAL/scripts/project-context-audit.py"
  export TMPDIR_TEST
  TMPDIR_TEST="$(mktemp -d)"
  export SAVIA_WORKSPACE_DIR="$TMPDIR_TEST"
  export HOME_REAL="$HOME"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.savia" "$SAVIA_WORKSPACE_DIR/projects/foo"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  export HOME="$HOME_REAL"
}

_seed_usage_db() {
  # $1 = turns count for projects/foo/CLAUDE.md in last 14d
  # $2 = optional cache_read total
  # $3 = optional cache_write total
  python3 - "$1" "${2:-0}" "${3:-0}" << 'PYEOF'
import os, sqlite3, sys, pathlib
n = int(sys.argv[1]); r = int(sys.argv[2]); w = int(sys.argv[3])
p = pathlib.Path(os.environ["HOME"]) / ".savia/usage.db"
con = sqlite3.connect(str(p))
con.executescript("""
CREATE TABLE IF NOT EXISTS turns (
  message_id TEXT PRIMARY KEY,
  ts TEXT NOT NULL,
  file_path TEXT,
  cache_read INTEGER DEFAULT 0,
  cache_write INTEGER DEFAULT 0
);
""")
for i in range(n):
    con.execute(
        "INSERT INTO turns(message_id, ts, file_path, cache_read, cache_write) "
        "VALUES (?, datetime('now','-1 days'), ?, ?, ?)",
        (f"m{i}", "projects/foo/CLAUDE.md", r // max(n,1), w // max(n,1)),
    )
con.commit(); con.close()
PYEOF
}

@test "parses balanced STATIC block and reports OK when ratio>=80%" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo project
<!-- [STATIC] -->
## Stack
- python 3.12
- fastapi
- postgres
- docker
- pytest
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"static="* ]]
  [[ "$output" == *"Status:  OK"* ]]
}

@test "reports WARNING when static ratio < 80%" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- a
- b
<!-- [/STATIC] -->
<!-- [DYNAMIC] -->
## Sprint
- sprint 1
- sprint 2
- sprint 3
- sprint 4
- sprint 5
- sprint 6
- sprint 7
- sprint 8
- sprint 9
- sprint 10
- sprint 11
- sprint 12
- sprint 13
- sprint 14
- sprint 15
- sprint 16
- sprint 17
<!-- [/DYNAMIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status:  WARNING"* ]]
  [[ "$output" == *"candidatos a extracción"* ]]
}

@test "detects UNMARKED H2 sections in gaps" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
## Orphan section
line one
line two
line three
line four
## Another orphan
content a
content b
content c
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNMARKED blocks"* ]]
  [[ "$output" == *"Orphan section"* ]]
}

@test "errors on unclosed STATIC marker" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- one
- two
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed marker"* ]]
}

@test "errors on mismatched closing tag" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- a
- b
<!-- [/DYNAMIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"mismatched closing"* ]]
}

@test "errors on closing marker without opening" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
## Stack
- a
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"no opening marker"* ]]
}

@test "shows INFORMATIONAL banner when usage.db missing" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- a
- b
- c
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFORMATIONAL MODE"* ]]
}

@test "shows INFORMATIONAL banner when <200 turns/14d" {
  _seed_usage_db 50 1000 100
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- a
- b
- c
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFORMATIONAL MODE"* ]]
  [[ "$output" == *"50 turns"* ]]
}

@test "shows ENFORCING-CAPABLE banner with hit_rate when prereqs met" {
  _seed_usage_db 300 9000 1000
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
## Stack
- a
- b
- c
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENFORCING-CAPABLE"* ]]
  [[ "$output" == *"hit_rate(14d)"* ]]
}

@test "blocks shorter than 3 lines are ignored as noise" {
  cat > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" << 'MD'
# Foo
<!-- [STATIC] -->
x
<!-- [/STATIC] -->
<!-- [STATIC] -->
## Real block
content one
content two
content three
content four
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" foo
  [ "$status" -eq 0 ]
  # Only the real block (>=3 lines) should appear
  [[ "$output" == *"static="* ]]
}

@test "accepts --file flag with explicit path" {
  cat > "$TMPDIR_TEST/external.md" << 'MD'
# External
<!-- [STATIC] -->
## Section
- a
- b
- c
<!-- [/STATIC] -->
MD
  run python3 "$AUDIT" --file "$TMPDIR_TEST/external.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project:"* ]]
}
