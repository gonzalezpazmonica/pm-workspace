---
name: savia-hub
description: Central hub for accessing Savia knowledge and tools
---

---

# /savia-hub — Shared Knowledge Repository

## Description
Manage SaviaHub — the shared Git repository for company, clients, users, and project metadata. Works local-first with optional remote sync. Supports offline "flight mode".

## Subcommands

### `/savia-hub init [--remote URL]`
Initialize SaviaHub structure. Without `--remote`: creates local repo at `$SAVIA_HUB_PATH` (default: `~/.savia-hub`). With `--remote`: clones existing hub.

### `/savia-hub status`
Show sync status: local/remote mode, flight mode, pending changes, last sync timestamp, divergence summary.

### `/savia-hub push`
Upload local changes to remote. Fails gracefully if no remote configured or offline. Shows diff summary before pushing.

### `/savia-hub pull`
Download remote changes to local. Detects conflicts and proposes resolution. Updates `.savia-hub-config.md` with last sync timestamp.

### `/savia-hub flight-mode on|off`
Toggle offline mode. When ON: all writes go to local only, queued for later sync. When OFF: triggers immediate sync if remote is configured.

## Prerequisites
- `@.claude/rules/domain/savia-hub-config.md` — Structure and path configuration
- `@.claude/rules/domain/savia-hub-offline.md` — Flight mode and sync queue rules

## Behavior

### Init flow
```
1. Check if SaviaHub already exists at $SAVIA_HUB_PATH
2. If exists → show status, offer pull
3. If not exists:
   a. Without --remote → create local Git repo + directory structure
   b. With --remote → git clone + verify structure
4. Create .savia-hub-config.md with defaults
5. Show structure summary
```

### Directory structure created on init
```
savia-hub/
├── company/
│   ├── identity.md          ← Company name, sector, conventions
│   └── org-chart.md         ← Organizational structure
├── clients/
│   ├── .index.md            ← Client index (auto-maintained)
│   └── {slug}/              ← One directory per client (Era 31)
├── users/
│   └── {handle}/profile.md  ← Public user profile
└── .savia-hub-config.md     ← Local config (sync mode, paths)
```

### Push/Pull flow
```
1. Check remote configured → error if not
2. Check flight mode → warn if ON
3. Run git status → show pending changes
4. Confirm with PM
5. Execute git push/pull
6. Handle conflicts: show diff, ask PM to resolve
7. Update last_sync in .savia-hub-config.md
```

### Flight mode
```
ON:  All writes → local only. Queue in .sync-queue.jsonl
OFF: Drain queue → push to remote. Resume normal sync
```

## Output format
```
══════════════════════════════════════════
  SaviaHub Status
══════════════════════════════════════════
  Mode:        Local + Remote
  Flight Mode: ❌ OFF
  Remote:      https://github.com/org/savia-hub
  Last Sync:   2026-03-05 14:30 UTC
  Pending:     2 local changes (clients/acme/profile.md, company/identity.md)
  Clients:     3 (acme-corp, techstart, medisalud)
  Users:       5
══════════════════════════════════════════
```

## Error handling
- No SAVIA_HUB_PATH → use default `~/.savia-hub`
- Remote unreachable → suggest flight-mode on
- Conflict on pull → show diff, never auto-resolve
- Init on existing → show status, don't overwrite
