#!/usr/bin/env bash
# scripts/command-tier-audit.sh — SE-253 Slice 1
# Audits and classifies .claude/commands/*.md by tier (core/extended).
#
# Usage:
#   ./scripts/command-tier-audit.sh --classify   # emit proposed classification to stdout
#   ./scripts/command-tier-audit.sh --check      # validate applied tiers against usage telemetry
#   ./scripts/command-tier-audit.sh --stats      # summary statistics only
set -euo pipefail

COMMANDS_DIR="${COMMANDS_DIR:-.claude/commands}"
QUALITY_GATE_LOG="${QUALITY_GATE_LOG:-output/quality-gate-history.jsonl}"
STALE_THRESHOLD="${STALE_THRESHOLD:-2026-05-01}"
USAGE_WARN_THRESHOLD="${USAGE_WARN_THRESHOLD:-5}"
CORE_IDLE_DAYS="${CORE_IDLE_DAYS:-90}"
MODE="${1:-}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

command_exists() { command -v "$1" &>/dev/null; }

# Returns last git commit date (YYYY-MM-DD) for a file; empty string if untracked
last_git_date() {
  local filepath="$1"
  git log --format="%ad" --date=format:"%Y-%m-%d" -1 -- "$filepath" 2>/dev/null | head -1
}

# Extract tier field from YAML frontmatter (returns "none" if absent)
extract_tier() {
  local filepath="$1"
  local tier
  # Only look inside first frontmatter block (between first pair of ---)
  tier=$(awk '
    BEGIN { in_front=0; found=0 }
    /^---/ {
      if (in_front==0) { in_front=1; next }
      else { exit }
    }
    in_front && /^tier:/ {
      gsub(/^tier:[[:space:]]*/, ""); gsub(/[[:space:]]*$/, ""); print; found=1; exit
    }
  ' "$filepath" 2>/dev/null)
  echo "${tier:-none}"
}

# Core forced patterns (names that are always core regardless of staleness)
is_forced_core() {
  local name="$1"
  local core_patterns=(
    '^sprint-'  '^daily-'  '^board-'
    '^my-sprint$'  '^my-focus$'  '^daily-routine$'  '^compact$'
    '^pr-plan$'  '^pr-review'  '^commit$'  '^push$'
    '^savia-live$'  '^savia-shield$'
    '^help$'  '^health$'  '^doctor$'  '^workspace-doctor$'
    '^index-compact$'  '^exit$'
    '^speckit\.'
    '^catalog$'
  )
  for pat in "${core_patterns[@]}"; do
    if [[ "$name" =~ $pat ]]; then
      return 0
    fi
  done
  return 1
}

# Classify one command: prints "core" or "extended"
classify_command() {
  local filepath="$1"
  local name
  name="$(basename "$filepath" .md)"
  local last_date
  last_date="$(last_git_date "$filepath")"
  last_date="${last_date:-2025-01-01}"

  if is_forced_core "$name"; then
    echo "core"
    return
  fi
  if [[ "$last_date" < "$STALE_THRESHOLD" ]]; then
    echo "extended"
  else
    echo "core"
  fi
}

# Classify reason for humans
classify_reason() {
  local filepath="$1"
  local name
  name="$(basename "$filepath" .md)"
  local last_date
  last_date="$(last_git_date "$filepath")"
  last_date="${last_date:-2025-01-01}"

  if is_forced_core "$name"; then
    echo "forced-core-pattern (last: $last_date)"
    return
  fi
  if [[ "$last_date" < "$STALE_THRESHOLD" ]]; then
    echo "stale (last: $last_date, threshold: $STALE_THRESHOLD)"
  else
    echo "recent (last: $last_date)"
  fi
}

# ---------------------------------------------------------------------------
# Mode: --classify
# ---------------------------------------------------------------------------

mode_classify() {
  local total=0 core_count=0 extended_count=0
  printf "%-50s %-10s %s\n" "file" "tier" "reason"
  printf "%-50s %-10s %s\n" "$(printf '%0.s-' {1..50})" "----------" "$(printf '%0.s-' {1..40})"
  while IFS= read -r -d '' filepath; do
    local name tier reason
    name="$(basename "$filepath" .md)"
    tier="$(classify_command "$filepath")"
    reason="$(classify_reason "$filepath")"
    printf "%-50s %-10s %s\n" "$name" "$tier" "$reason"
    (( total++ )) || true
    if [[ "$tier" == "core" ]]; then
      (( core_count++ )) || true
    else
      (( extended_count++ )) || true
    fi
  done < <(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)

  echo ""
  echo "SUMMARY: total=$total core=$core_count extended=$extended_count"
}

# ---------------------------------------------------------------------------
# Mode: --check
# ---------------------------------------------------------------------------

mode_check() {
  local exit_code=0
  local now_ts
  now_ts="$(date +%s)"
  local thirty_days=$(( 30 * 86400 ))
  local ninety_days=$(( 90 * 86400 ))

  # Check 1: extended commands with high recent usage
  echo "=== CHECK 1: extended commands with usage_count >= ${USAGE_WARN_THRESHOLD} in last 30 days ==="
  if [[ -f "$QUALITY_GATE_LOG" ]]; then
    while IFS= read -r -d '' filepath; do
      local name tier
      name="$(basename "$filepath" .md)"
      tier="$(extract_tier "$filepath")"
      if [[ "$tier" == "extended" ]]; then
        # Sum usage_count entries in last 30 days for this command
        local usage_sum=0
        while IFS= read -r line; do
          local entry_ts entry_cmd entry_usage
          entry_cmd="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || true)"
          entry_ts="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('timestamp',0))" 2>/dev/null || true)"
          entry_usage="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage_count',0))" 2>/dev/null || true)"
          if [[ "$entry_cmd" == "$name" ]] && (( now_ts - ${entry_ts:-0} <= thirty_days )); then
            usage_sum=$(( usage_sum + ${entry_usage:-0} ))
          fi
        done < "$QUALITY_GATE_LOG"
        if (( usage_sum >= USAGE_WARN_THRESHOLD )); then
          echo "FAIL: '$name' is tier:extended but has usage_count=$usage_sum in last 30 days — should be core"
          exit_code=1
        fi
      fi
    done < <(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)
    echo "  (scan complete)"
  else
    echo "  SKIP: $QUALITY_GATE_LOG not found — no telemetry to validate"
  fi

  # Check 2: core commands with zero usage in last 90 days (warning only)
  echo ""
  echo "=== CHECK 2: core commands idle >= ${CORE_IDLE_DAYS} days (WARNING only) ==="
  if [[ -f "$QUALITY_GATE_LOG" ]]; then
    local warn_count=0
    while IFS= read -r -d '' filepath; do
      local name tier
      name="$(basename "$filepath" .md)"
      tier="$(extract_tier "$filepath")"
      if [[ "$tier" == "core" ]]; then
        local usage_sum=0
        while IFS= read -r line; do
          local entry_cmd entry_ts entry_usage
          entry_cmd="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || true)"
          entry_ts="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('timestamp',0))" 2>/dev/null || true)"
          entry_usage="$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage_count',0))" 2>/dev/null || true)"
          if [[ "$entry_cmd" == "$name" ]] && (( now_ts - ${entry_ts:-0} <= ninety_days )); then
            usage_sum=$(( usage_sum + ${entry_usage:-0} ))
          fi
        done < "$QUALITY_GATE_LOG"
        if (( usage_sum == 0 )); then
          echo "  WARN: '$name' is tier:core but has no usage in last ${CORE_IDLE_DAYS} days"
          (( warn_count++ ))
        fi
      fi
    done < <(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)
    echo "  Total idle core commands: $warn_count (warning only, not failing)"
  else
    echo "  SKIP: $QUALITY_GATE_LOG not found — no telemetry to validate"
  fi

  echo ""
  if (( exit_code == 0 )); then
    echo "CHECK PASSED"
  else
    echo "CHECK FAILED (exit 1)"
  fi
  exit $exit_code
}

