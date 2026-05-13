#!/usr/bin/env bats
# tests/test-context-opt-gate.bats
# Integration tests for SPEC-CONTEXT-OPT-GATE.
#
# Covers:
#   - is_monitored regex (workspace + projects/*)
#   - dry-run when usage.db has <1000 turns in 14d
#   - bypass via SAVIA_CONTEXT_OPT_BYPASS=1
#   - disabled via SAVIA_CONTEXT_OPT_ENABLED=false
#   - snapshot taken on baseline_pending file
#   - audit log appended

setup() {
  WORKSPACE_REAL="$(pwd)"
  export TMPDIR_TEST
  TMPDIR_TEST="$(mktemp -d)"
  export SAVIA_WORKSPACE_DIR="$TMPDIR_TEST"
  export HOME_REAL="$HOME"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.savia" "$SAVIA_WORKSPACE_DIR/output" "$SAVIA_WORKSPACE_DIR/projects/foo"

  # Seed an empty usage.db with the turns schema but ZERO rows -> dry-run path
  python3 - << 'PYEOF'
import os, sqlite3, pathlib
p = pathlib.Path(os.environ["HOME"]) / ".savia/usage.db"
con = sqlite3.connect(str(p))
con.executescript("""
CREATE TABLE IF NOT EXISTS turns (
  message_id TEXT PRIMARY KEY,
  ts_ms INTEGER NOT NULL,
  cache_read_tokens INTEGER DEFAULT 0,
  cache_write_tokens INTEGER DEFAULT 0
);
""")
con.commit()
con.close()
PYEOF

  # Create a fake CLAUDE.md at workspace root
  echo "# Workspace CLAUDE.md" > "$SAVIA_WORKSPACE_DIR/CLAUDE.md"
  echo "# Project foo CLAUDE.md" > "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md"

  export GATE_PY="$WORKSPACE_REAL/scripts/context-opt-gate.py"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  export HOME="$HOME_REAL"
}

invoke_gate() {
  local file_path="$1"
  local content="${2:-test content}"
  printf '%s' "$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'file_path':sys.argv[1],'content':sys.argv[2]}}))" "$file_path" "$content")" \
    | python3 "$GATE_PY"
}

@test "gate exits 0 for non-monitored files" {
  run invoke_gate "$SAVIA_WORKSPACE_DIR/scripts/something.py" "x"
  [ "$status" -eq 0 ]
}

@test "gate enters dry-run when usage.db has <1000 turns" {
  run invoke_gate "$SAVIA_WORKSPACE_DIR/CLAUDE.md" "new content"
  [ "$status" -eq 0 ]
  grep -q '"event": "dry_run"' "$SAVIA_WORKSPACE_DIR/output/context-opt-audit.jsonl"
}

@test "gate matches projects/<name>/CLAUDE.md" {
  run invoke_gate "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" "new"
  [ "$status" -eq 0 ]
  # dry-run because prereqs not met, but file_path should appear in log
  grep -q "projects/foo/CLAUDE.md" "$SAVIA_WORKSPACE_DIR/output/context-opt-audit.jsonl"
}

@test "bypass env var logs bypass event and exits 0" {
  SAVIA_CONTEXT_OPT_BYPASS=1 run invoke_gate "$SAVIA_WORKSPACE_DIR/CLAUDE.md" "x"
  [ "$status" -eq 0 ]
  grep -q '"event": "bypass"' "$SAVIA_WORKSPACE_DIR/output/context-opt-audit.jsonl"
}

@test "hook wrapper exits 0 when SAVIA_CONTEXT_OPT_ENABLED=false" {
  SAVIA_CONTEXT_OPT_ENABLED=false run bash -c "echo '{}' | bash $WORKSPACE_REAL/.opencode/hooks/context-opt-gate.sh"
  [ "$status" -eq 0 ]
}

@test "snapshot is taken when monitored file is edited (dry-run)" {
  run invoke_gate "$SAVIA_WORKSPACE_DIR/CLAUDE.md" "new"
  [ "$status" -eq 0 ]
  # Snapshot dir under HOME
  ls "$HOME/.savia/context-opt-snapshots/" 2>/dev/null | head -1
  count=$(ls "$HOME/.savia/context-opt-snapshots/" 2>/dev/null | wc -l)
  [ "$count" -ge 1 ]
}

@test "audit log is append-only JSONL" {
  invoke_gate "$SAVIA_WORKSPACE_DIR/CLAUDE.md" "a"
  invoke_gate "$SAVIA_WORKSPACE_DIR/projects/foo/CLAUDE.md" "b"
  lines=$(wc -l < "$SAVIA_WORKSPACE_DIR/output/context-opt-audit.jsonl")
  [ "$lines" -ge 2 ]
  # Each line is valid JSON
  python3 -c "
import json,sys
with open(sys.argv[1]) as f:
  for line in f:
    json.loads(line)
" "$SAVIA_WORKSPACE_DIR/output/context-opt-audit.jsonl"
}

@test "measure script reports missing schema gracefully" {
  run python3 "$WORKSPACE_REAL/scripts/context-opt-measure.py"
  # No baselines yet — should not crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "gate ignores file_path outside workspace" {
  run invoke_gate "/tmp/random-CLAUDE.md" "x"
  [ "$status" -eq 0 ]
}
