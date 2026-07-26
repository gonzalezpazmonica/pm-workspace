#!/usr/bin/env bash
# hook-matcher-audit.sh — SE-270 Slice 5: hook matcher specificity audit.
#
# Reads all hook matchers from .claude/settings.json, identifies broad
# matchers (.*, wildcards, empty), suggests specific regex replacements,
# and reports count of broad matchers.
#
# Usage:
#   hook-matcher-audit.sh
#   hook-matcher-audit.sh --json
#   hook-matcher-audit.sh --event PreToolUse
#
# Exit codes:
#   0 — always (advisory report)
#   2 — usage error
#
# Ref: SE-270 §Slice 5, AC-5.4
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

JSON=0
FILTER_EVENT=""

usage() {
  cat <<EOF
Usage: $0 [options]

Audits hook matchers in .claude/settings.json. Identifies broad matchers
(.*, *, empty string) and suggests specific replacements.

Options:
  --json          JSON output
  --event EVENT   Filter to specific event (e.g. PreToolUse, PostToolUse)
                  If omitted, audits all events.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --event) FILTER_EVENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ ! -f "$SETTINGS" ]] && { echo "ERROR: settings.json not found: $SETTINGS" >&2; exit 2; }
command -v jq &>/dev/null || { echo "ERROR: jq required" >&2; exit 2; }

# ── Patterns for broad matchers ────────────────────────────────────────────────
is_broad() {
  local m="$1"
  # .* or "" or * (bare wildcard)
  [[ -z "$m" ]] && return 0
  [[ "$m" == ".*" ]] && return 0
  [[ "$m" == "*" ]] && return 0
  # Matchers that are a single tool name without qualification — depends on context
  # These are not technically "broad" but we flag them for review
  return 1
}

is_single_tool() {
  local m="$1"
  # Single tool name like "Task", "Bash", "Edit", "Write", "Read", "Agent"
  [[ "$m" =~ ^(Task|Bash|Edit|Write|Read|Glob|Grep|WebFetch|WebSearch|Agent|AskUserQuestion)$ ]] && return 0
  return 1
}

# ── Collect matchers by event ──────────────────────────────────────────────────
events=()
if [[ -n "$FILTER_EVENT" ]]; then
  events=("$FILTER_EVENT")
else
  while IFS= read -r ev; do
    events+=("$ev")
  done < <(jq -r '.hooks // {} | keys[]' "$SETTINGS" 2>/dev/null)
fi

total_matchers=0
broad_count=0
tool_only_count=0
specific_count=0
matcher_groups=()

for event in "${events[@]}"; do
  while IFS= read -r matcher; do
    [[ "$matcher" == "null" ]] && matcher=""
    hook_count=0
    hook_count=$(jq -r --arg event "$event" --arg matcher "$matcher" '
      .hooks[$event][]
      | select(if $matcher == "" then (.matcher // "") == "" else ."matcher" == $matcher end)
      | .hooks | length
    ' "$SETTINGS" 2>/dev/null)
    hook_count="${hook_count:-0}"

    total_matchers=$((total_matchers + 1))

    classification="specific"
    suggestion=""
    if is_broad "$matcher"; then
      classification="broad"
      broad_count=$((broad_count + 1))
      if [[ -z "$matcher" ]]; then
        suggestion="Replace empty matcher with explicit tool-name regex (e.g. Read|Write|Edit)"
      elif [[ "$matcher" == ".*" ]]; then
        suggestion="Restrict to known tool names: (Read|Write|Edit|Bash|Task|Glob|Grep|WebFetch)"
      elif [[ "$matcher" == "*" ]]; then
        suggestion="Use .* for all tools or restrict to relevant subset"
      fi
    elif is_single_tool "$matcher"; then
      classification="tool-only"
      tool_only_count=$((tool_only_count + 1))
      # Single tool names are acceptable but flag for review
      suggestion="Consider narrowing with args: ${matcher}(pattern*) for more precise control"
    else
      specific_count=$((specific_count + 1))
    fi

    matcher_groups+=("${event}|${matcher:-<empty>}|${classification}|${hook_count}|${suggestion}")
  done < <(jq -r --arg event "$event" '
    .hooks[$event][]? // empty | ."matcher" // ""
  ' "$SETTINGS" 2>/dev/null)
done

pct_broad=0
[[ "$total_matchers" -gt 0 ]] && pct_broad=$(( broad_count * 100 / total_matchers ))

# ── Output ─────────────────────────────────────────────────────────────────────
if [[ "$JSON" -eq 1 ]]; then
  broad_json=""
  for g in "${matcher_groups[@]}"; do
    IFS='|' read -r event matcher cls count sugg <<< "$g"
    if [[ "$cls" == "broad" ]]; then
      broad_json+="{\"event\":\"$event\",\"matcher\":\"$matcher\",\"hooks\":$count,\"suggestion\":\"$sugg\"},"
    fi
  done
  broad_json="[${broad_json%,}]"

  cat <<JSON
{
  "total_matchers": $total_matchers,
  "broad": $broad_count,
  "tool_only": $tool_only_count,
  "specific": $specific_count,
  "broad_pct": $pct_broad,
  "broad_details": $broad_json
}
JSON
else
  echo "=== SE-270 Slice 5: Hook Matcher Specificity Audit ==="
  echo ""
  echo "Total matchers:  $total_matchers"
  echo "  Broad:         $broad_count ($pct_broad%)"
  echo "  Tool-only:     $tool_only_count"
  echo "  Specific:      $specific_count"
  echo ""

  if [[ "$broad_count" -gt 0 ]]; then
    echo "Broad matchers (.*, *, empty):"
    for g in "${matcher_groups[@]}"; do
      IFS='|' read -r event matcher cls count sugg <<< "$g"
      if [[ "$cls" == "broad" ]]; then
        printf "  %-18s %-14s (%d hooks)\n" "$event" "'${matcher}'" "$count"
        [[ -n "$sugg" ]] && echo "             → $sugg"
      fi
    done
    echo ""
  fi

  if [[ "$tool_only_count" -gt 0 ]]; then
    echo "Tool-only matchers (acceptable, reviewable):"
    for g in "${matcher_groups[@]}"; do
      IFS='|' read -r event matcher cls count sugg <<< "$g"
      if [[ "$cls" == "tool-only" ]]; then
        printf "  %-18s %-14s (%d hooks)\n" "$event" "'${matcher}'" "$count"
      fi
    done
    echo ""
  fi

  echo "AC-5.4 target: zero broad matchers without inline justification."
  echo "Current broad count: $broad_count"
  echo ""
  echo "VERDICT: advisory report complete (always exit 0)"
fi

exit 0
