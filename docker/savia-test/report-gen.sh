#!/usr/bin/env bash
# report-gen.sh — Report generator for Savia E2E Test Harness
# Sourced by harness.sh. Requires: REPORT, METRICS_CSV, OUTPUT_DIR, counters, logs.

generate_report() {
  local tmpl="$HARNESS_DIR/report-template.md"
  cp "$tmpl" "$REPORT" 2>/dev/null || echo "# Savia E2E Test Report" > "$REPORT"
  {
    echo ""
    echo "## Run Summary"
    echo ""
    echo "- **Date**: $(date '+%Y-%m-%d %H:%M')"
    echo "- **Mode**: $MODE"
    echo "- **Auto-compact**: $AUTO_COMPACT (threshold: ${COMPACT_THRESHOLD}%)"
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
    local final_ctx ctx_pct
    final_ctx=$(get_context_load)
    ctx_pct=$((final_ctx * 100 / 200000))
    echo "- **Final accumulated context**: ${final_ctx} tokens (${ctx_pct}% of 200K window)"
    if [ "$ctx_pct" -gt 70 ]; then echo "- **WARNING**: Context > 70%, compression recommended"
    elif [ "$ctx_pct" -gt 50 ]; then echo "- **CAUTION**: Context > 50%, monitor closely"
    else echo "- **OK**: Context within safe range"
    fi
    echo ""
    if $AUTO_COMPACT && [ ${#COMPACT_LOG[@]} -gt 0 ]; then
      echo "## Auto-Compaction Events"
      echo ""
      for c in "${COMPACT_LOG[@]}"; do echo "- $c"; done
      echo ""
    fi
    echo "## Detailed CSV"
    echo ""
    echo "See: metrics.csv"
  } >> "$REPORT"
  log "📊 Report: $REPORT"
}
