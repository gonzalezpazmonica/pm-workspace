# Knowledge Graph Auto-Extraction Policy

> SE-297 — Sovereign entity extraction from documents
> context_tier: L2
> token_budget: 280

## Extraction Modes

1. **Deterministic** (regex): instant, confidence=1.0, covers known patterns
2. **LLM-enhanced** (via ProviderRouter SE-294): contextual, for uncovered sections
3. **Hybrid**: regex first, LLM fallback if coverage < 50%

## Quality Gates

- String match: entity must appear verbatim in source
- Confidence < 0.5 → rejected
- Confidence 0.5-0.7 → proposed (human review)
- Confidence > 0.7 → auto-persisted

## Human Review

- Command: /review-entities
- Unreviewed proposed entities → archived after 14 days
- Weekly quality report with 5 metrics
