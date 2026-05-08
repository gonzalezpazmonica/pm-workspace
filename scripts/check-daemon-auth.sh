#!/usr/bin/env bash
# check-daemon-auth.sh
# SPEC-SH02 — Deteccion proactiva de expiracion de auth en browser-daemon
#
# Lee ~/.savia/outlook-inbox/{alias}-status.json para account1 y account2.
# Exit codes:
#   0 → ambos daemons OK (status=running y last_check <30 min).
#   1 → alguno needs_auth / session_expired / error.
#   2 → fichero(s) missing (tratar como needs_auth).
#   3 → stale (last_check >30 min pero status=running).
# Salida JSON estructurada en stdout y lineas human-readable en stderr.

set -u

STATUS_DIR="${SAVIA_DAEMON_STATUS_DIR:-$HOME/.savia/outlook-inbox}"
STALE_THRESHOLD_SECONDS="${SAVIA_STALE_THRESHOLD_SECONDS:-1800}"  # 30 min

ACCOUNTS=("account1" "account2")

# Estado agregado
any_needs_auth=0
any_missing=0
any_stale=0

declare -A acct_status
declare -A acct_age_minutes
declare -A acct_action

now_epoch=$(date -u +%s)

iso8601_to_epoch() {
  local iso="$1"
  # Admite sufijo Z o +00:00
  local clean="${iso%Z}"
  clean="${clean%+00:00}"
  # date GNU/BSD/MSYS maneja ambos formatos con -d
  date -u -d "$clean" +%s 2>/dev/null || echo ""
}

for alias in "${ACCOUNTS[@]}"; do
  file="$STATUS_DIR/${alias}-status.json"
  relaunch_cmd="python scripts/browser-daemon.py ${alias} --auth"

  if [ ! -f "$file" ]; then
    acct_status[$alias]="missing"
    acct_age_minutes[$alias]="null"
    acct_action[$alias]="$relaunch_cmd"
    any_missing=1
    printf '%s MISSING  %s\n' "$alias" "$relaunch_cmd" >&2
    continue
  fi

  # Leer JSON sin jq (minima dependencia)
  content=$(cat "$file" 2>/dev/null | tr -d '\r')
  status=$(printf '%s' "$content" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  last_check=$(printf '%s' "$content" | sed -n 's/.*"last_check"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

  if [ -z "$status" ]; then
    acct_status[$alias]="corrupt"
    acct_age_minutes[$alias]="null"
    acct_action[$alias]="$relaunch_cmd"
    any_needs_auth=1
    printf '%s CORRUPT  %s\n' "$alias" "$relaunch_cmd" >&2
    continue
  fi

  age_minutes="null"
  if [ -n "$last_check" ]; then
    last_epoch=$(iso8601_to_epoch "$last_check")
    if [ -n "$last_epoch" ]; then
      age_seconds=$(( now_epoch - last_epoch ))
      age_minutes=$(( age_seconds / 60 ))
    fi
  fi

  if [ "$status" = "running" ]; then
    # Comprobar stale
    if [ "$age_minutes" != "null" ] && [ "$age_minutes" -gt $(( STALE_THRESHOLD_SECONDS / 60 )) ]; then
      acct_status[$alias]="stale"
      acct_age_minutes[$alias]="$age_minutes"
      acct_action[$alias]="$relaunch_cmd"
      any_stale=1
      printf '%s STALE    age=%smin %s\n' "$alias" "$age_minutes" "$relaunch_cmd" >&2
    else
      acct_status[$alias]="ok"
      acct_age_minutes[$alias]="$age_minutes"
      acct_action[$alias]="none"
      printf '%s OK       age=%smin\n' "$alias" "$age_minutes" >&2
    fi
  else
    # needs_auth, session_expired, error
    acct_status[$alias]="$status"
    acct_age_minutes[$alias]="$age_minutes"
    acct_action[$alias]="$relaunch_cmd"
    any_needs_auth=1
    printf '%s %s  %s\n' "$alias" "$(echo $status | tr '[:lower:]' '[:upper:]')" "$relaunch_cmd" >&2
  fi
done

# Construir JSON estructurado en stdout
printf '{"accounts":{'
first=1
for alias in "${ACCOUNTS[@]}"; do
  if [ $first -eq 0 ]; then printf ','; fi
  first=0
  age="${acct_age_minutes[$alias]}"
  printf '"%s":{"status":"%s","age_minutes":%s,"action":"%s"}' \
    "$alias" "${acct_status[$alias]}" "$age" "${acct_action[$alias]}"
done
printf '}}\n'

# Precedencia de exit codes (del spec):
# 2 missing > 1 needs_auth > 3 stale > 0 ok
if [ $any_missing -eq 1 ]; then
  exit 2
fi
if [ $any_needs_auth -eq 1 ]; then
  exit 1
fi
if [ $any_stale -eq 1 ]; then
  exit 3
fi
exit 0
