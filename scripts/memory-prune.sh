#!/bin/bash
# memory-prune.sh — SE-270 S6: prune low-confidence memory entries
# Identifies entries below confidence threshold AND age threshold.
# Moves to tombstone (archive, not delete). Respects CRIT-024.
# Usage:
#   memory-prune.sh [--dry-run|--apply] [--confidence-threshold 0.3] [--age-days 90]
#   memory-prune.sh --report
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STORE_FILE="${WORKSPACE}/output/.memory-store.jsonl"
TOMBSTONE_FILE="${WORKSPACE}/output/.memory-tombstone.jsonl"
REPORT_DIR="${WORKSPACE}/output/memory-prune-reports"

CONFIDENCE_THRESHOLD="${MEMORY_PRUNE_CONFIDENCE:-0.3}"
AGE_DAYS="${MEMORY_PRUNE_AGE_DAYS:-90}"
DRY_RUN=true
REPORT_ONLY=false
QUIET=false

log() { echo "[memory-prune] $*" >&2; }

usage() {
  cat <<USAGE
memory-prune.sh — SE-270 S6: prune low-confidence entries (CRIT-024)

Usage:
  memory-prune.sh                     # preview without writing
  memory-prune.sh --dry-run           # preview without writing
  memory-prune.sh --apply             # prune entries below threshold
  memory-prune.sh --report            # generate prune report only
  memory-prune.sh --confidence-threshold 0.2 --age-days 60
  memory-prune.sh --help

Exit: 0 always (never blocks)
USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --apply) DRY_RUN=false; shift ;;
    --report) REPORT_ONLY=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --confidence-threshold)
      CONFIDENCE_THRESHOLD="${2:-$CONFIDENCE_THRESHOLD}"; shift 2 ;;
    --age-days)
      AGE_DAYS="${2:-$AGE_DAYS}"; shift 2 ;;
    --store) STORE_FILE="${2:-$STORE_FILE}"; shift 2 ;;
    --tombstone) TOMBSTONE_FILE="${2:-$TOMBSTONE_FILE}"; shift 2 ;;
    --help|-h) usage ;;
    *) shift ;;
  esac
done

if [[ ! -f "$STORE_FILE" ]]; then
  log "store file not found: $STORE_FILE — nothing to prune"
  exit 0
fi

# ── Decay first (idempotent, always run before prune) ──────────────────────────

if [[ "$DRY_RUN" != "true" && "${SAVIA_TEST_MODE:-false}" != "true" ]]; then
  python3 "$SCRIPT_DIR/memory-decay.py" --store "$STORE_FILE" \
    --threshold "$CONFIDENCE_THRESHOLD" --quiet 2>/dev/null || true
fi

# ── Classify entries via Python ─────────────────────────────────────────────────

result=$(python3 - "$STORE_FILE" "$CONFIDENCE_THRESHOLD" "$AGE_DAYS" "$TOMBSTONE_FILE" "$DRY_RUN" <<'PY' 2>/dev/null
import json, sys
from datetime import datetime, timezone
from pathlib import Path

store_path = Path(sys.argv[1])
threshold = float(sys.argv[2])
age_days = int(sys.argv[3])
tombstone_path = Path(sys.argv[4])
dry_run = sys.argv[5].lower() == "true"

now_epoch = datetime.now(timezone.utc).timestamp()
cutoff_epoch = now_epoch - (age_days * 86400)

keep = []
tombstone = []
stats = {"total": 0, "pruned": 0, "kept": 0, "reasons": {}, "sample_tombstone": []}

with store_path.open(encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            keep.append(line)
            stats["kept"] += 1
            continue
        stats["total"] += 1

        # Determine confidence
        conf = entry.get("confidence")
        if conf is None:
            quality = entry.get("quality", "unverified")
            qmap = {"high": 0.9, "medium": 0.7, "low": 0.4, "unverified": 0.3}
            conf = qmap.get(quality, 0.5)

        # Determine age
        ts_str = entry.get("ts", entry.get("valid_from", ""))
        try:
            if "T" in ts_str:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            else:
                ts = datetime.strptime(ts_str[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
            age = max((now_epoch - ts.timestamp()) / 86400, 0)
        except (ValueError, TypeError, OSError):
            age = 0

        # CRIT-024: never prune human-explicit instructions
        source = entry.get("source", "")
        is_human = source == "user:explicit"
        is_pinned = entry.get("pin", False) or entry.get("pinned", False)
        importance = entry.get("importance_tier", "B")

        should_prune = False
        reason = ""

        if is_human or is_pinned or importance == "A":
            should_prune = False
        elif conf < threshold and age > age_days:
            should_prune = True
            reason = f"confidence={conf:.3f}<{threshold} age={age:.0f}d>{age_days}d"
        elif conf < threshold:
            reason = f"confidence={conf:.3f}<{threshold} (age OK: {age:.0f}d)"
        elif age > age_days and importance == "C":
            should_prune = True
            reason = f"tier=C age={age:.0f}d>{age_days}d"

        if should_prune:
            entry["tombstone_ts"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            entry["tombstone_reason"] = reason
            tombstone.append(entry)
            stats["pruned"] += 1
            if reason not in stats["reasons"]:
                stats["reasons"][reason] = 0
            stats["reasons"][reason] += 1
            if len(stats["sample_tombstone"]) < 3:
                stats["sample_tombstone"].append({
                    "topic_key": entry.get("topic_key", "?"),
                    "title": entry.get("title", "?")[:80],
                    "reason": reason,
                })
        else:
            keep.append(json.dumps(entry, ensure_ascii=False))
            stats["kept"] += 1

# Write tombstone (CRIT-024: quarantine, not delete)
if dry_run:
    print(json.dumps({**stats, "mode": "dry_run"}))
else:
    # Append to tombstone (accumulate for quarantine)
    tombstone_path.parent.mkdir(parents=True, exist_ok=True)
    with tombstone_path.open("a", encoding="utf-8") as fh:
        for entry in tombstone:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    # Rewrite store without pruned entries
    store_path.write_text("\n".join(keep) + "\n", encoding="utf-8")
    print(json.dumps({**stats, "mode": "live"}))
PY
)

# ── Generate prune report ─────────────────────────────────────────────────────

stats_total=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo 0)
stats_pruned=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('pruned',0))" 2>/dev/null || echo 0)
stats_kept=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('kept',0))" 2>/dev/null || echo 0)
stats_mode=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('mode','?'))" 2>/dev/null || echo "?")

now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
report_date=$(date +"%Y%m%d" 2>/dev/null || echo "unknown")
report_file="$REPORT_DIR/prune-${report_date}.json"

mkdir -p "$REPORT_DIR"

report_json=$(python3 -c "
import json
result = json.loads('''$result''')
report = {
    'ts': '$now_iso',
    'store_file': '$STORE_FILE',
    'tombstone_file': '$TOMBSTONE_FILE',
    'config': {
        'confidence_threshold': $CONFIDENCE_THRESHOLD,
        'age_days': ${AGE_DAYS},
        'mode': '$stats_mode',
    },
    'stats': result,
}
print(json.dumps(report, indent=2, ensure_ascii=False))
" 2>/dev/null || echo '{"error":"report generation failed"}')

echo "$report_json" > "$report_file"

if ! $QUIET; then
  echo "$report_json"
fi

log "prune complete: total=$stats_total pruned=$stats_pruned kept=$stats_kept mode=$stats_mode"
log "tombstone: $TOMBSTONE_FILE"
log "report: $report_file"

exit 0
