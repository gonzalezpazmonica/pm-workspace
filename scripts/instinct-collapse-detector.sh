#!/usr/bin/env bash
# instinct-collapse-detector.sh — SPEC-045 Phase 1: detect exploration collapse
# Analyzes instincts registry for staleness signals (AMI, CDS, PAR).
# Usage: instinct-collapse-detector.sh [--registry PATH] [--format json|table]
set -uo pipefail

REGISTRY=""
FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --help|-h) echo "Usage: $0 [--registry PATH] [--format json|table]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -z "$REGISTRY" ]]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  REGISTRY="$PROJECT_DIR/.claude/instincts/registry.json"
fi
[[ ! -f "$REGISTRY" ]] && { echo '{"instincts":[],"error":"Registry not found"}'; exit 0; }

python3 - "$REGISTRY" "$FORMAT" << 'PYEOF'
import json, sys
from datetime import datetime, timezone

registry_path, fmt = sys.argv[1], sys.argv[2]

with open(registry_path) as f:
    reg = json.load(f)

entries = reg.get("entries", [])
if not entries:
    if fmt == "table":
        print("No instincts registered yet.")
    else:
        print(json.dumps({"instincts": [], "total": 0, "collapsed": 0,
            "stale": 0, "drifted": 0, "healthy": 0}))
    sys.exit(0)

now = datetime.now(timezone.utc)
results = []

for e in entries:
    if not e.get("enabled", True):
        continue

    conf = e.get("confidence", 50)
    activations = e.get("activations", 0)
    last_used = e.get("last_used")

    # AMI: activation monotony index
    alternatives = e.get("alternatives_observed", [])
    alt_count = len(alternatives)
    ami = activations / (activations + alt_count) if (activations + alt_count) > 0 else 0

    # CDS: context drift score
    ctx_creation = e.get("context_at_creation", {})
    ctx_current = e.get("context_current", {})
    dimensions = ["role", "project", "primary_mode", "capability_group",
                  "sprint_phase", "team_size"]
    if ctx_creation and ctx_current:
        changed = sum(1 for d in dimensions
            if ctx_creation.get(d) != ctx_current.get(d) and ctx_creation.get(d))
        cds = changed / len(dimensions)
    else:
        cds = 0.0

    # PAR: passive acceptance rate
    silent_overrides = e.get("silent_overrides", 0)
    par = silent_overrides / activations if activations > 0 else 0

    # Classify
    if ami > 0.90 and cds > 0.40 and par > 0.30:
        status = "collapsed"
    elif ami > 0.90 and cds > 0.40:
        status = "drifted"
    elif ami > 0.90 and par > 0.30:
        status = "stale"
    else:
        status = "healthy"

    # Days since last use
    days_unused = 999
    if last_used:
        try:
            lu = datetime.fromisoformat(last_used.replace("Z", "+00:00"))
            days_unused = (now - lu).days
        except (ValueError, TypeError):
            days_unused = 999

    results.append({
        "id": e.get("id", "unknown"), "pattern": e.get("pattern", ""),
        "category": e.get("category", "unknown"), "confidence": conf,
        "activations": activations, "days_unused": days_unused,
        "ami": round(ami, 3), "cds": round(cds, 3),
        "par": round(par, 3), "status": status
    })

results.sort(key=lambda x: (
    {"collapsed": 0, "drifted": 1, "stale": 2, "healthy": 3}[x["status"]],
    -x["confidence"]))

summary = {
    "total": len(results),
    "collapsed": sum(1 for r in results if r["status"] == "collapsed"),
    "drifted": sum(1 for r in results if r["status"] == "drifted"),
    "stale": sum(1 for r in results if r["status"] == "stale"),
    "healthy": sum(1 for r in results if r["status"] == "healthy"),
}

if fmt == "table":
    print(f"Instinct Collapse Report — {summary['total']} instincts")
    print(f"Collapsed: {summary['collapsed']} | Drifted: {summary['drifted']} | "
          f"Stale: {summary['stale']} | Healthy: {summary['healthy']}")
    print("-" * 80)
    print(f"{'ID':<20} {'Conf':>5} {'AMI':>5} {'CDS':>5} {'PAR':>5} {'Status':<10}")
    print("-" * 80)
    for r in results:
        print(f"{r['id']:<20} {r['confidence']:>5} {r['ami']:>5.2f} "
              f"{r['cds']:>5.2f} {r['par']:>5.2f} {r['status']:<10}")
else:
    print(json.dumps({"instincts": results, **summary}, indent=2))
PYEOF
