#!/usr/bin/env bash
set -uo pipefail
# cognitive-debt.sh — SPEC-107 Phase 1 entry point.
#
# Manages opt-in cognitive-debt measurement: enable / disable / status.
# Phase 1 is OPT-IN by default (CD-04). The hooks ship installed but dormant
# until the user runs `cognitive-debt.sh enable`.
#
# Subcommands:
#   enable    — append hook entries to .claude/settings.json (with backup)
#   disable   — remove hook entries from .claude/settings.json
#   status    — show current state + summary of recent telemetry
#   summary   — aggregate weekly stats from telemetry log
#   forget    — wipe all telemetry (irreversible, requires --confirm)
#
# Privacy contract (CD-03):
#   - Telemetry lives in ~/.savia/cognitive-load/{user}.jsonl, N3 gitignored.
#   - Never exposed to team/manager/exec reports.
#   - Equality Shield: cannot be used as evaluation criterion (Rule #23).
#
# Reference: SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`)
# Pattern source: own — privacy-first telemetry from MIT/MS-CMU/CMU evidence (2025).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS="${SAVIA_SETTINGS_OVERRIDE:-$ROOT_DIR/.claude/settings.json}"

USER_NAME="${USER:-unknown}"
TELEMETRY_DIR="${SAVIA_COGNITIVE_DIR:-$HOME/.savia/cognitive-load}"
TELEMETRY_LOG="$TELEMETRY_DIR/$USER_NAME.jsonl"

HOOK_TELEMETRY="$ROOT_DIR/.opencode/hooks/cognitive-debt-telemetry.sh"
HOOK_HYPOTHESIS="$ROOT_DIR/.opencode/hooks/cognitive-debt-hypothesis-first.sh"

usage() {
  sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

ensure_telemetry_dir() {
  mkdir -p "$TELEMETRY_DIR" 2>/dev/null || {
    echo "ERROR: cannot create $TELEMETRY_DIR" >&2
    exit 4
  }
  chmod 700 "$TELEMETRY_DIR" 2>/dev/null || true
}

# settings.json must parse before we back it up or touch it: otherwise the
# edit fails half-way and the old code still reported success.
require_valid_json() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SETTINGS" 2>/dev/null && return 0
  echo "ERROR: $SETTINGS is not valid JSON — left untouched." >&2
  return 1
}

backup_settings() {
  local backup="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S).$$"
  cp "$SETTINGS" "$backup"
  echo "Backup: $backup"
}

# Shared Python prelude for enable/disable. ensure_ascii=False keeps accents
# verbatim (settings.json round-trips byte-identical); os.replace is atomic.
PY_SETTINGS_IO='import json, os, sys, tempfile
path = sys.argv[1]
def read_settings():
    with open(path, encoding="utf-8") as f:
        return json.load(f)
def write_settings(cfg):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.chmod(tmp, os.stat(path).st_mode & 0o777)
    os.replace(tmp, path)'

# ── Subcommand: status ──────────────────────────────────────────────────────

cmd_status() {
  echo "Cognitive Debt — SPEC-107 Phase 1 status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Hook activation state (does settings.json reference our hooks?)
  local enabled=0
  if grep -qF "cognitive-debt-telemetry.sh" "$SETTINGS" 2>/dev/null; then
    enabled=1
  fi
  if [ "$enabled" -eq 1 ]; then
    echo "  State:        ENABLED (hooks wired in settings.json)"
  else
    echo "  State:        DISABLED (opt-in default per CD-04)"
    echo "  Activate:     bash scripts/cognitive-debt.sh enable"
  fi

  echo "  User:         $USER_NAME"
  echo "  Telemetry:    $TELEMETRY_LOG"

  if [ -f "$TELEMETRY_LOG" ]; then
    local lines size today_count
    lines=$(wc -l < "$TELEMETRY_LOG" 2>/dev/null || echo 0)
    size=$(du -h "$TELEMETRY_LOG" 2>/dev/null | awk '{print $1}')
    # Timestamps are written in UTC by the telemetry hook: compare in UTC.
    # grep -c prints 0 and exits 1 on no match; keep its output, not a 2nd 0.
    today_count=$(grep -cE "\"ts\": ?\"$(date -u +%Y-%m-%d)" "$TELEMETRY_LOG" 2>/dev/null)
    today_count="${today_count:-0}"
    echo "  Total events: $lines"
    echo "  Today:        $today_count events"
    echo "  Log size:     $size"
  else
    echo "  Total events: 0 (no telemetry yet)"
  fi

  echo ""
  echo "  Hooks installed:"
  [ -x "$HOOK_TELEMETRY" ] && echo "    ✓ telemetry (PostToolUse, async)" || echo "    ✗ telemetry MISSING"
  [ -x "$HOOK_HYPOTHESIS" ] && echo "    ✓ hypothesis-first (warning-only, Phase 1)" || echo "    ✗ hypothesis-first MISSING"

  echo ""
  echo "  Privacy: telemetry is N3 (~/.savia/, gitignored, never exported)."
  echo "  Forget:  bash scripts/cognitive-debt.sh forget --confirm"
}

