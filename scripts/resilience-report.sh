#!/usr/bin/env bash
# resilience-report.sh — SE-348: agent resilience metrics from AgentRunSummary telemetry
#
# Computes per-run / per-agent resilience signals from data/agent-actuals.jsonl:
#   error_rate, weighted_error (eta-weighted by signal reliability), max_consec_errors,
#   t_rec_s (recovery time after perturbation), recovered, variance_class.
#
# variance_class:
#   nominal       — completed, no error signals
#   exploratory   — completed with error signals (recovered / adaptive variation — NOT an incident)
#   dysfunctional — aborted|timeout|error finish with prior error signals — incident
#   external      — aborted|timeout|error finish without prior error signals (infra cut)
#   in_progress   — record still running
#
# Usage:
#   resilience-report.sh [summary|detail <run_id>] [--agent <name>] [--json]
#
# Exit codes: 0 always (informative); 2 = input error.
# Ref: docs/propuestas/SE-348-resiliencia-baseline-capas.md
# CRIT-001: computes locally, no cloud telemetry.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
DEFAULT_LOG="$WORKSPACE_DIR/data/agent-actuals.jsonl"
AGENT_ACTUALS_LOG="${AGENT_ACTUALS_LOG:-$DEFAULT_LOG}"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 0
}

MODE="summary"
JSON=false
AGENT_FILTER=""
RUN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    summary) MODE="summary"; shift ;;
    detail) MODE="detail"; RUN_ID="${2:?detail requires <run_id>}"; shift 2 ;;
    --json) JSON=true; shift ;;
    --agent) AGENT_FILTER="${2:?--agent requires a name}"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$AGENT_ACTUALS_LOG" ]]; then
  echo "(no agent-actuals log at $AGENT_ACTUALS_LOG)" >&2
  exit 0
fi

export SE348_MODE="$MODE"
export SE348_JSON="$JSON"
export SE348_AGENT="$AGENT_FILTER"
export SE348_RUN_ID="$RUN_ID"
export SE348_LOG="$AGENT_ACTUALS_LOG"

python3 <<'PY'
import json, os, sys, datetime

def parse_ts(ts):
    if not ts:
        return None
    try:
        dt = datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")
        return (dt - datetime.datetime(1970,1,1)).total_seconds()
    except (ValueError, TypeError):
        return None

def median(xs):
    if not xs:
        return None
    xs = sorted(xs)
    n = len(xs)
    mid = n // 2
    if n % 2 == 1:
        return xs[mid]
    return (xs[mid-1] + xs[mid]) / 2.0

def run_metrics(rec):
    events = rec.get("tool_events") or []
    run_status = rec.get("run_status", "running")
    base = {
        "run_id": rec.get("run_id"),
        "agent": rec.get("agent"),
        "run_status": run_status,
    }
    if not events:
        calls = sum((rec.get("tools_invoked") or {}).values())
        if run_status == "completed":
            vc = "nominal"
        elif run_status == "running":
            vc = "in_progress"
        else:
            vc = "external"
        base.update({
            "calls": calls,
            "error_rate": None,
            "weighted_error": None,
            "max_consec_errors": None,
            "t_rec_s": None,
            "recovered": False,
            "variance_class": vc,
        })
        return base

    calls = len(events)
    no_ok = [e for e in events if e.get("status") not in ("ok", "skipped")]
    error_rate = (len(no_ok) / calls) if calls else 0.0
    weighted = (sum(float(e.get("reliability", 0.0)) for e in no_ok) / calls) if calls else 0.0

    best = 0
    cur = 0
    for e in events:
        if e.get("status") in ("ok", "skipped"):
            cur = 0
        else:
            cur += 1
            best = max(best, cur)

    rec_times = []
    n = len(events)
    i = 0
    while i < n:
        if events[i].get("status") in ("ok", "skipped"):
            i += 1
            continue
        start_ts = events[i].get("ts")
        j = i + 1
        while j < n and events[j].get("status") not in ("ok", "skipped"):
            j += 1
        if j < n and events[j].get("status") == "ok":
            s = parse_ts(start_ts)
            e = parse_ts(events[j].get("ts"))
            if s is not None and e is not None:
                rec_times.append(e - s)
        i = j

    recovered = (run_status == "completed") and len(rec_times) > 0

    if run_status == "completed":
        variance_class = "nominal" if not no_ok else "exploratory"
    elif run_status == "running":
        variance_class = "in_progress"
    else:
        variance_class = "dysfunctional" if no_ok else "external"

    base.update({
        "calls": calls,
        "error_rate": round(error_rate, 4),
        "weighted_error": round(weighted, 4),
        "max_consec_errors": best,
        "t_rec_s": median(rec_times),
        "recovered": recovered,
        "variance_class": variance_class,
        "events": events,
    })
    return base

