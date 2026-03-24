#!/usr/bin/env python3
"""Context Prefetch Cache — predict next context + track access (SPEC-040 EXP-02).
Markov model predicts next command. Pre-loads domain context. Tracks memory access.
Usage: python3 context-prefetch.py {predict|train|benchmark|access} [args]
"""
import argparse, json, os, time
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
TRANSITION_FILE = str(ROOT / "output/.prefetch-transitions.json")
ACCESS_LOG = str(ROOT / "output/.memory-access-log.jsonl")
DEFAULT_STORE = os.environ.get("STORE_FILE", str(ROOT / "output/.memory-store.jsonl"))

SEED = {  # from role-workflows.md
    "PM": ["sprint-status","team-workload","board-flow","risk-predict"],
    "PM_mon": ["sprint-plan","sprint-autoplan","risk-predict"],
    "PM_fri": ["report-hours","report-executive","sprint-review"],
    "PM_wed": ["pbi-plan-sprint","backlog-patterns","backlog-groom","backlog-prioritize"],
    "TL": ["tech-radar","pr-pending","spec-status","perf-audit"],
    "TL_w": ["arch-health","team-skills-matrix","diagram-generate"],
    "QA": ["qa-dashboard","pr-pending","security-alerts"],
    "Dev": ["my-sprint","my-focus"],
    "CEO": ["ceo-alerts","portfolio-overview","ceo-report"],
}
CMD_DOMAINS = {
    "sprint": "sprint", "team": "team", "board": "sprint", "risk": "sprint",
    "report": "sprint", "pbi": "product", "backlog": "product",
    "tech": "architecture", "pr": "quality", "spec": "architecture",
    "perf": "quality", "arch": "architecture", "diagram": "architecture",
    "qa": "quality", "security": "security", "my": "sprint",
    "ceo": "sprint", "portfolio": "sprint",
}

def _cmd_domain(cmd):
    return CMD_DOMAINS.get(cmd.split("-")[0] if "-" in cmd else cmd, "general")

def build_model(extra_log=None):
    trans = defaultdict(lambda: defaultdict(int))
    for seq in SEED.values():
        for i in range(len(seq) - 1):
            trans[seq[i]][seq[i+1]] += 1
    # Add observed transitions from log if exists
    if extra_log and os.path.exists(extra_log):
        prev = None
        with open(extra_log) as f:
            for line in f:
                try:
                    e = json.loads(line.strip())
                    cmd = e.get("command", "")
                    if prev and cmd: trans[prev][cmd] += 1
                    prev = cmd
                except json.JSONDecodeError: continue
    # Convert to probabilities
    model = {}
    for cmd, nxts in trans.items():
        total = sum(nxts.values())
        model[cmd] = {n: round(c/total, 2) for n, c in
                      sorted(nxts.items(), key=lambda x: -x[1])}
    return model

def predict(current, model=None):
    if not model: model = build_model()
    if current not in model:
        return {"predicted": [], "prefetch_domain": None}
    nxts = list(model[current].items())[:3]
    top_cmd = nxts[0][0] if nxts else None
    domain = _cmd_domain(top_cmd) if top_cmd else None
    return {
        "current": current,
        "predicted": [{"command": c, "probability": p, "domain": _cmd_domain(c)}
                      for c, p in nxts],
        "prefetch_domain": domain,
        "confidence": nxts[0][1] if nxts else 0,
    }

def save_model(model):
    os.makedirs(os.path.dirname(TRANSITION_FILE), exist_ok=True)
    with open(TRANSITION_FILE, "w") as f:
        json.dump(model, f, indent=2)

def log_access(topic_key, store=DEFAULT_STORE):
    os.makedirs(os.path.dirname(ACCESS_LOG), exist_ok=True)
    entry = {"ts": datetime.now(timezone.utc).isoformat(),
             "topic_key": topic_key, "store": os.path.basename(store)}
    with open(ACCESS_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")
    return entry

def get_access_stats(topic_key=None):
    stats = defaultdict(lambda: {"count": 0, "last": None})
    if not os.path.exists(ACCESS_LOG): return dict(stats)
    with open(ACCESS_LOG) as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                tk = e.get("topic_key", "")
                stats[tk]["count"] += 1
                stats[tk]["last"] = e.get("ts")
            except json.JSONDecodeError: continue
    if topic_key: return dict(stats).get(topic_key, {"count": 0, "last": None})
    return dict(stats)

def benchmark():
    model = build_model()
    tests, hits1, hits3 = 0, 0, 0
    for seq in SEED.values():
        for i in range(len(seq) - 1):
            p = predict(seq[i], model)
            preds = [x["command"] for x in p["predicted"]]
            if preds and preds[0] == seq[i+1]: hits1 += 1
            if seq[i+1] in preds[:3]: hits3 += 1
            tests += 1
    return {"tests": tests, "top1": round(hits1/max(tests,1), 2),
            "top3": round(hits3/max(tests,1), 2),
            "model_size": len(model),
            "cache_domains": len(set(_cmd_domain(c) for c in model))}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Context Prefetch Cache (SPEC-040)")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("predict"); s.add_argument("current")
    sub.add_parser("train").add_argument("--log", default=None)
    sub.add_parser("benchmark")
    a = sub.add_parser("access"); a.add_argument("topic_key")
    a.add_argument("--store", default=DEFAULT_STORE)
    args = p.parse_args()
    if args.cmd == "predict":
        print(json.dumps(predict(args.current), indent=2))
    elif args.cmd == "train":
        m = build_model(args.log); save_model(m)
        print(f"Model trained: {len(m)} commands, saved to {TRANSITION_FILE}")
    elif args.cmd == "benchmark":
        print(json.dumps(benchmark(), indent=2))
    elif args.cmd == "access":
        e = log_access(args.topic_key, args.store)
        print(f"Access logged: {e['topic_key']} at {e['ts']}")
    else: p.print_help()
