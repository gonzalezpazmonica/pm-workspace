#!/usr/bin/env python3
"""SPEC-018 Vector Quality Benchmark — validates semantic search improvement.

Run: python3 tests/test-vector-quality.py

Requires: pip install sentence-transformers hnswlib
If deps not installed, test is skipped (not failed).

Success criteria: vector Recall@5 > grep Recall@5 by at least 20pp.
"""
import json
import os
import shutil
import sys
import tempfile

# Skip gracefully if deps not installed
try:
    import hnswlib
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("SKIP: sentence-transformers or hnswlib not installed")
    print("Install with: pip install sentence-transformers hnswlib")
    sys.exit(0)

SCRIPT_DIR = os.path.join(os.path.dirname(__file__), "..", "scripts")
sys.path.insert(0, SCRIPT_DIR)

# Import the vector module directly
import importlib.util
spec = importlib.util.spec_from_file_location("memory_vector", os.path.join(SCRIPT_DIR, "memory-vector.py"))
mv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mv)

# --- Test corpus: 20 entries with semantic variety ---
CORPUS = [
    {"type": "bug", "title": "Token refresh timeout", "content": "Login fails after session expiry due to token cache not initialized on cold start"},
    {"type": "decision", "title": "PostgreSQL for relational data", "content": "Chose PostgreSQL over MySQL for better JSON support and extensions"},
    {"type": "bug", "title": "N+1 query in OrderService", "content": "LoadOrderItems iterates with lazy loading causing 200ms latency"},
    {"type": "pattern", "title": "Sprint velocity dropped 12%", "content": "Team capacity reduced by 2 blocked items and 3 underestimated PBIs"},
    {"type": "bug", "title": "Pipeline timeout on staging", "content": "Deploy failed because integration tests exceeded 10 min limit"},
    {"type": "decision", "title": "GraphQL for frontend", "content": "REST too granular for dashboard queries, GraphQL reduces round trips"},
    {"type": "discovery", "title": "Redis connection pool exhausted", "content": "Default pool size 10 too small for 50 concurrent requests"},
    {"type": "pattern", "title": "Retry with exponential backoff", "content": "External API calls need jitter to avoid thundering herd"},
    {"type": "decision", "title": "Kubernetes for orchestration", "content": "Docker Compose insufficient for multi-region HA deployment"},
    {"type": "bug", "title": "Memory leak in background worker", "content": "Event handlers not unsubscribed causing GC pressure"},
    {"type": "convention", "title": "Async all the way", "content": "Never use Task.Result or .Wait in async context to avoid deadlocks"},
    {"type": "discovery", "title": "CORS misconfigured on API", "content": "Wildcard origin allowed, should be restricted to app domain"},
    {"type": "pattern", "title": "Feature flags for rollout", "content": "LaunchDarkly for gradual rollout, kill switch on incidents"},
    {"type": "decision", "title": "Terraform for IaC", "content": "ARM templates too verbose, Terraform declarative and multi-cloud"},
    {"type": "bug", "title": "Timezone mismatch in reports", "content": "Server UTC but client local, dates off by hours in dashboard"},
    {"type": "convention", "title": "Conventional commits", "content": "feat/fix/docs/chore prefix for automated changelog generation"},
    {"type": "discovery", "title": "Sentry alert fatigue", "content": "Too many low-severity alerts, team ignoring real issues"},
    {"type": "decision", "title": "Monorepo with Nx", "content": "Separate repos caused version drift, Nx enforces consistency"},
    {"type": "pattern", "title": "Circuit breaker on external calls", "content": "Polly circuit breaker prevents cascade failures on downstream outage"},
    {"type": "bug", "title": "CSS z-index conflict in modal", "content": "Dropdown menu renders behind modal overlay, needs z-index 1050"},
]

