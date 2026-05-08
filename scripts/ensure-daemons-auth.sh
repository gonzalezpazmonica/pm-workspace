#!/usr/bin/env bash
# ensure-daemons-auth.sh
# SPEC-SH02 (auto) — Verifica y, si falta, relanza auth de browser-daemons
# sin bloquear el ciclo del radar. Auto-toca SIGNAL cuando detecta fin de login
# vía CDP. Fail-fast sólo si tras el intento sigue sin haber auth válida.
#
# Contrato:
#   exit 0  → ambos daemons OK (status=running), radar puede seguir.
#   exit 1  → tras intento de re-auth, al menos uno sigue sin auth. Radar aborta.
#   exit 2  → configuración ausente (mail-accounts.json).
#
# Flujo por daemon:
#   1. Lee status.json. Si OK → skip.
#   2. Mata procesos zombie chrome del perfil + borra locks Singleton.
#   3. Lanza `browser-daemon.py {alias} --auth` en background.
#   4. Polling cada 5s al CDP port:
#        - éxito: URL outlook/mail/ sin login|sso|signin|signup|authorize
#        - timeout: AUTH_WAIT_SECONDS (default 540s = 9 min)
#   5. Al detectar éxito → touch SIGNAL.
#   6. Espera que status.json pase a running (timeout 30s).
#
# Config vía env vars:
#   AUTH_WAIT_SECONDS   default 540
#   AUTH_POLL_SECONDS   default 5
#   SAVIA_DAEMON_STATUS_DIR  default $HOME/.savia/outlook-inbox

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

ACCOUNTS_FILE="$HOME/.savia/mail-accounts.json"
STATUS_DIR="${SAVIA_DAEMON_STATUS_DIR:-$HOME/.savia/outlook-inbox}"
SIGNAL_FILE="$HOME/.savia/browser-ready.signal"
AUTH_WAIT_SECONDS="${AUTH_WAIT_SECONDS:-540}"
AUTH_POLL_SECONDS="${AUTH_POLL_SECONDS:-5}"
LOG_DIR="/tmp/savia-auth-logs"
mkdir -p "$LOG_DIR"

if [ ! -f "$ACCOUNTS_FILE" ]; then
  echo "ERROR: $ACCOUNTS_FILE missing" >&2
  exit 2
fi

# CDP ports by alias (must match browser-daemon.py DEFAULT_CDP_PORTS)
cdp_port_for() {
  case "$1" in
    account1) echo 9222 ;;
    account2) echo 9223 ;;
    *) echo 0 ;;
  esac
}

session_dir_for() {
  python -c "import json; a=json.load(open(r'$ACCOUNTS_FILE')); print(a.get('$1',{}).get('session_dir',''))" 2>/dev/null
}

daemon_status() {
  # echoes status string or empty
  local alias="$1"
  local f="$STATUS_DIR/${alias}-status.json"
  [ -f "$f" ] || { echo ""; return; }
  python -c "import json; print(json.load(open(r'$f')).get('status',''))" 2>/dev/null
}

daemon_status_fresh() {
  # True (exit 0) if status=running AND ts is today.
  local alias="$1"
  local f="$STATUS_DIR/${alias}-status.json"
  [ -f "$f" ] || return 1
  python - "$f" <<'PY' 2>/dev/null
import json, sys, datetime
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
if d.get("status") != "running":
    sys.exit(1)
ts = d.get("ts", "")
today = datetime.datetime.now().strftime("%Y-%m-%d")
sys.exit(0 if ts.startswith(today) else 1)
PY
}

# Kill orphan chrome processes whose command line contains the profile session_dir.
kill_orphan_chrome() {
  local session="$1"
  [ -z "$session" ] && return 0
  # Use PowerShell via a oneliner; tolerate absence of PS on non-Windows.
  command -v powershell.exe >/dev/null 2>&1 || return 0
  powershell.exe -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*$session*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" \
    >/dev/null 2>&1 || true
  # Clean profile locks
  rm -f "$HOME/.savia/$session/SingletonLock" \
        "$HOME/.savia/$session/SingletonCookie" \
        "$HOME/.savia/$session/SingletonSocket" 2>/dev/null
}

# Poll CDP until URL is logged-in Outlook; returns 0 on success, 1 on timeout.
wait_for_login() {
  local port="$1"
  local max_iters=$(( AUTH_WAIT_SECONDS / AUTH_POLL_SECONDS ))
  for _i in $(seq 1 "$max_iters"); do
    sleep "$AUTH_POLL_SECONDS"
    local url
    url=$(curl -s --max-time 3 "http://localhost:${port}/json/list" 2>/dev/null \
          | python -c "import sys,json
try:
  tabs=json.load(sys.stdin)
  print(tabs[0].get('url','') if tabs else '')
except Exception:
  print('')" 2>/dev/null)
    [ -z "$url" ] && continue
    if echo "$url" | grep -qE '(outlook\.office365\.com|outlook\.cloud\.microsoft)/mail/' && \
       ! echo "$url" | grep -qE '(login|sso\.|signin|signup|authorize|oauth2)'; then
      return 0
    fi
  done
  return 1
}

ensure_one() {
  local alias="$1"
  local port
  port=$(cdp_port_for "$alias")
  local session
  session=$(session_dir_for "$alias")

  if daemon_status_fresh "$alias"; then
    echo "$alias OK (fresh running)" >&2
    return 0
  fi

  echo "$alias needs auth — launching window..." >&2
  kill_orphan_chrome "$session"
  rm -f "$SIGNAL_FILE"

  local logf="$LOG_DIR/${alias}-auth-$(date +%Y%m%d-%H%M%S).log"
  : > "$logf"
  (python scripts/browser-daemon.py "$alias" --auth > "$logf" 2>&1) &
  local daemon_pid=$!
  echo "$alias daemon pid=$daemon_pid log=$logf" >&2

  # Give Chromium time to expose CDP
  sleep 6

  if wait_for_login "$port"; then
    echo "$alias login detected — signaling..." >&2
    touch "$SIGNAL_FILE"
  else
    echo "$alias login timeout after ${AUTH_WAIT_SECONDS}s" >&2
    return 1
  fi

  # Wait for daemon to consume SIGNAL and write status=running
  for _j in $(seq 1 15); do
    sleep 3
    if daemon_status_fresh "$alias"; then
      echo "$alias status=running" >&2
      return 0
    fi
  done
  echo "$alias SIGNAL touched but status did not reach running" >&2
  return 1
}

# Run check-daemon-auth first; skip work if everything is already green.
if bash "$SCRIPT_DIR/check-daemon-auth.sh" >/dev/null 2>&1; then
  echo '{"ensure":"skipped","reason":"already_ok"}'
  exit 0
fi

FAILED=0
for alias in account1 account2; do
  if ! ensure_one "$alias"; then
    FAILED=1
  fi
done

# Final verify
if bash "$SCRIPT_DIR/check-daemon-auth.sh" >/dev/null 2>&1; then
  echo '{"ensure":"ok"}'
  exit 0
fi

echo '{"ensure":"failed","hint":"run manually: python scripts/browser-daemon.py <alias> --auth"}' >&2
exit 1
