#!/usr/bin/env bash
# trace-pattern-extractor.sh — SPEC-044 Phase 1: analyze agent traces
# Reads agent-traces.jsonl, computes per-agent metrics, ranks candidates.
# Usage: trace-pattern-extractor.sh [--agent NAME] [--min-traces N] [--traces-file PATH]
set -uo pipefail

MIN_TRACES="${MIN_TRACES:-20}"
AGENT_FILTER=""
TRACES_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT_FILTER="$2"; shift 2 ;;
    --min-traces) MIN_TRACES="$2"; shift 2 ;;
    --traces-file) TRACES_FILE="$2"; shift 2 ;;
    --help|-h) echo "Usage: $0 [--agent NAME] [--min-traces N] [--traces-file PATH]"; exit 0 ;;
    *) shift ;;
  esac
done

# Find traces file
if [[ -z "$TRACES_FILE" ]]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  TRACES_FILE=$(find "$PROJECT_DIR/projects" -name "agent-traces.jsonl" -type f 2>/dev/null | head -1)
  [[ -z "$TRACES_FILE" ]] && { echo '{"candidates":[],"error":"No traces file found"}'; exit 0; }
fi
[[ ! -f "$TRACES_FILE" ]] && { echo '{"candidates":[],"error":"Traces file not found: '"$TRACES_FILE"'"}'; exit 0; }

python3 - "$TRACES_FILE" "$MIN_TRACES" "$AGENT_FILTER" << 'PYEOF'
import json, sys
from collections import defaultdict

traces_file, min_traces = sys.argv[1], int(sys.argv[2])
agent_filter = sys.argv[3] if len(sys.argv) > 3 else ""

agents = defaultdict(lambda: {
    "total": 0, "failures": 0, "budget_exceeded": 0,
    "durations": [], "tokens_in": [], "tokens_out": [], "budgets": []
})

with open(traces_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try: t = json.loads(line)
        except json.JSONDecodeError: continue
        name = t.get("agent", "unknown")
        if agent_filter and name != agent_filter: continue
        a = agents[name]
        a["total"] += 1
        if t.get("outcome") == "failure": a["failures"] += 1
        if t.get("budget_exceeded"): a["budget_exceeded"] += 1
        a["durations"].append(t.get("duration_ms", 0))
        a["tokens_in"].append(t.get("tokens_in", 0))
        a["tokens_out"].append(t.get("tokens_out", 0))
        if t.get("token_budget", 0) > 0: a["budgets"].append(t["token_budget"])

candidates = []
for name, a in agents.items():
    if a["total"] < min_traces: continue
    failure_rate = a["failures"] / a["total"]
    budget_overage_rate = a["budget_exceeded"] / a["total"]
    dur = a["durations"]
    if len(dur) >= 20:
        prev10, last10 = sum(dur[-20:-10])/10, sum(dur[-10:])/10
        duration_trend = (last10 - prev10) / prev10 if prev10 > 0 else 0
    else: duration_trend = 0
    total_in, total_out = sum(a["tokens_in"]), sum(a["tokens_out"])
    token_efficiency = total_out / total_in if total_in > 0 else 0

    patterns = []
    if failure_rate > 0.20:
        patterns.append({"id": "frequent_failures", "signal": f"{failure_rate:.0%}",
            "fix": "Add error handling instructions"})
    if budget_overage_rate > 0.30:
        patterns.append({"id": "budget_blowout", "signal": f"{budget_overage_rate:.0%}",
            "fix": "Add budget awareness to prompt"})
    if duration_trend > 0.50:
        patterns.append({"id": "slow_execution", "signal": f"+{duration_trend:.0%}",
            "fix": "Reduce context loaded"})
    if token_efficiency < 0.05 and total_in > 0:
        patterns.append({"id": "sparse_output", "signal": f"{token_efficiency:.3f}",
            "fix": "Review output requirements"})
    if token_efficiency > 0.80:
        patterns.append({"id": "verbose_output", "signal": f"{token_efficiency:.2f}",
            "fix": "Add output length constraint"})

    score = (failure_rate*40)+(budget_overage_rate*30)+(max(0,duration_trend)*20)+(10 if patterns else 0)
    candidates.append({
        "agent": name, "total_traces": a["total"],
        "failure_rate": round(failure_rate, 3),
        "budget_overage_rate": round(budget_overage_rate, 3),
        "duration_trend": round(duration_trend, 3),
        "token_efficiency": round(token_efficiency, 3),
        "avg_duration_ms": round(sum(dur)/len(dur)) if dur else 0,
        "avg_tokens": round(total_in/a["total"]) if a["total"] else 0,
        "score": round(score, 1), "patterns": patterns
    })

candidates.sort(key=lambda x: -x["score"])
print(json.dumps({"candidates": candidates, "total_agents": len(agents),
    "analyzed": len(candidates), "min_traces": min_traces}, indent=2))
PYEOF
