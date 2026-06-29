#!/usr/bin/env bash
# session-registry.sh — Session coordination registry (SE-229 Slice 1)
# Manages ~/.savia/active-sessions.jsonl with flock-protected writes.
# Usage: session-registry.sh <command> [options]
set -uo pipefail

SAVIA_DIR="${HOME}/.savia"
SESSIONS_FILE="${SAVIA_DIR}/active-sessions.jsonl"
LOCK_FILE="${SAVIA_DIR}/active-sessions.lock"
STALE_SECONDS=600  # 10 minutes

# ── Ensure ~/.savia/ exists ───────────────────────────────────────────────────
mkdir -p "$SAVIA_DIR"

# ── JSON helpers (prefer jq; fallback to python3) ────────────────────────────
_json_get() {
  local json="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r ".$key // empty" 2>/dev/null
  else
    python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    v = d.get('$key','')
    print(v if v is not None else '', end='')
except Exception:
    pass
" "$json" 2>/dev/null
  fi
}

_json_build() {
  # Args: key=value pairs, space-separated (values must not contain newlines)
  local kv_string="$1"
  if command -v jq >/dev/null 2>&1; then
    # Build via jq null reduction
    local obj='{}'
    while IFS='=' read -r k v; do
      obj=$(printf '%s' "$obj" | jq --arg k "$k" --arg v "$v" '. + {($k): $v}')
    done <<< "${kv_string// /$'\n'}"
    printf '%s' "$obj"
  else
    python3 - "$kv_string" <<'PYEOF'
import sys, json
kv_string = sys.argv[1]
d = {}
for pair in kv_string.split('\t'):
    if '=' in pair:
        k, v = pair.split('=', 1)
        d[k] = v
print(json.dumps(d), end='')
PYEOF
  fi
}

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_now_epoch() { date +%s; }

_iso_to_epoch() {
  local iso="$1"
  if date -d "$iso" +%s 2>/dev/null; then return; fi
  python3 -c "
import sys
from datetime import datetime, timezone
dt = datetime.strptime(sys.argv[1], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
" "$iso" 2>/dev/null || echo 0
}

# ── Low-level JSONL write with flock ─────────────────────────────────────────
_locked_write() {
  # $1 = temp file with new JSONL content to replace the file with
  local tmpfile="$1"
  (
    flock -w 5 200 || { echo "ERROR: flock timeout" >&2; exit 1; }
    cat "$tmpfile" > "$SESSIONS_FILE" 2>/dev/null || true
  ) 200>"$LOCK_FILE"
}

_locked_append() {
  # $1 = single JSON line to append
  local line="$1"
  (
    flock -w 5 200 || { echo "ERROR: flock timeout" >&2; exit 1; }
    printf '%s\n' "$line" >> "$SESSIONS_FILE"
  ) 200>"$LOCK_FILE"
}

# ── Subcommand: register ──────────────────────────────────────────────────────
cmd_register() {
  local session_id="" nido="" branch="" task="" worktree=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session)   session_id="$2"; shift 2 ;;
      --nido)      nido="$2";       shift 2 ;;
      --branch)    branch="$2";     shift 2 ;;
      --task)      task="$2";       shift 2 ;;
      --worktree)  worktree="$2";   shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$session_id" ]]; then
    echo "ERROR: --session <id> required" >&2; exit 1
  fi

  local now; now=$(_now_iso)

  # Idempotency: if session_id already exists with status=active, update heartbeat
  if [[ -f "$SESSIONS_FILE" ]]; then
    local existing
    existing=$(grep "\"session_id\":\"${session_id}\"" "$SESSIONS_FILE" 2>/dev/null | tail -1)
    if [[ -n "$existing" ]]; then
      local existing_status
      existing_status=$(_json_get "$existing" status)
      if [[ "$existing_status" == "active" ]]; then
        # Update heartbeat_at in-place
        cmd_heartbeat --session "$session_id"
        return 0
      fi
    fi
  fi

  # Build JSON line (tab-separated k=v for python fallback)
  if command -v jq >/dev/null 2>&1; then
    local entry
    entry=$(jq -cn \
      --arg sid "$session_id" \
      --arg pid "$$" \
      --arg nido "$nido" \
      --arg branch "$branch" \
      --arg task "$task" \
      --arg worktree "$worktree" \
      --arg now "$now" \
      '{session_id:$sid, pid:$pid, nido:$nido, branch:$branch, task:$task, worktree:$worktree, started_at:$now, heartbeat_at:$now, status:"active"}')
  else
    local entry
    entry=$(python3 -c "
import sys, json, os
d = {
  'session_id': sys.argv[1],
  'pid':        str(os.getppid()),
  'nido':       sys.argv[2],
  'branch':     sys.argv[3],
  'task':       sys.argv[4],
  'worktree':   sys.argv[5],
  'started_at': sys.argv[6],
  'heartbeat_at': sys.argv[6],
  'status':     'active',
}
print(json.dumps(d))
" "$session_id" "$nido" "$branch" "$task" "$worktree" "$now")
  fi

  _locked_append "$entry"
}

