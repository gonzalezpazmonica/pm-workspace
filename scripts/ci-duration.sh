#!/usr/bin/env bash
# ci-duration.sh — SE-361: mide duración de jobs de CI (wrapper).
# set -uo pipefail
#
# Recoge duraciones de jobs de CI (desde gh run list, o cache local) y genera
# el informe de duración con p50/p95 y detección de jobs sobre presupuesto.
#
# Uso:
#   ci-duration.sh [--days 14] [--budget 5] [--format markdown|json] [--offline]
#
# --offline: usa el cache local (data/ci-duration/jobs.jsonl) sin llamar a gh.
# Ref: SE-361 — presupuesto de tiempo de CI
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAYS=14
BUDGET=5
FORMAT="markdown"
OFFLINE=false
JOBS_FILE="$ROOT/data/ci-duration/jobs.jsonl"

while [[ $# -gt 0 ]]; do case "$1" in
  --days) DAYS="$2"; shift 2 ;;
  --budget) BUDGET="$2"; shift 2 ;;
  --format) FORMAT="$2"; shift 2 ;;
  --offline) OFFLINE=true; shift ;;
  --input) JOBS_FILE="$2"; shift 2 ;;
  *) shift ;;
esac; done

mkdir -p "$ROOT/data/ci-duration"

if ! $OFFLINE && command -v gh >/dev/null 2>&1; then
  # Recoger jobs recientes (best-effort; si gh falla, usa cache)
  gh run list --limit 20 --json jobs --jq '.jobs[] | {name: .name, duration_ms: ((.completed_at // now) - (.started_at // now) | if type=="number" then .*1000 else 0 end), conclusion: .conclusion}' 2>/dev/null \
    | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        print(line)
    except Exception:
        pass
" >> "$JOBS_FILE" 2>/dev/null || true
fi

if [[ "$FORMAT" == "json" ]]; then
  python3 "$ROOT/scripts/ci-duration-agg.py" --input "$JOBS_FILE" --budget "$BUDGET" --json
  exit 0
fi

OUT_DIR="$ROOT/output/research"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/ci-duration-$(date +%Y%m%d).md"
python3 "$ROOT/scripts/ci-duration-agg.py" --input "$JOBS_FILE" --budget "$BUDGET" > "$OUT_FILE"
echo "Informe ci-duration escrito: $OUT_FILE"
echo "---"
cat "$OUT_FILE"
