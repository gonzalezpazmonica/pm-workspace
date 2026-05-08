---
globs: ["README.md", "CHANGELOG.md"]
---

# Rule: Managed Content Markers — Safe Auto-Generated Content

**Pattern:** ash-project/usage_rules inspired approach for safe regeneration of auto-generated sections.

## Core Rule

All auto-generated content MUST use managed markers. This protects manual content while allowing safe automatic updates.

**Marker Format:**
```markdown
<!-- managed-by: pm-workspace | section: {name} | updated: {ISO-date} -->
... auto-generated content ...
<!-- end-managed: {name} -->
```

## Integration Points

Run `/managed-sync` BEFORE:
- `/plugin-export` — ensure plugin.json capability counts fresh
- Release preparation — ensure all auto-generated sections updated
- Major version bumps — full audit of all markers

Run `/managed-scan` in:
- Sprint retro — identify stale sections (age > 7 days)
- Release planning — full marketplace audit

## Enforcement

- Marker format is **immutable** — changes require migration plan
- Content outside markers NEVER modified — technical debt blocker if violated
- Timestamp must be ISO-8601 (e.g., 2026-03-07)
- Missing/malformed markers block regeneration

## Use Cases

| File | Section | Purpose |
|---|---|---|
| CLAUDE.md | skills-catalog | List all skills with counts |
| CLAUDE.md | commands-summary | Category counts per command group |
| CLAUDE.md | agents-registry | Registry of all available agents |
| pm-workflow.md | command-counts | Category trends quarter-over-quarter |
| plugin.json | capabilities | Computed capability counts |
| README.md | feature-list | Feature matrix auto-generated |

## Related

- Skill: `.opencode/skills/managed-content/SKILL.md`
- Command: `/managed-sync` — Regenerate all marked sections
- Command: `/managed-scan` — Audit all markers with freshness
