#!/usr/bin/env bash
# SE-230 Auto-Loop Gate — classifies requests into loop/single-shot/clarify
# Usage: bash scripts/auto-loop-gate.sh --request "texto" [--context <path>]
# Output: JSON to stdout
# Exit 0 always (errors embedded in JSON)
set -uo pipefail

# -- Recursion guard
if [[ "${SAVIA_LOOP_CONTEXT:-}" != "" ]]; then
  printf '{"decision":"SINGLE_SHOT","loop_skill":null,"convergence_criterion":null,"max_iterations":null,"rationale":"SAVIA_LOOP_CONTEXT already set — recursion blocked (context: %s)","proposal_text":null}\n' \
    "${SAVIA_LOOP_CONTEXT}"
  exit 0
fi

# -- Args
REQUEST=""
CONTEXT_FILE=""
REQUEST_PROVIDED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --request)  REQUEST="$2"; REQUEST_PROVIDED=true; shift 2 ;;
    --context)  CONTEXT_FILE="$2";                   shift 2 ;;
    *)          shift ;;
  esac
done

if [[ "$REQUEST_PROVIDED" == false ]]; then
  echo "ERROR: --request is required" >&2
  exit 1
fi

if [[ -z "$REQUEST" ]]; then
  printf '{"decision":"SINGLE_SHOT","loop_skill":null,"convergence_criterion":null,"max_iterations":null,"rationale":"empty request — no pattern to classify","proposal_text":null}\n'
  exit 0
fi

# Normalise to lowercase for matching
REQ_LOWER=$(echo "$REQUEST" | tr '[:upper:]' '[:lower:]')

# -- Pattern helpers
has() { echo "$REQ_LOWER" | grep -qiE "$1"; }

# -- Decision table
DECISION="SINGLE_SHOT"
LOOP_SKILL="null"
CONVERGENCE=""
MAX_ITER="null"
RATIONALE=""

if has '\bspec\b' && has '\b(test|dod|criterio|acceptance)\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="tdd-vertical-slices"
  CONVERGENCE="tests_green_and_dod"
  MAX_ITER=8
  RATIONALE="Request contains spec SDD reference with verifiable DoD"
elif has '\bbug\b' && has '\b(test|reproduce|falla)\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="tdd-vertical-slices"
  CONVERGENCE="bug_reproduced_and_fixed"
  MAX_ITER=5
  RATIONALE="Bug report with reproducible test signal detected"
elif has '\brefactor\b' && has '\b(coverage|cobertura|test)\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="code-improvement-loop"
  CONVERGENCE="coverage_threshold_met"
  MAX_ITER=6
  RATIONALE="Refactor request with explicit coverage/test criterion"
elif has '\b(code.{0,5}review|pr.{0,5}review|review[[:space:]]+de[[:space:]]+código|revisar[[:space:]]+(pr|código))\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="court-orchestrator"
  CONVERGENCE="court_no_blocking_findings"
  MAX_ITER=3
  RATIONALE="Code/PR review request maps to court review loop"
elif has '\b(investiga|research|analiza)\b' && has '\b(fondo|profundidad|exhaustivo)\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="tech-research-agent"
  CONVERGENCE="research_saturation"
  MAX_ITER=4
  RATIONALE="In-depth research request with explicit depth qualifier"
elif has '\brefactor\b'; then
  DECISION="CLARIFY_NEEDED"
  LOOP_SKILL="null"
  CONVERGENCE=""
  MAX_ITER="null"
  RATIONALE="Refactor request lacks test/coverage criterion — cannot determine convergence"
else
  RATIONALE="No loop pattern matched — single-shot response appropriate"
fi

# -- Criterion descriptions
criterion_label() {
  case "$1" in
    tests_green_and_dod)         echo "todos los tests en verde y DoD cumplido" ;;
    bug_reproduced_and_fixed)    echo "bug reproducido y test en verde" ;;
    coverage_threshold_met)      echo "cobertura alcanza el umbral configurado" ;;
    court_no_blocking_findings)  echo "Code Review Court sin hallazgos bloqueantes" ;;
    research_saturation)         echo "saturación de fuentes (no nueva información relevante)" ;;
    *)                           echo "$1" ;;
  esac
}

# -- Proposal text
PROPOSAL_TEXT="null"
if [[ "$DECISION" == "PROPOSE_LOOP" ]]; then
  CRIT_LABEL=$(criterion_label "$CONVERGENCE")
  PROPOSAL_TEXT="Detecto que esta tarea tiene DoD verificable.\n  Loop sugerido: ${LOOP_SKILL}\n  Criterio de parada: ${CRIT_LABEL}\n  Budget máximo: ${MAX_ITER} iteraciones\n\n¿Activo el loop? [sí / no / ajustar budget]"
elif [[ "$DECISION" == "CLARIFY_NEEDED" ]]; then
  PROPOSAL_TEXT="La petición de refactor no incluye criterio de convergencia. ¿Quieres añadir un objetivo de cobertura o test? Ejemplo: 'refactor con coverage >80%'"
fi

# -- JSON output
# Escape backslashes and quotes in strings for valid JSON
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

R_ESC=$(escape_json "$RATIONALE")
P_ESC=$(escape_json "$PROPOSAL_TEXT")

if [[ "$LOOP_SKILL" == "null" ]]; then
  SKILL_JSON="null"
else
  SKILL_JSON="\"$LOOP_SKILL\""
fi

if [[ "$CONVERGENCE" == "" || "$CONVERGENCE" == "null" ]]; then
  CONV_JSON="null"
else
  CONV_JSON="\"$CONVERGENCE\""
fi

if [[ "$MAX_ITER" == "null" ]]; then
  ITER_JSON="null"
else
  ITER_JSON="$MAX_ITER"
fi

if [[ "$PROPOSAL_TEXT" == "null" ]]; then
  PROP_JSON="null"
else
  PROP_JSON="\"$P_ESC\""
fi

printf '{"decision":"%s","loop_skill":%s,"convergence_criterion":%s,"max_iterations":%s,"rationale":"%s","proposal_text":%s}\n' \
  "$DECISION" \
  "$SKILL_JSON" \
  "$CONV_JSON" \
  "$ITER_JSON" \
  "$R_ESC" \
  "$PROP_JSON"