# ---------------------------------------------------------------------------
# Mode: --stats
# ---------------------------------------------------------------------------

mode_stats() {
  local total=0 core_count=0 extended_count=0 no_tier=0
  while IFS= read -r -d '' filepath; do
    local tier
    tier="$(extract_tier "$filepath")"
    (( total++ )) || true
    case "$tier" in
      core)     (( core_count++ ))     || true ;;
      extended) (( extended_count++ )) || true ;;
      none)     (( no_tier++ ))        || true ;;
    esac
  done < <(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)

  echo "Command Tier Statistics (SE-253)"
  echo "  Total commands : $total"
  echo "  core           : $core_count"
  echo "  extended       : $extended_count"
  echo "  no tier field  : $no_tier"
  local pct=0
  if (( total > 0 )); then
    pct=$(( extended_count * 100 / total ))
  fi
  echo "  extended%      : ${pct}%"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$MODE" in
  --classify) mode_classify ;;
  --check)    mode_check ;;
  --stats)    mode_stats ;;
  *)
    echo "Usage: $0 [--classify|--check|--stats]"
    echo ""
    echo "  --classify  Emit proposed tier classification to stdout (does not modify files)"
    echo "  --check     Validate applied tiers against usage telemetry (exit 1 on failure)"
    echo "  --stats     Print tier distribution summary"
    exit 1
    ;;
esac
