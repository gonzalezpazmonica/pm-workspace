# Context Caching — Domain Context

## Why this skill exists

Claude context window costs tokens. Prompt caching (cache_control) reduces input token cost by 90% for repeated context. Large projects with 50K+ tokens of stable content (CLAUDE.md, rules, skill docs) benefit hugely. This skill optimizes context load order to maximize cache hit rates.

## Domain concepts

- **Cache Breakpoint** — Explicit cache_control marker; resets cache TTL
- **Cache Hierarchy** — 4 levels: PM globals → project context → skill content → dynamic request
- **TTL (Time To Live)** — Validity of cached content; API default 5 minutes
- **Cache Hit** — Reuse of cached tokens (90% cheaper)
- **Cache Miss** — Cold load (full cost); happens after TTL expires or content changes

## Business rules it implements

- **RN-CACHE-01**: Load stable content first (system prompt, CLAUDE.md, rules)
- **RN-CACHE-02**: Place cache_control after each stable block
- **RN-CACHE-03**: Estimate cost savings via `/cache-optimize`
- **RN-CACHE-04**: No cache for dynamic data (requests, results, conversation history)

## Relationship to other skills

**Upstream:** None (infrastructure skill)
**Downstream:** All commands load context; this skill optimizes their token costs
**Parallel:** Works with `prompt-caching` rule to define hierarchy

## Key decisions

- **Automatic ordering** — `/cache-optimize` reorders context for best hit rates
- **TTL tuning** — 5 min default; projects can override if refresh frequency varies
- **Transparent** — Users don't need to understand caching; it's automatic in Claude Code
