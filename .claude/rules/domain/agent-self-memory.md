---
paths: ["public-agent-memory/**", "private-agent-memory/**", "projects/*/agent-memory/**"]
---

# Agent Self-Memory System — Persistent Pattern Learning

> Agents maintain individual MEMORY.md files to capture and learn from patterns.
> Canonical 3-level rule: `agent-memory-isolation.md`.

---

## Schema: Pattern Entry

```markdown
| Date | Pattern | Context | Source |
|---|---|---|---|
| YYYY-MM-DD | Brief, actionable pattern (1 line) | When/where applies | Task or command that revealed it |
```

---

## Three Levels of Memory

| Level | Path | Tracked | Content |
|---|---|---|---|
| **Public** | `public-agent-memory/{agent}/MEMORY.md` | Yes (Git) | Generic best practices |
| **Private** | `private-agent-memory/{agent}/MEMORY.md` | No (gitignored) | Personal/team context |
| **Project** | `projects/{proyecto}/agent-memory/{agent}/MEMORY.md` | No (gitignored) | Client-specific data |

---

## Limits and Archival

**Max 30 entries per agent**. When approaching limit:
1. Compress entries > 90 days old (combine 2-3 related patterns into 1 summary)
2. Move oldest 5-10 to `MEMORY-archive-YYYYMMDD.md` in same directory
3. Keep latest 20 entries always accessible

---

## How Agents Read Memory

At task invocation, read all 3 levels (if they exist):
1. Public patterns → baseline knowledge
2. Private patterns → personal/org context
3. Project patterns → client-specific data
4. Apply relevant patterns; cite as recommendation source

---

## How Agents Write Memory

Agents MUST write when discovering:
- Pattern confirmed 2+ times (consistent rule)
- Critical anti-pattern (consistently causes failures)
- Surprising finding (contradicts assumptions)
- False positive eliminated (wrong assumption corrected)

**Never duplicate**: check if pattern exists before adding. Update date/source instead.

**Classify before writing**: generic → public, personal → private, client → project.

---

## Agents with Memory Enabled

| Agent | Public | Private | Focus |
|---|---|---|---|
| architect | Yes | — | Architecture decisions, patterns |
| code-reviewer | Yes | — | Review patterns, anti-patterns |
| security-guardian | Yes | — | Vulnerability patterns, false positives |
| test-runner | Yes | — | Testing gaps, edge cases |
| triage | Yes | — | Severity assessment, routing rules |
| savia | — | Yes | Team decisions, communication preferences |
| business-analyst | — | Yes | Domain vocabulary, stakeholder preferences |
| commit-guardian | — | Yes | Conventions, recurring failures |
| dotnet-developer | — | Yes | Project conventions, build quirks |
| sdd-spec-writer | — | Yes | Spec patterns, rejection history |

All agents write to **project level** when operating on a specific project.

---

## Integration

| System | Relationship |
|---|---|
| `agent-memory-isolation.md` | Canonical 3-level rule (IMMUTABLE) |
| `agent-memory-protocol.md` | Protocol details |
| `context-aging.md` | Entries > 90 days subject to compression |

## File Size Constraint

Each MEMORY.md must stay ≤ 150 lines.
