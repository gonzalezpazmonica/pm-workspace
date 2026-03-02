#!/usr/bin/env bash
# harness.sh — Savia Flow E2E Test Harness
# Ejecuta escenarios secuenciales contra pm-workspace usando Claude Code headless.
# Uso: bash harness.sh [--mock|--live] [--scenario N]
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCENARIOS_DIR="$HARNESS_DIR/scenarios"
OUTPUT_DIR="$HARNESS_DIR/output/run-$(date +%Y%m%d-%H%M%S)"
REPORT="$OUTPUT_DIR/report.md"
METRICS_CSV="$OUTPUT_DIR/metrics.csv"
MODE="${1:-mock}"
SINGLE_SCENARIO="${2:-}"
MAX_TURNS="${SAVIA_MAX_TURNS:-3}"
TIMEOUT="${SAVIA_TIMEOUT:-120}"

mkdir -p "$OUTPUT_DIR"

# ── Contadores ──────────────────────────────────────────────────────────────
TOTAL=0; PASS=0; FAIL=0; ERRORS=0; CONTEXT_WARNINGS=0
declare -a FAILURE_LOG=()
declare -a ERROR_LOG=()

# ── Helpers ─────────────────────────────────────────────────────────────────
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$OUTPUT_DIR/harness.log"; }
csv_header() { echo "scenario,step,role,command,mode,tokens_in,tokens_out,duration_ms,status,error,context_acc" > "$METRICS_CSV"; }
csv_row() { echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10:-},${11:-}" >> "$METRICS_CSV"; }

# ── State file (accumulated context between steps) ──────────────────────────
STATE_FILE="$OUTPUT_DIR/state.json"
init_state() { echo '{"specs":[],"tasks":[],"deployed":[],"context_tokens":0}' > "$STATE_FILE"; }
update_state() {
  local tokens="$1"
  local current
  current=$(jq -r '.context_tokens' "$STATE_FILE" 2>/dev/null || echo 0)
  jq ".context_tokens = $((current + tokens))" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}
get_context_load() { jq -r '.context_tokens' "$STATE_FILE" 2>/dev/null || echo 0; }

# ── Realistic mock engine (calibrated per command type) ─────────────────────
mock_response() {
  local cmd="$1" role="$2"
  local base_in base_out base_ms overflow_pct
  # Calibrated ranges per command type (from E2E report analysis)
  case "$cmd" in
    flow-setup*)       base_in=1500; base_out=2000; base_ms=3600; overflow_pct=0 ;;
    flow-spec*)        base_in=1500; base_out=2400; base_ms=3200; overflow_pct=2 ;;
    flow-board*)       base_in=1400; base_out=2500; base_ms=3200; overflow_pct=5 ;;
    flow-intake*)      base_in=1400; base_out=2200; base_ms=2700; overflow_pct=5 ;;
    flow-metrics*)     base_in=1400; base_out=2800; base_ms=3000; overflow_pct=3 ;;
    flow-protect*)     base_in=1200; base_out=2000; base_ms=2500; overflow_pct=2 ;;
    pbi-decompose*)    base_in=1500; base_out=2400; base_ms=3300; overflow_pct=5 ;;
    pbi-jtbd*)         base_in=1700; base_out=1800; base_ms=3000; overflow_pct=1 ;;
    pbi-prd*)          base_in=900;  base_out=2200; base_ms=3800; overflow_pct=1 ;;
    quality-gate*)     base_in=1100; base_out=2600; base_ms=2800; overflow_pct=2 ;;
    release-readiness*)base_in=1900; base_out=2400; base_ms=4500; overflow_pct=3 ;;
    retro-summary*)    base_in=1400; base_out=2000; base_ms=3500; overflow_pct=15 ;;
    outcome-track*)    base_in=1500; base_out=1800; base_ms=3000; overflow_pct=2 ;;
    spec-contract*)    base_in=1200; base_out=1800; base_ms=2500; overflow_pct=1 ;;
    *)                 base_in=1300; base_out=2200; base_ms=3000; overflow_pct=3 ;;
  esac
  # Add ±30% variance
  local variance=$((RANDOM % 60 - 30))
  local tokens_in=$(( base_in + base_in * variance / 100 ))
  local tokens_out=$(( base_out + base_out * variance / 100 ))
  local duration=$(( base_ms + base_ms * variance / 100 ))
  # Context accumulation increases overflow probability
  local ctx_load
  ctx_load=$(get_context_load)
  if [ "$ctx_load" -gt 80000 ]; then overflow_pct=$((overflow_pct + 10)); fi
  if [ "$ctx_load" -gt 120000 ]; then overflow_pct=$((overflow_pct + 20)); fi
  local rnd=$((RANDOM % 100))
  local status="ok" error=""
  if [ "$rnd" -lt "$overflow_pct" ]; then
    status="context_overflow"; error="Context overflow at accumulated ${ctx_load} tokens (cmd budget exceeded)"
  elif [ "$rnd" -lt $((overflow_pct + 2)) ]; then
    status="timeout"; error="Timeout after ${TIMEOUT}s"
  fi
  update_state "$((tokens_in + tokens_out))"
  cat <<EOF
{"type":"mock","role":"$role","command":"$cmd","tokens_in":$tokens_in,"tokens_out":$tokens_out,"duration_ms":$duration,"status":"$status","error":"$error","context_accumulated":$(get_context_load)}
EOF
}

