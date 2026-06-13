---
version_bump: patch
section: Added
---

### Added

- scripts/context-greedy-budget.py and .sh wrapper: stdlib-only Python module
  that scores graph nodes (PageRank power-iteration + TF-IDF cosine +
  multiplicative code-boost) and selects the most relevant subgraph fitting
  a token budget via greedy with neighbor decay. Four input adapters:
  .acm markdown with recursive @include resolution (cross-file subgraph),
  .scm Savia Capability Map, knowledge-graph SQLite (SE-162), generic
  JSON/JSONL graph. Three output formats: markdown, json, jsonl.
  --quality-json emits objective metrics (top1_score, savings_pct, dual
  baselines tokens_full_graph vs tokens_full_file). Pattern from upstream
  slurp project, re-implemented stdlib-only with Savia-specific adapters
  to avoid vendor lock-in (no slurp, networkx, numpy, sklearn, tiktoken
  is opt-in).

- .opencode/hooks/context-greedy-inject.sh (PreToolUse Read): intercepts
  Read on .acm/.scm files. When the turn query produces a high-quality
  subgraph (top1 >= 0.50, savings >= 30 percent, not all-nodes), it
  proposes the subgraph instead. Three modes: shadow (default, telemetry
  only, never blocks), warn (advisory), block (exit 2). Per-dir opt-out
  via .cgi-skip marker. JSONL telemetry to output/context-greedy-inject.jsonl
  for empirical validation before promoting shadow to block.

- Validated against 11 real project ACMs (45 query/file combinations).
  Projects with @include recursion (savia-web 42 nodes 3018t, mobile-android
  46 nodes 2588t) yield 62-97 percent token reduction on relevant queries.
  Irrelevant or empty queries trigger automatic bypass with zero selected
  nodes and zero savings reported. Small projects (5-7 nodes) bypass
  automatically.

- Tests: 88 of 88 green
  - tests/scripts/test_context_greedy_budget.py: 58 pytest cases (tokenizer,
    PageRank, TF-IDF, scoring, greedy budget, 4 adapters, recursive
    @include, dual baselines, anti-vendor-lock checks)
  - tests/test-context-greedy-budget.bats: 16 bats cases (CLI surface,
    real INDEX.acm smoke, format determinism, budget invariant)
  - tests/test-context-greedy-inject.bats: 14 bats cases (hook decision
    tree, shadow/warn/block paths, telemetry shape, tunable thresholds)

Spec PROPOSED in docs/propuestas/SPEC-189-greedy-context-budget.md, P1,
standard, 16 ACs.
