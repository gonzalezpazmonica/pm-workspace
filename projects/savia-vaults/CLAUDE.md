# SaviaVaults — Context Dome Server (MCP + A2A)

> **Project**: savia-vaults | **SE-280** | **Status**: draft
> **License**: MIT | **Language**: TypeScript | **Runtime**: Node.js 22+

## Research Analysis

### Landscape (July 2026)

| Project | Stars | License | Stack | Maturity | Key Features |
|---|---|---|---|---|---|
| [MCPVault](https://github.com/bitbonsai/mcpvault) | 2k+ | MIT | TypeScript | v0.12.5 (production) | MCP Obsidian bridge, BM25, wiki links, frontmatter, security hardening |
| [Cognithor](https://github.com/Alex8791-cyber/cognithor) | 152 | Apache 2.0 | Python | Active | Agent OS, 19 LLM, 145 MCP tools, 6-tier memory, local-first |
| [knowledge-vault-mcp](https://github.com/danieljhkim/knowledge-vault-mcp) | 2 | — | Python | Early | Obsidian MCP for planning, decision tracking |
| [vault-sync](https://github.com/graphlit/vault-sync) | 2 | — | Shell | Active | Git-backed vault sync for Claude Code/Codex |
| [second-brain-kit](https://github.com/xytek12/second-brain-kit) | 0 | — | Shell | Active | INDEX/MAP routing, Claude Code skill, no Obsidian required |

### Architectural Patterns Identified

1. **MCP Transport** (MCPVault, knowledge-vault-mcp): Universal AI agent access via Model Context Protocol
2. **Local-First Design** (Cognithor, second-brain-kit): Zero cloud dependency, filesystem-based storage
3. **Git-Backed Storage** (vault-sync): Version-controlled knowledge, PR-based updates
4. **Content-Addressed Index** (second-brain-kit): INDEX/MAP routing engine for fast retrieval
5. **Multi-Protocol** (Cognithor): MCP + REST + WebSocket + Telegram/Discord channels
6. **Security Sandbox** (MCPVault): Path normalization, deny lists, symlink blocking, TOCTOU hardening

### Gap Analysis — What SaviaVaults Adds

| Feature | MCPVault | Cognithor | SaviaVaults |
|---|---|---|---|
| MCP transport | Yes | Yes | Yes |
| A2A transport | No | No | **Yes** (agent-to-agent context sharing) |
| Git-backed | No | No | **Yes** (content-addressed, PR workflow) |
| Context dome pattern | No | No | **Yes** (bus factor protection, knowledge ownership) |
| Multi-frontend | Skill-based | CLI | **Native MCP + A2A SDK** |
| Embedding search | No | Yes | **Yes** (local embeddings + BM25 hybrid) |
| Content signing | No | Ed25519 | **Yes** (Ed25519 receipts + audit trail) |
| Path sandbox | Yes | Partial | **Yes** (extended: deny lists + allow lists + depth limits) |

## SaviaVaults Architecture

```
┌─────────────────────────────────────────────┐
│              AI Agents (Claude, GPT, etc.)   │
└──────────┬──────────────┬───────────────────┘
           │ MCP (stdio)  │ A2A (HTTP/SSE)
           ▼              ▼
┌─────────────────────────────────────────────┐
│           SaviaVaults Server                 │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐ │
│  │ MCP Layer │  │A2A Layer │  │ CLI Tool │ │
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

## Technical Decisions

- **TypeScript** — ecosystem alignment (MCP SDK is TS-native), type safety, npm distribution
- **MCP stdio transport** — universal AI agent access, zero network config
- **A2A HTTP/SSE transport** — agent-to-agent context sharing for multi-agent workflows
- **Git-backed storage** — every vault is a git repo, content-addressed, PR workflow
- **BM25 + local embeddings hybrid search** — no external API dependency, sovereign
- **Ed25519 content signing** — cryptographic receipts for knowledge provenance
- **Path sandbox with deny/allow lists** — defense in depth, inspired by MCPVault's security model
- **Context dome pattern** — knowledge ownership tracking, bus factor protection (from Savia SE-252)

## Quick Start

```bash
npm install -g savia-vaults
savia-vaults init my-knowledge
savia-vaults serve --transport mcp    # stdio MCP server
savia-vaults serve --transport a2a    # HTTP A2A server
```

## MCP Tools

| Tool | Description |
|---|---|
| `vault_read` | Read a note by path |
| `vault_write` | Create/update a note |
| `vault_search` | Hybrid BM25 + embedding search |
| `vault_list` | List vault contents (directory tree) |
| `vault_stats` | Vault statistics (size, count, domains) |
| `vault_index` | Regenerate INDEX.md and MAP.md |
| `vault_diff` | Show git diff for a note |
| `vault_log` | Show git history for a note |
| `vault_tags` | List all tags with counts |

## A2A Endpoints

| Method | Path | Description |
|---|---|---|
| A2A `query` | `/context/{vault}/{path}` | Fetch context by path |
| A2A `search` | `/search?q={query}&vault={name}` | Search across vaults |
| A2A `share` | `/share` | Push context to another agent |
| A2A `receipt` | `/receipt/{hash}` | Verify content signature |

## Security Model

- **Vault Boundary**: All paths normalized to vault root, no traversal
- **Deny List**: `.git`, `.obsidian`, `node_modules`, `.savia-vault` blocked at any depth
- **Allow List**: Only `.md`, `.yaml`, `.json`, `.txt` files readable by default (configurable)
- **Symlink Protection**: Symlinks pointing outside vault boundary blocked
- **Content Signing**: Ed25519 signatures on all writes, verifiable via receipts
- **Git Integrity**: Every write committed, every delete soft (git revert possible)
