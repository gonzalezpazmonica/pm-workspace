---
name: savia-hub
description: Central hub for accessing Savia knowledge and tools
tier: extended
---

---

# /savia-hub — Shared Knowledge Repository

## Description
Manage SaviaHub — the shared Git repository for company, clients, users, and project metadata. Works local-first with optional remote sync. Supports offline "flight mode".

## Subcommands

Each subcommand runs a deterministic script; exit codes and edge cases are in the
`savia-hub-sync` skill and covered by `tests/test-savia-hub-sync.bats`.

### `/savia-hub init [--remote URL]`
`bash scripts/savia-hub-init.sh [--remote URL]`. Without `--remote`: creates local repo (branch `main`) at `$SAVIA_HUB_PATH` (default: `~/.savia-hub`). With `--remote`: clones existing hub; an empty remote gets the structure committed locally, nothing pushed. Idempotent.

### `/savia-hub status`
`bash scripts/savia-hub-sync.sh status`. Flight mode, pending changes, last sync and a `Sync:` line that only says `sincronizado` when nothing is ahead, behind or uncommitted; otherwise `solo local` or `remote inalcanzable`.

### `/savia-hub push`
`bash scripts/savia-hub-sync.sh push` previews the file list without pushing; after the PM confirms, `push --yes`. Exit 3 without remote, 4 in flight mode, 5 unreachable, 7 if the remote is ahead (pull first).

### `/savia-hub pull`
`bash scripts/savia-hub-sync.sh pull`. Rebase onto the remote; on conflict lists files, aborts the rebase (local data intact) and exits 8 — the PM resolves by hand. Updates `last_sync`.

### `/savia-hub flight-mode on|off`
`bash scripts/savia-hub-sync.sh flight on|off`. ON blocks push and pull (exit 4). OFF only clears the flag; run pull and push afterwards.

## Prerequisites
- `@docs/rules/domain/savia-hub-config.md` — Structure and path configuration
- `@docs/rules/domain/savia-hub-offline.md` — Flight mode and sync queue rules

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
2. Check flight mode → block if ON (exit 4) unless --force
3. Fetch remote → error if unreachable (exit 5), never report "synced"
4. Show pending files (push preview) → confirm with PM → push --yes
5. Handle conflicts: list files, abort rebase, PM resolves by hand
6. Update last_sync in .savia-hub-config.md
```

### Flight mode
```
ON:  push and pull blocked. Pending work = git status (no script writes .sync-queue.jsonl)
OFF: clears the flag only. Run pull, then push
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
