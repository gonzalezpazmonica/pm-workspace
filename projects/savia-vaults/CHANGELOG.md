# Changelog — SaviaVaults

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-08-01 · Producto verificable (SE-286)

### Added

- **Core types** (`src/types.ts`): VaultConfig, Note, Receipt, SearchResult, Frontmatter, CommitEntry
- **Storage engine** (`src/storage/index.ts`): git-backed CRUD (init, read, write, delete, list, stats, diff, log) con frontmatter YAML y hashing SHA256
- **Search engine** (`src/search/index.ts`): BM25 full-text search via minisearch con busqueda por texto, tags, y pathPrefix
- **Security sandbox** (`src/security/index.ts`): 6-layer (path traversal, deny list, symlink, extension, depth, size)
- **Rate limiter** (`src/server/ratelimit.ts`): token bucket per-client con cleanup automatico
- **MCP server skeleton** (`src/server/mcp.ts`): inicializacion de vault con INDEX.md, MAP.md, .git
- **CLI** (`src/cli/index.ts`): 6 comandos — init, serve, search, stats, verify, export
- **Threat model** (`docs/threat-model.md`): actores, protecciones, y NO-protecciones declarados

### Changed

- **README**: reescrito con estado real; eliminado `npm install -g` falso hasta verificacion
- **CLAUDE.md**: tabla honesta de modulos implementados vs pendientes
- **package.json**: `private: true` retirado tras smoke de instalacion verificado
- **6 specs (SE-280..SE-285)**: campo Status explicito (PARTIAL, DONE, PROPOSED)
- **Federation audit-logger**: corregida rotacion intra-dia que generaba el mismo nombre de fichero
- **Test imports**: corregidos paths relativos en `federated-search.test.ts`

### Tests

- 89 tests en 14 ficheros, todos en verde sobre codigo real
- Smoke de instalacion real: `npm pack` → `npm install -g` → `init` → `search`
