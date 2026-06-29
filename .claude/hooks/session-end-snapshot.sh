#!/usr/bin/env bash
set -uo pipefail
# session-end-snapshot.sh — Save context snapshot at session end
# Hook: Stop event. Runs when Claude session ends.
# PERF: optimized 2026-05-07 — fire-and-forget background, return immediately
# ─────────────────────────────────────────────────────────────────

ERR_LOG="$HOME/.savia/hook-errors.log"
trap 'echo "[$(date +%H:%M:%S)] session-end-snapshot: $BASH_COMMAND failed (line $LINENO)" >> "$ERR_LOG" 2>/dev/null' ERR

cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
# Derive SCRIPTS_DIR for SE-230 integration
SCRIPTS_DIR="${ROOT}/scripts"

SNAPSHOT_SCRIPT=""
for spath in "$ROOT/scripts/context-snapshot.sh" "./scripts/context-snapshot.sh"; do
  if [ -x "$spath" ]; then
    SNAPSHOT_SCRIPT="$spath"
    break
  fi
done

# Fire-and-forget: snapshot writes to disk async, hook returns immediately.
# Stop hook latency is observable to user; snapshot work is best-effort.
if [ -n "$SNAPSHOT_SCRIPT" ]; then
  ( echo '' | bash "$SNAPSHOT_SCRIPT" save > /dev/null 2>&1 ) & disown
fi

# ── SE-229: Session Registry release + gc (fire-and-forget) ──────────────────
REGISTRY_SCRIPT=""
for reg_path in "${ROOT}/scripts/session-registry.sh" \
                "./scripts/session-registry.sh"; do
  if [ -x "$reg_path" ] 2>/dev/null; then
    REGISTRY_SCRIPT="$reg_path"
    break
  fi
done

if [ -n "$REGISTRY_SCRIPT" ]; then
  (
    # Release current session if SAVIA_SESSION_ID is set
    if [ -n "${SAVIA_SESSION_ID:-}" ]; then
      bash "$REGISTRY_SCRIPT" release --session "$SAVIA_SESSION_ID" >/dev/null 2>&1 || true
    fi
    # GC stale entries if sessions file exists
    if [ -f "${HOME}/.savia/active-sessions.jsonl" ]; then
      bash "$REGISTRY_SCRIPT" gc >/dev/null 2>&1 || true
    fi
  ) & disown 2>/dev/null || true
fi

# SE-230: guardar estado focal al cerrar
if [ -n "${SAVIA_NIDO:-}" ]; then
  ( bash "$SCRIPTS_DIR/focal-switch.sh" --save-only --nido "$SAVIA_NIDO" > /dev/null 2>&1 ) & disown
fi

exit 0
