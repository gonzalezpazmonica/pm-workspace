#!/bin/bash
# confidence-calibrate.sh - Confidence Calibration Analytics
# Reads data/confidence-log.jsonl, computes per-band accuracy and Brier score
set -euo pipefail
export LC_NUMERIC=C

PROJECT_ROOT="${PROJECT_ROOT:-.}"
DATA_DIR="${PROJECT_ROOT}/data"
LOG_FILE="${DATA_DIR}/confidence-log.jsonl"
ARCHIVE_DIR="${DATA_DIR}/.archive"

iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

cmd_report() {
    [[ ! -f "$LOG_FILE" ]] && { echo "No confidence log found at $LOG_FILE"; exit 1; }
    [[ $(wc -l < "$LOG_FILE") -eq 0 ]] && { echo "Log is empty"; exit 0; }

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Confidence Calibration Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Segment entries by confidence band
    local low=0 mid=0 high=0
    local low_correct=0 mid_correct=0 high_correct=0
    local sum_brier=0 count=0

    while IFS= read -r line; do
        local conf=$(echo "$line" | jq -r '.confidence // 0')
        local success=$(echo "$line" | jq -r '.success // false')
        local actual=$([ "$success" = "true" ] && echo "1" || echo "0")

        # Band segmentation
        if (( conf < 60 )); then
            low=$((low + 1))
            [[ "$success" = "true" ]] && low_correct=$((low_correct + 1))
        elif (( conf < 80 )); then
            mid=$((mid + 1))
            [[ "$success" = "true" ]] && mid_correct=$((mid_correct + 1))
        else
            high=$((high + 1))
            [[ "$success" = "true" ]] && high_correct=$((high_correct + 1))
        fi

        # Brier score: mean((confidence/100 - actual)^2)
        local pred=$(echo "scale=4; $conf / 100" | bc)
        local diff=$(echo "scale=4; $pred - $actual" | bc)
        local squared=$(echo "scale=4; $diff * $diff" | bc)
        sum_brier=$(echo "scale=4; $sum_brier + $squared" | bc)
        count=$((count + 1))
    done < "$LOG_FILE"

    local brier=$(echo "scale=4; $sum_brier / $count" | bc)

    # Accuracy per band
    local low_acc=$(( low > 0 ? (low_correct * 100 / low) : 0 ))
    local mid_acc=$(( mid > 0 ? (mid_correct * 100 / mid) : 0 ))
    local high_acc=$(( high > 0 ? (high_correct * 100 / high) : 0 ))

    echo "## Per-Band Accuracy"
    echo ""
    echo "| Band | Count | Correct | Accuracy | Status |"
    echo "|------|-------|---------|----------|--------|"
    printf "| <60%% | %d | %d | %d%% | %s |\n" "$low" "$low_correct" "$low_acc" \
        "$([ "$low_acc" -ge 70 ] && echo "✅" || echo "⚠️")"
    printf "| 60-79%% | %d | %d | %d%% | %s |\n" "$mid" "$mid_correct" "$mid_acc" \
        "$([ "$mid_acc" -ge 75 ] && echo "✅" || echo "⚠️")"
    printf "| ≥80%% | %d | %d | %d%% | %s |\n" "$high" "$high_correct" "$high_acc" \
        "$([ "$high_acc" -ge 85 ] && echo "✅" || echo "⚠️")"
    echo ""
    echo "## Overall Metrics"
    echo ""
    printf "Total Resolutions: %d\n" "$count"
    printf "Overall Brier Score: %.4f\n" "$brier"
    echo ""

    # Recommendations
    if (( $(echo "$brier > 0.2" | bc -l) )); then
        echo "## Recommendations"
        echo ""
        [[ "$low_acc" -lt 70 ]] && echo "- **Band <60%:** Accuracy is ${low_acc}%. Increase base penalty by 10%."
        [[ "$mid_acc" -lt 75 ]] && echo "- **Band 60-79%:** Accuracy is ${mid_acc}%. Adjust history bonus by ±2%."
        [[ "$high_acc" -lt 85 ]] && echo "- **Band ≥80%:** Accuracy is ${high_acc}%. Consider reducing base by 10%."
    else
        echo "✅ Calibration is good (Brier < 0.2). No adjustments needed."
    fi
    echo ""
}

cmd_summary() {
    [[ ! -f "$LOG_FILE" ]] && { echo "Log not found"; exit 1; }
    [[ $(wc -l < "$LOG_FILE") -eq 0 ]] && { echo "Empty"; exit 0; }

    local count=$(wc -l < "$LOG_FILE")
    local success=$(grep -c '"success":true' "$LOG_FILE" || echo "0")
    local brier=0
    local sum=0
    while IFS= read -r line; do
        local conf=$(echo "$line" | jq -r '.confidence // 0')
        local actual=$(grep -q '"success":true' <<< "$line" && echo "1" || echo "0")
        local pred=$(echo "scale=4; $conf / 100" | bc)
        local diff=$(echo "scale=4; $pred - $actual" | bc)
        local sq=$(echo "scale=4; $diff * $diff" | bc)
        sum=$(echo "scale=4; $sum + $sq" | bc)
    done < "$LOG_FILE"
    brier=$(echo "scale=4; $sum / $count" | bc)
    printf "Resolutions: %d | Success: %d | Brier: %.4f\n" "$count" "$success" "$brier"
}

cmd_reset() {
    [[ -f "$LOG_FILE" ]] || { echo "No log to archive"; exit 0; }
    mkdir -p "$ARCHIVE_DIR"
    local ts=$(date -u +"%Y%m%d-%H%M%S")
    mv "$LOG_FILE" "${ARCHIVE_DIR}/confidence-log-${ts}.jsonl"
    echo "✓ Log archived to ${ARCHIVE_DIR}/confidence-log-${ts}.jsonl"
}

mkdir -p "$DATA_DIR"
case "${1:-report}" in
    report) cmd_report ;;
    summary) cmd_summary ;;
    reset) cmd_reset ;;
    *) echo "Uso: $0 {report|summary|reset}"; exit 1 ;;
esac
