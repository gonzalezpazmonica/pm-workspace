#!/usr/bin/env bash
# engines.sh — Mock + Live engines for Savia E2E Test Harness
# Sourced by harness.sh. Requires: STATE_FILE, TIMEOUT, MAX_TURNS, harness helpers.

# ── Realistic mock engine (calibrated per command type) ─────────────────────
mock_response() {
  local cmd="$1" role="$2"
  local base_in base_out base_ms overflow_pct
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
  local variance=$((RANDOM % 60 - 30))
  local tokens_in=$(( base_in + base_in * variance / 100 ))
  local tokens_out=$(( base_out + base_out * variance / 100 ))
  local duration=$(( base_ms + base_ms * variance / 100 ))
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
  local tokens_in tokens_out
  tokens_in=$(echo "$output" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo "0")
  tokens_out=$(echo "$output" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo "0")
  echo "{\"status\":\"ok\",\"tokens_in\":$tokens_in,\"tokens_out\":$tokens_out,\"duration_ms\":$duration_ms}"
}
