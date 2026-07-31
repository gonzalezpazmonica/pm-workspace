# SE-280 — SaviaVaults: Context Dome Server (MCP + A2A)

> **Investigacion**: awesome-llm-apps + MCPVault + Cognithor + knowledge-vault ecosystem
> **Licencia**: MIT | **Stack**: TypeScript, Node.js 22+, MCP SDK, simple-git, minisearch

## Metadatos

- **Task ID:** SE-280
- **PBI padre:** Era 200 — Savia Intelligence Layer
- **developer_type:** agent-team
- **status:** draft
- **stack:** TypeScript + Node.js 22+ + MCP SDK + simple-git + minisearch
- **estimacion:** 20h (6 slices)

## Problema

Savia tiene 136 skills, 81 agentes, 566 comandos, y un sistema de memoria persistente (`~/.savia-memory/`). Pero **no hay un servidor de cupulas de contexto** que permita:

1. **Acceso universal**: cualquier AI agent (Claude, GPT, Codex, Cursor) interrogue el conocimiento de Savia via protocolo estandar
2. **Compartir contexto entre agentes**: agent-to-agent knowledge transfer sin copiar/pegar
3. **Versionado de conocimiento**: git-backed, inmutable, auditable
4. **Busqueda semantica**: BM25 + embeddings locales, sin dependencia cloud
5. **Firma de contenido**: Ed25519 receipts para trazabilidad de origen

### Landscape Analysis

