## SPEC-199 — Historical Context Conditioning Between Tribunal Rounds (2026-06-24)

### Added

- `scripts/embeddings-cache.py` — Embedding cache backed by sentence-transformers (`all-MiniLM-L6-v2`, 384 dims). Caches per-text to `~/.savia/embeddings-cache/<sha256>.npy`. In-process LRU + disk persistence. Fallback to zero-vector if model unavailable (fail-soft). CLI: `python3 scripts/embeddings-cache.py --text "..." --json`.
- `scripts/kg-schema-migrate-tribunal.py` — Idempotent SQLite schema migration. Creates `tribunal_iterations` table with privacy column + two indexes (`draft_hash`, `session_id`) in `~/.savia/tribunal-iterations.db`. CLI: `python3 scripts/kg-schema-migrate-tribunal.py [--db PATH] --json`.
- `scripts/recommendation-tribunal/historical-context.py` — Main SPEC-199 engine. Computes embedding of current draft, searches DB for top-K similar historical drafts (cosine similarity >= threshold), builds a token-capped `context_text` block for orchestrator injection. Persists current draft (skips entries flagged as private). Returns `is_zero_sc=true` when DB is empty (first round analog to DiffusionGemma's zero-signal first step). CLI: `python3 historical-context.py --draft TEXT --top-k 3 --similarity-threshold 0.6 --session-id ID --iteration N`.

### Modified

- `scripts/recommendation-tribunal/iterate.sh` — Extended `evaluate-stop` handler with SPEC-199 block. When `SAVIA_TRIBUNAL_HIST_CONTEXT=on`, calls `historical-context.py` before forwarding to `early_stop.py`. Result exported as `TRIBUNAL_HISTORICAL_CONTEXT` env var for orchestrator injection into judge prompts. Default remains `off` (opt-in pilot).

### Tests

- `tests/scripts/test_historical_context.py` — 12 pytest cases covering all ACs: top-k 0, empty DB, 1 entry match, 5 entries top-3 sorted, threshold enforcement, deterministic embeddings, cache hit, idempotent migration, private entry exclusion, token cap, is_zero_sc flag, 1000-entry latency <= 200ms. All 12 passing.
- `tests/test-historical-context-tribunal.bats` — 6 bats tests: CLI runs, output is valid JSON, top-k 0 returns empty, is_zero_sc present, iterate.sh unaffected when feature off, schema migration CLI works. All 6 passing.

### Configuration

```bash
SAVIA_TRIBUNAL_HIST_CONTEXT=on|off          # default off (pilot)
SAVIA_TRIBUNAL_HIST_TOP_K=3
SAVIA_TRIBUNAL_HIST_SIMILARITY_MIN=0.6
SAVIA_TRIBUNAL_HIST_MAX_TOKENS=500
SAVIA_TRIBUNAL_HIST_DB=~/.savia/tribunal-iterations.db
SAVIA_EMBEDDINGS_CACHE_DIR=~/.savia/embeddings-cache/
```

### Rationale

Implements the DiffusionGemma `SelfConditioning` pattern adapted for closed LLMs: instead of passing embeddings directly (not supported by Anthropic API), retrieves the K most similar historical drafts and injects a summary as text context. This conditions judges on tribunal iteration history without the O(n) token cost of full text replay. Named "historical-context-conditioning" per SPEC-199's honesty requirement (not literal self-conditioning).

### Acceptance Criteria (12/12)

All ACs from SPEC-199 verified: top-k boundary, empty DB zero-sc, similarity threshold, top-K sort order, determinism, cache, idempotent migration, private-entry exclusion, token cap, is_zero_sc flag, latency budget.

### Ref

- Spec: `docs/propuestas/SPEC-199-historical-context-tribunal-rounds.md`
- Blocked by: SPEC-195 (iterative tribunal), SPEC-189 (embeddings infra)
