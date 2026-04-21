#!/usr/bin/env python3
"""rerank.py — SE-032 Slice 2 cross-encoder reranker.

Wrapper stdin -> stdout. Input JSON con query + candidates, output top-K reordenados
por relevance score del cross-encoder. Fallback: si sentence-transformers no esta
instalado, devuelve orden original sin modificar (no-op safe).

Usage:
    echo '{"query":"Q","candidates":[{"id":"a","text":"..."},...]}' | python3 scripts/rerank.py --top-k 5

Input schema:
    {
      "query": "natural language question",
      "candidates": [
        {"id": "str", "text": "str", "cosine": 0.85}
      ]
    }

Output schema:
    {
      "query": "...",
      "reranked": [
        {"id":"a", "text":"...", "cosine": 0.85, "relevance": 0.92, "rank": 1}
      ],
      "backend": "cross-encoder|fallback-cosine|fallback-identity",
      "model": "BAAI/bge-reranker-base|null",
      "latency_ms": int
    }

Exit codes:
    0 - OK (rerank done or fallback applied)
    1 - parse error
    2 - usage error

Ref: SE-032, docs/propuestas/SE-032-reranker-layer.md
Safety: read-only. Zero egress. No credential handling.
"""

import argparse
import json
import sys
import time

DEFAULT_MODEL = "BAAI/bge-reranker-base"
DEFAULT_TOP_K = 5


def parse_args():
    p = argparse.ArgumentParser(
        description="Cross-encoder reranker for query + candidates (SE-032).",
    )
    p.add_argument("--top-k", type=int, default=DEFAULT_TOP_K,
                   help="Max results to return (default 5)")
    p.add_argument("--model", default=DEFAULT_MODEL,
                   help=f"HF model id (default {DEFAULT_MODEL})")
    p.add_argument("--json", action="store_true",
                   help="Pretty JSON output (otherwise compact)")
    return p.parse_args()


def fallback_cosine(candidates):
    """Sort by existing cosine score if present, else preserve order."""
    has_cosine = all("cosine" in c for c in candidates)
    if has_cosine:
        return sorted(candidates, key=lambda c: -c.get("cosine", 0.0)), "fallback-cosine"
    return candidates, "fallback-identity"


def try_cross_encode(query, candidates, model_id):
    """Attempt cross-encoder reranking. Returns (ranked, backend, model) or (None, backend, None).

    Redirects model loading stdout to stderr to keep our JSON output clean.
    """
    try:
        from sentence_transformers import CrossEncoder
    except ImportError:
        return None, "fallback", None

    try:
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            model = CrossEncoder(model_id)
            pairs = [[query, c["text"]] for c in candidates]
            scores = model.predict(pairs)
        sys.stderr.write(buf.getvalue())
        for c, s in zip(candidates, scores):
            c["relevance"] = float(s)
        ranked = sorted(candidates, key=lambda c: -c["relevance"])
        return ranked, "cross-encoder", model_id
    except (OSError, RuntimeError, ValueError) as e:
        sys.stderr.write(f"rerank: cross-encoder failed: {e}\n")
        return None, "fallback", None


def main():
    args = parse_args()

    if args.top_k < 1:
        sys.stderr.write("ERROR: --top-k must be >= 1\n")
        return 2

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"ERROR: invalid JSON input: {e}\n")
        return 1

    query = data.get("query", "").strip()
    candidates = data.get("candidates", [])

    if not query:
        sys.stderr.write("ERROR: 'query' field required\n")
        return 1
    if not isinstance(candidates, list):
        sys.stderr.write("ERROR: 'candidates' must be a list\n")
        return 1

    for i, c in enumerate(candidates):
        if not isinstance(c, dict) or "id" not in c or "text" not in c:
            sys.stderr.write(f"ERROR: candidate[{i}] must have 'id' and 'text'\n")
            return 1

    start = time.time()

    if not candidates:
        ranked, backend, model_used = [], "empty-input", None
    else:
        ranked, backend, model_used = try_cross_encode(query, candidates, args.model)
        if ranked is None:
            ranked, backend = fallback_cosine(candidates)
            model_used = None

    top_ranked = ranked[: args.top_k]
    for i, c in enumerate(top_ranked):
        c["rank"] = i + 1

    latency_ms = int((time.time() - start) * 1000)

    result = {
        "query": query,
        "reranked": top_ranked,
        "backend": backend,
        "model": model_used,
        "latency_ms": latency_ms,
    }

    indent = 2 if args.json else None
    sys.stdout.write(json.dumps(result, ensure_ascii=False, indent=indent))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
