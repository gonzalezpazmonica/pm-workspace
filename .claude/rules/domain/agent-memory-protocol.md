---
paths: ["public-agent-memory/**", "private-agent-memory/**", "projects/*/agent-memory/**"]
---

# Agent Memory Protocol — Persistent Knowledge Across Sessions

> Agents remember decisions, patterns, and lessons between sessions.
> Canonical rule: `agent-memory-isolation.md` (3 levels).

---

## Three Levels

| Level | Path | Git-tracked | Use case |
|---|---|---|---|
| **Public** | `public-agent-memory/{name}/` | Yes | Generic best practices (DDD, SOLID, security patterns) |
| **Private** | `private-agent-memory/{name}/` | No (gitignored) | Personal/team context (preferences, org conventions) |
| **Project** | `projects/{proyecto}/agent-memory/{name}/` | No (gitignored) | Client data, project-specific patterns |

## Load Order

At start of each invocation, agents read in this order:

```
1. public-agent-memory/{name}/MEMORY.md     (generic patterns)
2. private-agent-memory/{name}/MEMORY.md    (personal context)
3. projects/{proyecto}/agent-memory/{name}/MEMORY.md  (project data)
```

In case of conflict: project > private > public.

## Write Classification

Before writing, classify each pattern:

| Question | Destination |
|---|---|
| Generic best practice, no PII? | public-agent-memory/ |
| Personal, team, or org context? | private-agent-memory/ |
| Client or project-specific data? | projects/{proyecto}/agent-memory/ |

## MEMORY.md Structure

Max 150 lines per file. Content accumulates under `##` headers.
When approaching limit, compress oldest entries.

## When Agents Write Memory

1. **Architecture decision** that affects future work
2. **Pattern discovered** that should persist
3. **Bug root cause** identified after investigation
4. **False positive** confirmed in security/quality checks
5. **Project convention** learned from review feedback

Agents SHOULD NOT write: session-specific state, info already in docs, unverified assumptions.

## Memory Hygiene

- **Compress**: entries older than 90 days → one-line summary
- **Prune**: remove entries contradicted by newer information
- **Migrate**: patterns confirmed 3+ times → propose as domain rule

## Agents with Public Memory (7)

architect, code-reviewer, security-guardian, test-runner, triage,
coherence-validator, reflection-validator

## Agents with Private Memory (5)

savia, business-analyst, commit-guardian, dotnet-developer, sdd-spec-writer

## Agents with Project Memory (on demand)

meeting-digest, meeting-risk-analyst, meeting-confidentiality-judge,
and ANY agent when operating on a specific project.

## Integration

| System | Relationship |
|---|---|
| `agent-memory-isolation.md` | Canonical 3-level rule (IMMUTABLE) |
| `agent-notes-protocol` | Notes are per-session; memory persists across sessions |
| `context-aging.md` | Same aging rules apply (fresh/mature/ancient) |
| `memory-store.sh` | JSONL store is for user memory; agent memory uses markdown |
