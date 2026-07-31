# SaviaVaults — Context Dome Server (MCP + A2A)

> **Status (2026-08-01): en construccion activa.** La capa de federacion funciona y tiene 7 tests pasando sobre codigo real. El nucleo (storage, search, security) y los servidores MCP/A2A estan en implementacion — ver SE-286. El comando `npm install -g savia-vaults` aun NO funciona; el `bin` apunta a un CLI que no existe.

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7%2B-blue.svg)](https://www.typescriptlang.org)
[![Status](https://img.shields.io/badge/status-in--progress-yellow.svg)](.)

SaviaVaults da a agentes de IA acceso a cupulas de contexto locales: repositorios versionados, buscables y firmados de conocimiento, expuestos via protocolos estandar (MCP + A2A) con cero dependencia de nube.

---

## Que funciona hoy (2026-08-01)

| Modulo | Estado |
|---|---|
| `src/federation/types.ts` | Tipos de federacion |
| `src/federation/registry.ts` | CRUD de domes federados |
| `src/federation/cache.ts` | LRU cache con TTL |
| `src/federation/a2a-client.ts` | HTTP client con auth y timeout |
| `src/federation/search.ts` | Busqueda federada (parallel, merge, dedup) |
| `src/federation/circuit-breaker.ts` | CLOSED->OPEN->HALF_OPEN |
| `src/federation/audit-logger.ts` | JSONL audit trail |
| `src/federation/hash-verify.ts` | Verificacion de integridad |
| `src/config/schema.json` | Schema de configuracion |

**7 tests unitarios pasan** sobre estos modulos (registry, cache, search, circuit-breaker, audit-logger, hash-verify, types).

## En construccion (SE-286)

| Modulo | Estado |
|---|---|
| `src/types.ts` | Tipos nucleo — en implementacion |
| `src/storage/` | Almacenamiento git-backed — en implementacion |
| `src/search/` | Busqueda BM25 con minisearch — en implementacion |
| `src/security/` | Path sandbox + firma Ed25519 — en implementacion |
| `src/server/mcp.ts` | Servidor MCP — pendiente |
| `src/server/ratelimit.ts` | Rate limiter — pendiente |
| `src/cli/` | CLI (init, serve, search, stats) — pendiente |

## Quick Start (cuando este terminado)

```bash
npm install -g savia-vaults         # NO disponible aun
savia-vaults init my-knowledge      # NO disponible aun
savia-vaults serve --transport mcp  # NO disponible aun
```

## Development

```bash
git clone https://github.com/gonzalezpazmonica/savia-vaults.git
cd savia-vaults
npm install
npm run build              # compila solo lo que existe (federation + config)
npm test                   # 7 tests unitarios pasan; 7 importan modulos en construccion
npm run test:coverage
```

## License

MIT. See [LICENSE](LICENSE).

---

*Parte del ecosistema Savia — [pm-workspace](https://github.com/gonzalezpazmonica/pm-workspace)*