# ── Live engine ─────────────────────────────────────────────────────────────
live_exec() {
  local prompt="$1" step_dir="$2"
  local start_ms end_ms duration_ms
  start_ms=$(date +%s%3N 2>/dev/null || date +%s)
  local output
  output=$(timeout "$TIMEOUT" claude -p "$prompt" \
    --output-format json \
    --max-turns "$MAX_TURNS" \
    --verbose 2>"$step_dir/stderr.log") || {
    local exit_code=$?
    end_ms=$(date +%s%3N 2>/dev/null || date +%s)
    duration_ms=$((end_ms - start_ms))
    if [ "$exit_code" -eq 124 ]; then
      echo "{\"status\":\"timeout\",\"error\":\"Timeout after ${TIMEOUT}s\",\"duration_ms\":$duration_ms}"
    else
      echo "{\"status\":\"error\",\"error\":\"Exit code $exit_code\",\"duration_ms\":$duration_ms}"
    fi
    return
  }
  end_ms=$(date +%s%3N 2>/dev/null || date +%s)
  duration_ms=$((end_ms - start_ms))
  echo "$output" > "$step_dir/response.json"
  # Extract token counts from JSON output
  local tokens_in tokens_out
  tokens_in=$(echo "$output" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo "0")
  tokens_out=$(echo "$output" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo "0")
  echo "{\"status\":\"ok\",\"tokens_in\":$tokens_in,\"tokens_out\":$tokens_out,\"duration_ms\":$duration_ms}"
}

# ── Execute one step ────────────────────────────────────────────────────────
run_step() {
  local scenario="$1" step_num="$2" role="$3" command="$4" prompt="$5"
  local step_dir="$OUTPUT_DIR/$scenario/step-$(printf '%02d' "$step_num")"
  mkdir -p "$step_dir"
  echo "$prompt" > "$step_dir/prompt.txt"
  TOTAL=$((TOTAL + 1))
  local result
  if [ "$MODE" = "live" ]; then
    log "  🔴 LIVE [$role] $command"
    result=$(live_exec "$prompt" "$step_dir")
  else
    log "  🟡 MOCK [$role] $command"
    result=$(mock_response "$command" "$role")
  fi
  echo "$result" > "$step_dir/result.json"
  local status tokens_in tokens_out duration_ms error
  status=$(echo "$result" | jq -r '.status' 2>/dev/null || echo "parse_error")
  tokens_in=$(echo "$result" | jq -r '.tokens_in // 0' 2>/dev/null || echo "0")
  tokens_out=$(echo "$result" | jq -r '.tokens_out // 0' 2>/dev/null || echo "0")
  duration_ms=$(echo "$result" | jq -r '.duration_ms // 0' 2>/dev/null || echo "0")
  error=$(echo "$result" | jq -r '.error // ""' 2>/dev/null || echo "")
  local ctx_acc
  ctx_acc=$(echo "$result" | jq -r '.context_accumulated // 0' 2>/dev/null || echo "0")
  csv_row "$scenario" "$step_num" "$role" "$command" "$MODE" \
    "$tokens_in" "$tokens_out" "$duration_ms" "$status" "$error" "$ctx_acc"
  case "$status" in
    ok)               PASS=$((PASS + 1)); log "    ✅ ${duration_ms}ms | in:${tokens_in} out:${tokens_out}" ;;
    context_overflow)  CONTEXT_WARNINGS=$((CONTEXT_WARNINGS + 1)); FAIL=$((FAIL + 1))
                       FAILURE_LOG+=("[$scenario/$step_num] $command: $error")
                       log "    ⚠️  CONTEXT OVERFLOW: $error" ;;
    timeout)           ERRORS=$((ERRORS + 1)); ERROR_LOG+=("[$scenario/$step_num] $command: $error")
                       log "    ⏱️  TIMEOUT: $error" ;;
    *)                 ERRORS=$((ERRORS + 1)); ERROR_LOG+=("[$scenario/$step_num] $command: $status $error")
                       log "    ❌ ERROR: $status $error" ;;
  esac
}

