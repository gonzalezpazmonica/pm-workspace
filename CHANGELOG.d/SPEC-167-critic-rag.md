# SPEC-167 — Critic with RAG over external memory

**Date:** 2026-06-24

## Implementado

- `scripts/critic-rag.py`: critic that queries external memory before emitting verdict
  - `--draft TEXT`: text to critique
  - `--kg-path`: path to knowledge-graph.db (graceful fallback if missing)
  - `--top-k`: number of precedents to retrieve (default: 5)
  - BM25-style retrieval over entities table (or memory_entries fallback)
  - Output JSON: `{verdict, score, rag_context_used, precedents, latency_ms}`
  - Telemetry logged to `output/critic-rag-queries.jsonl`
  - Latency target: <200ms for 1000 entries (pure-Python BM25, no dependencies)
- `tests/scripts/test_critic_rag.py`: 7 pytest covering schema, fallback, BM25, RAG retrieval, CLI

## Tests: 7 passed
