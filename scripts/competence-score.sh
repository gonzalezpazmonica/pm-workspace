#!/usr/bin/env bash
# competence-score.sh — Calculate competence scores from tracking log
# SPEC-014 Phase 2. Reads competence-log.jsonl, generates competence.md.
# Usage: competence-score.sh [--slug USER_SLUG]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in --slug) SLUG="$2"; shift 2 ;; *) shift ;; esac
done

# Detect active user if no slug provided
if [[ -z "$SLUG" ]]; then
  for p in "$ROOT_DIR/.claude/profiles" "$HOME/.claude/profiles"; do
    af="$p/active-user.md"
    [[ -f "$af" ]] && SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$af" 2>/dev/null) && break
  done
fi
[[ -z "$SLUG" ]] && { echo "No active user. Use --slug."; exit 1; }

PROFILE_DIR="$ROOT_DIR/.claude/profiles/users/$SLUG"
LOG="$PROFILE_DIR/competence-log.jsonl"
OUT="$PROFILE_DIR/competence.md"

[[ ! -f "$LOG" ]] && { echo "No log at $LOG. Hook needs to run first."; exit 0; }

ENTRIES=$(wc -l < "$LOG")
[[ $ENTRIES -eq 0 ]] && { echo "Empty log."; exit 0; }

echo "Scoring $ENTRIES entries for $SLUG..."

# ── Calculate scores per domain using Python ─────────────────────────────
python3 - "$LOG" "$OUT" << 'PYEOF'
import json, sys, math
from datetime import datetime, timezone
from collections import defaultdict

log_path, out_path = sys.argv[1], sys.argv[2]
now = datetime.now(timezone.utc)
domains = defaultdict(lambda: {"count": 0, "last": None, "successes": 0})

with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        d = e.get("domain", "")
        if not d:
            continue
        domains[d]["count"] += 1
        if e.get("success", True):
            domains[d]["successes"] += 1
        ts = e.get("ts", "")
        if ts:
            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                if domains[d]["last"] is None or dt > domains[d]["last"]:
                    domains[d]["last"] = dt
            except ValueError:
                pass

# Score each domain
results = []
for domain, data in sorted(domains.items()):
    count = data["count"]
    # Entry count: log2(count+1) normalized to 0-1 (ceiling at 100)
    entry_norm = min(1.0, math.log2(count + 1) / math.log2(101))
    # Recency: exp decay with half_life=30 days
    if data["last"]:
        days = (now - data["last"]).total_seconds() / 86400
        recency = math.exp(-0.693 * days / 30)  # ln(2)/30
    else:
        recency = 0.0
    # Outcome rate
    outcome = data["successes"] / count if count > 0 else 0.0
    # Weighted score (equal weights since we don't have depth yet)
    score = (entry_norm * 0.35 + recency * 0.35 + outcome * 0.30)
    # Classification
    if score >= 0.75 and count >= 20:
        level = "expert"
    elif score >= 0.50 and count >= 5:
        level = "competent"
    elif count >= 1:
        level = "novice"
    else:
        level = "unknown"
    last_str = data["last"].strftime("%Y-%m-%d") if data["last"] else "-"
    results.append((domain, level, f"entries:{count} recency:{recency:.2f} outcome:{outcome:.2f}", last_str, score))

# Write competence.md
with open(out_path, "w") as f:
    f.write("---\n")
    f.write(f"updated: {now.strftime('%Y-%m-%d')}\n")
    f.write("---\n\n")
    f.write("## Competence by Domain\n\n")
    f.write("| Domain | Level | Signals | Last active |\n")
    f.write("|--------|-------|---------|-------------|\n")
    for domain, level, signals, last, score in results:
        f.write(f"| {domain} | {level} | {signals} | {last} |\n")

print(f"Generated {out_path} with {len(results)} domains.")
for d, l, s, la, sc in results:
    print(f"  {d}: {l} (score={sc:.2f})")
PYEOF
