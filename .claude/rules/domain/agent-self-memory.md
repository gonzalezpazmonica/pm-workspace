---
globs: [".claude/agent-memory/**"]
---

# Agent Self-Memory System — Persistent Pattern Learning

> Agents maintain individual MEMORY.md files to capture and learn from patterns discovered across tasks.

---

## Schema: Pattern Entry

Each entry in MEMORY.md follows this format:

```markdown
| Date | Pattern | Context | Source |
|---|---|---|---|
| YYYY-MM-DD | Brief, actionable pattern (1 line) | When/where pattern applies | Task, PR, or command that revealed it |
```

**Fields**: Date (ISO 8601), Pattern (concise insight), Context (where applies), Source (origin)

**Example**:
```markdown
| 2026-03-01 | Limit modules to 150 lines — break into smaller classes | Maintenance, readability | Refactoring dotnet-microservices |
| 2026-02-28 | Always include try/catch in async methods | Hot path async code | PR review code-reviewer |
```

---

## Scope: Project vs. Local

| Scope | Path | Tracked | Use case |
|---|---|---|---|
| **Project** | `.claude/agent-memory/{agent-name}/MEMORY.md` | Yes (Git) | Shared team knowledge |
| **Local** | `.claude/agent-memory-local/{agent-name}/MEMORY.md` | No (git-ignored) | Personal insights, env quirks |

---

## Limits and Archival

**Max 30 entries per agent**. When approaching limit:
1. Compress entries > 90 days old (combine 2-3 related patterns into 1 summary)
2. Move oldest 5-10 to `.claude/agent-memory/{agent}/MEMORY-archive-YYYYMMDD.md`
3. Keep latest 20 entries always accessible

**Compression**: Combine `readonly + const + immutable` into single entry: "Immutability: use readonly/const, immutable collections"

---

## How Agents Read Memory

At task invocation, agents with `memory: project` in profile:
1. Read `.claude/agent-memory/{name}/MEMORY.md`
2. Load patterns into working context
3. Apply relevant patterns when analyzing code/issues
4. Cite patterns as recommendation source

---

## How Agents Write Memory

Agents MUST write when discovering:
- Pattern confirmed 2+ times (consistent rule)
- Critical anti-pattern (consistently causes failures)
- Surprising finding (contradicts assumptions)
- False positive eliminated (wrong assumption corrected)
- Optimization discovered (performance/quality improvement)

Agents SHOULD NOT write: session-specific findings, info already in docs, unverified assumptions, duplicates.

**Never duplicate**: Before adding entry, check if pattern exists. If found, update date/source instead.

---

## Agents with Memory Enabled

| Agent | Domain | Memory Focus |
|---|---|---|
| **code-reviewer** | Code quality, SOLID | Review patterns, anti-patterns |
| **architect** | Design, layers | Architecture decisions, patterns |
| **security-guardian** | Security, compliance | Vulnerability patterns, false positives |
| **test-runner** | Testing, coverage | Testing gaps, edge cases |
| **triage** | Issue classification | Severity assessment, routing rules |

---

## Integration

| System | Relationship |
|---|---|
| `agent-memory-protocol.md` | Original protocol; this extends implementation |
| `context-aging.md` | Entries > 90 days subject to compression |
| `code-review-rules.md` | Patterns feed code review checks |

---

## File Size Constraint

Each MEMORY.md must stay ≤ 150 lines: ~5 header + 2 table header + ~60 lines for 30 entries = ~65 typical.
Archival starts when approaching 150.
