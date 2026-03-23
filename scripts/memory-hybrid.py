#!/usr/bin/env python3
"""Hybrid memory search — combines vector similarity + graph traversal (SPEC-035).

Source of truth: JSONL files (.md-backed). Indices are derived caches.
Fallback chain: hybrid → vector → graph → grep (always works).

Usage:
    python3 memory-hybrid.py search "query" [--top K] [--store PATH] [--mode MODE]
    python3 memory-hybrid.py status [--store PATH]

Modes: hybrid (default), vector, graph, naive (grep)
"""
import argparse, json, os, sys, subprocess
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
SCRIPTS = ROOT / "scripts"
DEFAULT_STORE = os.environ.get(
    "STORE_FILE", str(ROOT / "output" / ".memory-store.jsonl")
)

def _run_vector(query: str, top: int, store: str) -> list[dict]:
    """Run vector search via memory-vector.py."""
    try:
        r = subprocess.run(
            ["python3", str(SCRIPTS / "memory-vector.py"), "search", query,
             "--top", str(top * 2), "--store", store],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode == 0 and r.stdout.strip():
            data = json.loads(r.stdout)
            if not data.get("fallback") and data.get("results"):
                return [{"source": "vector", **e} for e in data["results"]]
    except Exception:
        pass
    return []

def _run_graph(query: str, top: int, store: str) -> list[dict]:
    """Run graph search via memory-graph.py."""
    try:
        r = subprocess.run(
            ["python3", str(SCRIPTS / "memory-graph.py"), "search", query,
             "--store", store],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode == 0 and r.stdout.strip():
            results = []
            for line in r.stdout.strip().split("\n"):
                line = line.strip()
                if line.startswith("-") or line.startswith("["):
                    results.append({"source": "graph", "title": line.lstrip("- "),
                                    "score": 0.5, "topic_key": "", "type": "graph"})
            return results[:top * 2]
    except Exception:
        pass
    return []

def _run_grep(query: str, top: int, store: str) -> list[dict]:
    """Grep fallback — always works, no dependencies."""
    results = []
    if not os.path.exists(store):
        return results
    with open(store) as f:
        for line in f:
            if query.lower() in line.lower():
                try:
                    entry = json.loads(line.strip())
                    # SPEC-034: skip superseded by default
                    if entry.get("valid_to"):
                        continue
                    results.append({
                        "source": "grep", "title": entry.get("title", ""),
                        "score": 0.3, "topic_key": entry.get("topic_key", ""),
                        "type": entry.get("type", ""), "ts": entry.get("ts", ""),
                        "sector": entry.get("sector", "semantic"),
                    })
                except json.JSONDecodeError:
                    continue
    return results[-top:]

def _dedup_merge(vec: list, graph: list, grep: list, top: int) -> list[dict]:
    """Merge results from all sources, deduplicate by title, sort by score."""
    seen = {}
    for item in vec + graph + grep:
        key = item.get("title", "")[:80]
        if key in seen:
            # Boost score if found by multiple sources
            seen[key]["score"] = min(1.0, seen[key]["score"] + 0.15)
            seen[key]["sources"] = seen[key].get("sources", seen[key]["source"])
            seen[key]["sources"] += "+" + item["source"]
        else:
            seen[key] = item
    ranked = sorted(seen.values(), key=lambda x: x.get("score", 0), reverse=True)
    return ranked[:top]

def cmd_search(query: str, top: int, store: str, mode: str) -> None:
    vec, graph, grep = [], [], []

    if mode in ("hybrid", "vector"):
        vec = _run_vector(query, top, store)
    if mode in ("hybrid", "graph"):
        graph = _run_graph(query, top, store)
    if mode == "naive" or (mode == "hybrid" and not vec and not graph):
        grep = _run_grep(query, top, store)
    # In hybrid, always add grep as baseline for dedup boost
    if mode == "hybrid" and (vec or graph):
        grep = _run_grep(query, top, store)

    results = _dedup_merge(vec, graph, grep, top)

    if not results:
        print(json.dumps({"results": [], "mode": mode, "fallback": True}))
        return

    output = {"results": results, "mode": mode, "fallback": False,
              "sources": {"vector": len(vec), "graph": len(graph), "grep": len(grep)}}
    print(json.dumps(output, ensure_ascii=False))

def cmd_status(store: str) -> None:
    vec_idx = store.replace(".jsonl", "-index.idx")
    graph_idx = store.replace(".jsonl", "-graph.json")
    print(f"Store: {store} — {'exists' if os.path.exists(store) else 'MISSING'}")
    print(f"Vector index: {'available' if os.path.exists(vec_idx) else 'not built'}")
    print(f"Graph index: {'available' if os.path.exists(graph_idx) else 'not built'}")
    available = []
    if os.path.exists(vec_idx): available.append("vector")
    if os.path.exists(graph_idx): available.append("graph")
    available.append("grep")
    best = "hybrid" if len(available) >= 3 else available[0] if available else "naive"
    print(f"Best mode: {best} ({'+'.join(available)})")

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Hybrid memory search (SPEC-035)")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("search")
    s.add_argument("query")
    s.add_argument("--top", type=int, default=5)
    s.add_argument("--store", default=DEFAULT_STORE)
    s.add_argument("--mode", choices=["hybrid","vector","graph","naive"], default="hybrid")
    st = sub.add_parser("status")
    st.add_argument("--store", default=DEFAULT_STORE)
    args = p.parse_args()
    if args.cmd == "search":
        cmd_search(args.query, args.top, args.store, args.mode)
    elif args.cmd == "status":
        cmd_status(args.store)
    else:
        p.print_help()
