---
rule_id: bitemporal-timeline-schema
title: Bitemporal Timeline Schema
status: ACTIVE
ref: SPEC-182
---

# Bitemporal Timeline Schema — SPEC-182

Distingue **event time** (cuando era cierto) de **transaction time** (cuando se registro).
Top-level fields (`status:`, `priority:`) reflejan el estado actual; `timeline:` preserva
la historia completa.

## Format

```yaml
timeline:
  - from: "2026-04-01"       # event time start (when it became true)
    until: "2026-05-15"      # event time end (absent = still current)
    learned: "2026-04-02"    # transaction time (when we recorded it)
    value: "PROPOSED"
    source: "initial spec creation"
  - from: "2026-05-15"
    learned: "2026-05-15"
    value: "APPROVED"
    source: "merge commit"
```

## Rules

1. `from` — required. ISO-8601 date. Start of validity interval.
2. `until` — optional. Absent means entry is still current.
3. `learned` — required. Date the fact was recorded (transaction time). May be equal or later than `from`.
4. `value` — required. New value of the tracked field (usually `status`).
5. `source` — required. Commit reference, merge number, or human note explaining the change.
6. Entries must be ordered chronologically (ascending `from`).
7. No two entries may have overlapping `from`/`until` intervals.
8. Top-level `status:` MUST equal `value` of the last timeline entry (gate: BATS).

## Invariants

- Last entry has no `until` (still current).
- `until` of entry N equals `from` of entry N+1.
- `learned` >= `from` always (cannot record before the event).

## Usage

```bash
# Append new status with audit trail
scripts/timeline-append.sh status docs/propuestas/SPEC-XXX.md APPROVED "merge commit abc123"

# Query historical status
scripts/timeline-query.sh docs/propuestas/SPEC-XXX.md --at 2026-04-01
```

## Scope

Apply to:
- `docs/propuestas/SPEC-*.md` — status transitions
- `.claude/external-memory/auto/decision/*.md` — decision mutations (optional)

Not applied to: `docs/rules/` files (future SPEC), non-status fields (future).
