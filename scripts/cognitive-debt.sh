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
SETTINGS="$ROOT_DIR/.claude/settings.json"

USER_NAME="${USER:-unknown}"
TELEMETRY_DIR="${SAVIA_COGNITIVE_DIR:-$HOME/.savia/cognitive-load}"
TELEMETRY_LOG="$TELEMETRY_DIR/$USER_NAME.jsonl"

HOOK_TELEMETRY="$ROOT_DIR/.claude/hooks/cognitive-debt-telemetry.sh"
HOOK_HYPOTHESIS="$ROOT_DIR/.claude/hooks/cognitive-debt-hypothesis-first.sh"

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

ensure_telemetry_dir() {
  mkdir -p "$TELEMETRY_DIR" 2>/dev/null || {
    echo "ERROR: cannot create $TELEMETRY_DIR" >&2
    exit 4
  }
  chmod 700 "$TELEMETRY_DIR" 2>/dev/null || true
}

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
    today_count=$(grep -c "$(date +%Y-%m-%d)" "$TELEMETRY_LOG" 2>/dev/null || echo 0)
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
from datetime import date, timedelta

path = sys.argv[1]
today = date.today()
week_ago = today - timedelta(days=7)

per_day = defaultdict(int)
fast_accept = 0
total = 0

with open(path) as f:
    for line in f:
        try:
            ev = json.loads(line)
            ts = ev.get("ts", "")
            d = ts[:10]
            if d >= str(week_ago):
                per_day[d] += 1
                total += 1
                if ev.get("duration_ms", 999) < 5000:
                    fast_accept += 1
        except Exception:
            continue

print(f"  Total events (last 7d):  {total}")
print(f"  Fast-accept ratio:       {(fast_accept/total*100 if total else 0):.0f}%   "
      f"(<5s between suggest and accept — proxy for skip-verification)")
print()
print("  Per day:")
for d in sorted(per_day):
    bar = "█" * min(per_day[d], 30)
    print(f"    {d}  {per_day[d]:>4}  {bar}")
PY
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

  # Backup
  local backup="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$backup"
  echo "Backup: $backup"

  # Use python to do safe JSON edit (preserves formatting where possible).
  python3 - "$SETTINGS" "$HOOK_TELEMETRY" "$HOOK_HYPOTHESIS" <<'PY'
import json, sys
path, hook_telem, hook_hypo = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("hooks", {})

def add_hook(event, command, matcher="*"):
    arr = cfg["hooks"].setdefault(event, [])
    for entry in arr:
        if entry.get("matcher") == matcher:
            for h in entry.get("hooks", []):
                if h.get("command") == command:
                    return  # already present
            entry["hooks"].append({"type": "command", "command": command})
            return
    arr.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})

add_hook("PostToolUse", f"$CLAUDE_PROJECT_DIR/.claude/hooks/cognitive-debt-telemetry.sh", "Edit|Write|Task")
add_hook("PreToolUse",  f"$CLAUDE_PROJECT_DIR/.claude/hooks/cognitive-debt-hypothesis-first.sh", "Edit|Write")

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("Hooks wired in settings.json")
PY

  echo "Cognitive Debt enabled. Hooks active on next Claude Code restart."
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

  local backup="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$backup"

  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
hooks = cfg.get("hooks", {})

def strip_event(event):
    arr = hooks.get(event, [])
    new_arr = []
    for entry in arr:
        entry["hooks"] = [h for h in entry.get("hooks", [])
                          if "cognitive-debt-" not in h.get("command", "")]
        if entry["hooks"]:
            new_arr.append(entry)
    if new_arr:
        hooks[event] = new_arr
    elif event in hooks:
        del hooks[event]

strip_event("PostToolUse")
strip_event("PreToolUse")

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
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
