---
version_bump: patch
section: Added
---

### Added

- scripts/context-greedy-budget.{py,sh}: stdlib-only Python module that scores graph nodes (PageRank power-iteration + TF-IDF cosine + code-boost) and selects the most relevant subgraph that fits a token budget using a greedy algorithm with neighbor decay. Three input adapters: .acm markdown, knowledge-graph SQLite (SE-162), generic JSON/JSONL graph. Three output formats: markdown, json, jsonl. Pattern observed in CarlosVallejoRuiz/slurp and reimplemented stdlib-only with adapters specific to Savias context formats — no vendor lock-in (no slurp, networkx, numpy, sklearn, or required tiktoken). 63/63 tests green (47 pytest + 16 bats). Real INDEX.acm query completes in <50ms. Spec PROPOSED in docs/propuestas/SPEC-189-greedy-context-budget.md, P1, standard, 16 ACs.

