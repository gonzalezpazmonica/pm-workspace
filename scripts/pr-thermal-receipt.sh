#!/usr/bin/env bash
# pr-thermal-receipt.sh — Thermal receipt for PRs (CodeFlow-inspired)
# Generates a sticky markdown receipt with delta metrics for a PR.
#
# Usage: bash scripts/pr-thermal-receipt.sh [--staged | --branch REFSPEC]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE=""
REFSPEC=""
FORMAT="md"
INCLUDE_HEALTH=false

usage() {
  cat <<EOF
Usage: bash scripts/pr-thermal-receipt.sh [--staged | --branch REFSPEC]

Generate a thermal receipt with delta metrics for a PR.

Options:
  --staged          Analyze git diff --staged
  --branch REFSPEC  Analyze diff between branches (e.g. main..feature/x)
  --project DIR     Project root. Default: current dir
  --format md|json  Output format. Default: md
  --health          Include health score delta (requires workspace-health.sh --v2)

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) MODE="staged"; shift ;;
    --branch) MODE="branch"; REFSPEC="$2"; shift 2 ;;
    --project) ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --health) INCLUDE_HEALTH=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ── Validate ──
if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repository" >&2
  exit 1
fi

if [[ -z "$MODE" ]]; then
  echo "ERROR: must specify --staged or --branch" >&2
  usage >&2
  exit 1
fi

# ── Gather metrics ──
TIMESTAMP=$(date -Iseconds)
ACTOR=$(git -C "$ROOT" config user.name 2>/dev/null || echo "unknown")
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "detached")

case "$MODE" in
  staged)
    if git -C "$ROOT" diff --staged --quiet 2>/dev/null; then
      echo "WARN: no staged changes" >&2
      FILES_CHANGED=0; FILES_ADDED=0; FILES_DELETED=0
      LOC_ADDED=0; LOC_REMOVED=0
    else
      DIFF_STAT=$(git -C "$ROOT" diff --staged --stat 2>/dev/null || true)
      FILES_CHANGED=$(echo "$DIFF_STAT" | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo 0)
      [[ "$FILES_CHANGED" == "0" ]] && FILES_CHANGED=$(git -C "$ROOT" diff --staged --name-only 2>/dev/null | wc -l)
      LOC_ADDED=$(git -C "$ROOT" diff --staged --numstat 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
      LOC_REMOVED=$(git -C "$ROOT" diff --staged --numstat 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
      FILES_ADDED=$(git -C "$ROOT" diff --staged --diff-filter=A --name-only 2>/dev/null | wc -l)
      FILES_DELETED=$(git -C "$ROOT" diff --staged --diff-filter=D --name-only 2>/dev/null | wc -l)
    fi
    ;;
  branch)
    if ! git -C "$ROOT" diff --quiet "$REFSPEC" 2>/dev/null; then
      DIFF_STAT=$(git -C "$ROOT" diff --stat "$REFSPEC" 2>/dev/null || true)
      FILES_CHANGED=$(echo "$DIFF_STAT" | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo 0)
      [[ "$FILES_CHANGED" == "0" ]] && FILES_CHANGED=$(git -C "$ROOT" diff --name-only "$REFSPEC" 2>/dev/null | wc -l)
      LOC_ADDED=$(git -C "$ROOT" diff --numstat "$REFSPEC" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
      LOC_REMOVED=$(git -C "$ROOT" diff --numstat "$REFSPEC" 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
      FILES_ADDED=$(git -C "$ROOT" diff --diff-filter=A --name-only "$REFSPEC" 2>/dev/null | wc -l)
      FILES_DELETED=$(git -C "$ROOT" diff --diff-filter=D --name-only "$REFSPEC" 2>/dev/null | wc -l)
    else
      FILES_CHANGED=0; FILES_ADDED=0; FILES_DELETED=0
      LOC_ADDED=0; LOC_REMOVED=0
    fi
    ;;
esac

# ── Functions delta (heuristic) ──
count_functions() {
  local diff_cmd
  case "$MODE" in
    staged) diff_cmd="git -C $ROOT diff --staged" ;;
    branch) diff_cmd="git -C $ROOT diff $REFSPEC" ;;
  esac
  local added=0 removed=0
  added=$($diff_cmd 2>/dev/null | grep -cE '^\+\s*(function |def |func |public .*\(|export .*\(|async .*\()' || true)
  removed=$($diff_cmd 2>/dev/null | grep -cE '^\-\s*(function |def |func |public .*\(|export .*\(|async .*\()' || true)
  echo "$added $removed"
}

FUNC_DELTA=$(count_functions)
FUNCTIONS_ADDED=$(echo "$FUNC_DELTA" | awk '{print $1}')
FUNCTIONS_REMOVED=$(echo "$FUNC_DELTA" | awk '{print $2}')

# ── Scripts delta ──
case "$MODE" in
  staged) diff_cmd="git -C $ROOT diff --staged --name-only" ;;
  branch) diff_cmd="git -C $ROOT diff --name-only $REFSPEC" ;;
