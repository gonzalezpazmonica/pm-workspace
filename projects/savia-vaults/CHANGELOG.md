# Changelog — SaviaVaults

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — 2026-08-06 · Knowledge Governance (SE-309)

### Added
- **Decision records** (`src/knowledge/decision.ts`): nodo de conocimiento de primera clase — categoria, escenario, razonamiento, resultado, confianza, decisor y estado de ciclo de vida (proposed/accepted/rejected) con ProvenanceRef. `createDecisionRecord()` + `validateDecision()`.
- **Decision state log** (`src/knowledge/decision-state.ts`): `promote()`/`getActiveState()`, historial DecisionStateLog con StateChange y razon de cambio.
- **Conflict detection** (`src/knowledge/conflicts.ts`): `detectConflicts()` para hechos contradictorios (misma entidad+propiedad con valores distintos), severidad info/warning/critical, estado open/resolved y `resolveConflict()` sin overwrite silencioso.
- 4 suites de tests nuevas (decision, decision-state, conflicts, index)

## [0.3.0] — 2026-08-01 · Capa de conocimiento (SE-288)

### Added
- **Entity schema** (schema/entities/): 7 tipos base (person, organization, project, decision, document, event, system) con validacion de frontmatter
- **SchemaRegistry** (src/schema/): carga YAML, valida required/vocabulary/pattern, alias resolubles
- **KnowledgeGraph** (src/knowledge/graph.ts): relaciones tipadas direccionales, derivacion de wikilinks, recorrido acotado
- **Introspector** (src/knowledge/introspector.ts): tipos, cobertura, propiedades por vault y entidad
- **QueryEngine** (src/knowledge/query.ts): notacion punteada determinista, doble salida markdown+filas, busqueda difusa
- **ProvenanceEngine** (src/knowledge/provenance.ts): assertions con fuente, autoridad, bitemporalidad, conflictos
- **QualityEngine** (src/knowledge/quality.ts): 8 indicadores de salud, informe formateado
- **Compliance** (src/compliance/): transparencia Art. 50 EU AI Act, inventario de salidas, marcado Ed25519
- 13 MCP tools, 8 A2A endpoints, 10 comandos CLI
- 125 tests (89 original + 36 knowledge layer)


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
