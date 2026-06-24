#!/usr/bin/env bash
# output-cleanup.sh — SE-101: Output directory retention policy
#
# Lists (dry-run) or removes files in output/ older than SAVIA_OUTPUT_RETENTION_DAYS.
# Protected files and dirs are NEVER deleted regardless of age.
#
# Usage:
#   bash scripts/output-cleanup.sh [--dry-run]    # default: list only
#   bash scripts/output-cleanup.sh --execute       # delete after confirmation
#   SAVIA_OUTPUT_RETENTION_DAYS=30 bash scripts/output-cleanup.sh --execute
#
# Protected (never deleted):
#   output/anti-adulation-telemetry.jsonl
#   output/quality-gate-history.jsonl
#   output/pentesting/
#   output/baselines/
#   output/cleanup-log-*.txt
#
# Log: output/cleanup-log-YYYYMMDD.txt
#
# Ref: SE-101
# Safety: --dry-run is default; --execute requires explicit confirmation.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"

RETENTION_DAYS="${SAVIA_OUTPUT_RETENTION_DAYS:-90}"

MODE="dry-run"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --dry-run)  MODE="dry-run" ;;
    --execute)  MODE="execute" ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--dry-run|--execute]

  --dry-run   (default) List files older than RETENTION_DAYS without deleting
  --execute   Delete stale files after interactive confirmation

Env:
  SAVIA_OUTPUT_RETENTION_DAYS  Override retention (default: 90)

Protected (never deleted):
  output/anti-adulation-telemetry.jsonl
  output/quality-gate-history.jsonl
  output/pentesting/
  output/baselines/
  output/cleanup-log-*.txt
EOF
      exit 0 ;;
    *) echo "ERROR: unknown argument '$1'. Use --dry-run or --execute." >&2; exit 2 ;;
  esac
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$RETENTION_DAYS" -lt 1 ]]; then
  echo "ERROR: SAVIA_OUTPUT_RETENTION_DAYS must be a positive integer (got: $RETENTION_DAYS)" >&2
  exit 2
fi

[[ ! -d "$OUTPUT_DIR" ]] && { echo "ERROR: output dir not found: $OUTPUT_DIR" >&2; exit 2; }

TODAY_TS=$(date +%s)
CUTOFF_TS=$(( TODAY_TS - RETENTION_DAYS * 86400 ))

LOG_DATE=$(date +%Y%m%d)
LOG_FILE="$OUTPUT_DIR/cleanup-log-${LOG_DATE}.txt"

PROTECTED_FILES=(
  "anti-adulation-telemetry.jsonl"
  "quality-gate-history.jsonl"
)
PROTECTED_PATTERNS=(
  "cleanup-log-"
)
PROTECTED_DIRS=(
  "pentesting"
  "baselines"
)

is_protected() {
  local filepath="$1"
  local relpath="${filepath#$OUTPUT_DIR/}"
  for pdir in "${PROTECTED_DIRS[@]}"; do
    [[ "$relpath" == "$pdir/"* || "$relpath" == "$pdir" ]] && return 0
  done
  local bn
  bn=$(basename "$filepath")
  for pf in "${PROTECTED_FILES[@]}"; do
    [[ "$bn" == "$pf" ]] && return 0
  done
  for pat in "${PROTECTED_PATTERNS[@]}"; do
    [[ "$bn" == ${pat}* ]] && return 0
  done
  return 1
}

STALE_FILES=()
while IFS= read -r -d '' f; do
  [[ ! -f "$f" ]] && continue
  is_protected "$f" && continue
  file_ts=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
  if [[ "$file_ts" -lt "$CUTOFF_TS" ]]; then
    STALE_FILES+=("$f")
  fi
done < <(find "$OUTPUT_DIR" -maxdepth 3 -type f -print0 2>/dev/null)

stale_count=${#STALE_FILES[@]}

{
  echo "# output-cleanup.sh run — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# Mode: $MODE | Retention: ${RETENTION_DAYS}d | Stale: $stale_count"
  echo ""
} >> "$LOG_FILE"

if [[ "$stale_count" -eq 0 ]]; then
  echo "No files older than ${RETENTION_DAYS} days found in output/"
  echo "# Result: nothing to do" >> "$LOG_FILE"
  exit 0
fi

echo "Files older than ${RETENTION_DAYS} days (${stale_count} found):"
for f in "${STALE_FILES[@]}"; do
  rel="${f#$PROJECT_ROOT/}"
  file_ts=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
  age_days=$(( (TODAY_TS - file_ts) / 86400 ))
  printf "  [%3dd]  %s\n" "$age_days" "$rel"
  echo "  stale: $rel (${age_days}d)" >> "$LOG_FILE"
done

if [[ "$MODE" == "dry-run" ]]; then
  echo ""
  echo "Dry-run complete. $stale_count file(s) would be deleted."
  echo "Run with --execute to delete after confirmation."
  echo "# Result: dry-run, no files deleted" >> "$LOG_FILE"
  exit 0
fi

echo ""
printf "Delete %d files? [y/N] " "$stale_count"
read -r confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted. No files deleted."
  echo "# Result: user aborted" >> "$LOG_FILE"
  exit 1
fi

deleted=0
failed=0
for f in "${STALE_FILES[@]}"; do
  rel="${f#$PROJECT_ROOT/}"
  if rm -f "$f" 2>/dev/null; then
    deleted=$((deleted + 1))
    echo "  deleted: $rel" >> "$LOG_FILE"
  else
    failed=$((failed + 1))
    echo "  FAILED:  $rel" >> "$LOG_FILE"
    echo "WARNING: could not delete $rel" >&2
  fi
done

echo "Deleted $deleted file(s). $failed failed."
echo "Log: $LOG_FILE"
echo "# Result: deleted=$deleted failed=$failed" >> "$LOG_FILE"
