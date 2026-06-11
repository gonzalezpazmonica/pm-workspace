#!/usr/bin/env bash
set -uo pipefail
# session-cleanup.sh — SE-219 S3: orphan process cleanup (abtop pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Usage: session-cleanup.sh register --pid <N> [--label <str>]
#        session-cleanup.sh list
#        session-cleanup.sh cleanup
#        session-cleanup.sh orphans
# Exit: 0 always (except register --pid invalid: exit 2)

SESSION_ID="${SESSION_ACTION_SESSION:-$$}"
PIDS_FILE="${SAVIA_PIDS_FILE:-output/.session-pids-${SESSION_ID}.json}"

cmd="${1:-help}"; shift || true

# ── helpers ─────────────────────────────────────────────────────────────────

_read_pids_file() {
  local file="${1:-$PIDS_FILE}"
  [[ -f "$file" ]] || { echo '{}'; return; }
  python3 -c "
import sys, json
with open('$file', encoding='utf-8', errors='replace') as f:
    print(json.dumps(json.load(f)))
" 2>/dev/null || echo '{}'
}

_pid_running() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

# ── subcommands ──────────────────────────────────────────────────────────────

cmd_register() {
  local pid="" label="unlabeled"
  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --pid)    pid="${2:?--pid requires a value}"; shift 2 ;;
      --label)  label="${2:-unlabeled}"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$pid" ]]; then
    echo "ERROR: --pid is required" >&2
    exit 2
  fi

  # Validate PID is a positive integer
  if ! [[ "$pid" =~ ^[0-9]+$ ]] || [[ "$pid" -le 0 ]]; then
    echo "ERROR: invalid PID: $pid" >&2
    exit 2
  fi

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "now")

  mkdir -p "$(dirname "$PIDS_FILE")" 2>/dev/null || true

  python3 - "$PIDS_FILE" "$SESSION_ID" "$pid" "$label" "$ts" <<'PY'
import sys, json, os

pids_file  = sys.argv[1]
session_id = sys.argv[2]
pid        = int(sys.argv[3])
label      = sys.argv[4]
ts         = sys.argv[5]

data = {"session_id": session_id, "pids": []}
if os.path.isfile(pids_file):
    try:
        with open(pids_file) as f:
            data = json.load(f)
    except Exception:
        data = {"session_id": session_id, "pids": []}

# Avoid duplicates
existing_pids = {e["pid"] for e in data.get("pids", [])}
if pid not in existing_pids:
    data["pids"].append({"pid": pid, "label": label, "registered_at": ts})

with open(pids_file, "w") as f:
    json.dump(data, f, indent=2)
print(f"registered pid={pid} label={label}")
PY
}

cmd_list() {
  if [[ ! -f "$PIDS_FILE" ]]; then
    echo "(no pids registered for session $SESSION_ID)"
    exit 0
  fi

  python3 - "$PIDS_FILE" <<'PY'
import sys, json, os

pids_file = sys.argv[1]
try:
    with open(pids_file) as f:
        data = json.load(f)
except Exception:
    print("(error reading pids file)")
    sys.exit(0)

pids = data.get("pids", [])
if not pids:
    print("(empty)")
    sys.exit(0)

for entry in pids:
    pid = entry.get("pid", 0)
    label = entry.get("label", "")
    try:
        os.kill(pid, 0)
        status = "running"
    except (ProcessLookupError, PermissionError):
        status = "dead"
    print(f"  pid={pid:6d}  {status:7s}  {label}")
PY
}

cmd_cleanup() {
  if [[ ! -f "$PIDS_FILE" ]]; then
    exit 0
  fi

  python3 - "$PIDS_FILE" <<'PY'
import sys, json, os, time, signal

pids_file = sys.argv[1]
try:
    with open(pids_file) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

for entry in data.get("pids", []):
    pid = entry.get("pid", 0)
    if pid <= 0:
        continue
    try:
        os.kill(pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass

time.sleep(1)

for entry in data.get("pids", []):
    pid = entry.get("pid", 0)
    if pid <= 0:
        continue
    try:
        os.kill(pid, 0)   # still alive?
        os.kill(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
PY

  rm -f "$PIDS_FILE"
  exit 0
}

cmd_orphans() {
  local output_dir="${SAVIA_PIDS_FILE:-output}"
  output_dir="$(dirname "${SAVIA_PIDS_FILE:-output/.session-pids-placeholder}")"

  local files
  files=$(ls "${output_dir}"/.session-pids-*.json 2>/dev/null || true)

  if [[ -z "$files" ]]; then
    exit 0
  fi

  python3 - "$files" <<'PY'
import sys, json, os

files = sys.argv[1:]
for pids_file in files:
    pids_file = pids_file.strip()
    if not pids_file or not os.path.isfile(pids_file):
        continue
    try:
        with open(pids_file) as f:
            data = json.load(f)
    except Exception:
        continue
    pids = [e.get("pid", 0) for e in data.get("pids", [])]
    if not pids:
        print(pids_file)
        continue
    any_alive = False
    for pid in pids:
        try:
            os.kill(pid, 0)
            any_alive = True
            break
        except (ProcessLookupError, PermissionError):
            pass
    if not any_alive:
        print(pids_file)
PY
  exit 0
}

# ── dispatch ─────────────────────────────────────────────────────────────────

case "$cmd" in
  register) cmd_register "$@" ;;
  list)     cmd_list ;;
  cleanup)  cmd_cleanup ;;
  orphans)  cmd_orphans ;;
  help|--help|-h)
    echo "Usage: session-cleanup.sh {register --pid N [--label str] | list | cleanup | orphans}"
    exit 0 ;;
  *)
    echo "Unknown subcommand: $cmd" >&2
    exit 1 ;;
esac