# ── Subcommand: summary (weekly aggregate) ───────────────────────────────────

cmd_summary() {
  if [ ! -f "$TELEMETRY_LOG" ]; then
    echo "No telemetry data yet. Run 'cognitive-debt.sh enable' to start."
    exit 0
  fi
  echo "Cognitive Debt — Weekly summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  python3 - "$TELEMETRY_LOG" <<'PY'
import json, sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

path = sys.argv[1]
# The hook writes UTC timestamps: the window is the last 7 UTC days,
# today included (today-6 .. today).
window_start = str(datetime.now(timezone.utc).date() - timedelta(days=6))

per_day = defaultdict(int)
fast_accept = timed = total = 0

with open(path, errors="replace") as f:
    for line in f:
        try:
            ev = json.loads(line)
        except ValueError:
            continue  # malformed line: skipped by design, the log is best-effort
        if not isinstance(ev, dict) or not isinstance(ev.get("ts"), str):
            continue  # not an event record
        d = ev["ts"][:10]
        if d < window_start:
            continue
        per_day[d] += 1
        total += 1
        # No numeric duration (the hook writes null when the payload has none)
        # says nothing about acceptance speed: excluded from the ratio.
        dur = ev.get("duration_ms")
        if isinstance(dur, (int, float)) and not isinstance(dur, bool):
            timed += 1
            fast_accept += dur < 5000

ratio = f"{fast_accept / timed * 100:.0f}%" if timed else "n/a"
print(f"  Total events (last 7d):  {total}")
print(f"  Fast-accept ratio:       {ratio}   (timed events: {timed}; "
      f"<5s between suggest and accept — proxy for skip-verification)")
print()
print("  Per day:")
for d in sorted(per_day):
    bar = "█" * min(per_day[d], 30)
    print(f"    {d}  {per_day[d]:>4}  {bar}")
PY

  # ── Quota integration (SPEC-127 Slice 5 + Slice 2b-ii) ─────────────────
  # If the user declared a budget in ~/.savia/preferences.yaml, also show
  # the month-to-date consumption summary right after cognitive metrics.
  local quota_tracker="${SCRIPT_DIR:-$(dirname "$0")}/savia-quota-tracker.sh"
  if [ -x "$quota_tracker" ]; then
    echo ""
    echo "Savia quota — month-to-date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$quota_tracker" summary 2>/dev/null || true
  fi
}

# ── Subcommand: enable ──────────────────────────────────────────────────────

