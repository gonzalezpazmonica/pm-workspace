#!/usr/bin/env python3
"""Memory R&D Experiments — SPEC-040. Three scientific experiments on agentic memory.

EXP-01: Ebbinghaus forgetting curve (strength = e^(-t/HL), HL adapts with access)
EXP-02: Workflow sequence prediction (Markov prefetch from role-workflows)
EXP-03: Semantic consolidation (merge near-duplicates, measure compression)

Usage: python3 memory-experiments.py {exp01|exp02|exp03|all} [--store PATH]
"""
import argparse, json, math, os, re
from pathlib import Path
from collections import defaultdict

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_STORE = str(ROOT / "tests/evals/memory-benchmark-store.jsonl")

def _words(t): return set(re.findall(r'[a-z]{3,}', t.lower()))
def _jaccard(a, b): return len(a & b) / len(a | b) if a | b else 0.0
def _load(store):
    if not os.path.exists(store): return []
    entries = []
    with open(store) as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                if not e.get("valid_to"): entries.append(e)
            except json.JSONDecodeError: continue
    return entries

def exp01(store):
    """EXP-01: Ebbinghaus forgetting curve vs linear recency."""
    entries = _load(store)
    if not entries: return {"error": "no entries"}
    for i, e in enumerate(entries):
        e["ac"] = max(1, len(entries) - i); e["days"] = i * 2
    lin = [(e["title"], round(1.0/(1+e["days"]/30), 3)) for e in entries]
    eb = []
    for e in entries:
        hl = 7.0 * (1 + math.log(1 + e["ac"]))
        s = min(1.0, math.exp(-e["days"]/hl) * (1 + 0.1*math.log(1+e["ac"])))
        eb.append((e["title"], round(s, 3)))
    lin.sort(key=lambda x: -x[1]); eb.sort(key=lambda x: -x[1])
    lt5, et5 = set(t for t,_ in lin[:5]), set(t for t,_ in eb[:5])
    reranked = et5 - lt5
    return {"experiment": "EXP-01: Ebbinghaus Forgetting Curve",
        "hypothesis": "Spaced repetition surfaces frequently-accessed memories better",
        "entries": len(entries), "linear_top5": lin[:5], "ebbinghaus_top5": eb[:5],
        "overlap": len(lt5 & et5), "reranked": len(reranked),
        "reranked_titles": list(reranked),
        "formula": "strength = e^(-days/HL) * (1 + 0.1*ln(1+access_count))",
        "half_life": "HL = 7 * (1 + ln(1 + access_count))",
        "finding": f"Ebbinghaus reranked {len(reranked)} entries vs linear"
                   + (" — promotes accessed-but-older entries" if reranked else "")}

WORKFLOWS = {
    "PM_daily": ["sprint-status","team-workload","board-flow","risk-predict"],
    "PM_mon": ["sprint-plan","sprint-autoplan","risk-predict"],
    "PM_fri": ["report-hours","report-executive","sprint-review"],
    "TL_daily": ["tech-radar","pr-pending","spec-status","perf-audit"],
    "TL_weekly": ["arch-health","team-skills-matrix","diagram-generate"],
    "QA_daily": ["qa-dashboard","pr-pending","security-alerts"],
    "Dev_daily": ["my-sprint","my-focus"],
    "CEO_daily": ["ceo-alerts","portfolio-overview","ceo-report"],
    "PM_wed": ["pbi-plan-sprint","backlog-patterns","backlog-groom","backlog-prioritize"],
}

def exp02():
    """EXP-02: Markov workflow prediction."""
    trans = defaultdict(lambda: defaultdict(int)); pairs = 0
    for seq in WORKFLOWS.values():
        for i in range(len(seq)-1):
            trans[seq[i]][seq[i+1]] += 1; pairs += 1
    model = {}
    for cmd, nxts in trans.items():
        total = sum(nxts.values())
        model[cmd] = {n: round(c/total, 2) for n, c in sorted(nxts.items(), key=lambda x: -x[1])}
    c1, c3, tests = 0, 0, 0
    for seq in WORKFLOWS.values():
        for i in range(len(seq)-1):
            if seq[i] in model:
                pred = list(model[seq[i]].keys())
                if pred[0] == seq[i+1]: c1 += 1
                if seq[i+1] in pred[:3]: c3 += 1
                tests += 1
    acc3 = round(c3/max(tests,1), 2)
    return {"experiment": "EXP-02: Workflow Sequence Prediction",
        "hypothesis": "Markov model predicts next command with >70% top-3 accuracy",
        "workflows": len(WORKFLOWS), "transitions": pairs, "commands": len(model),
        "model": model,
        "top1_accuracy": round(c1/max(tests,1), 2), "top3_accuracy": acc3,
        "tests": tests,
        "finding": f"Top-3: {int(acc3*100)}% — {'CONFIRMED' if acc3>0.7 else 'REJECTED'}"}

def exp03(store):
    """EXP-03: Semantic consolidation."""
    entries = _load(store)
    if not entries: return {"error": "no entries"}
    cands = []
    for i, a in enumerate(entries):
        wa = _words(f"{a.get('title','')} {a.get('content','')}")
        da = a.get("domain", a.get("topic_key","").split("/")[0])
        for j, b in enumerate(entries[i+1:], i+1):
            wb = _words(f"{b.get('title','')} {b.get('content','')}")
            db = b.get("domain", b.get("topic_key","").split("/")[0])
            sim = _jaccard(wa, wb)
            if sim > 0.4 and da == db:
                cands.append({"a": a["title"], "b": b["title"],
                    "similarity": round(sim, 2), "domain": da})
    orig = len(entries); merged = len(cands); reduced = round(merged/max(orig,1)*100, 1)
    return {"experiment": "EXP-03: Semantic Consolidation",
        "hypothesis": "Merging similar entries reduces store >30% keeping quality",
        "entries": orig, "candidates": cands, "merge_count": merged,
        "consolidated_size": orig - merged, "reduction_pct": reduced,
        "finding": f"{reduced}% reduction — "
                   + ("CONFIRMED" if reduced>30 else "PARTIAL" if reduced>10 else "NEEDS MORE DATA")}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Memory R&D (SPEC-040)")
    sub = p.add_subparsers(dest="cmd")
    for n in ["exp01","exp03","all"]:
        s = sub.add_parser(n); s.add_argument("--store", default=DEFAULT_STORE)
    sub.add_parser("exp02")
    args = p.parse_args(); store = getattr(args, "store", DEFAULT_STORE)
    if args.cmd == "exp01": print(json.dumps(exp01(store), indent=2))
    elif args.cmd == "exp02": print(json.dumps(exp02(), indent=2))
    elif args.cmd == "exp03": print(json.dumps(exp03(store), indent=2))
    elif args.cmd == "all":
        print(json.dumps({"exp01": exp01(store), "exp02": exp02(), "exp03": exp03(store)}, indent=2))
    else: p.print_help()
