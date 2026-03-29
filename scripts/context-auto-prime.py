#!/usr/bin/env python3
"""Context Auto-Priming — memory that loads itself (SPEC-039).

Scores memory entries by domain + keywords + recency + importance.
Returns pre-formatted context block. No LLM — pure arithmetic.

Usage:
    python3 context-auto-prime.py prime "query" [--store PATH] [--top K]
    python3 context-auto-prime.py benchmark [--store PATH]
"""
import argparse, json, math, os, re, time, importlib.util
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
SCRIPTS = ROOT / "scripts"
DEFAULT_STORE = os.environ.get("STORE_FILE", str(ROOT / "output/.memory-store.jsonl"))

def _load_domains():
    p = SCRIPTS / "memory-domains.py"
    if not p.exists(): return None
    try:
        spec = importlib.util.spec_from_file_location("md", str(p))
        m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
    except Exception: return None

def _days(ts):
    try: return (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace("Z","+00:00"))).days
    except Exception: return 999

def _recency(d): return 1.0 if d < 7 else 0.7 if d < 30 else 0.4 if d < 90 else 0.1

def _load_access():
    """Load access stats from tracker (feeds EXP-01 forgetting curve)."""
    log = str(ROOT / "output/.memory-access-log.jsonl")
    if not os.path.exists(log): return {}
    from collections import defaultdict
    s = defaultdict(lambda: {"count": 0, "last": None})
    with open(log) as f:
        for line in f:
            try:
                e = json.loads(line.strip()); tk = e.get("topic_key", "")
                s[tk]["count"] += 1; s[tk]["last"] = e.get("ts")
            except json.JSONDecodeError: continue
    return dict(s)

def _strength(tk, stats):
    """Ebbinghaus: strength = e^(-days/HL) * ln_boost. HL adapts with access."""
    info = stats.get(tk, {"count": 0, "last": None})
    if info["count"] == 0: return 0.5
    d = _days(info["last"]) if info["last"] else 999
    hl = 7.0 * (1 + math.log(1 + info["count"]))
    return min(1.0, math.exp(-d / hl) * (1 + 0.1 * math.log(1 + info["count"])))

def _jaccard(a, b): return len(a & b) / len(a | b) if a | b else 0.0

def _words(t): return set(re.findall(r'[a-z]{3,}', t.lower()))

def prime(query, store, top=5, max_tok=300):
    if not os.path.exists(store): return {"primed": [], "tokens": 0, "domain": None}
    dmod = _load_domains()
    qdom = set(dmod.top_domains(query)[:2]) if dmod else set()
    qw = _words(query)
    # Silent prime: trivial queries with <2 meaningful words
    if len(qw) < 2: return {"primed": [], "tokens": 0, "domain": None, "candidates": 0}
    entries = []
    with open(store) as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                if e.get("valid_to"): continue
                entries.append(e)
            except json.JSONDecodeError: continue
    access_stats = _load_access()
    scored = []
    for e in entries:
        ed = e.get("domain", "general")
        if not ed and dmod: ed = dmod.classify_entry(e)
        dm = 1.0 if ed in qdom else 0.3
        ks = _jaccard(qw, _words(f"{e.get('title','')} {e.get('content','')}"))
        rc = _recency(_days(e.get("ts", "")))
        # EXP-01: forgetting curve strength replaces static rev/max_rev
        stg = _strength(e.get("topic_key", ""), access_stats)
        sc = dm * 0.28 + ks * 0.32 + rc * 0.18 + stg * 0.22
        if sc > 0.35:
            scored.append({"title": e.get("title",""), "topic_key": e.get("topic_key",""),
                "type": e.get("type",""), "domain": ed, "ts": e.get("ts","")[:10],
                "rev": e.get("rev",1), "score": round(sc, 3),
                "tokens_est": e.get("tokens_est", len(e.get("title",""))//4)})
    scored.sort(key=lambda x: -x["score"])
    sel, tok = [], 0
    for item in scored[:top * 2]:
        est = item["tokens_est"] + 20
        if tok + est > max_tok: break
        sel.append(item); tok += est
        if len(sel) >= top: break
    return {"primed": sel, "tokens": tok, "domain": list(qdom)[:2] if qdom else None,
            "candidates": len(scored)}
def format_prime(r):
    if not r["primed"]: return ""
    d = f' from "{r["domain"][0]}"' if r.get("domain") else ""
    lines = [f'[Auto-primed: {len(r["primed"])} memories{d} ({r["tokens"]} tok)]']
    for m in r["primed"]:
        lines.append(f'- {m["title"]} ({m["ts"]}, rev:{m["rev"]}, score:{m["score"]})')
    return "\n".join(lines)
BM = [("How do we handle SQL injection?","security",True),
      ("What is our sprint velocity?","sprint",True),
      ("Show deployment pipeline","devops",True),
      ("Hello",None,False), ("ok",None,False),
      ("Architecture pattern we use?","architecture",True),
      ("How to onboard new developers?","team",True),
      ("Acceptance criteria rules?","product",True)]
def benchmark(store):
    results, primed, silent, dok, tok, ms_t = [], 0, 0, 0, 0, 0.0
    for q, exp, should in BM:
        t0 = time.time(); r = prime(q, store); ms = round((time.time()-t0)*1000, 1); ms_t += ms
        did = len(r["primed"]) > 0
        if did: primed += 1
        else: silent += 1
        d_ok = (exp in r.get("domain", []) if exp and r.get("domain") else not exp)
        if d_ok: dok += 1
        tok += r["tokens"]
        results.append({"query": q, "should": should, "did": did,
            "correct": did == should, "domain_ok": d_ok,
            "count": len(r["primed"]), "tokens": r["tokens"], "ms": ms})
    n = len(BM)
    return {"queries": results, "summary": {
        "total": n, "primed": primed, "silent": silent,
        "prime_accuracy": round(sum(1 for q in results if q["correct"])/n, 2),
        "domain_accuracy": round(dok/n, 2),
        "avg_tokens": round(tok/max(primed,1)),
        "avg_ms": round(ms_t/n, 1),
        "silence_rate": round(silent/n, 2)}}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Context Auto-Priming (SPEC-039)")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("prime"); s.add_argument("query")
    s.add_argument("--store", default=DEFAULT_STORE)
    s.add_argument("--top", type=int, default=5)
    s.add_argument("--max-tokens", type=int, default=300)
    b = sub.add_parser("benchmark"); b.add_argument("--store", default=DEFAULT_STORE)
    args = p.parse_args()
    if args.cmd == "prime":
        r = prime(args.query, args.store, args.top, args.max_tokens)
        out = format_prime(r)
        print(out if out else "(silent — no relevant memories)")
    elif args.cmd == "benchmark":
        print(json.dumps(benchmark(args.store), indent=2, ensure_ascii=False))
    else: p.print_help()