| Proyecto | MCP | A2A | Git | Search | Firma | Local | Madurez |
|---|---|---|---|---|---|---|---|
| [MCPVault](https://github.com/bitbonsai/mcpvault) | Si | No | No | BM25 | No | Si | v0.12.5 (prod) |
| [Cognithor](https://github.com/Alex8791-cyber/cognithor) | Si | No* | No | Si | No | Si | Active dev |
| [knowledge-vault-mcp](https://github.com/danieljhkim/knowledge-vault-mcp) | Si | No | No | No | No | Si | Early |
| [vault-sync](https://github.com/graphlit/vault-sync) | No | No | Si | No | No | Si | Active |
| **SaviaVaults** | **Si** | **Si** | **Si** | **BM25+Emb** | **Ed25519** | **Si** | **draft** |

*Cognithor tiene multi-channel pero sin protocolo A2A estandar.

## Objetivo

Un servidor local-first que expone vaults de conocimiento via **MCP** (Model Context Protocol, transporte stdio) y **A2A** (Agent-to-Agent, HTTP/SSE). Git-backed, content-addressed, con busqueda hibrida y firma de contenido.

## Diseno

```
AI Agents (Claude, GPT, Codex, Cursor)
        │ MCP (stdio)          │ A2A (HTTP)
        ▼                      ▼
   ┌─────────────────────────────────┐
   │       SaviaVaults Server        │
   │  ┌──────────┐  ┌─────────────┐  │
   │  │ MCP Layer│  │ A2A Layer   │  │
   │  └────┬─────┘  └──────┬──────┘  │
   │       │               │         │
   │  ┌────▼───────────────▼──────┐  │
   │  │       Core Engine         │  │
   │  │  Search │ Storage │ Sec   │  │
   │  │  BM25+  │ Git +   │ Sand  │  │
   │  │  Embed  │ Content │ box   │  │
   │  └───────────────────────────┘  │
   └──────────────┬──────────────────┘
                  │
   ┌──────────────▼──────────────────┐
   │     Vault (Filesystem + Git)    │
   │  vaults/{name}/                 │
   │  ├── INDEX.md   (content map)   │
   │  ├── MAP.md     (routing table) │
   │  └── {notes}/   (markdown docs) │
   └─────────────────────────────────┘
```

## MCP Tools (9 tools)

| Tool | Descripcion |
|---|---|
| `vault_read` | Leer nota por path |
| `vault_write` | Crear/actualizar nota (git-commit + firma) |
| `vault_search` | Busqueda BM25 con snippets |
| `vault_list` | Listar arbol de directorios |
| `vault_stats` | Estadisticas del vault |
| `vault_index` | Reconstruir indice de busqueda |
| `vault_diff` | Git diff de una nota |
| `vault_log` | Historial git de una nota |
| `vault_tags` | Listar tags con conteos |

## A2A Endpoints

| Metodo | Path | Descripcion |
|---|---|---|
| GET | `/context/{vault}/{path}` | Obtener contexto por path |
| GET | `/search?q=&vault=&maxResults=` | Buscar entre vaults |
| POST | `/share` | Compartir contexto con otro agente |
| GET | `/stats` | Estadisticas del vault |
| GET | `/health` | Health check |

## Modelo de Seguridad

- **Path sandbox**: normalizacion de paths, bloqueo de traversal (`..`, absolutos)
- **Deny list**: `.git`, `.obsidian`, `node_modules`, `.savia-vault`, `.trash`
- **Allow list**: `.md`, `.yaml`, `.yml`, `.json`, `.txt`, `.canvas`, `.base`
- **Symlink protection**: symlinks fuera del vault bloqueados (TOCTOU-safe)
- **Size limits**: archivos >10MB bloqueados (configurable)
- **Depth limits**: paths >10 niveles bloqueados
- **Content signing**: Ed25519 receipts en cada escritura

## Implementacion

### Slice 1 — Core types + security (3h)
- `src/types.ts` — todas las interfaces
- `src/security/index.ts` — VaultSecurity con 6 checks

### Slice 2 — Storage engine (4h)
- `src/storage/index.ts` — VaultStorage: init, read, write, delete, list, stats, diff, log

### Slice 3 — Search engine (3h)
- `src/search/index.ts` — SearchEngine: BM25, buildIndex, search, getTags

### Slice 4 — MCP Server (4h)
- `src/server/mcp.ts` — 9 MCP tools via stdio transport

### Slice 5 — A2A Server (3h)
- `src/server/a2a.ts` — HTTP server con endpoints REST

### Slice 6 — CLI + Tests (3h)
- `src/cli/index.ts` — comandos: init, serve, search, stats
- `tests/unit/` — security, storage, search (33 tests)
- `tests/integration/` — CRUD workflow, multi-note
- `tests/e2e/` — MCP protocol compliance

## Criterios de Aceptacion

**AC-1**: `savia-vaults init test-vault` crea directorio con INDEX.md, MAP.md, .git.

**AC-2**: `savia-vaults serve --transport mcp` inicia servidor MCP stdio con 9 tools.

**AC-3**: `savia-vaults serve --transport a2a` inicia servidor HTTP en :8923.

**AC-4**: `vault_write` produce receipt con contentHash y signature.

**AC-5**: `vault_search "microservices"` encuentra notas con ese contenido.

**AC-6**: Security blocks `../../../etc/passwd` (path traversal).

**AC-7**: Security blocks `.git/config` (deny list).

**AC-8**: 33+ tests pasan con coverage >= 80%.

## File Inventory

| Accion | Path |
|---|---|
| CREATE | `projects/savia-vaults/package.json` |
| CREATE | `projects/savia-vaults/tsconfig.json` |
| CREATE | `projects/savia-vaults/vitest.config.ts` |
| CREATE | `projects/savia-vaults/CLAUDE.md` |
| CREATE | `projects/savia-vaults/src/types.ts` |
| CREATE | `projects/savia-vaults/src/security/index.ts` |
| CREATE | `projects/savia-vaults/src/storage/index.ts` |
| CREATE | `projects/savia-vaults/src/search/index.ts` |
| CREATE | `projects/savia-vaults/src/server/mcp.ts` |
| CREATE | `projects/savia-vaults/src/server/a2a.ts` |
| CREATE | `projects/savia-vaults/src/cli/index.ts` |
| CREATE | `projects/savia-vaults/tests/unit/security.test.ts` |
| CREATE | `projects/savia-vaults/tests/unit/storage.test.ts` |
| CREATE | `projects/savia-vaults/tests/unit/search.test.ts` |
| CREATE | `projects/savia-vaults/tests/integration/vault-workflow.test.ts` |
| CREATE | `projects/savia-vaults/tests/e2e/mcp-server.test.ts` |
| CREATE | `projects/savia-vaults/specs/SE-280-savia-vaults.spec.md` |
| CREATE | `projects/savia-vaults/docs/research.md` |
| MODIFY | `.gitignore` (exception for projects/savia-vaults/) |