def fmt_num(v, nd=2):
    if v is None:
        return "—"
    return f"{v:.{nd}f}"

def main():
    mode = os.environ.get("SE348_MODE", "summary")
    as_json = os.environ.get("SE348_JSON") == "true"
    agent_filter = os.environ.get("SE348_AGENT", "")
    run_id_filter = os.environ.get("SE348_RUN_ID", "")
    log_path = os.environ.get("SE348_LOG", "")

    runs = []
    with open(log_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "run_id" not in rec or rec.get("schema_version") != "2":
                continue
            runs.append(run_metrics(rec))

    if agent_filter:
        runs = [r for r in runs if r.get("agent") == agent_filter]
    if mode == "detail":
        if not run_id_filter:
            print("Error: detail requires <run_id>", file=sys.stderr)
            sys.exit(2)
        runs = [r for r in runs if r.get("run_id") == run_id_filter]

    if mode == "detail":
        if not runs:
            print(f"(no run with run_id={run_id_filter})", file=sys.stderr)
            sys.exit(0)
        r = runs[0]
        if as_json:
            out = {k: v for k, v in r.items() if k != "events"}
            out["events"] = r.get("events", [])
            print(json.dumps(out, indent=2))
        else:
            print(f"run_id: {r['run_id']}")
            print(f"agent: {r['agent']}   status: {r['run_status']}   calls: {r['calls']}")
            print(f"error_rate: {fmt_num(r.get('error_rate'),3)}   weighted_error: {fmt_num(r.get('weighted_error'),3)}   max_consec_errors: {r.get('max_consec_errors')}")
            print(f"t_rec_s: {fmt_num(r.get('t_rec_s'),1)}   recovered: {r.get('recovered')}   variance_class: {r.get('variance_class')}")
            print("tool events:")
            for e in (r.get("events") or []):
                print(f"  {e.get('tool'):<10} {e.get('status'):<9} rel={e.get('reliability')} ts={e.get('ts')}")
        sys.exit(0)

    # summary mode
    if as_json:
        by_agent = {}
        for r in runs:
            a = r.get("agent") or "unknown"
            ag = by_agent.setdefault(a, {"runs": 0, "err_rates": [], "w_errs": [], "t_recs": [], "classes": {}})
            ag["runs"] += 1
            if r.get("error_rate") is not None:
                ag["err_rates"].append(r["error_rate"])
            if r.get("weighted_error") is not None:
                ag["w_errs"].append(r["weighted_error"])
            if r.get("t_rec_s") is not None:
                ag["t_recs"].append(r["t_rec_s"])
            vc = r.get("variance_class")
            if vc:
                ag["classes"][vc] = ag["classes"].get(vc, 0) + 1
        payload = {
            "runs": [{k: v for k, v in r.items() if k != "events"} for r in runs],
            "by_agent": {
                a: {
                    "runs": g["runs"],
                    "error_rate_avg": round(sum(g["err_rates"])/len(g["err_rates"]),4) if g["err_rates"] else None,
                    "weighted_error_avg": round(sum(g["w_errs"])/len(g["w_errs"]),4) if g["w_errs"] else None,
                    "t_rec_s_median": median(g["t_recs"]),
                    "variance_classes": g["classes"],
                }
                for a, g in by_agent.items()
            },
        }
        print(json.dumps(payload, indent=2))
        sys.exit(0)

    # plain text summary table
    print(f"{'agent':<24}{'runs':>5}{'calls':>7}{'err_rate':>9}{'w_err':>7}{'max_cons':>9}{'t_rec_s':>9}  class")
    by_agent = {}
    for r in runs:
        a = r.get("agent") or "unknown"
        by_agent.setdefault(a, []).append(r)
    for a in sorted(by_agent):
        rs = by_agent[a]
        total_calls = sum(r["calls"] for r in rs if r.get("calls"))
        errs = [r["error_rate"] for r in rs if r.get("error_rate") is not None]
        w_errs = [r["weighted_error"] for r in rs if r.get("weighted_error") is not None]
        t_recs = [r["t_rec_s"] for r in rs if r.get("t_rec_s") is not None]
        from collections import Counter
        classes = Counter(r.get("variance_class") for r in rs if r.get("variance_class"))
        dominant = classes.most_common(1)[0][0] if classes else "—"
        print(f"{a:<24}{len(rs):>5}{total_calls:>7}"
              f"{fmt_num(round(sum(errs)/len(errs),4) if errs else None,3):>9}"
              f"{fmt_num(round(sum(w_errs)/len(w_errs),4) if w_errs else None,3):>7}"
              f"{max((r['max_consec_errors'] or 0) for r in rs):>9}"
              f"{fmt_num(median(t_recs),1):>9}  {dominant}")
    if not by_agent:
        print("(no runs)")

if __name__ == "__main__":
    main()
PY
