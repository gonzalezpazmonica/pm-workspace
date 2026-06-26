#!/usr/bin/env bash
set -uo pipefail
# iterate.sh — SPEC-195: Iterative tribunal loop controller.
#
# Drives the iterative refinement loop:
#   1. Tribunal evaluates draft -> verdict + scores.
#   2. If verdict == PASS or VETO: return immediately.
#   3. If WARN: regenerate draft with judges' hints.
#   4. Repeat from 1 until early_stop OR max_iter.
#
# This script does NOT call the LLM (that is the orchestrator agent's job).
# It is the deterministic glue that:
#   - tracks iteration state (draft hashes, judge scores per iter)
#   - calls early_stop.py to decide if loop should terminate
#   - persists history as JSONL for audit
#
# The orchestrator calls this script between rounds to know whether to stop.
#
# Usage:
#   iterate.sh evaluate-stop \
#       --iteration N \
#       --max-iter 3 \
#       --draft-hash <sha256> \
#       --previous-draft-hash <sha256 | empty> \
#       --judge-scores "85,92,78,..." \
#       --entropy-threshold 5.0
#
#   iterate.sh log-iteration \
#       --session-id <id> \
#       --iteration N \
#       --verdict PASS|WARN|VETO \
#       --draft-hash <sha256> \
#       --scores-csv "..." \
#       --stop-reason "stability|entropy|max_iter|none"
#
# Master switch: SAVIA_TRIBUNAL_ITERATIVE=on|off (default off during pilot).
#
# Ref: SPEC-195 docs/propuestas/SPEC-195-iterative-tribunal-early-stop.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
EARLY_STOP="$SCRIPT_DIR/early_stop.py"
HIST_CONTEXT="$SCRIPT_DIR/historical-context.py"
LOG_DIR="$ROOT_DIR/output/tribunal-iterations"

# Master switch
if [[ "${SAVIA_TRIBUNAL_ITERATIVE:-off}" == "off" ]]; then
  echo '{"enabled":false,"reason":"SAVIA_TRIBUNAL_ITERATIVE=off"}'
  exit 0
fi

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

cmd="${1:-}"
if [[ -z "$cmd" ]]; then
  usage
fi
shift || true