cmd_enable() {
  ensure_telemetry_dir

  if [ ! -f "$SETTINGS" ]; then
    echo "ERROR: $SETTINGS not found — cannot wire hooks." >&2
    exit 5
  fi

  if grep -qF "cognitive-debt-telemetry.sh" "$SETTINGS" 2>/dev/null; then
    echo "Already enabled. Run 'cognitive-debt.sh status' to see state."
    return 0
  fi

  require_valid_json || exit 6
  backup_settings

  # Python does the JSON edit; write_settings() keeps non-ASCII text verbatim
  # and replaces the file atomically.
  { printf '%s\n' "$PY_SETTINGS_IO"; cat <<'PY'; } | python3 - "$SETTINGS" \
    || { echo "ERROR: could not update $SETTINGS" >&2; exit 6; }
cfg = read_settings()
cfg.setdefault("hooks", {})

# Same entry shape as the workspace's own registration: quoted project dir
# (paths with spaces), named, non-blocking, short timeout.
def add_hook(event, name, matcher, timeout):
    hook = {"type": "command",
            "command": f'bash "$CLAUDE_PROJECT_DIR"/.opencode/hooks/{name}.sh',
            "name": name, "blocking": False, "timeout": timeout}
    arr = cfg["hooks"].setdefault(event, [])
    for entry in arr:
        if entry.get("matcher") == matcher:
            if not any(name in h.get("command", "") for h in entry.get("hooks", [])):
                entry.setdefault("hooks", []).append(hook)
            return
    arr.append({"matcher": matcher, "hooks": [hook]})

add_hook("PostToolUse", "cognitive-debt-telemetry", "Edit|Write|Task", 2)
add_hook("PreToolUse", "cognitive-debt-hypothesis-first", "Edit|Write", 3)

write_settings(cfg)
print("Hooks wired in settings.json")
PY

  echo "Cognitive Debt enabled. Hooks active on next Claude Code / OpenCode restart."
  echo "Disable any time: bash scripts/cognitive-debt.sh disable"
}

# ── Subcommand: disable ─────────────────────────────────────────────────────

cmd_disable() {
  if [ ! -f "$SETTINGS" ]; then
    echo "settings.json not found — nothing to disable."
    exit 0
  fi
  if ! grep -qF "cognitive-debt-telemetry.sh" "$SETTINGS" 2>/dev/null; then
    echo "Already disabled."
    return 0
  fi

  require_valid_json || exit 6
  backup_settings

  { printf '%s\n' "$PY_SETTINGS_IO"; cat <<'PY'; } | python3 - "$SETTINGS" \
    || { echo "ERROR: could not update $SETTINGS" >&2; exit 6; }
cfg = read_settings()
hooks = cfg.get("hooks", {})
# Only the two hooks that `enable` wires. cognitive-debt-check.sh is a
# separate opt-in (SAVIA_COGNITIVE_MONITOR) and must survive a disable.
OURS = ("cognitive-debt-telemetry.sh", "cognitive-debt-hypothesis-first.sh")

def strip_event(event):
    arr = hooks.get(event, [])
    new_arr = []
    for entry in arr:
        entry["hooks"] = [h for h in entry.get("hooks", [])
                          if not any(o in h.get("command", "") for o in OURS)]
        if entry["hooks"]:
            new_arr.append(entry)
    if new_arr:
        hooks[event] = new_arr
    elif event in hooks:
        del hooks[event]

strip_event("PostToolUse")
strip_event("PreToolUse")

write_settings(cfg)
print("Hooks removed from settings.json")
PY

  echo "Cognitive Debt disabled. Telemetry preserved (run 'forget --confirm' to wipe)."
}

# ── Subcommand: forget ──────────────────────────────────────────────────────

cmd_forget() {
  local confirm=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --confirm) confirm=1; shift ;;
      *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
  done

  if [ "$confirm" -ne 1 ]; then
    echo "ERROR: --confirm required (this is irreversible)" >&2
    echo "Will delete: $TELEMETRY_LOG" >&2
    exit 2
  fi

  if [ -f "$TELEMETRY_LOG" ]; then
    rm -f "$TELEMETRY_LOG"
    echo "Telemetry wiped: $TELEMETRY_LOG"
  else
    echo "No telemetry to wipe."
  fi
}

# ── Dispatch ────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage

case "${1:-}" in
  status)  shift; cmd_status "$@" ;;
  summary) shift; cmd_summary "$@" ;;
  enable)  shift; cmd_enable "$@" ;;
  disable) shift; cmd_disable "$@" ;;
  forget)  shift; cmd_forget "$@" ;;
  -h|--help) usage ;;
  *) echo "ERROR: unknown subcommand: $1" >&2; usage ;;
esac
