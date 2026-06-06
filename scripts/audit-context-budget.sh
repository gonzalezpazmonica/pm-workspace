#!/usr/bin/env bash
# audit-context-budget.sh — SPEC-181 Slice 3
# Reads context_tier + token_budget frontmatter from docs/rules/domain/*.md
# Sums budgets per tier (L0/L1/L2/L3) and enforces: L0+L1 <= 3000
#
# Usage:
#   bash scripts/audit-context-budget.sh          # text summary
#   bash scripts/audit-context-budget.sh --json   # JSON output
#
# Exit 0 if L0+L1 <= 3000 and no errors, exit 1 otherwise.
#
# Ref: SPEC-181 AC3, AC7

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOMAIN_DIR="$ROOT/docs/rules/domain"

MODE_JSON=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) MODE_JSON=true ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Counters ──────────────────────────────────────────────────────────────────
total_L0=0; total_L1=0; total_L2=0; total_L3=0
count_L0=0; count_L1=0; count_L2=0; count_L3=0
count_missing=0; count_invalid=0; count_total=0
warn_messages=()

# ── Parse each file ───────────────────────────────────────────────────────────
while IFS= read -r filepath; do
  fname="$(basename "$filepath")"
  count_total=$((count_total + 1))

  # Extract frontmatter block (between first --- and second ---)
  fm_block=""
  in_fm=false
  fm_end=false
  line_count=0
  while IFS= read -r line; do
    line_count=$((line_count + 1))
    if [[ $line_count -eq 1 && "$line" == "---" ]]; then
      in_fm=true
      continue
    fi
    if $in_fm && [[ "$line" == "---" ]]; then
      fm_end=true
      break
    fi
    if $in_fm; then
      fm_block="${fm_block}${line}"$'\n'
    fi
    if [[ $line_count -gt 30 ]]; then
      break
    fi
  done < "$filepath"

  # Extract fields
  tier=""
  budget=""
  if [[ -n "$fm_block" ]]; then
    tier="$(echo "$fm_block" | grep -m1 '^context_tier:' | sed 's/context_tier:[[:space:]]*//')"
    budget="$(echo "$fm_block" | grep -m1 '^token_budget:' | sed 's/token_budget:[[:space:]]*//')"
  fi

  # Validate tier
  if [[ -z "$tier" ]]; then
    warn_messages+=("WARN  missing context_tier: $fname")
    count_missing=$((count_missing + 1))
    continue
  fi

  if [[ "$tier" != "L0" && "$tier" != "L1" && "$tier" != "L2" && "$tier" != "L3" ]]; then
    warn_messages+=("FAIL  invalid tier '${tier}': $fname")
    count_invalid=$((count_invalid + 1))
    continue
  fi

  # Validate budget is numeric
  if [[ -z "$budget" ]] || ! [[ "$budget" =~ ^[0-9]+$ ]]; then
    warn_messages+=("WARN  missing/non-numeric token_budget: $fname")
    count_missing=$((count_missing + 1))
    continue
  fi

  bud_int=$((budget + 0))

  case "$tier" in
    L0) total_L0=$((total_L0 + bud_int)); count_L0=$((count_L0 + 1)) ;;
    L1) total_L1=$((total_L1 + bud_int)); count_L1=$((count_L1 + 1)) ;;
    L2) total_L2=$((total_L2 + bud_int)); count_L2=$((count_L2 + 1)) ;;
    L3) total_L3=$((total_L3 + bud_int)); count_L3=$((count_L3 + 1)) ;;
  esac

done < <(find "$DOMAIN_DIR" -maxdepth 1 -name "*.md" | sort)

# ── Invariant check ───────────────────────────────────────────────────────────
total_eager=$((total_L0 + total_L1))
invariant_ok=true
if [[ $total_eager -gt 3000 ]]; then
  invariant_ok=false
fi

exit_code=0
if ! $invariant_ok; then
  exit_code=1
fi
if [[ $count_invalid -gt 0 ]]; then
  exit_code=1
fi

# ── Output ─────────────────────────────────────────────────────────────────────
if $MODE_JSON; then
  invariant_str="$($invariant_ok && echo true || echo false)"
  cat <<JSON
{
  "tiers": {
    "L0": { "files": ${count_L0}, "tokens": ${total_L0} },
    "L1": { "files": ${count_L1}, "tokens": ${total_L1} },
    "L2": { "files": ${count_L2}, "tokens": ${total_L2} },
    "L3": { "files": ${count_L3}, "tokens": ${total_L3} }
  },
  "eager_total": ${total_eager},
  "invariant_L0_L1_lte_3000": ${invariant_str},
  "missing_frontmatter": ${count_missing},
  "invalid_tier": ${count_invalid},
  "total_files": ${count_total}
}
JSON
else
  echo "Context Budget Audit — docs/rules/domain/ (SPEC-181)"
  echo "======================================================"
  printf "  L0: %3d files  %5d tokens\n" "$count_L0" "$total_L0"
  printf "  L1: %3d files  %5d tokens\n" "$count_L1" "$total_L1"
  printf "  L2: %3d files  %5d tokens\n" "$count_L2" "$total_L2"
  printf "  L3: %3d files  %5d tokens\n" "$count_L3" "$total_L3"
  echo "------------------------------------------------------"
  printf "  Eager (L0+L1): %d tokens  (limit: 3000)\n" "$total_eager"

  if $invariant_ok; then
    echo "  INVARIANT: OK (L0+L1 <= 3000)"
  else
    echo "  INVARIANT: FAIL (L0+L1=$total_eager > 3000)"
  fi

  if [[ ${#warn_messages[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings/Errors:"
    for msg in "${warn_messages[@]}"; do
      echo "  $msg"
    done
  fi

  printf "\n  Total files: %d  |  Missing frontmatter: %d  |  Invalid tier: %d\n" \
    "$count_total" "$count_missing" "$count_invalid"
fi

exit $exit_code
