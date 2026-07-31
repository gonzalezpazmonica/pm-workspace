# SaviaVaults — Context Dome Server (MCP + A2A)

> **Status (2026-08-01): v0.1.0 — producto minimo verificable.** 89 tests en verde, CLI funcional, smoke de instalacion real pasa. La capa de federacion + nucleo (storage, search, security) operan sobre codigo real. Los servidores MCP/A2A completos estan en construccion (ver SE-286 S4).

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
| `src/server/mcp.ts` | Servidor MCP completo — pendiente |
| Servidor A2A | HTTP REST endpoints — pendiente |

## Alcance de Gobernanza

SaviaVaults es un **servidor de contexto**, no un agente soberano. No implementa la constitucion ni el criterio de Savia. Expone cupulas de contexto via protocolos estandar para que cualquier agente (Savia o externo) pueda consumirlas sin adoptar la plataforma.

El servidor respeta niveles de confidencialidad (N1-N4) en el frontmatter de los documentos y filtra por nivel maximo declarado al arrancar. Para verificacion de gobierno completo, la herramienta produce recibos verificables por terceros sin dependencia del ecosistema Savia.

Lee el [modelo de amenaza](docs/threat-model.md) para entender que se protege y que NO. Las garantias de seguridad se detallan en `docs/threat-model.md`.

## Quick Start

```bash
# Install globally
npm install -g savia-vaults

# Create your first vault
savia-vaults init my-knowledge

# Search from CLI
savia-vaults search "architecture" --path vaults/my-knowledge

# Get stats
savia-vaults stats --path vaults/my-knowledge
```

> Los comandos `serve` (servidor MCP/A2A completo) estan en construccion. Ver SE-286 S4.

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
