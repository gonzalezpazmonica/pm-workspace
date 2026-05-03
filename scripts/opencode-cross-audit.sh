#!/bin/bash
set -uo pipefail
# opencode-cross-audit.sh — Verifies .opencode/ vs .claude/ resource alignment
# Usage: bash scripts/opencode-cross-audit.sh [--fix] [--json]
# Exit: 0=PASS, 1=FAIL (drift detected), 2=error

FIX=false
JSON=false
for a in "$@"; do
  case "$a" in
    --fix) FIX=true ;;
    --json) JSON=true ;;
    --help) echo "Usage: opencode-cross-audit.sh [--fix] [--json]"; exit 0 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$ROOT/.claude"
OPENCODE_DIR="$ROOT/.opencode"
DRIFT=0
MISSING=0
DRIFT_CONTENT=0

_tab_row() {
  local label="$1" ok="$2" missing="$3" drift="$4"
  if $JSON; then
    echo "    {\"name\":\"$label\",\"ok\":$ok,\"missing\":$missing,\"drift\":$drift},"
  else
    printf "  %-12s %4s OK, %2s missing, %2s drift\n" "$label" "$ok" "$missing" "$drift"
  fi
}

_compare_dir() {
  local src="$1" dst="$2" glob="$3" label="$4"
  local ok=0 missing=0 drift=0
  for f in $(cd "$src" && ls $glob 2>/dev/null); do
    local sf="$src/$f" df="$dst/$f"
    if [[ ! -f "$df" ]]; then
      echo "  missing: $label/$f" >&2
      missing=$((missing + 1))
      MISSING=$((MISSING + 1))
      $FIX && cp "$sf" "$df" && echo "    fixed: copied $f" >&2
      continue
    fi
    if ! diff -q "$sf" "$df" >/dev/null 2>&1; then
      echo "  drift: $label/$f" >&2
      drift=$((drift + 1))
      DRIFT_CONTENT=$((DRIFT_CONTENT + 1))
      $FIX && cp "$sf" "$df" && echo "    fixed: synced $f" >&2
      continue
    fi
    ok=$((ok + 1))
  done
  _tab_row "$label" "$ok" "$missing" "$drift"
  DRIFT=$((DRIFT + missing + drift))
}

_compare_subdirs() {
  local src="$1" dst="$2"
  for d in $(cd "$src" && ls -d */ 2>/dev/null); do
    local sd="$src/$d" dd="$dst/$d"
    if [[ ! -d "$dd" ]]; then
      echo "  missing dir: $d" >&2
      MISSING=$((MISSING + 1))
      $FIX && cp -r "$sd" "$dd" && echo "    fixed: created $d" >&2
      continue
    fi
    if ! diff -qr "$sd" "$dd" >/dev/null 2>&1; then
      echo "  drift dir: $d" >&2
      DRIFT_CONTENT=$((DRIFT_CONTENT + 1))
      $FIX && rsync -a "$sd/" "$dd/" 2>/dev/null && echo "    fixed: synced $d" >&2
    fi
  done
}

if $JSON; then echo "["; fi
echo "=== OpenCode Cross-Audit ==="
echo ""

_compare_dir "$CLAUDE_DIR/commands" "$OPENCODE_DIR/commands" "*.md" "commands"
# Agents are intentionally transformed by agents-opencode-convert.sh (different format)
# Skills use different loading mechanisms — skip content comparison
SKILL_CLAUDE=$(find "$CLAUDE_DIR/skills" -name SKILL.md | wc -l)
SKILL_OPEN=$(find "$OPENCODE_DIR/skills" -name SKILL.md 2>/dev/null | wc -l)
echo "  skills: claude=$SKILL_CLAUDE, opencode=$SKILL_OPEN $([ $SKILL_CLAUDE -gt 0 ] && echo OK || echo WARN)"
AGENT_CLAUDE=$(ls -1 "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l)
AGENT_OPEN=$(ls -1 "$OPENCODE_DIR/agents"/*.md 2>/dev/null | wc -l)
echo "  agents: claude=$AGENT_CLAUDE, opencode=$AGENT_OPEN $([ $AGENT_CLAUDE -eq $AGENT_OPEN ] && echo OK || echo WARN)"
# Subdirectory check (decision-trees etc)
_compare_subdirs "$CLAUDE_DIR/agents" "$OPENCODE_DIR/agents"

echo ""
if $JSON; then
  echo "  {\"result\": \"$([ $DRIFT -eq 0 ] && echo PASS || echo FAIL)\", \"ok\": true}"
  echo "]"
fi
echo "Result: $([ $DRIFT -eq 0 ] && echo PASS || echo FAIL)"
exit $([ $DRIFT -eq 0 ] && echo 0 || echo 1)
