#!/usr/bin/env bash
# hook-latency-budget.sh — SE-270 Slice 5: hook latency budget enforcement.
#
# Measures execution time of each PreToolUse hook, compares against
# declared budget (default 100ms for hot path), reports hooks exceeding
# budget. Uses `time` command internally for POSIX measurement.
#
# Reads: .claude/settings.json PreToolUse section
# Budget: declared in hook metadata (budget_ms field) or default 100ms
#
# Usage:
#   hook-latency-budget.sh
#   hook-latency-budget.sh --budget MS
#   hook-latency-budget.sh --iterations N
#   hook-latency-budget.sh --json
#
# Exit codes:
#   0 — all hooks within budget
#   1 — at least one hook exceeds budget
#   2 — usage error
#
# Ref: SE-270 §Slice 5, AC-5.2, AC-5.3
# Safety: read-only measurement. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

DEFAULT_BUDGET_MS=100
ITERATIONS=3
JSON=0
VERBOSE=0

usage() {
  cat <<EOF
Usage: $0 [options]

Measures PreToolUse hook latency and compares against declared budget.

Options:
  --budget MS       Default hot-path budget in ms (default: $DEFAULT_BUDGET_MS)
  --iterations N    Measurements per hook (default: $ITERATIONS)
  --json            JSON output
  --verbose         Show per-hook timing even when within budget
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget) DEFAULT_BUDGET_MS="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ ! -f "$SETTINGS" ]] && { echo "ERROR: settings.json not found: $SETTINGS" >&2; exit 2; }
command -v jq &>/dev/null || { echo "ERROR: jq required" >&2; exit 2; }

for v in DEFAULT_BUDGET_MS ITERATIONS; do
  val="${!v}"
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [[ "$val" -lt 1 ]]; then
    echo "ERROR: ${v} must be positive integer" >&2; exit 2
  fi
done

# ── Measure a single hook ──────────────────────────────────────────────────────
measure_hook() {
  local hook_path="$1" iters="$2"
  [[ -x "$hook_path" ]] || { echo "-1"; return; }

  local total_ns=0
  for ((i=0; i<iters; i++)); do
    local t0 t1
    t0=$(date +%s%N 2>/dev/null || echo 0)
    timeout 2 bash "$hook_path" </dev/null >/dev/null 2>&1 || true
    t1=$(date +%s%N 2>/dev/null || echo 0)
    total_ns=$((total_ns + (t1 - t0)))
  done
  echo $(( total_ns / iters / 1000000 ))
}

# ── Resolve hook path from command string ──────────────────────────────────────
resolve_hook_path() {
  local cmd="$1"
  # Handle quoted paths: "$CLAUDE_PROJECT_DIR"/.opencode/hooks/foo.sh
  # or: bash "$CLAUDE_PROJECT_DIR"/.opencode/hooks/foo.sh
  # or: bash .claude/hooks/foo.sh
  local script=""
  script=$(echo "$cmd" | sed -E 's/^bash[[:space:]]+//; s/^"//; s/"$//' | sed "s|\"\$CLAUDE_PROJECT_DIR\"|$PROJECT_ROOT|g; s|\$CLAUDE_PROJECT_DIR|$PROJECT_ROOT|g")
  if [[ "$script" == "$PROJECT_ROOT"/* ]]; then
    echo "$script"
  elif [[ "$script" == .* ]]; then
    echo "$PROJECT_ROOT/${script#./}"
  else
    echo ""
  fi
}

# ── Extract PreToolUse hooks ───────────────────────────────────────────────────
# Single jq pass: flatten all PreToolUse hooks to avoid double-counting
# when same matcher appears in multiple groups.
exceeded=()
all_results=()
total=0

while IFS='@' read -r matcher htype hcommand htimeout hbudget_raw; do
  [[ -z "$matcher" ]] && continue
  htype="${htype:-command}"
  hbudget="${hbudget_raw:-$DEFAULT_BUDGET_MS}"
  total=$((total + 1))

  if [[ "$htype" != "command" ]] || [[ -z "$hcommand" ]]; then
    all_results+=("${matcher}@${htype}@SKIP@${hbudget}@0")
    continue
  fi

  hook_path=$(resolve_hook_path "$hcommand")
  latency=0
  if [[ -n "$hook_path" ]] && [[ -f "$hook_path" ]]; then
    latency=$(measure_hook "$hook_path" "$ITERATIONS")
  fi

  if [[ "$latency" -lt 0 ]]; then
    all_results+=("${matcher}@${htype}@SKIP@${hbudget}@0")
    continue
  fi

  all_results+=("${matcher}@${htype}@${latency}@${hbudget}@0")

  if [[ "$latency" -gt "$hbudget" ]]; then
    exceeded+=("${matcher}@${hbudget}@${latency}")
  fi
done < <(jq -r '
  .hooks.PreToolUse[]? // empty | . as $group |
  $group.hooks[]? |
  [ ($group.matcher // "null"), (.type // "command"), (.command // ""), (.timeout // 5), (.budget_ms // '"${DEFAULT_BUDGET_MS}"') ] | join("@")
' "$SETTINGS" 2>/dev/null)

exceeded_count=${#exceeded[@]}

# ── Output ─────────────────────────────────────────────────────────────────────
if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{
  "verdict": "$([[ $exceeded_count -gt 0 ]] && echo FAIL || echo PASS)",
  "total_measured": $total,
  "budget_ms": $DEFAULT_BUDGET_MS,
  "exceeded_count": $exceeded_count
}
JSON
else
  echo "=== SE-270 Slice 5: PreToolUse Hook Latency Budget ==="
  echo ""
  echo "Budget:      ${DEFAULT_BUDGET_MS}ms (hot path default)"
  echo "Iterations:  ${ITERATIONS}"
  echo "Measured:    ${total} PreToolUse handlers"
  echo "Exceeded:    ${exceeded_count}"
  echo ""

  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Per-hook latency:"
    for r in "${all_results[@]}"; do
      IFS='@' read -r m t l b _ <<< "$r"
      if [[ "$l" == "SKIP" ]]; then
        printf "  [SKIP] %-12s %-8s\n" "$t" "$m"
      elif [[ "$l" -gt "$b" ]]; then
        printf "  [OVER] %-12s %-8s %4dms (budget %dms)\n" "$t" "$m" "$l" "$b"
      else
        printf "  [ OK ] %-12s %-8s %4dms (budget %dms)\n" "$t" "$m" "$l" "$b"
      fi
    done
    echo ""
  fi

  if [[ "$exceeded_count" -gt 0 ]]; then
    echo "Hooks exceeding budget:"
    for e in "${exceeded[@]}"; do
      IFS='@' read -r m b l <<< "$e"
      echo "  • matcher='${m}' budget=${b}ms measured=${l}ms (+$((l - b))ms)"
    done
    echo ""
    echo "Remediation:"
    echo "  1. Add early-exit guard at top of offending hook scripts"
    echo "  2. Consider migrating to async: true for non-blocking checks"
    echo "  3. Replace broad matcher with specific regex to reduce invocations"
  fi

  echo ""
  if [[ "$exceeded_count" -eq 0 ]]; then
    echo "VERDICT: PASS"
  else
    echo "VERDICT: FAIL — ${exceeded_count} hook(s) over budget"
  fi
fi

[[ "$exceeded_count" -eq 0 ]] && exit 0 || exit 1
