#!/usr/bin/env python3
"""E2E Context Pipeline Benchmark — proves each layer adds value.
5 levels: none → grep → domain → prime → brain. Measures precision, noise, tokens, ms.
Usage: python3 benchmark-context-pipeline.py [--store PATH]
"""
import json, os, re, time, importlib.util
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
SCRIPTS = ROOT / "scripts"
DEFAULT_STORE = str(ROOT / "tests/evals/memory-benchmark-store.jsonl")

def _mod(name):
    p = SCRIPTS / f"{name}.py"
    if not p.exists(): return None
    try:
        s = importlib.util.spec_from_file_location(name, str(p))
        m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
    except Exception: return None

def _words(t): return set(re.findall(r'[a-z]{3,}', t.lower()))

# Queries with expected relevant memories (ground truth)
QUERIES = [
    {"query": "How do we handle SQL injection?",
     "relevant": ["SQL parameterized queries mandatory", "OWASP Top 10"],
     "irrelevant": ["Sprint velocity", "Team onboarding", "Deploy pipeline"],
     "domain": "security"},
    {"query": "What is our sprint velocity?",
     "relevant": ["Sprint velocity baseline 40 SP", "Sprint planning underestimation"],
     "irrelevant": ["SQL parameterized", "Repository pattern", "Deploy pipeline"],
     "domain": "sprint"},
    {"query": "How do we deploy to production?",
     "relevant": ["Deploy pipeline blue-green strategy", "Terraform modules"],
     "irrelevant": ["Sprint velocity", "SQL parameterized", "PBI acceptance"],
     "domain": "devops"},
    {"query": "What architecture patterns do we use?",
     "relevant": ["Repository pattern", "Microservice boundary", "ADR required"],
     "irrelevant": ["Sprint velocity", "Team onboarding", "Deploy pipeline"],
     "domain": "architecture"},
]

def _load_all(store):
    entries = []
    if not os.path.exists(store): return entries
    with open(store) as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                if not e.get("valid_to"): entries.append(e)
            except json.JSONDecodeError: continue
    return entries

def _score_results(results, q):
    """Score context quality: precision (relevant/total) and noise (irrelevant/total)."""
    titles = [r.get("title", "") for r in results]
    relevant_found = sum(1 for t in titles if any(r in t for r in q["relevant"]))
    irrelevant_found = sum(1 for t in titles if any(r in t for r in q["irrelevant"]))
    total = len(titles) if titles else 1
    return {
        "precision": round(relevant_found / total, 2) if total else 0,
        "noise": round(irrelevant_found / total, 2) if total else 0,
        "relevant": relevant_found, "irrelevant": irrelevant_found, "total": len(titles)
    }

# ── Levels ───────────────────────────────────────────────────────────────
def level0(q, store): return {"results": [], "tokens": 0, "ms": 0}

def level1(q, store):
    t0 = time.time(); entries = _load_all(store)
    ql = q["query"].lower(); results = []
    for e in entries:
        text = f"{e.get('title','')} {e.get('content','')}".lower()
        if any(w in text for w in ql.split() if len(w) > 3):
            results.append(e)
    ms = round((time.time()-t0)*1000, 1)
    return {"results": results[:10], "tokens": sum(e.get("tokens_est",10) for e in results[:10]), "ms": ms}

def level2(q, store):
    dm = _mod("memory-domains")
    if not dm: return level1(q, store)
    t0 = time.time()
    r = dm.domain_search(q["query"], 10, store)
    ms = round((time.time()-t0)*1000, 1)
    return {"results": r.get("results", []), "tokens": sum(x.get("tokens_est",10) for x in r.get("results",[])), "ms": ms}

def level3(q, store):
    pm = _mod("context-auto-prime")
    if not pm: return level2(q, store)
    t0 = time.time()
    r = pm.prime(q["query"], store, top=10, max_tok=9999)
    ms = round((time.time()-t0)*1000, 1)
    return {"results": r.get("primed", []), "tokens": r.get("tokens", 0), "ms": ms}

def level4(q, store):
    br = _mod("context-reasoning")
    if not br: return level3(q, store)
    t0 = time.time()
    r = br.reason(q["query"], store, budget=10)
    ms = round((time.time()-t0)*1000, 1)
    return {"results": r.get("context", []), "tokens": sum(c.get("tokens_est",10) for c in r.get("context",[])), "ms": ms}

LEVELS = [
    ("L0: No context", level0),
    ("L1: Grep only", level1),
    ("L2: + Domain routing", level2),
    ("L3: + Auto-prime", level3),
    ("L4: + Brain reasoning", level4),
]

def run(store):
    results = {"levels": {}, "queries": [], "improvement_table": []}
    for lname, lfn in LEVELS:
        level_scores = {"precision": [], "noise": [], "tokens": [], "ms": []}
        for q in QUERIES:
            r = lfn(q, store)
            sc = _score_results(r["results"], q)
            level_scores["precision"].append(sc["precision"])
            level_scores["noise"].append(sc["noise"])
            level_scores["tokens"].append(r["tokens"])
            level_scores["ms"].append(r["ms"])
        avg = lambda lst: round(sum(lst)/max(len(lst),1), 2)
        results["levels"][lname] = {
            "avg_precision": avg(level_scores["precision"]),
            "avg_noise": avg(level_scores["noise"]),
            "avg_tokens": avg(level_scores["tokens"]),
            "avg_ms": avg(level_scores["ms"]),
        }
    # Improvement table
    prev_prec = 0
    for lname, _ in LEVELS:
        d = results["levels"][lname]
        delta = round(d["avg_precision"] - prev_prec, 2) if prev_prec else 0
        results["improvement_table"].append({
            "level": lname, "precision": d["avg_precision"],
            "noise": d["avg_noise"], "tokens": d["avg_tokens"],
            "ms": d["avg_ms"], "delta_precision": f"+{delta}" if delta>0 else str(delta)})
        prev_prec = d["avg_precision"]
    return results

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(); p.add_argument("--store", default=DEFAULT_STORE)
    r = run(p.parse_args().store)
    print(json.dumps(r, indent=2))
    print(f"\n{'Level':<25} {'Prec':>6} {'Noise':>6} {'Tok':>5} {'ms':>5} {'Delta':>7}")
    print("-" * 58)
    for row in r["improvement_table"]:
        print(f"{row['level']:<25} {row['precision']:>6} {row['noise']:>6} "
              f"{row['tokens']:>5} {row['ms']:>5} {row['delta_precision']:>7}")