esac
SCRIPTS_ADDED=$($diff_cmd 2>/dev/null | grep -cE '^scripts/' || true)
SCRIPTS_DELETED=$(git -C "$ROOT" diff --diff-filter=D --name-only ${MODE:+--staged} ${REFSPEC:+"$REFSPEC"} 2>/dev/null | grep -cE '^scripts/' || true)

# ── Health delta (optional) ──
HEALTH_BEFORE=""
HEALTH_AFTER=""
HEALTH_DELTA=""
if $INCLUDE_HEALTH; then
  HEALTH_SCRIPT="$ROOT/scripts/workspace-health.sh"
  if [[ -x "$HEALTH_SCRIPT" ]]; then
    HEALTH_JSON=$(bash "$HEALTH_SCRIPT" --json --v2 2>/dev/null || echo "{}")
    HEALTH_SCORE=$(echo "$HEALTH_JSON" | grep -oE '"score": [0-9]+' | head -1 | grep -oE '[0-9]+' || echo "?")
    HEALTH_GRADE=$(echo "$HEALTH_JSON" | grep -oE '"grade": "[A-F][+-]?"' | head -1 | grep -oE '[A-F][+-]?' || echo "?")
    HEALTH_AFTER="$HEALTH_GRADE"
    HEALTH_DELTA="?"
  else
    HEALTH_AFTER="?"
    HEALTH_DELTA="?"
  fi
fi

# ── Output ──
if [[ "$FORMAT" == "json" ]]; then
  cat <<JSON
{
  "timestamp": "$TIMESTAMP",
  "actor": "$ACTOR",
  "branch": "$BRANCH",
  "delta": {
    "files_changed": $FILES_CHANGED,
    "files_added": $FILES_ADDED,
    "files_deleted": $FILES_DELETED,
    "loc_added": $LOC_ADDED,
    "loc_removed": $LOC_REMOVED,
    "functions_added": $FUNCTIONS_ADDED,
    "functions_removed": $FUNCTIONS_REMOVED,
    "scripts_added": $SCRIPTS_ADDED,
    "scripts_removed": $SCRIPTS_DELETED
    $([ -n "$HEALTH_AFTER" ] && echo ",\"health_after\": {\"score\": $HEALTH_SCORE, \"grade\": \"$HEALTH_GRADE\"}")
  }
}
JSON
else
  cat <<MD
<!-- codeflow-card:receipt -->
\`\`\`text
--- THERMAL RECEIPT ---
PR · $(date +%Y-%m-%d)
actor: $ACTOR
branch: $BRANCH
--------------------------
files          $FILES_CHANGED (+$FILES_ADDED new, -$FILES_DELETED removed)
LOC           +$LOC_ADDED / -$LOC_REMOVED
functions      +$FUNCTIONS_ADDED / -$FUNCTIONS_REMOVED
scripts        +$SCRIPTS_ADDED / -$SCRIPTS_DELETED
$([ -n "$HEALTH_AFTER" ] && echo "health        $HEALTH_AFTER")
--------------------------
   thank you for your code
\`\`\`
MD
fi
