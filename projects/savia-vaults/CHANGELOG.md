# Changelog — SaviaVaults

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-08-01 · Servidores reales, backups, firma (SE-287)

### Added

- **MCP Server real** (`src/server/mcp.ts`): 9 tools con stdio transport usando `@modelcontextprotocol/sdk`. Cada tool delega en storage/search/security.
- **A2A Server** (`src/server/a2a.ts`): HTTP REST con 5 endpoints (/health, /search, /context, /stats, /share). Rate limiter integrado por cliente. Auth via Bearer token. Loopback por defecto con warning si se expone.
- **Backup system** (`src/backup/index.ts`): creación/lista/restauración de backups tar.gz. Sincronización con Nextcloud via carpeta local (desktop client) o WebDAV directo.
- **Ed25519 signing** (`src/security/index.ts`): firmas criptográficas reales con generación automática de keypair. `signContent()` y `verifySignature()` usando `node:crypto`.
- **Federate CLI**: `federate add|list|remove|health` usando FederationRegistry.
- **Backup CLI**: `backup create|list|restore|status` usando BackupManager.
- **Export funcional**: produce directorio con documentos legibles sin la herramienta.
- **Verify**: verifica integridad de firmas de todos los documentos.
- **Documentación**: `docs/USAGE.md` (guía completa), `docs/BACKUP.md` (guía Nextcloud).

### Changed

- **Storage**: `write()` usa firma Ed25519 real en lugar del placeholder sha256.
- **CLI**: `serve` inicia servidores reales MCP/A2A. `export` y `verify` funcionales.
- **CLI**: añadidos 10+ comandos nuevos (backup, federate, export real, verify real).

## [0.1.0] — 2026-08-01 · Producto verificable (SE-286)

### Added

- **Core types** (`src/types.ts`): VaultConfig, Note, Receipt, SearchResult, Frontmatter, CommitEntry
- **Storage engine** (`src/storage/index.ts`): git-backed CRUD con frontmatter YAML y hashing SHA256
- **Search engine** (`src/search/index.ts`): BM25 full-text search via minisearch
- **Security sandbox** (`src/security/index.ts`): 6-layer path validation
- **Rate limiter** (`src/server/ratelimit.ts`): token bucket per-client
- **MCP server skeleton** (`src/server/mcp.ts`): inicialización de vault
- **CLI** (`src/cli/index.ts`): 6 comandos (init, serve, search, stats, verify, export)
- **Threat model** (`docs/threat-model.md`)
- **Federation modules**: registry, cache, a2a-client, search merge, circuit-breaker, audit-logger, hash-verify

### Tests

- 89 tests en 14 ficheros, todos en verde sobre código real
