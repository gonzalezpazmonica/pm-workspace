# Command: managed-sync

Regenerate all managed sections in workspace files. Safe preview mode by default.

## Usage

```
/managed-sync [file] [--apply] [--verbose]
```

## Parameters

- `file` (optional) — specific file path to sync (default: all managed files)
- `--apply` — write changes to disk (default: preview mode)
- `--verbose` — detailed diff output

## Flow

1. **Scan** — Find all files with managed markers
2. **Regenerate** — Re-generate content between markers
3. **Validate** — Verify marker integrity and freshness
4. **Preview** — Show diff (unless `--apply`)
5. **Write** — Save changes if `--apply` flag present

## Output

```
📋 Scanning for managed markers...
Found: 4 files with 6 managed sections

  file | section | updated | status
  -----|---------|---------|--------
  CLAUDE.md | skills-catalog | 2026-03-02 | FRESH (5 days)
  CLAUDE.md | commands-summary | 2026-02-28 | STALE (10 days)
  README.md | feature-list | 2026-01-15 | OLD (52 days)

🔄 Regenerating 3 sections...
✅ Regenerated: 3 sections
⚠️  Needs attention: feature-list (52 days old)

📄 Preview (use --apply to write):
  ...diff output...
```

## Safety

- Content outside markers is NEVER modified
- Preview shows exactly what will change
- Markers include timestamp of last regeneration
- Validation fails if markers malformed — shows error with line number

## Related

- `/managed-scan` — Audit all markers with freshness status
- `.claude/skills/managed-content/SKILL.md` — Marker format and workflow
- `.claude/rules/domain/managed-content.md` — Enforcement rules
