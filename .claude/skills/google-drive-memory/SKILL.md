---
name: google-drive-memory
description: Persist project memory and context in Google Drive as Git alternative
summary: |
  Persiste memoria de proyecto en Google Drive como alternativa a Git.
  Sincroniza context, decisiones y notas. Util cuando
  el equipo no usa Git para documentacion.
maturity: stable
context: fork
category: "reporting"
tags: ["google-drive", "memory", "sync", "non-technical"]
priority: "low"
---

# Google Drive Memory — Persistence for Non-Technical Users

## Purpose

For POs, stakeholders, and non-technical users who don't use Git, Google Drive Memory provides a **bidirectional sync system** that keeps project context, memory, and specifications updated.

Instead of Git commits and branches, changes are timestamped and synced directly to Drive folders.

---

## Phase 1: Setup — Drive Folder Structure

Configure a standardized folder hierarchy:
```
PM-Workspace/
├── {project}/
│   ├── context/          ← CLAUDE.md, equipo.md, reglas-negocio.md
│   ├── memory/           ← agent-notes, lessons-learned, decisions
│   ├── specs/            ← SDD specs, technical documentation
│   ├── reports/          ← output files, analysis, generated reports
│   └── discovery/        ← JTBD, PRD docs, research
```

---

## Phase 2: Sync Protocol — Bidirectional Sync

**Upload**: `/drive-sync {project} push` after generating reports/specs/memory  
**Download**: `/drive-sync {project} pull` at session start  
**Status**: `/drive-sync {project} status` to check sync state

Conflict resolution: Timestamp-based, local changes win by default.

---

## Phase 3: Permissions Mapping — Role-Based Access

| Role | context/ | memory/ | specs/ | reports/ | discovery/ |
|------|---------|--------|-------|----------|-----------|
| PM | RW | RW | RW | RW | RW |
| Developer | R | R | RW | R | R |
| PO | R | - | R | R | RW |
| Stakeholder | - | - | - | R | R |

Set via `/drive-setup {project}` command.

---

## Phase 4: MCP Integration

Use **google-drive MCP server** for file operations:
- `uploadFile()` — Upload local file to Drive
- `downloadFile()` — Download Drive file to local
- `listFiles()` — Show folder contents
- `deleteFile()` — Remove from Drive

OAuth scope: `drive.file` (folder-level access only). Never store tokens in Drive.

---

## Security

- OAuth scopes limited to PM-Workspace folder
- No API tokens stored in Drive (local .env only)
- Google Drive encryption in-transit & at-rest
- Audit trail maintained by Google Drive
