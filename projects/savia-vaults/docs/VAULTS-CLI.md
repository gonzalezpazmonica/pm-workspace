# vaults CLI — Reference Manual

> **SaviaVaults unified operations command** | v0.1.0 | 30+ subcommands | 5 command groups

`vaults` is the single command to manage the complete lifecycle of SaviaVaults context domes: servers, domes, users, backups, confidentiality, and configuration.

## Quick Start

```bash
# Install
npm install -g savia-vaults

# Or: source the install script which registers 'vaults' to /usr/local/bin
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/savia-vaults/main/scripts/install.sh | bash

# Verify
vaults version
vaults help
```

## Command Reference

### vaults server — Start, stop, and monitor vault servers

```bash
vaults server start  --name <dome> [--transport mcp|a2a|both] [--port <n>] [--tls]
vaults server stop   --name <dome> [--force]
vaults server restart --name <dome> [--transport]
vaults server status --name <dome>
vaults server logs   --name <dome> [--follow] [--lines <n>]
```

| Subcommand | Description | Key Options |
|---|---|---|
| `start` | Start MCP/A2A server for a dome | `--name` (required), `--transport` (mcp|a2a|both), `--port` (8923), `--tls` |
| `stop` | Graceful shutdown (SIGTERM) | `--name`, `--force` (SIGKILL) |
| `restart` | Stop + start | Same as start |
| `status` | Check if server is running | `--name` |
| `logs` | View server logs | `--name`, `--follow` (tail -f), `--lines` (default 50) |

**Examples:**
```bash
vaults server start --name my-docs --transport both --port 8923
vaults server logs --name my-docs --follow
vaults server stop --name my-docs --force
```

### vaults dome — Create, manage, and federate context domes

```bash
vaults dome create   <name> [--path <dir>]
vaults dome list     [--format table|json]
vaults dome info     <name>
vaults dome delete   <name> [--force]
vaults dome rename   <name> <new-name>

# Federation
vaults dome federate add     <id> <url> [--token <t>] [--weight <w>]
vaults dome federate remove  <id>
vaults dome federate list
vaults dome federate health

# Content
vaults dome sync     <name> --source <dir>
vaults dome index    <name> [--force]
vaults dome stats    <name>
vaults dome search   <query> [--dome <name>] [--federated] [--max <n>]
```

| Subcommand | Description | Key Options |
|---|---|---|
| `create` | Initialize a new dome (git repo, INDEX.md, MAP.md, config) | `--path` (default: `~/.savia/vaults/<name>`) |
| `list` | List all domes with note count and size | `--format` (table|json) |
| `info` | Detailed dome info (path, notes, size, last commit, confidentiality) | |
| `delete` | Remove a dome permanently | `--force` (skip confirmation) |
| `rename` | Rename a dome | |
| `federate add` | Register a remote dome for cross-dome search | `--weight` (0.1-2.0), `--token` |
| `federate remove` | Remove a federated dome | |
| `federate list` | List all federated domes | |
| `federate health` | Health check all federated domes | |
| `sync` | Sync content from external directory into dome | `--source` |
| `index` | Rebuild search index | `--force` |
| `stats` | Show dome statistics | |
| `search` | Search dome content (and federated if `--federated`) | `--dome`, `--federated`, `--max` |

**Examples:**
```bash
vaults dome create team-knowledge
vaults dome federate add specs http://192.168.1.50:8924 --token "$TOKEN" --weight 1.5
vaults dome search "microservices" --federated --max 20
vaults dome sync my-docs --source ~/Documents/project-docs
```

### vaults user — Manage vault users and permissions

```bash
vaults user add     <username> [--role admin|reader|writer] [--dome <name>]
vaults user remove  <username> [--dome <name>]
vaults user list    [--dome <name>]
vaults user passwd  <username> [--dome <name>]
vaults user perm    <username> <permission> <true|false> [--dome <name>]
```

| Role | Permissions |
|---|---|
| `admin` | Full access: read, write, delete, federate, backup, manage users |
| `writer` | Read + write notes, cannot delete dome or manage users |
| `reader` | Read-only access to notes |

| Permission | Description |
|---|---|
| `read` | Read notes |
| `write` | Create/update notes |
| `delete` | Delete notes |
| `federate` | Manage federated domes |
| `backup` | Create/restore backups |
| `admin` | Manage users and dome configuration |

**Examples:**
```bash
vaults user add alice --role admin --dome team-docs
vaults user perm bob write true --dome team-docs
vaults user passwd alice --dome team-docs
```

### vaults backup — Create, restore, and schedule backups

```bash
vaults backup create     [--name <dome>] [--output <dir>] [--compress]
vaults backup list       [--format table|json]
vaults backup restore    <backup-id> [--target <dir>] [--dry-run]
vaults backup schedule   <cron-expr> [--name <dome>] [--output <dir>]
vaults backup unschedule <schedule-id>
vaults backup status
```

| Subcommand | Description |
|---|---|
| `create` | Create a backup (full copy or tar.gz) |
| `list` | List all backups |
| `restore` | Restore a backup to target directory |
| `schedule` | Add a cron entry for automatic backups |
| `unschedule` | Remove a scheduled backup by cron line number |
| `status` | Show all scheduled backup cron entries |

**Examples:**
```bash
vaults backup create --name my-docs --compress
vaults backup schedule "0 2 * * *" --name my-docs --output /mnt/backups
vaults backup restore backup-my-docs-20260730 --target /tmp/restore --dry-run
vaults backup unschedule 3
```

### vaults confidentiality — Set and audit confidentiality levels

```bash
vaults confidentiality set   <N1|N2|N3|N4> --dome <name>
vaults confidentiality get   --dome <name>
vaults confidentiality list
vaults confidentiality audit --dome <name> [--output <file>]
```

| Level | Name | Description |
|---|---|---|
| **N1** | Public | Open information, shareable freely |
| **N2** | Internal | Team-internal, not for public distribution |
| **N3** | Confidential | Sensitive business data, restricted access |
| **N4** | Restricted | Highly sensitive, legal/compliance required |

**Examples:**
```bash
vaults confidentiality set N2 --dome team-docs
vaults confidentiality audit --dome secrets --output audit-report.md
```

### vaults config — Manage vault configuration

```bash
vaults config init
vaults config show      [--format json|yaml]
vaults config edit      [--editor <path>]
vaults config validate  [--strict]
```

**Examples:**
```bash
vaults config show
EDITOR=nano vaults config edit
vaults config validate --strict
```

### vaults health — System health check

```bash
vaults health
```

Shows: vault root status, dome count, running servers, backup count, scheduled tasks.

### vaults search — Quick search across domes

```bash
vaults search <query> [--dome <name>] [--federated] [--max <n>]
```

Shorthand for `vaults dome search`. Searches local dome (or all domes if `--federated`).

### vaults stats — Quick dome statistics

```bash
vaults stats <name>
```

Shorthand for `vaults dome stats`.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SAVIA_VAULT_ROOT` | `~/.savia/vaults` | Root directory for all domes |
| `EDITOR` | `vi` | Editor for `vaults config edit` |

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Error (missing argument, dome not found, etc.) |

## Test Results

```
59 PASS | 0 FAIL — 11 test categories
  ✓ Help & Version (4)
  ✓ Sub-command help (6)
  ✓ Dome CRUD (12)
  ✓ Content & Search (4)
  ✓ User management (10)
  ✓ Federation (7)
  ✓ Confidentiality (5)
  ✓ Backup (4)
  ✓ Config (1)
  ✓ Server commands (3)
  ✓ Health (3)
```
