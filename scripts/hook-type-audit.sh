#!/usr/bin/env bash
# hook-type-audit.sh — SE-270 Slice 5: hook handler type audit.
#
# Reads .claude/settings.json hooks section, classifies each hook by
# handler type (command/prompt/agent/http), reports distribution and
# recommendations for migration. Exits 0 with report.
#
# Usage:
#   hook-type-audit.sh
#   hook-type-audit.sh --json
#
# Exit codes:
#   0 — always (advisory report)
#   2 — usage error
#
# Ref: SE-270 §Slice 5, AC-5.1
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

JSON=0

usage() {
  cat <<EOF
Usage: $0 [--json]

Classifies all hooks in .claude/settings.json by handler type and reports
distribution. Recommends migration paths for missing types.

Options:
  --json    JSON output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ ! -f "$SETTINGS" ]] && { echo "ERROR: settings.json not found: $SETTINGS" >&2; exit 2; }

command -v jq &>/dev/null || { echo "ERROR: jq required" >&2; exit 2; }

# ── Classification ─────────────────────────────────────────────────────────────
# Collect all hook definitions with their event and matcher context

# Get all hook events
declare -A type_counts
type_counts["command"]=0
type_counts["prompt"]=0
type_counts["agent"]=0
type_counts["http"]=0
type_counts["unknown"]=0

# Accumulate detail per hook
hooks_detail=()
total=0

# Single jq pass: flatten all hooks to (event, matcher, type) tuples.
# Separator '@' avoids collision with '|' in matcher patterns like Edit|Write.
while IFS='@' read -r event matcher htype; do
  [[ -z "$event" ]] && continue
  matcher="${matcher:-null}"
  if [[ "$matcher" == "null" ]]; then
    matcher="(no matcher)"
  fi
  total=$((total + 1))
  htype="${htype:-unknown}"
  type_counts["$htype"]=$((${type_counts["$htype"]:-0} + 1))
  hooks_detail+=("${event}|${matcher}|${htype}")
done < <(jq -r '
  .hooks | to_entries[] |
  .key as $event | .value[] as $group |
  $group.hooks[]? |
  [ $event, ($group.matcher // "null"), (.type // "unknown") ] | join("@")
' "$SETTINGS" 2>/dev/null)

td="${type_counts["command"]:-0}"
tc="${type_counts["prompt"]:-0}"
ta="${type_counts["agent"]:-0}"
th="${type_counts["http"]:-0}"
tu="${type_counts["unknown"]:-0}"

# ── Recommendations ────────────────────────────────────────────────────────────
recs=()
# Agent type — useful for semantic validation that needs tool access
if [[ "$ta" -eq 0 ]]; then
  recs+=("agent: 0 agent-type handlers found. Consider migrating complex validation hooks (e.g. commit-message review) from prompt to agent for tool access.")
fi
# HTTP type — useful for external services
if [[ "$th" -le 1 ]]; then
  recs+=("http: only ${th} HTTP handler(s). Expand HTTP gate for latency-sensitive synchronous checks that benefit from persistent connections.")
fi
# Prompt type — useful for one-shot LLM evaluation
if [[ "$tc" -le 1 ]]; then
  recs+=("prompt: only ${tc} prompt-type handler(s). Use for lightweight LLM evaluation where a subagent is overkill (classification, format check).")
fi
# Balance check
pct_cmd=0
[[ "$total" -gt 0 ]] && pct_cmd=$(( td * 100 / total ))
if [[ "$pct_cmd" -ge 95 ]]; then
  recs+=("balance: ${pct_cmd}% of handlers are command-type. Migrate non-blocking evaluative hooks (format checks, semantic review) to prompt or agent types to reduce shell overhead.")
fi

# ── Output ─────────────────────────────────────────────────────────────────────
if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{
  "total_hooks": $total,
  "types": {
    "command": $td,
    "prompt": $tc,
    "agent": $ta,
    "http": $th,
    "unknown": $tu
  },
  "recommendations": $(jq -n --args '$ARGS.positional' "${recs[@]}")
}
JSON
else
  echo "=== SE-270 Slice 5: Hook Handler Type Audit ==="
  echo ""
  echo "Total handlers:    $total"
  echo "  command:         $td"
  echo "  prompt:          $tc"
  echo "  agent:           $ta"
  echo "  http:            $th"
  echo "  unknown:         $tu"
  echo ""
  echo "Coverage: ${pct_cmd}% command — target <80% with prompt/agent/http complement"
  echo ""
  if [[ ${#recs[@]} -gt 0 ]]; then
    echo "Recommendations:"
    for r in "${recs[@]}"; do
      echo "  - $r"
    done
  else
    echo "Recommendations: none — type distribution healthy."
  fi
  echo ""
  echo "VERDICT: advisory report complete (always exit 0)"
fi

exit 0
