# SaviaVaults — Context Dome Server (MCP + A2A)

> **Project**: savia-vaults | **SE-286** | **Status**: in-progress
> **License**: MIT | **Language**: TypeScript | **Runtime**: Node.js 22+
> **Specs**: 7 (SE-280..SE-286) | **Tests**: 14 files (7 passing, 7 blocked) | **Branch**: agent/se286-vaults-producto

## Project State (2026-08-01)

Local-first context dome server. MCP + A2A transports. Git-backed, BM25, Ed25519 signing, 6-layer security.

**Honest assessment**: The README previously claimed the package was installable via `npm install -g`. That was false. 7 source modules were documented in CLAUDE.md as existing when they didn't. This spec (SE-286) is the correction plan.

### Modules — Implemented (9 source files)

| Module | File | Purpose |
|---|---|---|
| Types | `src/federation/types.ts` | FederatedDome, FederationConfig, SearchResult |
| Registry | `src/federation/registry.ts` | CRUD for federated domes |
| Cache | `src/federation/cache.ts` | LRU cache, 5min TTL, 1000 entries |
| A2A Client | `src/federation/a2a-client.ts` | HTTP client with auth, timeout |
| Federation Search | `src/federation/search.ts` | Parallel queries, merge, dedup, interleave |
| Circuit Breaker | `src/federation/circuit-breaker.ts` | CLOSED->OPEN->HALF_OPEN lifecycle |
| Audit Logger | `src/federation/audit-logger.ts` | JSONL audit trail, daily rotation |
| Hash Verify | `src/federation/hash-verify.ts` | Content integrity verification |
| Config Schema | `src/config/schema.json` | JSON Schema for config |

### Modules — NOT implemented (to build via SE-286)

| Module | File |
|---|---|
| Core Types | `src/types.ts` |
| Storage | `src/storage/index.ts` |
| Search | `src/search/index.ts` |
| Security | `src/security/index.ts` |
| MCP Server | `src/server/mcp.ts` |
| Rate Limiter | `src/server/ratelimit.ts` |
| CLI | `src/cli/index.ts` |

### Test Matrix

| Layer | Files | Status |
|---|---|---|
| Unit — federation (registry, cache, search, types, circuit-breaker, hash-verify, audit) | 7 | 7 PASS |
| Unit — storage, search, security, ratelimit | 4 | BLOCKED (import non-existent modules) |
| Integration — vault workflow, federated search | 2 | 1 PASS (federation), 1 BLOCKED (vault-workflow) |
| E2E — MCP protocol | 1 | BLOCKED (imports non-existent MCP server) |

### Scripts

| Script | Purpose |
|---|---|
| `install.sh` / `install.ps1` | Dependency check + install |
| `start-server.sh` / `stop-server.sh` | Lifecycle with PID file |
| `index-docs.sh` | Index Savia docs/ -> vault (1028 files) |
| `e2e-test-dome.sh` | Dome vs filesystem parity |
| `e2e-test-federate.sh` | 2-vault federation E2E |

### Active spec

SE-286 (vaults-producto.spec.md) — 7 slices, ~64h, converting skeleton to verifiable product.
