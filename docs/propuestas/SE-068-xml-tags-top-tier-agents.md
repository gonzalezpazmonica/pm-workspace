---
id: SE-068
title: SE-068 — XML tag structure in top-tier opus-4-7 agents
status: IMPLEMENTED
origin: Opus 4.7 migration analysis 2026-04-23
author: Savia
priority: media
effort: M 6h
gap_link: Zero agents use XML tags; Opus 4.7 response quality +30% with structured multi-doc input
approved_at: "2026-04-23"
applied_at: "2026-04-23"
batches: [33]
expires: "2026-05-23"
era: 186
---

# SE-068 — XML tags in top-tier opus-4-7 agents

## Purpose

Anthropic's Opus 4.7 migration guide reports up to 30% response quality improvement on complex multi-document inputs when prompts use XML tag structure (`<instructions>`, `<context>`, `<examples>`, `<input>`) with queries at the end.

Current state: 0 out of 65 agents use XML tag structure. Top-tier opus-4-7 agents are the highest-leverage targets because they handle multi-document, multi-file analysis where attention-over-structure benefits compound.

## Affected agents (Slice 1 scope)

Top 5 agents by context complexity + opus-4-7 model + frequent invocation:
1. `architect` — multi-file architectural decisions
2. `dev-orchestrator` — spec → plan → slice decomposition
3. `court-orchestrator` — convenes multiple judges + aggregates verdicts
4. `truth-tribunal-orchestrator` — 7-judge panel orchestration
5. `code-reviewer` — full file reviews + cross-file dependency analysis

## Scope

### Slice 1 — 5 top-tier agents migrated (M, 4h)

For each agent, restructure the system prompt using XML sections:

```markdown
<role>
{current role description}
</role>

<instructions>
{current instructions, cleaned up}
</instructions>

<context_usage>
{how to use available context, files, memory}
</context_usage>

<examples>
{3-5 examples of good behavior wrapped in <example> tags}
</examples>

<constraints>
{non-negotiables — permissions, safety, scope}
</constraints>

<output_format>
{expected format of final output}
</output_format>
```

Query (user turn input) arrives AFTER this structure — critical for the "query at end" 30% boost.

### Slice 2 — Validation + BATS (S, 1h)

`scripts/opus47-compliance-check.sh --xml-tags` asserts the 5 agents contain ≥3 XML tag types from the canonical set.

### Slice 3 — Rollout doc (S, 1h)

`docs/rules/domain/agent-prompt-xml-structure.md` — canonical XML tag set, when to use each, examples.

## Acceptance criteria

- 5 agents migrated to XML structure (≥3 distinct tag types each)
- `opus47-compliance-check.sh --xml-tags` exits 0
- BATS tests assert tag presence in each of the 5 agents
- No regression in agent invocation: `readiness-check.sh` PASS
- Documentation explains the pattern for future agents

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| XML parsing overhead in smaller models | Baja | Bajo | Only opus-4-7 agents in scope; haiku/sonnet use narrative prompts |
| Prompt length increases beyond attention budget | Media | Medio | Migration REFORMATS, doesn't ADD — should be token-neutral or smaller |
| Inconsistency vs legacy agents | Media | Bajo | Rollout doc guides future adoption; not urgent to retrofit all 65 |
| Model ignores XML and treats as plaintext | Baja | Bajo | Well-documented Anthropic-recommended pattern; 4.7 was trained on it |

## No hacen

- Does NOT migrate all 65 agents — only top-tier opus-4-7. Rest follow as needed.
- Does NOT change agent behavior — only prompt structure.
- Does NOT introduce new tags beyond the canonical 6 set.

## Referencias

- Opus 4.7 migration guide: "Put longform data at the top of your prompt, above your query. Queries at the end can improve response quality by up to 30%"
- Anthropic prompt engineering docs — XML tag usage
- Complementary: SE-066 (finding-vs-filtering), SE-067 (fan-out)