# ── Subcommand: list ──────────────────────────────────────────────────────────
cmd_list() {
  if [[ ! -f "$SESSIONS_FILE" ]]; then
    echo "No active sessions."
    return 0
  fi

  local now_epoch; now_epoch=$(_now_epoch)
  local found=0

  printf "%-36s %-20s %-30s %-10s %s\n" "SESSION_ID" "NIDO" "BRANCH" "STATUS" "TASK"
  printf '%s\n' "$(printf '─%.0s' {1..110})"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local status hb_iso hb_epoch age
    status=$(_json_get "$line" status)
    [[ "$status" != "active" ]] && continue

    hb_iso=$(_json_get "$line" heartbeat_at)
    hb_epoch=$(_iso_to_epoch "$hb_iso")
    age=$(( now_epoch - hb_epoch ))
    [[ "$age" -ge "$STALE_SECONDS" ]] && continue

    local sid nido branch task
    sid=$(_json_get "$line" session_id)
    nido=$(_json_get "$line" nido)
    branch=$(_json_get "$line" branch)
    task=$(_json_get "$line" task)

    printf "%-36s %-20s %-30s %-10s %s\n" \
      "${sid:0:36}" "${nido:0:20}" "${branch:0:30}" "active" "${task:0:50}"
    found=$(( found + 1 ))
  done < "$SESSIONS_FILE"

  if [[ "$found" -eq 0 ]]; then
    echo "No active sessions."
  fi
}

# ── Subcommand: claim ─────────────────────────────────────────────────────────
cmd_claim() {
  local branch="" session_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch)  branch="$2";     shift 2 ;;
      --session) session_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$branch" || -z "$session_id" ]]; then
    echo "ERROR: --branch and --session required" >&2; exit 1
  fi

  if [[ ! -f "$SESSIONS_FILE" ]]; then
    return 0  # No sessions file — branch is free
  fi

  local now_epoch; now_epoch=$(_now_epoch)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local status b sid hb_iso hb_epoch age
    status=$(_json_get "$line" status)
    [[ "$status" != "active" ]] && continue

    b=$(_json_get "$line" branch)
    [[ "$b" != "$branch" ]] && continue

    hb_iso=$(_json_get "$line" heartbeat_at)
    hb_epoch=$(_iso_to_epoch "$hb_iso")
    age=$(( now_epoch - hb_epoch ))
    [[ "$age" -ge "$STALE_SECONDS" ]] && continue

    sid=$(_json_get "$line" session_id)
    # Same session claiming its own branch — OK
    [[ "$sid" == "$session_id" ]] && continue

    echo "WARNING: branch '$branch' is already claimed by session '$sid'" >&2
    exit 1
  done < "$SESSIONS_FILE"

  return 0
}

# ── Subcommand: release ───────────────────────────────────────────────────────
cmd_release() {
  local session_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) session_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$session_id" ]]; then
    echo "ERROR: --session <id> required" >&2; exit 1
  fi

  if [[ ! -f "$SESSIONS_FILE" ]]; then return 0; fi

  local tmpfile; tmpfile=$(mktemp)
  local now; now=$(_now_iso)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local sid
    sid=$(_json_get "$line" session_id)
    if [[ "$sid" == "$session_id" ]]; then
      if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$(printf '%s' "$line" | jq -c --arg now "$now" '.status="released" | .heartbeat_at=$now')" >> "$tmpfile"
      else
        python3 -c "
import sys, json
d = json.loads(sys.argv[1])
d['status'] = 'released'
d['heartbeat_at'] = sys.argv[2]
print(json.dumps(d))
" "$line" "$now" >> "$tmpfile"
      fi
    else
      printf '%s\n' "$line" >> "$tmpfile"
    fi
  done < "$SESSIONS_FILE"

  _locked_write "$tmpfile"
  rm -f "$tmpfile"
}

# ── Subcommand: heartbeat ─────────────────────────────────────────────────────
cmd_heartbeat() {
  local session_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) session_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$session_id" ]]; then
    echo "ERROR: --session <id> required" >&2; exit 1
  fi

  if [[ ! -f "$SESSIONS_FILE" ]]; then return 0; fi

  local tmpfile; tmpfile=$(mktemp)
  local now; now=$(_now_iso)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local sid
    sid=$(_json_get "$line" session_id)
    if [[ "$sid" == "$session_id" ]]; then
      if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$(printf '%s' "$line" | jq -c --arg now "$now" '.heartbeat_at=$now')" >> "$tmpfile"
      else
        python3 -c "
import sys, json
d = json.loads(sys.argv[1])
d['heartbeat_at'] = sys.argv[2]
print(json.dumps(d))
" "$line" "$now" >> "$tmpfile"
      fi
    else
      printf '%s\n' "$line" >> "$tmpfile"
    fi
  done < "$SESSIONS_FILE"

  _locked_write "$tmpfile"
  rm -f "$tmpfile"
}

# ── Subcommand: gc ────────────────────────────────────────────────────────────
cmd_gc() {
  if [[ ! -f "$SESSIONS_FILE" ]]; then return 0; fi

  local now_epoch; now_epoch=$(_now_epoch)
  local tmpfile; tmpfile=$(mktemp)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local status hb_iso hb_epoch age
    status=$(_json_get "$line" status)

    # Drop released entries
    if [[ "$status" == "released" ]]; then continue; fi

    # Drop stale active entries
    if [[ "$status" == "active" ]]; then
      hb_iso=$(_json_get "$line" heartbeat_at)
      hb_epoch=$(_iso_to_epoch "$hb_iso")
      age=$(( now_epoch - hb_epoch ))
      if [[ "$age" -ge "$STALE_SECONDS" ]]; then continue; fi
    fi

    printf '%s\n' "$line" >> "$tmpfile"
  done < "$SESSIONS_FILE"

  _locked_write "$tmpfile"
  rm -f "$tmpfile"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  register)  cmd_register "$@" ;;
  list)      cmd_list "$@" ;;
  claim)     cmd_claim "$@" ;;
  release)   cmd_release "$@" ;;
  heartbeat) cmd_heartbeat "$@" ;;
  gc)        cmd_gc "$@" ;;
  *)
    echo "Usage: session-registry.sh <register|list|claim|release|heartbeat|gc> [options]" >&2
    exit 1
    ;;
esac
