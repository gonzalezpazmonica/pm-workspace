#!/usr/bin/env bash
# harness.sh — Savia Flow E2E Test Harness (orchestrator)
# Ejecuta escenarios secuenciales contra pm-workspace usando Claude Code headless.
# Uso: bash harness.sh [mock|live] [scenario] [--auto-compact] [--compact-threshold=N]
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
AUTO_COMPACT=false
COMPACT_THRESHOLD="${SAVIA_COMPACT_THRESHOLD:-40}"
COMPACT_LOG=()
for arg in "$@"; do
  case "$arg" in
    --auto-compact) AUTO_COMPACT=true ;;
    --compact-threshold=*) COMPACT_THRESHOLD="${arg#*=}" ;;
  esac
done

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
  local tokens="$1" current
  current=$(jq -r '.context_tokens' "$STATE_FILE" 2>/dev/null || echo 0)
  jq ".context_tokens = $((current + tokens))" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}
get_context_load() { jq -r '.context_tokens' "$STATE_FILE" 2>/dev/null || echo 0; }

# ── Auto-compact (compresses context between scenarios) ─────────────────────
compact_context() {
  local before_ctx ratio savings threshold_tokens new_ctx
  before_ctx=$(get_context_load)
  threshold_tokens=$((200000 * COMPACT_THRESHOLD / 100))
  if [ "$before_ctx" -lt "$threshold_tokens" ]; then return 1; fi
  ratio=$((60 + RANDOM % 11))  # 60-70% reduction
  savings=$((before_ctx * ratio / 100))
  new_ctx=$((before_ctx - savings))
  jq ".context_tokens = $new_ctx" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  COMPACT_LOG+=("Compacted: ${before_ctx}→${new_ctx} tokens (-${ratio}%, saved ${savings})")
  log "  🗜️  AUTO-COMPACT: ${before_ctx}→${new_ctx} tokens (-${ratio}%)"
  return 0
}

# ── Source engines and report generator ─────────────────────────────────────
source "$HARNESS_DIR/engines.sh"   # shellcheck source=engines.sh
source "$HARNESS_DIR/report-gen.sh" # shellcheck source=report-gen.sh

# ── Execute one step ────────────────────────────────────────────────────────
run_step() {
  local scenario="$1" step_num="$2" role="$3" command="$4" prompt="$5"
  local step_dir="$OUTPUT_DIR/$scenario/step-$(printf '%02d' "$step_num")"
  mkdir -p "$step_dir"; echo "$prompt" > "$step_dir/prompt.txt"; TOTAL=$((TOTAL + 1))
  local result label="🟡 MOCK"
  if [ "$MODE" = "live" ]; then label="🔴 LIVE"; fi
  log "  $label [$role] $command"
  if [ "$MODE" = "live" ]; then result=$(live_exec "$prompt" "$step_dir")
  else result=$(mock_response "$command" "$role"); fi
  echo "$result" > "$step_dir/result.json"
  local s ti to dm er ca
  s=$(echo "$result" | jq -r '.status // "parse_error"' 2>/dev/null)
  ti=$(echo "$result" | jq -r '.tokens_in // 0' 2>/dev/null)
  to=$(echo "$result" | jq -r '.tokens_out // 0' 2>/dev/null)
  dm=$(echo "$result" | jq -r '.duration_ms // 0' 2>/dev/null)
  er=$(echo "$result" | jq -r '.error // ""' 2>/dev/null)
  ca=$(echo "$result" | jq -r '.context_accumulated // 0' 2>/dev/null)
  csv_row "$scenario" "$step_num" "$role" "$command" "$MODE" "$ti" "$to" "$dm" "$s" "$er" "$ca"
  case "$s" in
    ok)               PASS=$((PASS + 1)); log "    ✅ ${dm}ms | in:${ti} out:${to}" ;;
    context_overflow)  CONTEXT_WARNINGS=$((CONTEXT_WARNINGS + 1)); FAIL=$((FAIL + 1))
                       FAILURE_LOG+=("[$scenario/$step_num] $command: $er"); log "    ⚠️  CONTEXT OVERFLOW: $er" ;;
    timeout)           ERRORS=$((ERRORS + 1)); ERROR_LOG+=("[$scenario/$step_num] $command: $er"); log "    ⏱️  TIMEOUT: $er" ;;
    *)                 ERRORS=$((ERRORS + 1)); ERROR_LOG+=("[$scenario/$step_num] $command: $s $er"); log "    ❌ ERROR: $s $er" ;;
  esac
}

# ── Parse scenario file ────────────────────────────────────────────────────
run_scenario() {
  local file="$1" name
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
  if [ "$step" -gt 0 ] && [ -n "$prompt" ]; then
    run_step "$name" "$step" "$role" "$command" "$prompt"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  log "🚀 Savia E2E Test Harness — mode: $MODE, auto-compact: $AUTO_COMPACT"
  log "   Output: $OUTPUT_DIR"
  csv_header
  init_state
  if [ -n "$SINGLE_SCENARIO" ]; then
    local f="$SCENARIOS_DIR/$SINGLE_SCENARIO.md"
    if [ -f "$f" ]; then run_scenario "$f"
    else log "❌ Scenario not found: $f"; exit 1; fi
  else
    for f in "$SCENARIOS_DIR"/*.md; do
      if [ -f "$f" ]; then
        $AUTO_COMPACT && compact_context
        run_scenario "$f"
      fi
    done
  fi
  generate_report
  log "═══════════════════════════════════════════════════════════"
  log "  Total: $TOTAL | ✅ $PASS | ❌ $FAIL | 💥 $ERRORS | ⚠️  $CONTEXT_WARNINGS"
  log "═══════════════════════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && [ "$ERRORS" -eq 0 ] && exit 0 || exit 1
}

main
