---
name: company-messaging
description: >
  Knowledge module for Company Savia messaging: message lifecycle,
  @handle resolution, encryption protocol, privacy rules.
disable-model-invocation: false
user-invocable: false
allowed-tools: [Read, Bash, Glob, Grep]
---

# Company Messaging — Skill

## Overview

Company Savia enables async messaging between Savia instances across a company
using a shared Git repository. Messages are plain markdown files with YAML
frontmatter, stored in personal inboxes and a company-wide inbox.

## Architecture

```
company-savia-repo/
├── company-inbox/           ← Announcements (persistent, all members)
├── team/{handle}/
│   ├── savia-inbox/
│   │   ├── unread/          ← New messages (moved to read/ when opened)
│   │   └── read/            ← Read messages (archive)
│   └── public/
│       └── pubkey.pem       ← Public key for E2E encryption
└── directory.md             ← @handle → name/role mapping
```

## Message Lifecycle

1. **Compose**: Savia creates message file with YAML frontmatter
2. **Deliver**: File placed in `team/{recipient}/savia-inbox/unread/`
3. **Sync**: `git add + commit + push` delivers to shared repo
4. **Receive**: Recipient does `git pull` (via `/company-repo sync`)
5. **Read**: Message moved from `unread/` to `read/`
6. **Reply**: New message with `thread` and `reply_to` fields set

## @Handle Resolution

Handles are resolved from `directory.md`:

```markdown
| Handle | Name | Role | Status |
|--------|------|------|--------|
| @admin | Admin Name | Admin | active |
```

Parse: `grep -oP '@\K\w+' directory.md` to list available handles.

## Encryption Protocol

**Hybrid RSA-4096 + AES-256-CBC** (openssl only, zero deps):

1. **Keygen**: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096`
2. **Encrypt**: Generate random AES-256 key → encrypt body → encrypt AES key with RSA pubkey
3. **Deliver**: Base64-encoded `encrypted_key:::encrypted_body` in message file
4. **Decrypt**: RSA-decrypt AES key → AES-decrypt body

Keys stored at `$HOME/.pm-workspace/savia-keys/` (private.pem: chmod 600).
Public keys published to `team/{handle}/public/pubkey.pem` in the repo.

## Privacy Rules

Before any `git push` to the company repo:

1. **Layer 1**: `validate_privacy()` — PATs, tokens, IPs, connection strings
2. **Layer 2**: Scan messages for secrets in YAML frontmatter and body
3. **Layer 3**: Scan documents in `team/{handle}/documents/`

Script: `scripts/privacy-check-company.sh`

## Message Types

| Type | Location | Persist | Encrypted |
|------|----------|---------|-----------|
| Direct message | `team/{handle}/savia-inbox/` | Until archived | Optional |
| Reply | `team/{handle}/savia-inbox/` | Until archived | Optional |
| Announcement | `company-inbox/` | Permanent | Never |
| Broadcast | Each recipient's inbox | Until archived | Optional |

## Threading

Messages form threads via two fields:
- `thread`: ID of the first message in the thread
- `reply_to`: ID of the message being directly replied to

If original message has no `thread`, the reply uses the original's `id` as thread.

## Read Tracking

- **Personal messages**: moved from `unread/` to `read/` directory
- **Announcements**: tracked in `$HOME/.pm-workspace/company-inbox-read.log`
  (pipe-delimited: `timestamp|message_id`)

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/company-repo.sh` | Repo lifecycle (create/connect/sync) |
| `scripts/savia-messaging.sh` | Message CRUD operations |
| `scripts/savia-crypto.sh` | E2E encryption (RSA+AES) |
| `scripts/privacy-check-company.sh` | Privacy validation |
| `scripts/company-repo-templates.sh` | Repo structure templates |

## Session-Init Integration

When company repo is configured, `session-init.sh` shows unread count:
```
📬 3 mensaje(s) · 1 anuncio(s)
```
This is filesystem-only (no network calls, no git pull).
