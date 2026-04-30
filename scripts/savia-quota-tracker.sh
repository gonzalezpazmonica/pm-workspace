#!/usr/bin/env bash
set -uo pipefail
# savia-quota-tracker.sh — SPEC-127 Slice 5
#
# Generic quota/budget tracker. Reads `budget_kind` and `budget_limit` from
# `~/.savia/preferences.yaml` (per-user). Counts consumption per session
# via heuristics that work across any provider (request count, token count,
# or dollar amount via per-request rate). When `budget_kind: none` (e.g.
# LocalAI / Ollama / self-hosted), the tracker skips silently.
#
# Subcommands:
#   record <event-json>           Append a request event to the session log.
#   summary                        Print month-to-date consumption summary.
#   threshold                      Print {none|under-70|over-70|over-85|over-95|exceeded}.
#   reset --confirm                Wipe the session log (irreversible).
#   status                         Quick: kind, limit, MTD, % used, threshold.
#
# Storage: `${SAVIA_QUOTA_DIR:-$HOME/.savia/quota}/${USER}.jsonl` — N3,
# never committed to repo. One JSONL line per recorded event:
#   {"ts": "<ISO>", "kind": "req|tokens|dollars", "value": <number>, "tool": "<name>"}
#
# Provider-agnostic — branches on `budget_kind` (declared by the user),
# never on vendor name. PV-06.
#
# Reference: SPEC-127 Slice 5 AC-5.1, AC-5.2, AC-5.3
# Reference: docs/rules/domain/provider-agnostic-env.md

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PREFS_SCRIPT="${ROOT}/scripts/savia-preferences.sh"
QUOTA_DIR="${SAVIA_QUOTA_DIR:-${HOME:-/tmp}/.savia/quota}"
QUOTA_LOG="${QUOTA_DIR}/${USER:-default}.jsonl"

usage() {
  cat <<USG
Usage: savia-quota-tracker.sh <subcommand> [args]

Subcommands:
  record <event-json>           Append event {ts, kind, value, tool}
  summary                       MTD consumption summary
  threshold                     Print threshold marker
  reset --confirm               Wipe the session log
  status                        Compact one-line status

Storage: ${QUOTA_LOG} (N3, never committed)
Reads policy from: ~/.savia/preferences.yaml (budget_kind / budget_limit)
USG
}

# ── Read policy from preferences.yaml ──────────────────────────────────────
budget_kind() {
  if [[ -x "$PREFS_SCRIPT" ]]; then
    bash "$PREFS_SCRIPT" get budget_kind 2>/dev/null
  fi
}

budget_limit() {
  if [[ -x "$PREFS_SCRIPT" ]]; then
    bash "$PREFS_SCRIPT" get budget_limit 2>/dev/null
  fi
}

# ── Storage management ─────────────────────────────────────────────────────
ensure_log() {
  mkdir -p "$QUOTA_DIR" 2>/dev/null || true
  [[ -f "$QUOTA_LOG" ]] || : > "$QUOTA_LOG"
}

# ── Subcommands ────────────────────────────────────────────────────────────
record_event() {
  local event_json="${1:-}"
  if [[ -z "$event_json" ]]; then
    echo "ERROR: record requires JSON event payload" >&2
    return 2
  fi
  local kind
  kind=$(budget_kind)
  case "$kind" in
    none|"")
      # No quota declared — silent skip per AC-5.3
      return 0
      ;;
  esac
  ensure_log
  # Validate JSON (avoid corrupt log lines on bad input)
  if ! printf '%s' "$event_json" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
    echo "ERROR: invalid JSON event" >&2
    return 2
  fi
  printf '%s\n' "$event_json" >> "$QUOTA_LOG"
}

summary() {
  local kind
  kind=$(budget_kind)
  if [[ -z "$kind" || "$kind" == "none" ]]; then
    echo "no quota declared (budget_kind=${kind:-unset}) — tracker idle"
    return 0
  fi
  if [[ ! -f "$QUOTA_LOG" ]]; then
    echo "no events recorded yet (kind=$kind)"
    return 0
  fi
  python3 - "$QUOTA_LOG" "$kind" "$(budget_limit)" <<'PY'
import json, sys
from datetime import datetime, timezone
log_path, kind, limit = sys.argv[1], sys.argv[2], sys.argv[3]
now = datetime.now(timezone.utc)
month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).isoformat().replace("+00:00", "Z")
total = 0.0
events = 0
with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        ts = ev.get("ts", "")
        if ts < month_start:
            continue
        if ev.get("kind") not in ("req", "tokens", "dollars"):
            continue
        total += float(ev.get("value", 0))
        events += 1
unit = {"req-count": "reqs", "token-count": "tokens", "dollar-cap": "$"}.get(kind, "units")
print(f"kind: {kind}")
print(f"limit: {limit or '<unset>'}")
print(f"events MTD: {events}")
print(f"consumption MTD: {total:g} {unit}")
if limit:
    try:
        pct = 100 * total / float(limit)
        print(f"% used: {pct:.1f}%")
    except (ValueError, ZeroDivisionError):
        pass
PY
}

threshold() {
  local kind limit total
  kind=$(budget_kind)
  if [[ -z "$kind" || "$kind" == "none" ]]; then
    echo "none"
    return 0
  fi
  limit=$(budget_limit)
  if [[ -z "$limit" ]]; then
    echo "none"
    return 0
  fi
  if [[ ! -f "$QUOTA_LOG" ]]; then
    echo "under-70"
    return 0
  fi
  total=$(python3 - "$QUOTA_LOG" <<'PY'
import json, sys
from datetime import datetime, timezone
now = datetime.now(timezone.utc)
month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).isoformat().replace("+00:00", "Z")
total = 0.0
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        if ev.get("ts", "") < month_start:
            continue
        total += float(ev.get("value", 0))
print(total)
PY
)
  python3 - "$total" "$limit" <<'PY'
import sys
total = float(sys.argv[1] or 0)
limit = float(sys.argv[2] or 0)
if limit <= 0:
    print("none"); sys.exit(0)
pct = 100 * total / limit
if pct >= 100: print("exceeded")
elif pct >= 95: print("over-95")
elif pct >= 85: print("over-85")
elif pct >= 70: print("over-70")
else: print("under-70")
PY
}

reset_log() {
  if [[ "${1:-}" != "--confirm" ]]; then
    echo "ERROR: reset requires --confirm (irreversible)" >&2
    return 2
  fi
  if [[ -f "$QUOTA_LOG" ]]; then
    rm -f "$QUOTA_LOG"
    echo "quota log deleted"
  else
    echo "no log to delete"
  fi
}

status() {
  local kind=$(budget_kind)
  local limit=$(budget_limit)
  local thr=$(threshold)
  printf 'kind=%s limit=%s threshold=%s\n' "${kind:-unset}" "${limit:-unset}" "$thr"
}

case "${1:-}" in
  record)    shift; record_event "${1:-}" ;;
  summary)   summary ;;
  threshold) threshold ;;
  reset)     shift; reset_log "${1:-}" ;;
  status)    status ;;
  --help|-h|help) usage ;;
  *) echo "unknown subcommand: ${1:-(none)}" >&2; usage >&2; exit 2 ;;
esac
