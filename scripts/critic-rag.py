#!/usr/bin/env python3
"""critic-rag.py — SPEC-167: Critic with RAG over external memory.

Queries ~/.savia/knowledge-graph.db (or a custom path) for relevant
memory entries using BM25-style keyword matching, then produces a
critic verdict enriched with retrieved precedents.

Usage:
  python3 scripts/critic-rag.py --draft "text to critique"
  python3 scripts/critic-rag.py --draft "text" --kg-path ~/.savia/knowledge-graph.db
  python3 scripts/critic-rag.py --draft "text" --top-k 5
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import sqlite3
import sys
import time
from pathlib import Path
from typing import Any

# ── Constants ─────────────────────────────────────────────────────────────────

DEFAULT_KG_PATH = Path.home() / ".savia" / "knowledge-graph.db"
DEFAULT_TOP_K = 5
BM25_MIN_SCORE = 0.05      # skip precedents below this relevance threshold
MAX_PRECEDENT_TOKENS = 500  # cap memory injected into verdict context

# ── BM25 helpers ─────────────────────────────────────────────────────────────

def _tokenize(text: str) -> list[str]:
    """Simple whitespace + punctuation tokenizer, lowercase."""
    return re.findall(r"[a-z0-9_\-]{3,}", text.lower())


def _idf(term: str, doc_count: int, df: int) -> float:
    """BM25 IDF formula."""
    return math.log((doc_count - df + 0.5) / (df + 0.5) + 1.0)


def bm25_score(query_tokens: list[str], doc_text: str, idf_map: dict[str, float],
               k1: float = 1.5, b: float = 0.75, avg_dl: float = 50.0) -> float:
    """Compute BM25 score of doc_text against query_tokens."""
    doc_tokens = _tokenize(doc_text)
    dl = len(doc_tokens)
    tf_map: dict[str, int] = {}
    for t in doc_tokens:
        tf_map[t] = tf_map.get(t, 0) + 1

    score = 0.0
    for term in query_tokens:
        tf = tf_map.get(term, 0)
        if tf == 0:
            continue
        idf = idf_map.get(term, math.log(1.5))
        numerator = tf * (k1 + 1)
        denominator = tf + k1 * (1 - b + b * dl / avg_dl)
        score += idf * numerator / denominator
    return score


# ── KG access ─────────────────────────────────────────────────────────────────

def _load_kg_entries(kg_path: Path) -> list[dict]:
    """Load text entries from knowledge-graph.db. Returns empty list on failure."""
    if not kg_path.exists():
        return []
    try:
        conn = sqlite3.connect(str(kg_path))
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        # Try entities table (standard KG schema)
        try:
            cur.execute(
                "SELECT id, name, entity_type, description, created_at "
                "FROM entities ORDER BY created_at DESC LIMIT 2000"
            )
            rows = cur.fetchall()
            entries = []
            for r in rows:
                text = " ".join(filter(None, [
                    str(r["name"] or ""),
                    str(r["entity_type"] or ""),
                    str(r["description"] or ""),
                ]))
                entries.append({
                    "id": str(r["id"]),
                    "text": text,
                    "source": f"kg:entities:{r['id']}",
                })
            conn.close()
            return entries
        except sqlite3.OperationalError:
            pass
        # Fallback: try memory_entries table
        try:
            cur.execute(
                "SELECT id, content, memory_type, created_at "
                "FROM memory_entries ORDER BY created_at DESC LIMIT 2000"
            )
            rows = cur.fetchall()
            entries = [
                {"id": str(r["id"]), "text": str(r["content"] or ""),
                 "source": f"memory:{r['id']}"}
                for r in rows
            ]
            conn.close()
            return entries
        except sqlite3.OperationalError:
            pass
        conn.close()
    except Exception:
        pass
    return []


# ── Retrieval ─────────────────────────────────────────────────────────────────

def retrieve_precedents(draft: str, kg_path: Path, top_k: int = DEFAULT_TOP_K) -> dict:
    """
    Retrieve top-K relevant memory entries for a given draft text.
    Returns {entries: [...], latency_ms: float, rag_available: bool}
    """
    t0 = time.time()
    entries = _load_kg_entries(kg_path)
    if not entries:
        return {"entries": [], "latency_ms": (time.time() - t0) * 1000, "rag_available": False}

    query_tokens = _tokenize(draft)
    if not query_tokens:
        return {"entries": [], "latency_ms": (time.time() - t0) * 1000, "rag_available": True}

    # Build IDF map from corpus
    doc_count = len(entries)
    df_map: dict[str, int] = {}
    for e in entries:
        for t in set(_tokenize(e["text"])):
            df_map[t] = df_map.get(t, 0) + 1
    idf_map = {t: _idf(t, doc_count, df) for t, df in df_map.items()}
    avg_dl = sum(len(_tokenize(e["text"])) for e in entries) / max(doc_count, 1)

    scored: list[tuple[float, dict]] = []
    for e in entries:
        score = bm25_score(query_tokens, e["text"], idf_map, avg_dl=avg_dl)
        if score >= BM25_MIN_SCORE:
            scored.append((score, e))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = scored[:top_k]

    latency_ms = (time.time() - t0) * 1000
    return {
        "entries": [
            {"id": e["id"], "text": e["text"][:300], "score": round(s, 4),
             "source": e.get("source", "")}
            for s, e in top
        ],
        "latency_ms": round(latency_ms, 1),
        "rag_available": True,
    }


# ── Critic ────────────────────────────────────────────────────────────────────

def _simple_heuristic_verdict(draft: str, precedents: list[dict]) -> tuple[str, float]:
    """
    Lightweight heuristic critic (no LLM call).
    Scores based on draft length, presence of contradictory keywords, and
    whether any precedent flagged similar content.
    Returns (verdict_text, score 0..1).
    """
    words = draft.split()
    length_ok = 10 <= len(words) <= 5000

    negative_signals = [
        "never", "always", "impossible", "guaranteed", "broken",
        "deprecated without replacement", "missing", "undefined",
    ]
    warnings = [sig for sig in negative_signals if sig in draft.lower()]

    precedent_flags = any("conflict" in (p.get("text", "").lower()) for p in precedents)

    base_score = 0.7
    if not length_ok:
        base_score -= 0.2
    if warnings:
        base_score -= 0.05 * len(warnings)
    if precedent_flags:
        base_score -= 0.1

    base_score = max(0.0, min(1.0, base_score))

    if base_score >= 0.65:
        verdict = "PASS"
    elif base_score >= 0.4:
        verdict = "WARN"
    else:
        verdict = "FAIL"

    if warnings:
        verdict += f" — signals detected: {', '.join(warnings[:3])}"

    return verdict, base_score


def critique(
    draft: str,
    kg_path: Path = DEFAULT_KG_PATH,
    top_k: int = DEFAULT_TOP_K,
) -> dict[str, Any]:
    """
    Run critic with RAG context.
    Returns JSON-serialisable dict with verdict, score, rag_context_used, precedents.
    """
    rag = retrieve_precedents(draft, kg_path, top_k)
    precedents = rag["entries"]
    rag_used = rag["rag_available"] and len(precedents) > 0

    # Build context snippet (capped at MAX_PRECEDENT_TOKENS chars)
    context_text = ""
    if rag_used:
        snippets = [f"[{p['id']}] {p['text'][:200]}" for p in precedents]
        context_text = "\n".join(snippets)[:MAX_PRECEDENT_TOKENS]

    verdict_text, score = _simple_heuristic_verdict(draft, precedents)

    # Log to telemetry file
    telemetry_path = Path("output") / "critic-rag-queries.jsonl"
    try:
        telemetry_path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "draft_preview": draft[:100],
            "verdict": verdict_text,
            "score": score,
            "rag_used": rag_used,
            "precedent_count": len(precedents),
            "latency_ms": rag["latency_ms"],
        }
        with telemetry_path.open("a", encoding="utf-8") as fh:
            import json as _json
            fh.write(_json.dumps(record) + "\n")
    except Exception:
        pass

    return {
        "verdict": verdict_text,
        "score": round(score, 3),
        "rag_context_used": rag_used,
        "precedents": [p["id"] for p in precedents],
        "precedent_snippets": precedents,
        "latency_ms": rag["latency_ms"],
        "rag_available": rag["rag_available"],
        "context_injected": context_text,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SPEC-167 critic-rag")
    p.add_argument("--draft", required=True, help="Text to critique")
    p.add_argument("--kg-path", default=str(DEFAULT_KG_PATH),
                   help=f"Path to knowledge-graph.db (default: {DEFAULT_KG_PATH})")
    p.add_argument("--top-k", type=int, default=DEFAULT_TOP_K,
                   help=f"Number of precedents to retrieve (default: {DEFAULT_TOP_K})")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    result = critique(args.draft, kg_path=Path(args.kg_path), top_k=args.top_k)
    print(json.dumps(result, indent=2))
    if not args.quiet:
        print(
            f"verdict={result['verdict']} score={result['score']} "
            f"rag={result['rag_context_used']} latency={result['latency_ms']}ms",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
