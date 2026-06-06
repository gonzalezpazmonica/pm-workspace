---
rule_id: reconciliation-decision-tree
title: Reconciliation 3-bucket decision tree
status: ACTIVE
ref: SPEC-183
deps: [SPEC-182]
context_tier: L3
token_budget: 700
---

# Reconciliation 3-bucket Decision Tree — SPEC-183

Used by the `reconciler` agent and `drift-auditor` to classify contradictions.
Three mutually exclusive outcomes: **evolution**, **auto-resolve**, **conflict-doc**.

## Decision Tree

```
Given: fragment_a (older), fragment_b (newer), optional timeline context

Step 1 — Evolution check
  Q: Does either fragment have a timeline: entry where from/until spans
     the difference in dates between a and b?
  YES → bucket = EVOLUTION
        action  = append timeline entry via SPEC-182 timeline-append.sh
        rationale: change is temporal-coherent, not a contradiction

Step 2 — Auto-resolve check
  Q: Is fragment_b strictly newer AND from a more authoritative source?
     (authoritative = SPEC doc > decision entry > comment/note)
  YES → bucket = AUTO_RESOLVE
        action  = rewrite fragment_a with fragment_b value
                  + append ## History block: old_value → new_value + source + date
        rationale: winner is clear, no ambiguity

Step 3 — Default
  Neither Step 1 nor Step 2 matched
  → bucket = CONFLICT_DOC
    action  = create output/conflicts/{topic}-{YYYYMMDD}.md with status: open
    rationale: human decision required
```

## Bucket definitions

| Bucket | Condition | Agent action |
|---|---|---|
| `evolution` | Temporal-coherent change (timeline explains it) | Append timeline entry |
| `auto-resolve` | Clear winner: newer + more authoritative | Rewrite + History block |
| `conflict-doc` | Ambiguous or equal authority | Create conflict-doc, escalate |

## conflict-doc required frontmatter

```yaml
---
conflict_id: "CONFLICT-{topic}-{YYYYMMDD}"
status: open
topic: "{short topic slug}"
sources:
  - path: "path/to/fragment_a"
    value: "old value"
    date: "YYYY-MM-DD"
  - path: "path/to/fragment_b"
    value: "new value"
    date: "YYYY-MM-DD"
detected_at: "YYYY-MM-DDTHH:MM:SSZ"
resolved_at: null
resolution: null
---
```

## Examples (2 per bucket)

### Evolution examples

**E1** — SPEC status progresses PROPOSED → APPROVED over time:
- fragment_a: `status: PROPOSED` (2026-04-01)
- fragment_b: `status: APPROVED` (2026-05-01)
- timeline entry exists with `until: "2026-05-01"`
- Outcome: EVOLUTION — no contradiction, append entry only

**E2** — Decision entry updated with more recent research:
- fragment_a: `value: "Use PostgreSQL"` (2026-03-01)
- fragment_b: `value: "Use PostgreSQL"` (2026-04-01, reconfirmed)
- Both agree — temporal re-confirmation
- Outcome: EVOLUTION

### Auto-resolve examples

**A1** — Spec overrides old comment:
- fragment_a: comment in code `# version = 1.0` (2026-01-15)
- fragment_b: SPEC frontmatter `version: 2.0` (2026-05-01)
- fragment_b is newer AND from SPEC doc (higher authority)
- Outcome: AUTO_RESOLVE — update comment, log history

**A2** — Newer SPEC supersedes older decision entry:
- fragment_a: decision entry `Auth: JWT only` (2026-02-01)
- fragment_b: SPEC-100 frontmatter `auth: JWT+OAuth2` (2026-04-01)
- fragment_b newer + SPEC authority
- Outcome: AUTO_RESOLVE

### Conflict-doc examples

**C1** — Two SPECs at same date contradict each other:
- fragment_a: SPEC-101 `db: postgres` (2026-05-01)
- fragment_b: SPEC-102 `db: mysql` (2026-05-01)
- Same date, same authority level
- Outcome: CONFLICT_DOC — human must decide

**C2** — Decision entry newer but less authoritative than older SPEC:
- fragment_a: SPEC frontmatter `cache: redis` (2026-04-01)
- fragment_b: meeting note `cache: memcached` (2026-05-01)
- fragment_b newer but meeting note < SPEC authority
- Ambiguous — cannot auto-resolve
- Outcome: CONFLICT_DOC
