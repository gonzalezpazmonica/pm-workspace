#!/usr/bin/env bash
set -uo pipefail
# loop-state-prune.sh — Archiva ítems cerrados en Recently Resolved
# SPEC: SE-228 Slice 1 — Loop State Schema
#
# Usage:
#   bash scripts/loop-state-prune.sh --skill <nombre>
#   bash scripts/loop-state-prune.sh --skill <nombre> --dry-run
#   bash scripts/loop-state-prune.sh --skill <nombre> --max-resolved N
#
# What it does:
#   - Reads High Priority and Watch List items from STATE.md
#   - For each item with a PR number (#NNN) or branch name, checks via
#     `gh pr list` or `git branch --list` if merged/closed
#   - Moves resolved items to Recently Resolved with timestamp
#   - Trims Recently Resolved to --max-resolved N (default 20)
#
# Exit codes:
#   0 — OK
#   1 — Error (missing arg, missing file, parse failure)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_NAME=""
DRY_RUN=false
MAX_RESOLVED=20

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      [[ -z "${2:-}" ]] && { echo "ERROR: --skill requires a value" >&2; exit 1; }
      SKILL_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --max-resolved)
      [[ -z "${2:-}" ]] && { echo "ERROR: --max-resolved requires a number" >&2; exit 1; }
      MAX_RESOLVED="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SKILL_NAME" ]]; then
  echo "ERROR: --skill <nombre> is required" >&2
  exit 1
fi

STATE_FILE="${PROJECT_ROOT}/output/loop-state/${SKILL_NAME}/STATE.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: STATE.md not found: ${STATE_FILE}" >&2
  exit 1
fi

NOW_UTC="$(date -u '+%Y-%m-%d')"

# ── Helper: check if a PR number is merged/closed ────────────────────────────
pr_is_resolved() {
  local pr_num="$1"
  # gh may not be available or configured; graceful fallback
  if command -v gh &>/dev/null; then
    local state
    state="$(gh pr view "$pr_num" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")"
    case "$state" in
      MERGED|CLOSED) return 0 ;;
    esac
  fi
  return 1
}

# ── Helper: check if a branch is gone (merged/deleted) ───────────────────────
branch_is_resolved() {
  local branch_name="$1"
  # branch present locally → not resolved yet
  if git -C "$PROJECT_ROOT" branch --list "$branch_name" 2>/dev/null | grep -q .; then
    return 1
  fi
  # branch present on remote → not resolved yet
  if git -C "$PROJECT_ROOT" ls-remote --heads origin "$branch_name" 2>/dev/null | grep -q .; then
    return 1
  fi
  # branch not found anywhere → resolved
  return 0
}

# ── Read STATE.md ─────────────────────────────────────────────────────────────
STATE_CONTENT="$(cat "$STATE_FILE")"

# Early exit if file is effectively empty (no High Priority or Watch List items)
if ! echo "$STATE_CONTENT" | grep -qE '^\- \[ \]'; then
  echo "INFO: no active items found in ${STATE_FILE}, nothing to prune"
  exit 0
fi

# ── Parse and classify active items ───────────────────────────────────────────
# We process line by line and rebuild the file sections
declare -a HIGH_PRIORITY_KEEP=()
declare -a HIGH_PRIORITY_RESOLVE=()
declare -a WATCH_LIST_KEEP=()
declare -a WATCH_LIST_RESOLVE=()
declare -a RECENTLY_RESOLVED_EXISTING=()
declare -a NOISE_EXISTING=()

CURRENT_SECTION=""
HEADER_LINES=()

