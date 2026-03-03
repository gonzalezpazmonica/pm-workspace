# Agent Memory Protocol — Persistent Knowledge Across Sessions

> Agents remember decisions, patterns, and lessons between sessions.

---

## Three Scopes

| Scope | Path | Git-tracked | Use case |
|---|---|---|---|
| **project** | `.claude/agent-memory/{name}/` | Yes | Shared team knowledge (architecture decisions, conventions) |
| **local** | `.claude/agent-memory-local/{name}/` | No (gitignored) | Personal insights (debugging notes, local env quirks) |
| **user** | `~/.claude/agent-memory/{name}/` | N/A | Cross-project knowledge (language patterns, tool preferences) |

## MEMORY.md Structure

Each agent's MEMORY.md has 3 sections with `##` headers. Content accumulates under each.
Max 150 lines per file. When approaching limit, compress oldest entries.

## When Agents Write Memory

Agents SHOULD write to their MEMORY.md when:

1. **Architecture decision** made that affects future work
2. **Pattern discovered** that should persist (naming, structure, style)
3. **Bug root cause** identified after investigation
4. **False positive** confirmed in security/quality checks
5. **Project convention** learned from code review feedback

Agents SHOULD NOT write:

1. Session-specific temporary state
2. Information already in CLAUDE.md or project docs
3. Unverified assumptions from a single file read

## How Agents Read Memory

At the start of each invocation, agents with `memory: project` in frontmatter
SHOULD read their MEMORY.md to restore context from previous sessions.

## Memory Hygiene

- **Compress**: entries older than 90 days → one-line summary
- **Prune**: remove entries contradicted by newer information
- **Migrate**: patterns confirmed 3+ times → propose as domain rule
- `/agent-memory {name} --clear` resets to template headers

## Integration with Existing Systems

| System | Relationship |
|---|---|
| `agent-notes-protocol` | Notes are per-session; memory persists across sessions |
| `context-aging.md` | Same aging rules apply (fresh/mature/ancient) |
| `memory-store.sh` | JSONL store is for user memory; agent memory uses markdown |
| `AEPD framework` | Agent memory subject to data minimization principle |

## Agents with Memory Enabled (8)

architect, security-guardian, commit-guardian, code-reviewer,
business-analyst, sdd-spec-writer, test-runner, dotnet-developer
