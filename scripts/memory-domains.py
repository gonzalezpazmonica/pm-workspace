#!/usr/bin/env python3
"""Knowledge Domain Routing — classifier + index + search (SPEC-038).

Classifies queries into 8 knowledge domains, routes searches to subsets.
Like human teams: don't ask security about sprint planning.

Usage:
    python3 memory-domains.py classify "SQL injection in auth"
    python3 memory-domains.py rebuild [--store PATH]
    python3 memory-domains.py search "query" [--top K] [--store PATH]
    python3 memory-domains.py benchmark [--store PATH]
"""
import argparse, json, os, re, time
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_STORE = os.environ.get("STORE_FILE", str(ROOT / "output/.memory-store.jsonl"))

DOMAINS = {
    "security":     {"kw": r"vuln|cve|owasp|inject|xss|csrf|auth|token|secret|password|encrypt|penetrat|exploit|attack|rbac",
                     "pfx": ["security/"], "tags": ["security", "vulnerability", "auth"]},
    "architecture": {"kw": r"pattern|layer|ddd|solid|coupling|microservice|monolith|cqrs|hexagonal|repository|aggregate",
                     "pfx": ["architecture/", "adr/"], "tags": ["architecture", "design", "pattern"]},
    "sprint":       {"kw": r"sprint|velocity|burndown|capacity|daily|retro|planning|standup|scrum|kanban|wip|blocker|ceremony",
                     "pfx": ["sprint/", "decision/"], "tags": ["sprint", "agile", "planning"]},
    "quality":      {"kw": r"test|coverage|lint|review|regression|bug|defect|mock|fixture|flaky|sonar|code.?smell",
                     "pfx": ["quality/", "bug/"], "tags": ["testing", "quality", "coverage"]},
    "devops":       {"kw": r"deploy|infra|terraform|docker|kubernetes|pipeline|azure.?devops|github.?action|monitoring|sre",
                     "pfx": ["devops/", "infra/"], "tags": ["devops", "infrastructure", "deployment"]},
    "team":         {"kw": r"assign|onboard|skill|competenc|evaluat|mentor|pair|feedback|wellbeing|burnout|workload",
                     "pfx": ["team/"], "tags": ["team", "onboarding", "skills"]},
    "product":      {"kw": r"pbi|story|epic|discovery|jtbd|prd|stakeholder|requirement|acceptance|feature|roadmap|okr",
                     "pfx": ["product/", "feature/"], "tags": ["product", "discovery", "requirements"]},
    "memory":       {"kw": r"context|compact|search|vector|graph|memory|index|cache|embedding|recall",
                     "pfx": ["config/", "memory/"], "tags": ["memory", "context", "search"]},
}

def classify_text(text):
    low = text.lower()
    return {d: round(min(1.0, len(re.findall(s["kw"], low)) * 0.25), 2) for d, s in DOMAINS.items()}

def classify_entry(entry):
    topic = entry.get("topic_key", "")
    for d, s in DOMAINS.items():
        if any(topic.startswith(p) for p in s["pfx"]): return d
    concepts = entry.get("concepts", [])
    if isinstance(concepts, str): concepts = [c.strip() for c in concepts.split(",")]
    for d, s in DOMAINS.items():
        if any(c in s["tags"] for c in concepts): return d
    scores = classify_text(f"{entry.get('title','')} {entry.get('content','')}")
    best = max(scores, key=scores.get)
    return best if scores.get(best, 0) >= 0.25 else "general"

def top_domains(text, threshold=0.25):
    scores = classify_text(text)
    return [d for d, _ in sorted(((d, s) for d, s in scores.items() if s >= threshold), key=lambda x: -x[1])]

def rebuild_index(store):
    index = {d: [] for d in DOMAINS}; index["general"] = []
    if not os.path.exists(store): return index
    with open(store) as f:
        for line in f:
            try: e = json.loads(line.strip())
            except json.JSONDecodeError: continue
            if e.get("valid_to"): continue
            d, t = classify_entry(e), e.get("topic_key", "")
            if t and t not in index.get(d, []): index.setdefault(d, []).append(t)
    with open(store.replace(".jsonl", "-domain-index.json"), "w") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
    return index

def load_index(store):
    p = store.replace(".jsonl", "-domain-index.json")
    return json.load(open(p)) if os.path.exists(p) else None

