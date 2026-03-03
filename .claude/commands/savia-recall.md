---
name: savia-recall
description: Query Savia's accumulated contextual memory across sessions.
argument-hint: "[topic] [--project name] [--scope decisions|vocabulary|preferences|lessons]"
allowed-tools: [Read, Glob, Grep]
model: haiku
context_cost: low
---

# /savia-recall — Query Savia's Memory

Search and retrieve accumulated context from Savia's persistent memory.

## Usage

- `/savia-recall` — Show full Savia memory overview
- `/savia-recall {topic}` — Search for a specific topic across all sections
- `/savia-recall --scope decisions` — Show only team decisions
- `/savia-recall --project {name}` — Filter by project

## Behavior

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🦉 /savia-recall — Contextual Memory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. Read `.claude/agent-memory/savia/MEMORY.md`
2. If topic provided: grep for matching entries
3. If scope provided: show only that section
4. Display results with timestamps and source references

## Memory Sources

| Source | Auto-populated |
|---|---|
| `/session-save` | Yes — decisions saved at session end |
| `/sprint-retro` | Yes — lessons from retrospectives |
| `/profile-setup` | Yes — communication preferences |
| Manual | Via `/memory-save` with savia scope |

## Privacy

- Savia memory follows AEPD data minimization principle
- No personal data stored — only project-relevant context
- Use `/savia-forget` to remove specific entries (GDPR compliance)