# Queries with ground truth — semantic intent that keywords miss
QUERIES = [
    ("auth problems", "Token refresh timeout"),
    ("performance issues", "N+1 query in OrderService"),
    ("database decision", "PostgreSQL for relational data"),
    ("team capacity", "Sprint velocity dropped 12%"),
    ("deploy failure", "Pipeline timeout on staging"),
    ("API design choice", "GraphQL for frontend"),
    ("connection issues", "Redis connection pool exhausted"),
    ("infrastructure", "Kubernetes for orchestration"),
    ("memory problems", "Memory leak in background worker"),
    ("security vulnerability", "CORS misconfigured on API"),
]


def grep_search(query: str, entries: list, k: int = 5) -> list[str]:
    """Simulate keyword search (same as memory-store.sh grep fallback)."""
    scored = []
    for e in entries:
        score = 0
        text = f"{e['title']} {e['content']}".lower()
        for word in query.lower().split():
            if word in text:
                score += 1
        if score > 0:
            scored.append((score, e["title"]))
    scored.sort(reverse=True)
    return [t for _, t in scored[:k]]


def main():
    # Write corpus to temp JSONL
    tmp_dir = tempfile.mkdtemp()
    tmp_store = os.path.join(tmp_dir, ".memory-store.jsonl")

    with open(tmp_store, "w") as f:
        for i, entry in enumerate(CORPUS):
            obj = {
                "ts": f"2026-03-{i+1:02d}T10:00:00Z",
                "type": entry["type"],
                "title": entry["title"],
                "content": entry["content"],
                "concepts": [],
                "tokens_est": len(entry["content"]) // 4,
                "topic_key": f"{entry['type']}/{entry['title'].lower().replace(' ', '-')[:30]}",
                "project": "null",
                "hash": "test",
                "rev": 1,
            }
            f.write(json.dumps(obj) + "\n")

    # Build vector index
    mv.cmd_rebuild(tmp_store)

    # Load model for vector search
    model = SentenceTransformer(mv.MODEL_NAME)
    idx_path = mv._index_path(tmp_store)
    idx = hnswlib.Index(space="cosine", dim=mv.DIMENSIONS)
    idx.load_index(idx_path)
    idx.set_ef(50)

    def vector_search(query: str, k: int = 5) -> list[str]:
        qemb = model.encode([query], normalize_embeddings=True)
        labels, _ = idx.knn_query(qemb, k=min(k, idx.get_current_count()))
        return [CORPUS[int(l)]["title"] for l in labels[0]]

    # Run benchmark
    grep_hits = 0
    vector_hits = 0

    print(f"\n{'Query':<25} {'Expected':<35} {'Grep':^6} {'Vector':^6}")
    print("-" * 80)

    for query, expected in QUERIES:
        g_results = grep_search(query, CORPUS)
        v_results = vector_search(query)

        g_found = expected in g_results
        v_found = expected in v_results

        if g_found:
            grep_hits += 1
        if v_found:
            vector_hits += 1

        print(f"{query:<25} {expected:<35} {'Y' if g_found else '-':^6} {'Y' if v_found else '-':^6}")

    print("-" * 80)
    grep_recall = grep_hits / len(QUERIES) * 100
    vector_recall = vector_hits / len(QUERIES) * 100
    improvement = vector_recall - grep_recall

    print(f"Recall@5:  Grep={grep_recall:.0f}%  Vector={vector_recall:.0f}%  Delta=+{improvement:.0f}pp")

    # Cleanup
    shutil.rmtree(tmp_dir, ignore_errors=True)

    # Assertions
    assert vector_recall > grep_recall, f"Vector ({vector_recall}%) must beat grep ({grep_recall}%)"
    assert improvement >= 20, f"Improvement must be >=20pp, got {improvement}pp"
    assert vector_recall >= 70, f"Vector recall must be >=70%, got {vector_recall}%"

    print(f"\nPASS: Vector search improved recall by +{improvement:.0f}pp ({grep_recall:.0f}% -> {vector_recall:.0f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
