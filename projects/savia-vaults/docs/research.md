# SaviaVaults — Research Analysis

> **Date**: 2026-07-30 | **Researcher**: Savia (Mónica)
> **Sources**: GitHub, npm, web

## Executive Summary

The "context dome server" space is nascent but growing rapidly. **MCPVault** (bitbonsai/mcpvault) is the clear leader with 2k+ stars, v0.12.5 in production, MIT license, and comprehensive security hardening. No existing project combines MCP + A2A + Git-backed storage + content signing — this is SaviaVaults' unique value proposition.

## Detailed Analysis

### MCPVault (bitbonsai/mcpvault) — Reference Implementation
- **Stack**: TypeScript, MCP SDK, minisearch (BM25), yaml
- **Maturity**: Production (v0.12.5, 100+ PRs, 2 security advisories resolved)
- **Strengths**: Security model (path sandbox, deny lists, symlink protection, TOCTOU), BM25 search, wiki links, frontmatter AST preservation, Obsidian integration
- **Weaknesses**: Obsidian-specific, no Git backing, no A2A, no content signing
- **License**: MIT — safe for adaptation
- **Architectural patterns to copy**: Security layer (6 checks), tool registration pattern, search engine design

### Cognithor (Alex8791-cyber/cognithor) — Comprehensive Agent OS
- **Stack**: Python 3.12+, 19 LLM providers, 18 channels, 145 MCP tools
- **Maturity**: Active development (152 stars)
- **Strengths**: Multi-provider, 6-tier memory, local-first, agent packs marketplace
- **Weaknesses**: Very complex (monolithic), no A2A protocol, no Git backing
- **License**: Apache 2.0 — safe for adaptation
- **Architectural patterns to copy**: Layered memory architecture, multi-channel design

### vault-sync (graphlit/vault-sync) — Git Sync Pattern
- **Stack**: Shell, simple-git wrapper
- **Maturity**: Active (2 stars)
- **Strengths**: Simple git-backed vault sync for Claude Code/Codex
- **Weaknesses**: No MCP, no search, shell-only, no security layer
- **Architectural patterns to copy**: Git sync workflow, multi-frontend support

### second-brain-kit (xytek12/second-brain-kit) — Routing Engine
- **Stack**: Shell, Claude Code skill
- **Maturity**: Active (0 stars)
- **Strengths**: INDEX/MAP routing pattern, Claude Code native, no Obsidian requirement
- **Weaknesses**: Skill-only (not a server), no MCP, no search
- **Architectural patterns to copy**: INDEX.md + MAP.md dual-index pattern, context dome integration

## Design Decisions

### Why TypeScript over Python?
- MCP SDK is TypeScript-native (Python SDK is less mature)
- npm distribution model for `npx savia-vaults` (zero-install)
- Type safety for security-critical code
- Larger ecosystem of MCP tooling

### Why Git-backed?
- Immutable audit trail for knowledge changes
- PR workflow for knowledge contributions
- Rollback capability (knowledge is code)
- Content-addressed storage (SHA hashes as identifiers)

### Why dual protocol (MCP + A2A)?
- MCP: universal AI agent access (Claude, GPT, Codex, Cursor, Gemini)
- A2A: agent-to-agent context sharing (multi-agent workflows)
- Different use cases: MCP for human→agent, A2A for agent→agent

### Why Ed25519 signing?
- Compact signatures (64 bytes vs 256+ for RSA)
- Fast verification
- Cryptographic proof of knowledge provenance
- Compatible with Savia's confidentiality signing infrastructure
