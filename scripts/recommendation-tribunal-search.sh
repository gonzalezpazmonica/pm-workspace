#!/usr/bin/env bash
# recommendation-tribunal-search.sh — SPEC-125 Slice 2: CLI for audit-trail inspection.
#
# Reads JSONL files under output/recommendation-tribunal/<date>/<hash>.json,
# applies filters, and emits matching records.
#
# Usage:
#   recommendation-tribunal-search.sh [--from YYYY-MM-DD] [--to YYYY-MM-DD]
#                                     [--verdict PASS|WARN|VETO|PENDING-SLICE-2]
#                                     [--risk low|medium|high]
#                                     [--hash <prefix>]
#                                     [--summary]
#                                     [--json]
#
# Default scope: today's directory.
# Default output: human summary (one line per record).
# --json: emit raw records (one JSON object per line).
# --summary: aggregated counts (verdicts, risks).
#
# Exit codes:
#   0  ok (zero or more records matched)
#   2  usage / args invalid
#   3  audit-trail directory missing
#
# Reference: SPEC-125 § 8 (audit trail).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

AUDIT_BASE="${RECOMMENDATION_TRIBUNAL_AUDIT_DIR:-$ROOT_DIR/output/recommendation-tribunal}"

FROM_DATE=""
TO_DATE=""
VERDICT=""
RISK=""
HASH_PREFIX=""
MODE="human"

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage ;;
    --from) FROM_DATE="${2:-}"; shift 2 ;;
    --to) TO_DATE="${2:-}"; shift 2 ;;
    --verdict) VERDICT="${2:-}"; shift 2 ;;
    --risk) RISK="${2:-}"; shift 2 ;;
    --hash) HASH_PREFIX="${2:-}"; shift 2 ;;
    --json) MODE="json"; shift ;;
    --summary) MODE="summary"; shift ;;
    *) echo "ERROR: unknown argument '$1'" >&2; usage ;;
  esac
done

# ── Resolve scan range ──────────────────────────────────────────────────────

if [[ ! -d "$AUDIT_BASE" ]]; then
  echo "ERROR: audit-trail directory missing: $AUDIT_BASE" >&2
  exit 3
fi

# Default to today only when no range specified
if [[ -z "$FROM_DATE" && -z "$TO_DATE" ]]; then
  FROM_DATE=$(date +%Y-%m-%d)
  TO_DATE="$FROM_DATE"
fi
[[ -z "$FROM_DATE" ]] && FROM_DATE="0000-01-01"
[[ -z "$TO_DATE" ]] && TO_DATE="9999-12-31"

# ── Collect candidate files ────────────────────────────────────────────────

candidates=()
while IFS= read -r -d '' dir; do
  date_dir=$(basename "$dir")
  # Skip non-date entries
  [[ "$date_dir" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
  # Range filter
  if [[ "$date_dir" < "$FROM_DATE" || "$date_dir" > "$TO_DATE" ]]; then
    continue
  fi
  while IFS= read -r -d '' f; do
    candidates+=("$f")
  done < <(find "$dir" -maxdepth 1 -name '*.json' -type f -print0 2>/dev/null)
done < <(find "$AUDIT_BASE" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# ── Filter and emit ─────────────────────────────────────────────────────────

# Per-file filtering uses python3 to handle JSONL safely (one record per line).
filter_py='
import json,sys,os
verdict_filter = os.environ.get("VERDICT","")
risk_filter    = os.environ.get("RISK","")
hash_filter    = os.environ.get("HASH","")
mode           = os.environ.get("MODE","human")
records        = []
for path in sys.argv[1:]:
  try:
    with open(path) as f:
      for line in f:
        line = line.strip()
        if not line: continue
        try:
          d = json.loads(line)
        except json.JSONDecodeError:
          continue
        if verdict_filter and d.get("verdict","") != verdict_filter: continue
        cls = d.get("classification",{}) if isinstance(d.get("classification"),dict) else {}
        if risk_filter and cls.get("risk_class","") != risk_filter: continue
        if hash_filter and not d.get("draft_hash","").startswith(hash_filter): continue
        records.append(d)
  except Exception:
    continue
if mode == "json":
  for r in records:
    print(json.dumps(r))
elif mode == "summary":
  from collections import Counter
  vc = Counter(r.get("verdict","?") for r in records)
  rc = Counter((r.get("classification",{}) or {}).get("risk_class","?") for r in records)
  print(f"records={len(records)}")
  print("verdicts: " + (", ".join(f"{k}={v}" for k,v in sorted(vc.items())) or "(none)"))
  print("risks:    " + (", ".join(f"{k}={v}" for k,v in sorted(rc.items())) or "(none)"))
else:
  for r in records:
    ts   = r.get("ts","?")
    h    = (r.get("draft_hash","") or "")[:12]
    verd = r.get("verdict","?")
    risk = (r.get("classification",{}) or {}).get("risk_class","?")
    prev = (r.get("draft_preview","") or "").replace("\n"," ")[:60]
    print(f"{ts}  {h}  risk={risk:<6}  verdict={verd:<18}  {prev}")
'

if [[ ${#candidates[@]} -eq 0 ]]; then
  case "$MODE" in
    summary) printf 'records=0\nverdicts: (none)\nrisks:    (none)\n' ;;
    *) : ;;  # silent (no records)
  esac
  exit 0
fi

VERDICT="$VERDICT" RISK="$RISK" HASH="$HASH_PREFIX" MODE="$MODE" \
  python3 -c "$filter_py" "${candidates[@]}"

exit 0
