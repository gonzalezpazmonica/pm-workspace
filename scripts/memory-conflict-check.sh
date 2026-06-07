#!/bin/bash
# memory-conflict-check.sh — SE-214: detect conflicting memory entries
# Ref: docs/propuestas/SE-214-memory-conflict-detection.md
set -uo pipefail
CONTENT="${1:-}"
TYPE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$WORKSPACE_DIR/output"
STORE_FILE="${PROJECT_ROOT:-.}/output/.memory-store.jsonl"

# ── Flags ─────────────────────────────────────────────────────────────────────
CHECK_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-only) CHECK_ONLY=true; shift ;;
        --store)      STORE_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── Guard: empty content or unsupported type ──────────────────────────────────
if [[ -z "$CONTENT" ]]; then
    exit 0
fi

# Only check types that can conflict meaningfully
if [[ -n "$TYPE" ]] && [[ "$TYPE" != "decision" && "$TYPE" != "instruction" && "$TYPE" != "pattern" && "$TYPE" != "convention" ]]; then
    exit 0
fi

# ── Extract keywords from new content ─────────────────────────────────────────
# Split content into words, keep tokens ≥4 chars, lowercase, deduplicate
extract_keywords() {
    local text="$1"
    echo "$text" | tr '[:upper:]' '[:lower:]' \
        | tr -s ' .,;:!?()[]{}"\n\t' '\n' \
        | awk 'length($0) >= 4' \
        | sort -u \
        | head -20
}

new_keywords=()
while IFS= read -r kw; do
    [[ -n "$kw" ]] && new_keywords+=("$kw")
done < <(extract_keywords "$CONTENT")

[[ ${#new_keywords[@]} -eq 0 ]] && exit 0

# ── Scan existing entries for keyword overlap ─────────────────────────────────
conflicts_found=0
conflict_json_lines=()
ts_now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
log_date=$(date +%Y%m%d 2>/dev/null || echo "00000000")
log_file="$OUTPUT_DIR/memory-conflicts-${log_date}.jsonl"

if [[ -f "$STORE_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Filter by type if specified
        if [[ -n "$TYPE" ]]; then
            entry_type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4 || true)
            [[ "$entry_type" != "$TYPE" ]] && continue
        fi

        entry_content=$(echo "$line" | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | head -c 500 || true)
        entry_title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 || true)
        entry_ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 || true)
        entry_date=$(echo "$entry_ts" | cut -d'T' -f1 || true)

        [[ -z "$entry_content" ]] && continue

        # Count keyword overlap
        old_keywords=()
        while IFS= read -r kw; do
            [[ -n "$kw" ]] && old_keywords+=("$kw")
        done < <(extract_keywords "$entry_content")

        overlap=0
        for kw in "${new_keywords[@]}"; do
            for okw in "${old_keywords[@]}"; do
                if [[ "$kw" == "$okw" ]]; then
                    ((overlap++)) || true
                    break
                fi
            done
        done

        # Overlap threshold: ≥3 shared keywords = potential conflict
        if [[ $overlap -ge 3 ]]; then
            ((conflicts_found++)) || true
            echo "[CONFLICT-WARN] Nueva entry puede contradecir '${entry_title:-entry}' (${entry_date:-unknown}). Revisar antes de guardar." >&2

            if [[ "$CHECK_ONLY" != "true" ]]; then
                mkdir -p "$OUTPUT_DIR" 2>/dev/null || true
                new_safe=$(echo "$CONTENT" | head -c 200 | tr '"' "'" | tr '\n' ' ')
                old_safe=$(echo "$entry_content" | head -c 200 | tr '"' "'" | tr '\n' ' ')
                conflict_json_lines+=("{\"ts\":\"$ts_now\",\"new\":\"$new_safe\",\"conflict\":\"$old_safe\",\"date_conflict\":\"${entry_date:-unknown}\",\"type\":\"${TYPE:-unknown}\"}")
            fi
        fi
    done < "$STORE_FILE"
fi

# ── Write conflict log ─────────────────────────────────────────────────────────
if [[ "$CHECK_ONLY" != "true" && ${#conflict_json_lines[@]} -gt 0 ]]; then
    for cline in "${conflict_json_lines[@]}"; do
        echo "$cline" >> "$log_file"
    done
fi

# Always exit 0 — conflict check never blocks saves
exit 0