def _grep(query, store, domain_filter=None):
    results = []
    if not os.path.exists(store): return results
    ql = query.lower()
    with open(store) as f:
        for line in f:
            try: e = json.loads(line.strip())
            except json.JSONDecodeError: continue
            if e.get("valid_to"): continue
            if domain_filter and classify_entry(e) not in domain_filter: continue
            text = f"{e.get('title','')} {e.get('content','')}"
            if ql not in text.lower(): continue
            sc = 0.5 + (0.3 if ql in e.get("title","").lower() else 0) + (0.2 if ql in (e.get("topic_key") or "").lower() else 0)
            results.append({"title": e.get("title",""), "topic_key": e.get("topic_key",""),
                            "type": e.get("type",""), "domain": classify_entry(e), "score": round(sc, 2), "ts": e.get("ts","")})
    results.sort(key=lambda x: -x["score"]); return results

def domain_search(query, top, store):
    t0 = time.time(); domains = top_domains(query) or list(DOMAINS.keys())
    load_index(store) or rebuild_index(store)
    results = _grep(query, store, domain_filter=set(domains[:2]))
    return {"results": results[:top], "domains_queried": domains[:2], "ms": round((time.time()-t0)*1000, 1)}

def full_search(query, top, store):
    t0 = time.time(); results = _grep(query, store)
    return {"results": results[:top], "ms": round((time.time()-t0)*1000, 1)}

BM_QUERIES = [("SQL injection vulnerability","security"),("sprint velocity trending down","sprint"),
    ("microservice coupling analysis","architecture"),("test coverage below threshold","quality"),
    ("deploy pipeline failing","devops"),("team onboarding new developer","team"),
    ("PBI acceptance criteria missing","product"),("context window optimization","memory")]

def run_benchmark(store):
    rebuild_index(store); qs, d_ms, f_ms, ok = [], 0.0, 0.0, 0
    for q, exp in BM_QUERIES:
        ds = top_domains(q); correct = exp in ds[:2] if ds else False
        if correct: ok += 1
        dr, fs = domain_search(q, 5, store), full_search(q, 5, store)
        d_ms += dr["ms"]; f_ms += fs["ms"]
        qs.append({"query": q, "expected": exp, "classified": ds[:2], "correct": correct,
                   "domain_ms": dr["ms"], "full_ms": fs["ms"],
                   "domain_results": len(dr["results"]), "full_results": len(fs["results"])})
    n = len(BM_QUERIES)
    return {"queries": qs, "summary": {"total_queries": n, "domain_accuracy": round(ok/n, 2),
            "avg_domain_ms": round(d_ms/n, 1), "avg_full_ms": round(f_ms/n, 1),
            "speedup": round(f_ms/d_ms, 1) if d_ms > 0 else 0}}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Knowledge Domain Routing (SPEC-038)")
    sub = p.add_subparsers(dest="cmd")
    c = sub.add_parser("classify"); c.add_argument("text")
    r = sub.add_parser("rebuild"); r.add_argument("--store", default=DEFAULT_STORE)
    s = sub.add_parser("search"); s.add_argument("query"); s.add_argument("--top", type=int, default=5); s.add_argument("--store", default=DEFAULT_STORE)
    b = sub.add_parser("benchmark"); b.add_argument("--store", default=DEFAULT_STORE)
    args = p.parse_args()
    if args.cmd == "classify":
        top = top_domains(args.text); print(f"Domains: {top if top else ['general']}")
        for d, s in sorted(classify_text(args.text).items(), key=lambda x: -x[1]):
            if s > 0: print(f"  {d}: {s}")
    elif args.cmd == "rebuild":
        idx = rebuild_index(args.store); total = sum(len(v) for v in idx.values())
        print(f"Index rebuilt: {total} topics across {len(idx)} domains")
        for d, ts in sorted(idx.items(), key=lambda x: -len(x[1])):
            if ts: print(f"  {d}: {len(ts)} topics")
    elif args.cmd == "search": print(json.dumps(domain_search(args.query, args.top, args.store), indent=2, ensure_ascii=False))
    elif args.cmd == "benchmark": print(json.dumps(run_benchmark(args.store), indent=2, ensure_ascii=False))
    else: p.print_help()
