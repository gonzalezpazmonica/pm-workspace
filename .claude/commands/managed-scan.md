---
name: managed-scan
description: Scan managed content for stale or outdated sections
---

---

# Command: managed-scan

Scan workspace for all managed markers and report freshness status.

## Usage

```
/managed-scan [--json]
```

## Parameters

- `--json` — output in JSON format (for tooling)

## Flow

1. Find all managed markers in workspace
2. Extract: file, section name, last updated timestamp
3. Calculate freshness (days since update)
4. Report status: FRESH (< 7 days), STALE (7-30 days), OLD (> 30 days)
5. Suggest: which sections to regenerate soon

## Output

```
📊 Managed Content Audit — 2026-03-07

File | Section | Updated | Days | Status
-----|---------|---------|------|--------
CLAUDE.md | skills-catalog | 2026-03-05 | 2 | ✅ FRESH
CLAUDE.md | commands-summary | 2026-02-28 | 7 | ⚠️ STALE
CLAUDE.md | agents-registry | 2026-01-30 | 36 | 🔴 OLD
README.md | feature-list | 2026-01-01 | 66 | 🔴 OLD

Summary:
  FRESH (< 7d): 1 section
  STALE (7-30d): 1 section
  OLD (> 30d): 2 sections

Next step: Run /managed-sync to regenerate stale/old sections
```

## Related

- `/managed-sync [file]` — Regenerate managed sections
- `.opencode/skills/managed-content/SKILL.md` — Marker format and workflow
