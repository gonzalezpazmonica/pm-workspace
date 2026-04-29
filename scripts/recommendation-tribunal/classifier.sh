#!/usr/bin/env bash
# classifier.sh — SPEC-125 Slice 1: detect actionable recommendations in Savia's draft.
#
# Heuristic-first classifier. Reads draft from stdin (or --file), emits JSON to
# stdout: {"is_recommendation": bool, "risk_class": "low|medium|high|critical",
# "patterns_hit": [...], "method": "heuristic|llm-fallback"}.
#
# The orchestrator only convenes the 4 judges if risk_class >= medium.
# This avoids 95% of conversational turns going through the tribunal needlessly.
#
# Usage:
#   echo "draft text" | classifier.sh
#   classifier.sh --file draft.txt
#
# Exit codes:
#   0  ok (always — JSON on stdout describes whether to invoke)
#   2  usage / args invalid
#
# Reference: SPEC-125 § 1 (trigger detection).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_FILE=""
DRAFT=""

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) INPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: file not found: $INPUT_FILE" >&2
    exit 2
  fi
  DRAFT=$(cat "$INPUT_FILE")
else
  DRAFT=$(cat)
fi

# ── Pattern catalog ─────────────────────────────────────────────────────────

# Critical: explicit safety-bypass language → critical risk, definitively a recommendation
declare -a CRITICAL_PATTERNS=(
  'bypass|disable|skip the (gate|check|test|hook|judge)'
  'ignore the (rule|gate|check)'
  'turn off (the )?(gate|hook|check|safety|tribunal)'
  'workaround.*(gate|hook|check|safety)'
  'temporary (override|bypass|skip)'
  'lower the threshold'
  '(baja|baj[áa]|reduce|reduc[íi]) (el|la|los|las) (umbral|threshold|cobertura|coverage)'
  '[ -]+no-(verify|gpg-sign|hooks)'
  'force(.| )push'
  'override.*safety'
  'commit (without|skipping)'
  'merge (anyway|without)'
  'desactiva|desactivar.*(hook|gate|judge|tribunal|check)'
  'salt[áa]rselo|salt[áa]r el (gate|hook|test|check)'
)

# High: imperative recommendations on risky domains
declare -a HIGH_PATTERNS=(
  'install |install_'
  'rm -rf|delete (the |this )'
  'drop table|truncate'
  'sudo '
  '(production|prod|prd)\b.*\b(deploy|push|merge|update)'
  'database (migration|schema change)'
  'rotate.*credential|leak.*credential'
  'should not (run|execute|enable|disable)'
)

# Medium: ordinary recommendations / suggestions / fixes
declare -a MEDIUM_PATTERNS=(
  'te recomiendo|yo recomendaría|sugiero'
  'should (use|change|add|remove|update|switch|migrate)'
  'deberías|tendrías que'
  '(lo |la )(correcto|mejor) es'
  'el problema es|la causa es|root cause'
  'el patrón estándar'
  'usa (la librería|el comando|el script|el hook|el flag)'
  'cambia .* por |reemplaza .* por'
  'añade|agrega'
  'configure|configura'
  'evita |no hagas '
)

# ── Match and classify ──────────────────────────────────────────────────────

is_recommendation=0
risk_class="low"
declare -a hits=()

# Lowercase draft for matching (most patterns are lowercase)
DRAFT_LC=$(printf '%s' "$DRAFT" | tr '[:upper:]' '[:lower:]')

for p in "${CRITICAL_PATTERNS[@]}"; do
  if printf '%s' "$DRAFT_LC" | grep -qE -e "$p"; then
    is_recommendation=1
    risk_class="critical"
    hits+=("$p")
  fi
done

if [[ "$risk_class" != "critical" ]]; then
  for p in "${HIGH_PATTERNS[@]}"; do
    if printf '%s' "$DRAFT_LC" | grep -qE -e "$p"; then
      is_recommendation=1
      risk_class="high"
      hits+=("$p")
    fi
  done
fi

if [[ "$risk_class" == "low" ]]; then
  for p in "${MEDIUM_PATTERNS[@]}"; do
    if printf '%s' "$DRAFT_LC" | grep -qE -e "$p"; then
      is_recommendation=1
      risk_class="medium"
      hits+=("$p")
    fi
  done
fi

# ── Emit JSON ───────────────────────────────────────────────────────────────

# Build JSON array of hits manually (no jq dependency)
hits_json=""
for h in "${hits[@]:-}"; do
  [[ -z "$h" ]] && continue
  esc=$(printf '%s' "$h" | sed 's/\\/\\\\/g; s/"/\\"/g')
  if [[ -z "$hits_json" ]]; then
    hits_json="\"$esc\""
  else
    hits_json="$hits_json,\"$esc\""
  fi
done

is_rec_str="false"
[[ "$is_recommendation" -eq 1 ]] && is_rec_str="true"

printf '{"is_recommendation":%s,"risk_class":"%s","patterns_hit":[%s],"method":"heuristic"}\n' \
  "$is_rec_str" "$risk_class" "$hits_json"
