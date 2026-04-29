#!/usr/bin/env bash
# aggregate.sh — SPEC-125 Slice 1: deterministic aggregation of 4 judge verdicts.
#
# Reads 4 judge JSON outputs from stdin or files, applies veto rules, computes
# final verdict (PASS|WARN|VETO), emits aggregate JSON to stdout.
#
# Usage:
#   aggregate.sh --judges <memory.json> <rule.json> <hallucination.json> <expertise.json>
#   cat all-judges.jsonl | aggregate.sh --stdin
#
# Exit codes:
#   0  ok (verdict in JSON; PASS|WARN|VETO is in the JSON, not in exit code)
#   2  usage / args invalid
#   3  judge file missing or unreadable
#   4  malformed judge JSON
#
# Verdict logic:
#   - VETO if ANY judge has veto:true with confidence ≥ 0.8
#   - WARN if 0 vetos AND consensus_score < 80
#   - PASS otherwise
#
# Where consensus_score = average of (memory, rule, hallucination) judge scores.
# Expertise judge does NOT contribute to score (it's a mode, not a numeric).
#
# Reference: SPEC-125 § 3 (verdicts).

set -uo pipefail

JUDGES_DIR=""
declare -a JUDGE_FILES=()

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

# ── Argument parsing ────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  usage
fi

case "${1:-}" in
  -h|--help) usage ;;
  --judges)
    shift
    if [[ $# -ne 4 ]]; then
      echo "ERROR: --judges requires exactly 4 file paths (memory rule hallucination expertise)" >&2
      exit 2
    fi
    JUDGE_FILES=("$@")
    ;;
  --stdin)
    # Read 4 JSON lines from stdin into temp files
    JUDGES_DIR=$(mktemp -d)
    trap 'rm -rf "$JUDGES_DIR"' EXIT
    i=0
    while IFS= read -r line && [[ $i -lt 4 ]]; do
      [[ -z "$line" ]] && continue
      printf '%s\n' "$line" > "$JUDGES_DIR/j$i.json"
      JUDGE_FILES+=("$JUDGES_DIR/j$i.json")
      ((i++))
    done
    if [[ ${#JUDGE_FILES[@]} -ne 4 ]]; then
      echo "ERROR: --stdin expected 4 JSON lines, got ${#JUDGE_FILES[@]}" >&2
      exit 2
    fi
    ;;
  *)
    echo "ERROR: unknown arg: $1" >&2
    usage
    ;;
esac

# ── Validate files exist ────────────────────────────────────────────────────

for f in "${JUDGE_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: judge file not found: $f" >&2
    exit 3
  fi
done

# ── Helper: extract field from JSON (no jq dependency) ──────────────────────

# get_field <file> <key>  →  prints value, empty if not found
get_field() {
  local f="$1" key="$2"
  python3 -c "
import json,sys
try:
  d = json.load(open('$f'))
  v = d.get('$key', '')
  if isinstance(v, bool): print('true' if v else 'false')
  elif v is None: print('')
  else: print(v)
except Exception as e:
  sys.exit(4)
" 2>/dev/null
}

# ── Read each judge's score + veto + confidence ─────────────────────────────

declare -A J_SCORE J_VETO J_CONF J_NAME

for i in 0 1 2 3; do
  f="${JUDGE_FILES[$i]}"
  name=$(get_field "$f" "judge")
  score=$(get_field "$f" "score")
  veto=$(get_field "$f" "veto")
  conf=$(get_field "$f" "confidence")

  if [[ -z "$name" ]]; then
    echo "ERROR: malformed judge JSON (no 'judge' field): $f" >&2
    exit 4
  fi

  J_NAME[$i]="$name"
  J_SCORE[$i]="${score:-null}"
  J_VETO[$i]="${veto:-false}"
  J_CONF[$i]="${conf:-0}"
done

# ── Apply veto rules ────────────────────────────────────────────────────────

veto_triggered=false
declare -a veto_reasons=()

for i in 0 1 2 3; do
  if [[ "${J_VETO[$i]}" == "true" ]]; then
    # Check confidence threshold (≥ 0.8)
    if awk -v c="${J_CONF[$i]}" 'BEGIN { exit !(c >= 0.8) }'; then
      veto_triggered=true
      veto_reasons+=("${J_NAME[$i]}")
    fi
  fi
done

# ── Compute consensus score (average of memory, rule, hallucination) ────────

sum=0
count=0
for i in 0 1 2 3; do
  name="${J_NAME[$i]}"
  score="${J_SCORE[$i]}"
  if [[ "$name" == "expertise-asymmetry" ]]; then
    continue   # expertise doesn't contribute to numeric consensus
  fi
  if [[ "$score" == "null" || -z "$score" ]]; then
    continue
  fi
  sum=$(awk -v s="$sum" -v x="$score" 'BEGIN { printf "%.0f", s + x }')
  ((count++))
done

if [[ "$count" -eq 0 ]]; then
  consensus="null"
else
  consensus=$(awk -v s="$sum" -v c="$count" 'BEGIN { printf "%.0f", s / c }')
fi

# ── Final verdict ───────────────────────────────────────────────────────────

verdict="PASS"
if [[ "$veto_triggered" == "true" ]]; then
  verdict="VETO"
elif [[ "$consensus" != "null" ]] && awk -v s="$consensus" 'BEGIN { exit !(s < 80) }'; then
  verdict="WARN"
fi

# ── Build veto_reasons JSON array ────────────────────────────────────────────

veto_json=""
for r in "${veto_reasons[@]:-}"; do
  [[ -z "$r" ]] && continue
  if [[ -z "$veto_json" ]]; then
    veto_json="\"$r\""
  else
    veto_json="$veto_json,\"$r\""
  fi
done

# ── Emit aggregate JSON ──────────────────────────────────────────────────────

printf '{"verdict":"%s","consensus_score":%s,"veto_triggered":%s,"veto_judges":[%s],"judge_files":["%s","%s","%s","%s"]}\n' \
  "$verdict" "$consensus" "$veto_triggered" "$veto_json" \
  "${JUDGE_FILES[0]}" "${JUDGE_FILES[1]}" "${JUDGE_FILES[2]}" "${JUDGE_FILES[3]}"