case "$cmd" in
  evaluate-stop)
    # SPEC-199: if historical context feature is enabled, build context block first
    if [[ "${SAVIA_TRIBUNAL_HIST_CONTEXT:-off}" == "on" ]]; then
      _hist_draft=""
      _hist_session="${SAVIA_TRIBUNAL_SESSION_ID:-default}"
      _hist_iter=0
      _peek_args=("$@")
      for (( _i=0; _i<${#_peek_args[@]}; _i++ )); do
        if [[ "${_peek_args[$_i]}" == "--draft-hash" ]]; then
          _hist_draft="${_peek_args[$((_i+1))]:-}"
        fi
        if [[ "${_peek_args[$_i]}" == "--iteration" ]]; then
          _hist_iter="${_peek_args[$((_i+1))]:-0}"
        fi
      done
      HIST_CTX=$(python3 "$SCRIPT_DIR/historical-context.py" \
        --draft "${_hist_draft}" \
        --top-k "${SAVIA_TRIBUNAL_HIST_TOP_K:-3}" \
        --similarity-threshold "${SAVIA_TRIBUNAL_HIST_SIMILARITY_MIN:-0.6}" \
        --session-id "${_hist_session}" \
        --iteration "${_hist_iter}" \
        2>/dev/null || echo '{"similar_drafts":[],"context_text":"","tokens_estimate":0,"is_zero_sc":true}')
      export TRIBUNAL_HISTORICAL_CONTEXT="$HIST_CTX"
    fi
    # Forward all args to early_stop.py
    exec python3 "$EARLY_STOP" --json "$@"
    ;;
  log-iteration)
    # Parse args
    session_id=""
    iteration=""
    verdict=""
    draft_hash=""
    scores_csv=""
    stop_reason=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --session-id) session_id="$2"; shift 2 ;;
        --iteration) iteration="$2"; shift 2 ;;
        --verdict) verdict="$2"; shift 2 ;;
        --draft-hash) draft_hash="$2"; shift 2 ;;
        --scores-csv) scores_csv="$2"; shift 2 ;;
        --stop-reason) stop_reason="$2"; shift 2 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    if [[ -z "$session_id" || -z "$iteration" || -z "$verdict" || -z "$draft_hash" ]]; then
      echo "ERROR: --session-id, --iteration, --verdict, --draft-hash are required" >&2
      exit 2
    fi
    mkdir -p "$LOG_DIR"
    ts=$(date -Iseconds 2>/dev/null || date)
    log_file="$LOG_DIR/$session_id.jsonl"
    if command -v jq >/dev/null 2>&1; then
      jq -nc \
        --arg ts "$ts" --arg sid "$session_id" \
        --arg iter "$iteration" --arg verdict "$verdict" \
        --arg dh "$draft_hash" --arg sc "$scores_csv" \
        --arg sr "$stop_reason" \
        '{ts:$ts, session_id:$sid, iteration:($iter|tonumber? // 0), verdict:$verdict, draft_hash:$dh, scores_csv:$sc, stop_reason:$sr}' \
        >> "$log_file"
    else
      printf '{"ts":"%s","session_id":"%s","iteration":%s,"verdict":"%s","draft_hash":"%s","scores_csv":"%s","stop_reason":"%s"}\n' \
        "$ts" "$session_id" "$iteration" "$verdict" "$draft_hash" "$scores_csv" "$stop_reason" \
        >> "$log_file"
    fi
    echo "{\"logged\":true,\"file\":\"$log_file\"}"
    ;;
  compute-temperature)
    # SPEC-197 wired: returns the LLM temperature for the current iteration.
    # Usage:
    #   iterate.sh compute-temperature \
    #       --iteration N --max-iter M \
    #       [--max-t 0.9] [--min-t 0.1] [--exponent 2.0]
    iter_val=""
    max_iter=""
    max_t="${SAVIA_ANNEAL_MAX_T:-0.9}"
    min_t="${SAVIA_ANNEAL_MIN_T:-0.1}"
    exponent="${SAVIA_ANNEAL_EXPONENT:-2.0}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --iteration) iter_val="$2"; shift 2 ;;
        --max-iter) max_iter="$2"; shift 2 ;;
        --max-t) max_t="$2"; shift 2 ;;
        --min-t) min_t="$2"; shift 2 ;;
        --exponent) exponent="$2"; shift 2 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    if [[ -z "$iter_val" || -z "$max_iter" ]]; then
      echo "ERROR: --iteration and --max-iter required" >&2
      exit 2
    fi
    ANNEAL_SCRIPT="$ROOT_DIR/scripts/annealing-schedule.py"
    if [[ ! -f "$ANNEAL_SCRIPT" ]]; then
      # SPEC-197 module absent — return max_t (no annealing)
      echo "{\"temperature\":$max_t,\"strategy\":\"no-annealing\",\"iteration\":$iter_val,\"max_iter\":$max_iter}"
      exit 0
    fi
    exec python3 "$ANNEAL_SCRIPT" \
      --index "$iter_val" --total "$max_iter" \
      --max-t "$max_t" --min-t "$min_t" --exponent "$exponent" --json
    ;;
  get-historical-context)
    # SPEC-199: get historical context for iteration N+1.
    # Usage: iterate.sh get-historical-context --draft "..." [--top-k 3] [--db path]
    if [[ "${SAVIA_TRIBUNAL_HIST_CONTEXT:-off}" != "on" ]]; then
      echo '{"similar_drafts":[],"context_text":"","tokens_estimate":0,"enabled":false}'
      exit 0
    fi
    if [[ ! -f "$HIST_CONTEXT" ]]; then
      echo '{"similar_drafts":[],"context_text":"","tokens_estimate":0,"enabled":false,"error":"historical-context.py not found"}'
      exit 0
    fi
    exec python3 "$HIST_CONTEXT" "$@"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "ERROR: unknown command: $cmd" >&2
    usage
    ;;
esac
