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
csv_header() { echo "scenario,step,role,command,mode,tokens_in,tokens_out,duration_ms,status,error" > "$METRICS_CSV"; }
csv_row() { echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10:-}" >> "$METRICS_CSV"; }

# ── Mock engine ─────────────────────────────────────────────────────────────
mock_response() {
  local cmd="$1" role="$2"
  local tokens_in=$((RANDOM % 2000 + 500))
  local tokens_out=$((RANDOM % 3000 + 800))
  local duration=$((RANDOM % 5000 + 1000))
  # Simulate occasional failures (5%)
  local rnd=$((RANDOM % 100))
  local status="ok" error=""
  if [ "$rnd" -lt 3 ]; then status="context_overflow"; error="Simulated context overflow at ${tokens_in} tokens"
  elif [ "$rnd" -lt 5 ]; then status="timeout"; error="Simulated timeout after ${TIMEOUT}s"
  fi
  cat <<EOF
{"type":"mock","role":"$role","command":"$cmd","tokens_in":$tokens_in,"tokens_out":$tokens_out,"duration_ms":$duration,"status":"$status","error":"$error"}
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
  csv_row "$scenario" "$step_num" "$role" "$command" "$MODE" \
    "$tokens_in" "$tokens_out" "$duration_ms" "$status" "$error"
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