while IFS= read -r line; do
  case "$line" in
    "# Loop State — "*)
      HEADER_LINES+=("$line")
      ;;
    "Last run: "*)
      HEADER_LINES+=("$line")
      ;;
    "## High Priority"*)
      CURRENT_SECTION="high"
      ;;
    "## Watch List"*)
      CURRENT_SECTION="watch"
      ;;
    "## Recently Resolved"*)
      CURRENT_SECTION="resolved"
      ;;
    "## Noise / Ignored"*)
      CURRENT_SECTION="noise"
      ;;
    "- [ ] "*)
      # Active item — check if resolved
      item_text="${line#- [ ] }"

      # Extract identifier: PR number (#NNN) or branch name (agent/*)
      resolved=false
      pr_num=""
      branch_name=""

      if [[ "$item_text" =~ \#([0-9]+) ]]; then
        pr_num="${BASH_REMATCH[1]}"
        if pr_is_resolved "$pr_num"; then
          resolved=true
        fi
      elif [[ "$item_text" =~ ^(agent/[^[:space:]—]+) ]]; then
        branch_name="${BASH_REMATCH[1]}"
        if branch_is_resolved "$branch_name"; then
          resolved=true
        fi
      fi

      case "$CURRENT_SECTION" in
        high)
          if [[ "$resolved" == true ]]; then
            HIGH_PRIORITY_RESOLVE+=("$item_text")
          else
            HIGH_PRIORITY_KEEP+=("$line")
          fi
          ;;
        watch)
          if [[ "$resolved" == true ]]; then
            WATCH_LIST_RESOLVE+=("$item_text")
          else
            WATCH_LIST_KEEP+=("$line")
          fi
          ;;
      esac
      ;;
    "- [x] "*)
      [[ "$CURRENT_SECTION" == "resolved" ]] && RECENTLY_RESOLVED_EXISTING+=("$line")
      ;;
    "- [-] "*)
      [[ "$CURRENT_SECTION" == "noise" ]] && NOISE_EXISTING+=("$line")
      ;;
    "")
      : # skip blank lines, we'll rebuild them
      ;;
  esac
done < "$STATE_FILE"

# Count newly resolved items
NEWLY_RESOLVED=$(( ${#HIGH_PRIORITY_RESOLVE[@]} + ${#WATCH_LIST_RESOLVE[@]} ))

if [[ "$DRY_RUN" == true ]]; then
  echo "DRY-RUN: would process ${STATE_FILE}"
  echo "DRY-RUN: newly resolved items: ${NEWLY_RESOLVED}"
  for item in "${HIGH_PRIORITY_RESOLVE[@]+"${HIGH_PRIORITY_RESOLVE[@]}"}"; do
    echo "DRY-RUN: resolve from High Priority: ${item}"
  done
  for item in "${WATCH_LIST_RESOLVE[@]+"${WATCH_LIST_RESOLVE[@]}"}"; do
    echo "DRY-RUN: resolve from Watch List: ${item}"
  done
  echo "DRY-RUN: max-resolved = ${MAX_RESOLVED}"
  exit 0
fi

if [[ "$NEWLY_RESOLVED" -eq 0 ]]; then
  echo "INFO: no newly resolved items found, nothing to prune"
  exit 0
fi

# ── Build new Recently Resolved list ─────────────────────────────────────────
declare -a NEW_RESOLVED_ENTRIES=()
for item in "${HIGH_PRIORITY_RESOLVE[@]+"${HIGH_PRIORITY_RESOLVE[@]}"}"; do
  NEW_RESOLVED_ENTRIES+=("- [x] ${item} (resolved: ${NOW_UTC}, outcome: closed)")
done
for item in "${WATCH_LIST_RESOLVE[@]+"${WATCH_LIST_RESOLVE[@]}"}"; do
  NEW_RESOLVED_ENTRIES+=("- [x] ${item} (resolved: ${NOW_UTC}, outcome: closed)")
done

# Prepend new entries, then existing, trim to max-resolved
ALL_RESOLVED=("${NEW_RESOLVED_ENTRIES[@]}"  "${RECENTLY_RESOLVED_EXISTING[@]+"${RECENTLY_RESOLVED_EXISTING[@]}"}")
TRIMMED_RESOLVED=("${ALL_RESOLVED[@]:0:${MAX_RESOLVED}}")

# ── Rebuild STATE.md ──────────────────────────────────────────────────────────
{
  # Header
  for h in "${HEADER_LINES[@]}"; do
    echo "$h"
  done

  echo ""
  echo "## High Priority (loop actuando o esperando humano)"
  echo ""
  for line in "${HIGH_PRIORITY_KEEP[@]+"${HIGH_PRIORITY_KEEP[@]}"}"; do
    echo "$line"
  done

  echo ""
  echo "## Watch List"
  echo ""
  for line in "${WATCH_LIST_KEEP[@]+"${WATCH_LIST_KEEP[@]}"}"; do
    echo "$line"
  done

  echo ""
  echo "## Recently Resolved"
  echo ""
  for entry in "${TRIMMED_RESOLVED[@]+"${TRIMMED_RESOLVED[@]}"}"; do
    echo "$entry"
  done

  echo ""
  echo "## Noise / Ignored"
  echo ""
  for line in "${NOISE_EXISTING[@]+"${NOISE_EXISTING[@]}"}"; do
    echo "$line"
  done
} > "$STATE_FILE"

echo "OK: pruned ${STATE_FILE} — ${NEWLY_RESOLVED} items moved to Recently Resolved"
