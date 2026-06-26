#!/usr/bin/env bats
# tests/test-session-registry.bats — SE-229 Slice 1: 15 tests
# bats ≥ 1.7 required

REGISTRY=""

setup() {
  # Use a temp dir per test to avoid cross-test pollution
  export HOME_BACKUP="$HOME"
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export SAVIA_DIR="$TEST_HOME/.savia"
  mkdir -p "$SAVIA_DIR"

  # Locate the registry script relative to this test file
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  REGISTRY="${SCRIPT_DIR}/../scripts/session-registry.sh"
  # Ensure executable
  chmod +x "$REGISTRY"
}

teardown() {
  export HOME="$HOME_BACKUP"
  rm -rf "$TEST_HOME" 2>/dev/null || true
}

# Helper: create a stale timestamp (>10 min ago) in ISO-8601 UTC
stale_ts() {
  date -u -d "15 minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || python3 -c "from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(minutes=15)).strftime('%Y-%m-%dT%H:%M:%SZ'))"
}

# Helper: fresh timestamp
fresh_ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Test 1: register crea entrada en JSONL ────────────────────────────────────
@test "1: register creates entry in JSONL" {
  run bash "$REGISTRY" register \
    --session "sess-001" --nido "test-nido" \
    --branch "feature/test" --task "test task"
  [ "$status" -eq 0 ]
  [ -f "$SAVIA_DIR/active-sessions.jsonl" ]
  run grep '"session_id":"sess-001"' "$SAVIA_DIR/active-sessions.jsonl"
  [ "$status" -eq 0 ]
}

# ── Test 2: register con misma session_id es idempotente ─────────────────────
@test "2: register with same session_id is idempotent" {
  bash "$REGISTRY" register --session "sess-idem" --nido "n" --branch "b" --task "t"
  bash "$REGISTRY" register --session "sess-idem" --nido "n" --branch "b" --task "t"
  run grep -c '"session_id":"sess-idem"' "$SAVIA_DIR/active-sessions.jsonl"
  # Should have exactly 1 active entry (idempotent = no duplicate)
  [ "$output" -eq 1 ]
}

# ── Test 3: list muestra sesiones activas ─────────────────────────────────────
@test "3: list shows active sessions" {
  bash "$REGISTRY" register --session "sess-list" --nido "my-nido" \
    --branch "main" --task "coding"
  run bash "$REGISTRY" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"sess-list"* ]]
}

