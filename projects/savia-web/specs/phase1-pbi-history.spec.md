# Spec: PBI Field-Level History

## Metadatos
- project: savia-web
- phase: 1 — Backlog Data Model
- feature: pbi-history
- status: pending
- developer_type: agent
- depends: none (foundational)

## Objective

Add an append-only audit trail to every PBI file, tracking who changed what field, when, and the previous value. This brings parity with Azure DevOps History tab while keeping everything Git-native.

## Data Model Changes

### New section in every PBI markdown (after `## Notas`)

```markdown
## Historial
| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
```

Rows are **append-only** — never edit or delete existing rows. Newest at the bottom.

### Fields

| Column | Type | Description |
|--------|------|-------------|
| Fecha | ISO 8601 datetime | `YYYY-MM-DD HH:mm` (local time) |
| Autor | @handle | From `active-user.md`. Always with `@` prefix |
| Campo | string | Frontmatter field name that changed |
| Anterior | string | Previous value (empty string if new) |
| Nuevo | string | New value |

### Tracked fields

All frontmatter fields are tracked: `title`, `type`, `state`, `priority`, `estimation_sp`, `estimation_hours`, `assigned_to`, `sprint`, `tags`, `azure_devops_id`, `jira_id`, `github_issue_id`.

Field `updated` is auto-set to current date when any change occurs — not logged separately.

### Creation entry

When a PBI is created, log a single row:

```markdown
| 2026-03-14 10:30 | @monica | _created | | PBI-020 |
```

## Implementation

### 1. Hook: `pbi-history-capture.sh` (PostToolUse, matcher: Edit|Write)

Trigger: any edit to `projects/*/backlog/pbi/PBI-*.md`.

Logic:
1. Read `active-user.md` → extract `@handle`
2. Parse frontmatter BEFORE edit (from git: `git show HEAD:path`)
3. Parse frontmatter AFTER edit (current file)
4. For each field where before != after: append row to `## Historial`
5. Update `updated:` field in frontmatter to today

Edge cases:
- File is new (no git history) → log `_created` entry
- Multiple fields change at once → one row per field, same timestamp
- `## Historial` section doesn't exist → create it before appending

### 2. Command: `/pbi-history {pbi-id}`

```
/pbi-history PBI-004
/pbi-history PBI-004 --field state
/pbi-history PBI-004 --author @alice
/pbi-history PBI-004 --since 2026-03-01
```

Output: formatted table filtered by criteria. Read from `## Historial` section.

### 3. Bridge API endpoint (for web/mobile)

```
GET /backlog/pbi/{id}/history
  ?field=state
  &author=@alice
  &since=2026-03-01
Response: { entries: [{ fecha, autor, campo, anterior, nuevo }] }
```

## Migration

Existing PBIs (PBI-001 to PBI-019) get `## Historial` section appended with a single `_migrated` entry:

```markdown
## Historial
| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-14 00:00 | @system | _migrated | | Added history tracking |
```

## Acceptance Criteria

- [ ] AC-1: Editing a PBI's `state` field appends a history row with correct @author, old and new values
- [ ] AC-2: Editing multiple fields in one save creates one row per changed field, same timestamp
- [ ] AC-3: Creating a new PBI logs a `_created` entry
- [ ] AC-4: `/pbi-history PBI-004` shows all history entries formatted
- [ ] AC-5: `/pbi-history PBI-004 --field state` shows only state changes
- [ ] AC-6: Bridge endpoint returns JSON array of history entries
- [ ] AC-7: Existing PBIs are migrated with `_migrated` entry
- [ ] AC-8: History section is never edited — only appended
