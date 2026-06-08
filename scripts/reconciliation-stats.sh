#!/usr/bin/env bash
# reconciliation-stats.sh — Append/report reconciliation classification metrics
# Usage:
#   reconciliation-stats.sh --bucket <auto-resolve|evolution|conflict-doc> \
#                            --file <path> [--source <str>] [--confidence <float>]
#   reconciliation-stats.sh --report
# Ref: SPEC-183 reconciliation 3-bucket
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
STATS_DIR="${SAVIA_WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.savia"
STATS_FILE="$STATS_DIR/reconciliation-stats.jsonl"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Append mode (default):
  --bucket  <auto-resolve|evolution|conflict-doc>  Required
  --file    <path>                                  Required — affected file
  --source  <text>                                  Optional — reconciler rationale
  --confidence <0.0-1.0>                            Optional — classifier confidence

Report mode:
  --report  Print summary counts (auto-resolve / evolution / conflict-doc / total)

Options:
  --help    Show this help
EOF
  exit 0
}

BUCKET=""
FILE=""
SOURCE=""
CONFIDENCE=""
REPORT_MODE=false
PILOT_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)     shift; BUCKET="${1:-}" ;;
    --file)       shift; FILE="${1:-}" ;;
    --source)     shift; SOURCE="${1:-}" ;;
    --confidence) shift; CONFIDENCE="${1:-}" ;;
    --report)     REPORT_MODE=true ;;
    pilot)        PILOT_MODE=true ;;
    --help|-h)    usage ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Pilot mode ─────────────────────────────────────────────────────────────────
if [[ "$PILOT_MODE" == "true" ]]; then
  WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TODAY="$(date +%Y%m%d)"
  OUTPUT_FILE="$WORKSPACE_ROOT/output/reconciliation-pilot-${TODAY}.md"

  # Scan docs/rules/domain/*.md for same-term different definitions heuristic
  declare -A TERM_SEEN
  CONTRADICTIONS=()

  while IFS= read -r -d '' f; do
    while IFS= read -r line; do
      term="$(echo "$line" | sed -E 's/^\*\*([A-Za-z][A-Za-z0-9 _-]*)\*\*.*$/\1/;s/^### ([A-Za-z][A-Za-z0-9 _-]*)$/\1/' | xargs)"
      [[ -z "$term" ]] && continue
      norm="$(echo "$term" | tr '[:upper:]' '[:lower:]' | tr -s ' _-' ' ' | xargs)"
      [[ -z "$norm" ]] && continue
      if [[ -n "${TERM_SEEN[$norm]+x}" ]] && [[ "${TERM_SEEN[$norm]}" != "$f" ]]; then
        CONTRADICTIONS+=("$norm|${TERM_SEEN[$norm]}|$f")
        # Log to stats file
        bash "$SCRIPT_NAME" --bucket "conflict-doc" --file "$f" \
          --source "pilot-scan-${TODAY}" 2>/dev/null || true
      else
        TERM_SEEN[$norm]="$f"
      fi
    done < <(grep -nE '^\*\*[A-Za-z][A-Za-z0-9 _-]{2,40}\*\*[: ]|^### [A-Za-z][A-Za-z0-9 _-]{2,40}$' "$f" 2>/dev/null || true)
  done < <(find "$WORKSPACE_ROOT/docs/rules/domain" -name '*.md' -type f -print0 2>/dev/null)

  mkdir -p "$WORKSPACE_ROOT/output"
  {
    echo "---"
    echo "generated_by: reconciliation-stats.sh pilot"
    echo "date: $(date -u +%Y-%m-%d)"
    echo "spec: SPEC-183"
    echo "---"
    echo ""
    echo "# Reconciliation Pilot Scan — ${TODAY}"
    echo ""
    echo "Potential contradictions found: ${#CONTRADICTIONS[@]}"
    echo ""
    for c in "${CONTRADICTIONS[@]}"; do
      term="${c%%|*}"; rest="${c#*|}"; f1="${rest%%|*}"; f2="${rest##*|}"
      echo "- \`$term\`: \`$f1\` vs \`$f2\`"
    done
  } > "$OUTPUT_FILE"
  echo "Pilot scan complete. Contradictions found: ${#CONTRADICTIONS[@]}"
  echo "Report: $OUTPUT_FILE"
  exit 0
fi

# ── Report mode ────────────────────────────────────────────────────────────────
if [[ "$REPORT_MODE" == "true" ]]; then
  if [[ ! -f "$STATS_FILE" ]]; then
    echo "No reconciliation stats found at $STATS_FILE"
    exit 0
  fi
  auto=$(grep -c '"bucket":"auto-resolve"' "$STATS_FILE" 2>/dev/null || echo 0)
  evol=$(grep -c '"bucket":"evolution"' "$STATS_FILE" 2>/dev/null || echo 0)
  conf=$(grep -c '"bucket":"conflict-doc"' "$STATS_FILE" 2>/dev/null || echo 0)
  total=$((auto + evol + conf))
  echo "Reconciliation stats:"
  echo "  auto-resolve:  $auto"
  echo "  evolution:     $evol"
  echo "  conflict-doc:  $conf"
  echo "  total:         $total"
  if [[ "$total" -gt 0 ]]; then
    echo "  auto-rate:     $(python3 -c "print(f'{$auto/$total*100:.1f}%')" 2>/dev/null || echo 'n/a')"
  fi
  exit 0
fi

# ── Append mode ────────────────────────────────────────────────────────────────
if [[ -z "$BUCKET" ]]; then
  echo "ERROR: --bucket is required in append mode" >&2
  exit 1
fi
if [[ -z "$FILE" ]]; then
  echo "ERROR: --file is required in append mode" >&2
  exit 1
fi

case "$BUCKET" in
  auto-resolve|evolution|conflict-doc) ;;
  *)
    echo "ERROR: --bucket must be one of: auto-resolve evolution conflict-doc" >&2
    exit 1
    ;;
esac

mkdir -p "$STATS_DIR"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
CONF_FIELD=""
[[ -n "$CONFIDENCE" ]] && CONF_FIELD=',"confidence":'"$CONFIDENCE"

printf '{"ts":"%s","bucket":"%s","file":"%s","source":"%s"%s}\n' \
  "$TS" "$BUCKET" "$FILE" "${SOURCE:-}" "$CONF_FIELD" \
  >> "$STATS_FILE"

echo "Logged: bucket=$BUCKET file=$FILE"
