# SaviaVaults — Context Dome Server

> **MCP + A2A server for AI agent knowledge vaults with git-backed storage, hybrid search, and content signing.**

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7%2B-blue.svg)](https://www.typescriptlang.org)

SaviaVaults gives AI agents (Claude, GPT, Codex, Cursor) safe, intelligent access to local knowledge vaults. Think of it as a **context dome**: a versioned, searchable, cryptographically-signed repository of everything your project knows — accessible through standard protocols (MCP + A2A) with zero cloud dependency.

---

## Quick Start

```bash
# Install globally
npm install -g savia-vaults

# Create your first vault
savia-vaults init my-knowledge
cd vaults/my-knowledge

# Start MCP server (Claude Code / Codex / Cursor connect automatically)
savia-vaults serve --transport mcp

# Or start A2A server (agent-to-agent sharing)
savia-vaults serve --transport a2a --port 8923

# Search from CLI
savia-vaults search "architecture patterns" --path ./vaults/my-knowledge

# Get stats
savia-vaults stats --path ./vaults/my-knowledge
```

## What is a Context Dome?

A **context dome** is a structured knowledge repository that:
- **Versions** knowledge like code (git-backed, every write is a commit)
- **Signs** content cryptographically (Ed25519 receipts for provenance)
- **Indexes** everything for hybrid search (BM25 + embeddings)
- **Exposes** knowledge through standard AI protocols (MCP + A2A)
- **Protects** against leaks with 6-layer security sandbox

Inspired by [MCPVault](https://github.com/bitbonsai/mcpvault), [Cognithor](https://github.com/Alex8791-cyber/cognithor), and Savia's own [context-dome](https://github.com/gonzalezpazmonica/pm-workspace) pattern (SE-252).

## Architecture

```
AI Agents (Claude, GPT, Codex, Cursor, Gemini)
        │ MCP (stdio)          │ A2A (HTTP/SSE)
        ▼                      ▼
┌─────────────────────────────────────────────┐
│           SaviaVaults Server                 │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐ │
│  │ MCP Layer │  │A2A Layer │  │   CLI    │ │
│  │  9 tools  │  │5 endpoints│  │ 4 cmds   │ │
│  └─────┬─────┘  └────┬─────┘  └────┬─────┘ │
│        │              │              │       │
│  ┌─────▼──────────────▼──────────────▼─────┐ │
│  │           Core Engine                   │ │
│  │  ┌────────┐ ┌────────┐ ┌────────────┐  │ │
│  │  │ Search │ │Storage │ │  Security   │  │ │
│  │  │ BM25+  │ │ Git +  │ │ Sandbox +   │  │ │
│  │  │Embed   │ │Content │ │Signatures   │  │ │
│  │  └────────┘ └────────┘ └────────────┘  │ │
│  └────────────────────────────────────────┘ │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│           Vault (Filesystem + Git)           │
│  vaults/{name}/                              │
│  ├── INDEX.md          (content map)         │
│  ├── MAP.md            (routing table)       │
│  ├── context/          (context domes)       │
│  ├── knowledge/        (domain knowledge)    │
│  ├── decisions/        (ADR records)         │
│  └── .savia-vault      (metadata + receipts) │
└─────────────────────────────────────────────┘
```

## MCP Tools

| Tool | Description | Parameters |
|---|---|---|
| `vault_read` | Read a note by path | `path` (required) |
| `vault_write` | Create/update a note (git-committed, signed) | `path`, `content` (required), `message` |
| `vault_search` | BM25 full-text search with snippets | `query` (required), `pathPrefix`, `maxResults` |
| `vault_list` | List vault contents (directory tree) | `path` (optional) |
| `vault_stats` | Vault statistics (count, size, commits) | — |
| `vault_index` | Rebuild search index | — |
| `vault_diff` | Show git diff for a note | `path` (required) |
| `vault_log` | Show git history for a note | `path` (required), `maxCount` |
| `vault_tags` | List all tags with occurrence counts | — |

## A2A Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/context/{vault}/{path}` | Fetch context by vault and path |
| `GET` | `/search?q={query}&vault={name}&maxResults={n}` | Search across vaults |
| `POST` | `/share` | Share context with another agent (receipt optional) |
| `GET` | `/stats` | Vault statistics |
| `GET` | `/health` | Health check |

## Security Model

| Check | Description |
|---|---|
| **Path Sandbox** | All paths normalized to vault root — traversal blocked (`..`, absolute) |
| **Deny List** | `.git`, `.obsidian`, `node_modules`, `.savia-vault`, `.trash` blocked at any depth |
| **Allow List** | Only `.md`, `.yaml`, `.yml`, `.json`, `.txt`, `.canvas`, `.base` readable |
| **Symlink Protection** | Symlinks pointing outside vault boundary blocked (TOCTOU-safe) |
| **Size Limits** | Files >10MB blocked (configurable) |
| **Depth Limits** | Paths >10 levels deep blocked |
| **Content Signing** | Ed25519 receipts on every write for knowledge provenance |

## Installation

### Linux / macOS

```bash
npm install -g savia-vaults
```

Or use the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/savia-vaults/main/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
npm install -g savia-vaults
```

Or use the install script:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gonzalezpazmonica/savia-vaults/main/scripts/install.ps1" | Invoke-Expression
```

### Requirements
- Node.js 22+
- Git 2.40+
- npm 10+

## Development

```bash
git clone https://github.com/gonzalezpazmonica/savia-vaults.git
cd savia-vaults
npm install
npm run build
npm test
npm run test:coverage
```

## License

MIT. See [LICENSE](LICENSE).

---

*Part of the Savia ecosystem — [pm-workspace](https://github.com/gonzalezpazmonica/pm-workspace)*