# ── Test 4: list no muestra sesiones con heartbeat >10 min ───────────────────
@test "4: list hides stale sessions (heartbeat >10 min)" {
  local ts; ts=$(stale_ts)
  local entry
  if command -v jq >/dev/null 2>&1; then
    entry=$(jq -cn \
      --arg sid "sess-stale" --arg ts "$ts" \
      '{session_id:$sid,pid:"1",nido:"n",branch:"b",task:"t",worktree:"",started_at:$ts,heartbeat_at:$ts,status:"active"}')
  else
    entry=$(python3 -c "
import json,sys
d={'session_id':'sess-stale','pid':'1','nido':'n','branch':'b','task':'t','worktree':'',
   'started_at':sys.argv[1],'heartbeat_at':sys.argv[1],'status':'active'}
print(json.dumps(d))" "$ts")
  fi
  echo "$entry" >> "$SAVIA_DIR/active-sessions.jsonl"

  run bash "$REGISTRY" list
  [ "$status" -eq 0 ]
  [[ "$output" != *"sess-stale"* ]]
}

# ── Test 5: claim devuelve 0 si rama libre ────────────────────────────────────
@test "5: claim returns 0 when branch is free" {
  run bash "$REGISTRY" claim --branch "free-branch" --session "sess-a"
  [ "$status" -eq 0 ]
}

# ── Test 6: claim devuelve 1 y warning si rama ocupada por otra sesión ────────
@test "6: claim returns 1 with warning when branch is taken by another session" {
  bash "$REGISTRY" register --session "sess-owner" --nido "n" \
    --branch "contested" --task "t"
  run bash "$REGISTRY" claim --branch "contested" --session "sess-other"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WARNING"* ]]
}

# ── Test 7: claim devuelve 0 si la única sesión con esa rama es la propia ─────
@test "7: claim returns 0 when only claimant for that branch is self" {
  bash "$REGISTRY" register --session "sess-self" --nido "n" \
    --branch "my-branch" --task "t"
  run bash "$REGISTRY" claim --branch "my-branch" --session "sess-self"
  [ "$status" -eq 0 ]
}

# ── Test 8: release marca entry como released ─────────────────────────────────
@test "8: release marks entry as released" {
  bash "$REGISTRY" register --session "sess-rel" --nido "n" \
    --branch "b" --task "t"
  run bash "$REGISTRY" release --session "sess-rel"
  [ "$status" -eq 0 ]
  run grep '"session_id":"sess-rel"' "$SAVIA_DIR/active-sessions.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"released"'* ]]
}

# ── Test 9: release + list no muestra la entrada released ─────────────────────
@test "9: released session is not shown by list" {
  bash "$REGISTRY" register --session "sess-hide" --nido "n" \
    --branch "b" --task "t"
  bash "$REGISTRY" release --session "sess-hide"
  run bash "$REGISTRY" list
  [[ "$output" != *"sess-hide"* ]]
}

# ── Test 10: heartbeat actualiza heartbeat_at ─────────────────────────────────
@test "10: heartbeat updates heartbeat_at" {
  # Write entry with stale heartbeat
  local ts; ts=$(stale_ts)
  local entry
  if command -v jq >/dev/null 2>&1; then
    entry=$(jq -cn --arg sid "sess-hb" --arg ts "$ts" \
      '{session_id:$sid,pid:"1",nido:"n",branch:"b",task:"t",worktree:"",started_at:$ts,heartbeat_at:$ts,status:"active"}')
  else
    entry=$(python3 -c "
import json,sys
d={'session_id':'sess-hb','pid':'1','nido':'n','branch':'b','task':'t','worktree':'',
   'started_at':sys.argv[1],'heartbeat_at':sys.argv[1],'status':'active'}
print(json.dumps(d))" "$ts")
  fi
  echo "$entry" >> "$SAVIA_DIR/active-sessions.jsonl"

  # Heartbeat should refresh it
  run bash "$REGISTRY" heartbeat --session "sess-hb"
  [ "$status" -eq 0 ]

  # Now list should show it (no longer stale)
  run bash "$REGISTRY" list
  [[ "$output" == *"sess-hb"* ]]
}

# ── Test 11: gc elimina entradas stale ────────────────────────────────────────
@test "11: gc removes stale entries (heartbeat >10 min)" {
  local ts; ts=$(stale_ts)
  local entry
  if command -v jq >/dev/null 2>&1; then
    entry=$(jq -cn --arg sid "sess-gc-stale" --arg ts "$ts" \
      '{session_id:$sid,pid:"1",nido:"n",branch:"b",task:"t",worktree:"",started_at:$ts,heartbeat_at:$ts,status:"active"}')
  else
    entry=$(python3 -c "
import json,sys
d={'session_id':'sess-gc-stale','pid':'1','nido':'n','branch':'b','task':'t','worktree':'',
   'started_at':sys.argv[1],'heartbeat_at':sys.argv[1],'status':'active'}
print(json.dumps(d))" "$ts")
  fi
  echo "$entry" >> "$SAVIA_DIR/active-sessions.jsonl"

  bash "$REGISTRY" gc
  run grep '"session_id":"sess-gc-stale"' "$SAVIA_DIR/active-sessions.jsonl"
  [ "$status" -ne 0 ]
}

# ── Test 12: gc no elimina entradas activas recientes ─────────────────────────
@test "12: gc does not remove recent active entries" {
  bash "$REGISTRY" register --session "sess-gc-keep" --nido "n" \
    --branch "b" --task "t"
  bash "$REGISTRY" gc
  run grep '"session_id":"sess-gc-keep"' "$SAVIA_DIR/active-sessions.jsonl"
  [ "$status" -eq 0 ]
}

# ── Test 13: concurrent writes no corrompen JSONL ─────────────────────────────
@test "13: concurrent writes do not corrupt JSONL" {
  # Fire 5 parallel registers
  for i in 1 2 3 4 5; do
    bash "$REGISTRY" register --session "sess-c${i}" --nido "n${i}" \
      --branch "b${i}" --task "t${i}" &
  done
  wait

  # Every line must be valid JSON
  local bad=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    python3 -c "import sys,json; json.loads(sys.argv[1])" "$line" 2>/dev/null || bad=$((bad+1))
  done < "$SAVIA_DIR/active-sessions.jsonl"
  [ "$bad" -eq 0 ]

  # All 5 sessions should be present
  for i in 1 2 3 4 5; do
    run grep "sess-c${i}" "$SAVIA_DIR/active-sessions.jsonl"
    [ "$status" -eq 0 ]
  done
}

# ── Test 14: gc con fichero vacío es no-op ────────────────────────────────────
@test "14: gc on empty file is no-op" {
  touch "$SAVIA_DIR/active-sessions.jsonl"
  run bash "$REGISTRY" gc
  [ "$status" -eq 0 ]
}

# ── Test 15: register sin nido funciona (nido="") ─────────────────────────────
@test "15: register without nido works (manual session, nido=empty string)" {
  run bash "$REGISTRY" register \
    --session "sess-manual" --nido "" --branch "main" --task "manual work"
  [ "$status" -eq 0 ]
  run grep '"session_id":"sess-manual"' "$SAVIA_DIR/active-sessions.jsonl"
  [ "$status" -eq 0 ]
  # nido field should be empty string, not missing
  [[ "$output" == *'"nido":""'* ]]
}
