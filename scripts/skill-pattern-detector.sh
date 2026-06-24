#!/usr/bin/env bash
# scripts/skill-pattern-detector.sh — SPEC-SE-030 Phase 1: Pattern Detection
#
# Analyzes skill invocations to detect repeated command sequences.
#
# CLI:
#   bash scripts/skill-pattern-detector.sh [--min-count 3] [--json]
#
# Detection rule:
#   Same sequence of 3+ commands appearing 3+ times in the last 20 sessions.
#
# Sources:
#   data/skill-invocations.jsonl  (primary)
#   output/router-decisions.jsonl (supplemental signals)
#
# Output (--json):
#   {patterns_found: N, patterns: [{sequence: [], count: int, suggestion: str}]}
#
# If no data: {patterns_found: 0, note: "insufficient data (need >=20 sessions)"}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output}"
INVOCATIONS_LOG="${INVOCATIONS_LOG:-$DATA_DIR/skill-invocations.jsonl}"
ROUTER_LOG="${ROUTER_LOG:-$OUTPUT_DIR/router-decisions.jsonl}"

MIN_COUNT=3
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-count) MIN_COUNT="$2"; shift 2 ;;
    --json)      JSON_MODE=true; shift ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Check data availability ───────────────────────────────────────────────────

if [[ ! -f "$INVOCATIONS_LOG" ]]; then
  if "$JSON_MODE"; then
    printf '{"patterns_found":0,"note":"insufficient data (need >=20 sessions)"}\n'
  else
    echo "Insufficient data: $INVOCATIONS_LOG not found (need >=20 sessions)"
  fi
  exit 0
fi

SESSION_COUNT=0
if command -v python3 >/dev/null 2>&1; then
  SESSION_COUNT=$(python3 -c "
import json, sys
from pathlib import Path
f = Path('$INVOCATIONS_LOG')
if not f.exists():
    print(0); sys.exit(0)
sessions = set()
for line in f.read_text().splitlines():
    line = line.strip()
    if not line: continue
    try:
        r = json.loads(line)
        s = r.get('session_id','')
        if s: sessions.add(s)
    except Exception:
        pass
print(len(sessions))
" 2>/dev/null) || SESSION_COUNT=0
fi

NEEDED=20
if (( SESSION_COUNT < NEEDED )); then
  if "$JSON_MODE"; then
    printf '{"patterns_found":0,"note":"insufficient data (need >=20 sessions)"}\n'
  else
    echo "Insufficient data: $SESSION_COUNT sessions found (need >=$NEEDED)"
  fi
  exit 0
fi

# ── Pattern detection via Python ──────────────────────────────────────────────

if command -v python3 >/dev/null 2>&1; then
  python3 << PYSCRIPT
import json, sys, collections
from pathlib import Path

invocations_path = Path("$INVOCATIONS_LOG")
router_path = Path("$ROUTER_LOG")
min_count = int("$MIN_COUNT")

def load_jsonl(p):
    records = []
    if not p.exists():
        return records
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except Exception:
            pass
    return records

invocations = load_jsonl(invocations_path)
router_signals = load_jsonl(router_path)

# Group by session, get last 20 sessions chronologically
session_map = collections.defaultdict(list)
for r in invocations:
    sid = r.get("session_id", "")
    if sid:
        session_map[sid].append(r)

# Sort sessions by earliest ts
def session_min_ts(records):
    tss = [r.get("ts","") for r in records if r.get("ts")]
    return min(tss) if tss else ""

sorted_sessions = sorted(session_map.keys(), key=lambda s: session_min_ts(session_map[s]))
last_20 = sorted_sessions[-20:]

# Extract command sequences per session
session_seqs = {}
for sid in last_20:
    recs = sorted(session_map[sid], key=lambda r: r.get("ts",""))
    cmds = [r.get("command","") for r in recs if r.get("command","")]
    session_seqs[sid] = cmds

# Find repeating sub-sequences of length >= 3
seq_counts = collections.Counter()
for sid, cmds in session_seqs.items():
    n = len(cmds)
    seen_in_session = set()
    for length in range(3, n+1):
        for start in range(n - length + 1):
            sub = tuple(cmds[start:start+length])
            if sub not in seen_in_session:
                seq_counts[sub] += 1
                seen_in_session.add(sub)

patterns = []
for seq, count in seq_counts.items():
    if count >= min_count:
        suggestion = "Consider creating a skill that automates: " + " -> ".join(seq)
        patterns.append({
            "sequence": list(seq),
            "count": count,
            "suggestion": suggestion,
        })

# Sort by count descending, then by length descending for determinism
patterns.sort(key=lambda p: (-p["count"], -len(p["sequence"])))

result = {
    "patterns_found": len(patterns),
    "patterns": patterns,
}
print(json.dumps(result, indent=2))
PYSCRIPT
else
  # No python3: return minimal JSON
  printf '{"patterns_found":0,"note":"python3 not available for pattern detection"}\n'
fi
