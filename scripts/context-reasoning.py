#!/usr/bin/env python3
"""Brain-Inspired Context Reasoning Engine — SPEC-041.
Pre-LLM: decides WHAT context the LLM sees. 4 mechanisms:
Working Memory Gate, Contradiction Detection, Priority Tagging, Attention Focus.
Usage: python3 context-reasoning.py {reason|benchmark} [args]
"""
import argparse, json, os, re, importlib.util
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
SCRIPTS = ROOT / "scripts"
DEFAULT_STORE = os.environ.get("STORE_FILE", str(ROOT / "output/.memory-store.jsonl"))

def _mod(name):
    p = SCRIPTS / f"{name}.py"
    if not p.exists(): return None
    try:
        s = importlib.util.spec_from_file_location(name, str(p))
        m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
    except Exception: return None

def _words(t): return set(re.findall(r'[a-z]{3,}', t.lower()))

# Mechanism 1: Working Memory Gate (Prefrontal Cortex) — MUST/USEFUL/NOISE
def _relevance(qw, entry):
    ew = _words(f"{entry.get('title','')} {entry.get('content','')}")
    r = len(qw & ew) / max(len(qw), 1)
    if r >= 0.4: return "MUST", 1.0
    if r >= 0.15: return "USEFUL", 0.5
    return "NOISE", 0.0

# Mechanism 2: Contradiction Detection (Hippocampus)
def _contradictions(entries):
    by_base, conflicts = {}, []
    for e in entries:
        tk = e.get("topic_key", "")
        base = tk.rsplit("/", 1)[0] if "/" in tk else tk
        if not base: continue
        if base in by_base and by_base[base].get("rev", 1) != e.get("rev", 1):
            conflicts.append({"topic": base, "old": by_base[base]["title"], "new": e["title"]})
        by_base[base] = e
    return conflicts

# Mechanism 3: Priority Tagging (Amygdala) — critical memories always surface
PRI_TYPES = {"bug", "correction", "feedback"}
PRI_KW = {"nunca", "siempre", "critico", "critical", "blocker", "obligatorio"}

def _priority(e):
    if e.get("type", "") in PRI_TYPES: return 1.0
    if e.get("rev", 1) >= 3: return 0.8
    if any(k in f"{e.get('title','')} {e.get('content','')}".lower() for k in PRI_KW): return 0.9
    return 0.3

# Mechanism 4: Attention Focus (Parietal Cortex) — zoom level by task type
def _zoom(query):
    ql = query.lower()
    if re.search(r'^(como|how|que es|what|por que|why|donde|where)\b', ql): return "narrow", 3
    if re.search(r'(status|resumen|overview|todo|list|sprint|todas)', ql): return "wide", 7
    return "medium", 5

def reason(query, store, budget=5):
    if not os.path.exists(store): return {"context": [], "reasoning": "no store"}
    pm = _mod("context-auto-prime")
    if pm:
        raw = pm.prime(query, store, top=budget*3, max_tok=9999)
        cands = raw.get("primed", [])
    else:
        cands = []
        with open(store) as f:
            for line in f:
                try:
                    e = json.loads(line.strip())
                    if not e.get("valid_to"):
                        cands.append({"title": e.get("title",""), "topic_key": e.get("topic_key",""),
                            "type": e.get("type",""), "content": e.get("content",""),
                            "rev": e.get("rev",1), "ts": e.get("ts","")[:10]})
                except json.JSONDecodeError: continue
    qw, (zt, mx) = _words(query), _zoom(query)
    scored = []
    for i, c in enumerate(cands):
        rl, rs = _relevance(qw, c)
        pri = _priority(c)
        att = 1.0 if i < mx else 0.3
        gate = rs*0.35 + 1.0*0.20 + pri*0.25 + att*0.20
        scored.append({**c, "gate": round(gate, 3), "rel": rl, "pri": round(pri, 2), "zoom": zt})
    conf = _contradictions(scored)
    old_titles = {c["old"] for c in conf}
    filtered = sorted([s for s in scored if s["gate"] > 0.50 and s["title"] not in old_titles],
                      key=lambda x: -x["gate"])[:mx]
    noise = sum(1 for s in scored if s["rel"] == "NOISE")
    return {"context": filtered, "reasoning": {
        "query": query, "zoom": zt, "max": mx, "candidates": len(cands),
        "selected": len(filtered), "contradictions": conf, "noise": noise}}

def fmt(result):
    r = result["reasoning"]
    lines = [f'[Brain Reasoning: {r["selected"]}/{r["candidates"]}, '
             f'zoom={r["zoom"]}, {r["noise"]} noise filtered]']
    for c in result["context"]:
        tag = "!" if c["pri"] >= 0.8 else " "
        lines.append(f' {tag} {c["title"]} (gate:{c["gate"]}, {c["rel"]})')
    for cf in r.get("contradictions", []):
        lines.append(f' ~ "{cf["old"]}" superseded by "{cf["new"]}"')
    return "\n".join(lines)

BM = [("How do we handle SQL injection?", "narrow", True),
      ("sprint status overview", "wide", True),
      ("What architecture pattern?", "narrow", True),
      ("ok", "narrow", False), ("hello", "narrow", False),
      ("all decisions this sprint", "wide", True)]

def benchmark(store):
    res, ok = [], 0
    for q, ez, should in BM:
        r = reason(q, store)
        has = len(r["context"]) > 0; correct = has == should
        if correct: ok += 1
        res.append({"query": q, "zoom": r["reasoning"]["zoom"], "zoom_ok": r["reasoning"]["zoom"]==ez,
            "ctx": len(r["context"]), "noise": r["reasoning"]["noise"], "correct": correct})
    return {"queries": res, "accuracy": round(ok/len(BM), 2)}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Brain Context Reasoning (SPEC-041)")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("reason"); s.add_argument("query")
    s.add_argument("--store", default=DEFAULT_STORE); s.add_argument("--budget", type=int, default=5)
    b = sub.add_parser("benchmark"); b.add_argument("--store", default=DEFAULT_STORE)
    args = p.parse_args()
    if args.cmd == "reason": print(fmt(reason(args.query, args.store, args.budget)))
    elif args.cmd == "benchmark": print(json.dumps(benchmark(args.store), indent=2))
    else: p.print_help()
