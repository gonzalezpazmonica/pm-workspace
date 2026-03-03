---
name: savia-forget
description: >
  GDPR-compliant memory pruning — remove specific entries from Savia's memory.
argument-hint: "[topic|--all] [--scope section] [--dry-run]"
allowed-tools: [Read, Write, Edit, Glob, Grep]
model: haiku
context_cost: low
---

# /savia-forget — Memory Pruning (GDPR)

Remove specific entries from Savia's persistent memory.
Implements AEPD data minimization principle.

## Usage

- `/savia-forget {topic}` — Remove entries matching topic
- `/savia-forget --scope vocabulary` — Clear entire section
- `/savia-forget --all` — Clear all memory (with double confirmation)
- `/savia-forget --dry-run {topic}` — Preview what would be removed

## Behavior

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🦉 /savia-forget — Memory Pruning
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Single topic

1. Search MEMORY.md for entries matching topic
2. Show matches to user
3. Confirm: "Remove N entries about '{topic}'?"
4. If confirmed: remove entries, preserve section headers

### Full clear (`--all`)

1. Show summary of all memory contents
2. First confirmation: "Clear ALL Savia memory? This cannot be undone."
3. Second confirmation: "Type 'FORGET' to confirm."
4. If confirmed: reset MEMORY.md to template headers only

## AEPD Compliance

| Principle | Implementation |
|---|---|
| Data minimization | Only project-relevant context stored |
| Right to erasure | This command implements Art. 17 RGPD |
| Purpose limitation | Memory used only for PM assistance |
| Transparency | User can inspect all memory via `/savia-recall` |

## Rules

- NEVER delete the MEMORY.md file — only clear content sections
- ALWAYS show what will be removed before removing
- Log the forget action in audit trail if enabled
- `--all` requires double confirmation to prevent accidents
