# SaviaVaults — Context Dome Server (MCP + A2A)

> **Status (2026-08-01): v0.2.0 — servidores reales.** 9-tool MCP server funcional, A2A HTTP REST server, backups con Nextcloud, firma Ed25519. 89 tests en verde.

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7%2B-blue.svg)](https://www.typescriptlang.org)
[![Status](https://img.shields.io/badge/status-in--progress-yellow.svg)](.)

SaviaVaults da a agentes de IA acceso a cupulas de contexto locales: repositorios versionados, buscables y firmados de conocimiento, expuestos via protocolos estandar (MCP + A2A) con cero dependencia de nube.

---

## Que funciona hoy (2026-08-01)

Servidores MCP y A2A reales, backups locales y Nextcloud, firma Ed25519, CLI completa.

| Modulo | Estado |
|---|---|
| MCP Server (9 tools, stdio) | Funcional |
| A2A Server (5 endpoints HTTP) | Funcional |
| Storage (git-backed CRUD) | Funcional |
| Search (BM25, minisearch) | Funcional |
| Security (6-layer sandbox) | Funcional |
| Backups (tar.gz + Nextcloud) | Funcional |
| Federation (8 modulos) | Funcional |
| CLI (12+ comandos) | Funcional |
| Ed25519 signing | Funcional |

## Alcance de Gobernanza

SaviaVaults es un **servidor de contexto**, no un agente soberano. No implementa la constitucion ni el criterio de Savia. Expone cupulas de contexto via protocolos estandar para que cualquier agente (Savia o externo) pueda consumirlas sin adoptar la plataforma.

El servidor respeta niveles de confidencialidad (N1-N4) en el frontmatter de los documentos y filtra por nivel maximo declarado al arrancar. Para verificacion de gobierno completo, la herramienta produce recibos verificables por terceros sin dependencia del ecosistema Savia.

Lee el [modelo de amenaza](docs/threat-model.md) para entender que se protege y que NO. Las garantias de seguridad se detallan en `docs/threat-model.md`.

## Quick Start

```bash
npm install -g savia-vaults
savia-vaults init my-knowledge
savia-vaults serve --transport mcp --path vaults/my-knowledge
savia-vaults search "architecture" --path vaults/my-knowledge
savia-vaults backup create --path vaults/my-knowledge
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