# ── Parse scenario file ────────────────────────────────────────────────────
run_scenario() {
  local file="$1"
  local name
  name=$(basename "$file" .md)
  log "━━━ Scenario: $name ━━━"
  mkdir -p "$OUTPUT_DIR/$name"
  local step=0 role="" command="" prompt="" in_prompt=false
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##\ Step ]]; then
      if [ "$step" -gt 0 ] && [ -n "$prompt" ]; then
        run_step "$name" "$step" "$role" "$command" "$prompt"
      fi
      step=$((step + 1)); prompt=""; in_prompt=false
    elif [[ "$line" =~ ^-\ \*\*Role\*\*:\ (.*) ]]; then
      role="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-\ \*\*Command\*\*:\ (.*) ]]; then
      command="${BASH_REMATCH[1]}"
    elif [[ "$line" == '```prompt' ]]; then
      in_prompt=true; prompt=""
    elif [[ "$line" == '```' ]] && $in_prompt; then
      in_prompt=false
    elif $in_prompt; then
      prompt="${prompt:+$prompt$'\n'}$line"
    fi
  done < "$file"
  # Last step
  if [ "$step" -gt 0 ] && [ -n "$prompt" ]; then
    run_step "$name" "$step" "$role" "$command" "$prompt"
  fi
}

# ── Generate report ────────────────────────────────────────────────────────
generate_report() {
  local tmpl="$HARNESS_DIR/report-template.md"
  cp "$tmpl" "$REPORT" 2>/dev/null || echo "# Savia E2E Test Report" > "$REPORT"
  {
    echo ""
    echo "## Run Summary"
    echo ""
    echo "- **Date**: $(date '+%Y-%m-%d %H:%M')"
    echo "- **Mode**: $MODE"
    echo "- **Total steps**: $TOTAL"
    echo "- **Passed**: $PASS | **Failed**: $FAIL | **Errors**: $ERRORS"
    echo "- **Context warnings**: $CONTEXT_WARNINGS"
    echo ""
    if [ ${#FAILURE_LOG[@]} -gt 0 ]; then
      echo "## Failures"
      echo ""
      for f in "${FAILURE_LOG[@]}"; do echo "- $f"; done
      echo ""
    fi
    if [ ${#ERROR_LOG[@]} -gt 0 ]; then
      echo "## Errors"
      echo ""
      for e in "${ERROR_LOG[@]}"; do echo "- $e"; done
      echo ""
    fi
    echo "## Token Metrics"
    echo ""
    if [ -f "$METRICS_CSV" ]; then
      local total_in=0 total_out=0 total_time=0
      while IFS=, read -r _ _ _ _ _ tin tout dur _ _; do
        [[ "$tin" == "tokens_in" ]] && continue
        total_in=$((total_in + tin)); total_out=$((total_out + tout))
        total_time=$((total_time + dur))
      done < "$METRICS_CSV"
      echo "- **Total input tokens**: $total_in"
      echo "- **Total output tokens**: $total_out"
      echo "- **Total time**: $((total_time / 1000))s"
      if [ "$TOTAL" -gt 0 ]; then
        echo "- **Avg tokens/step**: in=$((total_in / TOTAL)) out=$((total_out / TOTAL))"
        echo "- **Avg time/step**: $((total_time / TOTAL))ms"
      fi
    fi
    echo ""
    echo "## Context Accumulation"
    echo ""
    local final_ctx
    final_ctx=$(get_context_load)
    local ctx_pct=$((final_ctx * 100 / 200000))
    echo "- **Final accumulated context**: ${final_ctx} tokens (${ctx_pct}% of 200K window)"
    if [ "$ctx_pct" -gt 70 ]; then echo "- **WARNING**: Context > 70%, compression recommended between scenarios"
    elif [ "$ctx_pct" -gt 50 ]; then echo "- **CAUTION**: Context > 50%, monitor closely"
    else echo "- **OK**: Context within safe range"
    fi
    echo ""
    echo "## Detailed CSV"
    echo ""
    echo "See: metrics.csv"
  } >> "$REPORT"
  log "📊 Report: $REPORT"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  log "🚀 Savia E2E Test Harness — mode: $MODE"
  log "   Output: $OUTPUT_DIR"
  csv_header
  init_state
  if [ -n "$SINGLE_SCENARIO" ]; then
    local f="$SCENARIOS_DIR/$SINGLE_SCENARIO.md"
    if [ -f "$f" ]; then run_scenario "$f"
    else log "❌ Scenario not found: $f"; exit 1; fi
  else
    for f in "$SCENARIOS_DIR"/*.md; do
      [ -f "$f" ] && run_scenario "$f"
    done
  fi
  generate_report
  log "═══════════════════════════════════════════════════════════"
  log "  Total: $TOTAL | ✅ $PASS | ❌ $FAIL | 💥 $ERRORS | ⚠️  $CONTEXT_WARNINGS"
  log "═══════════════════════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && [ "$ERRORS" -eq 0 ] && exit 0 || exit 1
}

main
