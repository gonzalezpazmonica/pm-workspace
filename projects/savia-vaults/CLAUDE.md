# SaviaVaults — Context Dome Server (MCP + A2A)

> **Project**: savia-vaults | **SE-280/281/282/283** | **Status**: active
> **License**: MIT | **Language**: TypeScript | **Runtime**: Node.js 22+
> **Specs**: 4 (MVP, Gaps, Federation, Hardening) | **Tests**: 90+ | **Slices**: 23

## Project State (2026-07-30)

Local-first context dome server. MCP + A2A transports. Git-backed, BM25, Ed25519 signing, 6-layer security.

### Modules (14 source files)

| Module | File | Purpose |
|---|---|---|
| Types | `src/types.ts` | Core interfaces (VaultConfig, Note, Search, Receipt) |
| Security | `src/security/index.ts` | 6-layer sandbox (path, deny, allow, symlink, size, depth) |
| Storage | `src/storage/index.ts` | Git-backed CRUD, frontmatter, tags, diff, log |
| Search | `src/search/index.ts` | BM25 engine (minisearch), tag indexing |
| MCP Server | `src/server/mcp.ts` | 9 MCP tools via stdio |
| A2A Server | `src/server/a2a.ts` | HTTP REST: /search, /context, /share, /stats, /health |
| Rate Limiter | `src/server/ratelimit.ts` | Token bucket for A2A throttling |
| CLI | `src/cli/index.ts` | init, serve, search, stats, federate |
| Config | `src/config/schema.json` | JSON Schema for config |
| Federation | `src/federation/types.ts` | FederatedDome, FederationConfig, SearchResult |
| Federation | `src/federation/registry.ts` | CRUD for federated domes |
| Federation | `src/federation/cache.ts` | LRU cache, 5min TTL, 1000 entries |
| Federation | `src/federation/a2a-client.ts` | HTTP client with auth, timeout |
| Federation | `src/federation/search.ts` | Parallel queries, merge, dedup, interleave |
| Hardening | `src/federation/circuit-breaker.ts` | CLOSED→OPEN→HALF_OPEN lifecycle |
| Hardening | `src/federation/audit-logger.ts` | JSONL audit trail, daily rotation |
| Hardening | `src/federation/hash-verify.ts` | Content integrity verification |

### Test Matrix (90+ tests)

| Layer | Count |
|---|---|
| Unit — security, storage, search, ratelimit | 53 |
| Unit — federation (registry, cache, search, types) | 20 |
| Unit — hardening (circuit-breaker, hash-verify, audit) | 17 |
| Integration — vault workflow, federated search | 5 |
| E2E — MCP protocol | 4 |
| E2E — Dome vs Direct | 22 PASS |
| E2E — Federation | 21 PASS |

### Scripts

| Script | Purpose |
|---|---|
| `install.sh` / `install.ps1` | Dependency check + global install |
| `start-server.sh` / `stop-server.sh` | Lifecycle with PID file |
| `index-docs.sh` | Index Savia docs/ → vault (1028 files) |
| `e2e-test-dome.sh` | Dome vs filesystem parity (22 PASS) |
| `e2e-test-federate.sh` | 2-vault federation E2E (21 PASS) |

### Quick Start

```bash
npm install -g savia-vaults
savia-vaults init my-knowledge
savia-vaults serve --transport mcp
savia-vaults federate add remote http://other:8924
savia-vaults search "architecture" --federated
```
