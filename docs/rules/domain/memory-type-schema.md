---
context_tier: L2
token_budget: 500
spec: SE-211
---

# Memory Type Schema — 13 Semantic Types

> Canonical enum for `memory_type` field in the Knowledge Graph (SE-211).
> Source of truth for `scripts/knowledge-graph.py` and `scripts/memory-store.sh`.

## The 13 Types (Memanto-inspired)

| Type | Description | When to use |
|---|---|---|
| `fact` | Objective verifiable fact | Stable truths: "Python 3.12 dropped X" |
| `decision` | Decision taken with justification | Architecture choices, strategy calls |
| `instruction` | Operative rule or behaviour instruction | How to run X, coding conventions |
| `preference` | User or system preference | Tone preferences, tooling choices |
| `goal` | Objective to achieve | Sprint goals, long-term targets |
| `commitment` | Commitment with date or condition | "Will deliver Y by sprint end" |
| `event` | Punctual event (merge, deploy, meeting) | Deploys, PRs merged, milestones |
| `learning` | Discovered pattern or lesson | Retro outcomes, discovered anti-patterns |
| `error` | Bug, failure or detected error | Production bugs, test failures |
| `observation` | Neutral observation without value judgement | Metrics, measurements, discoveries |
| `relationship` | Relation between entities | "Module A depends on B" |
| `context` | Session summary or situational context | Session summaries, situation snapshots |
| `artifact` | Produced artefact (file, spec, doc) | Generated specs, created files |

## Type Mapping from memory-store.sh

| store type | memory_type |
|---|---|
| `decision` | `decision` |
| `discovery` | `observation` |
| `bug` | `error` |
| `architecture` | `artifact` |
| `pattern` | `learning` |
| `session-summary` | `context` |
| `episode` | `event` |
| `feedback` | `observation` |
| others | `unknown` |

## Confidence and Provenance (SE-213)

> Fields added to KG entities by SE-213 for quality-filtered queries.

### Confidence (REAL, 0.0–1.0)

| Value | Meaning |
|---|---|
| `1.0` | Verified — confirmed by direct observation or human validation |
| `0.9` | High — strong evidence, sourced from primary docs |
| `0.8` | Neutral (default) — unverified but plausible |
| `0.7` | Inferred — derived from related entities, not stated directly |
| `0.5` | Uncertain — indirect evidence or ambiguous source |
| `<0.5` | Low trust — contradicted by other sources or outdated |

### Provenance Values

| Value | Criteria |
|---|---|
| `explicit_statement` | Entry comes from explicit MEMORY.md decision or user statement |
| `inferred` | Derived from relations or context — not directly stated |
| `observed` | Sourced from events, commits, or system measurements |
| `unknown` | Origin not classified (default for ingested entities) |
