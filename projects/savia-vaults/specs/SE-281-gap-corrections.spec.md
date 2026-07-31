# SE-281 — SaviaVaults: Gap Analysis and Corrections

> **Audit date**: 2026-07-30 | **E2E result**: 22 PASS, 0 FAIL
> **Parent**: SE-280 (SaviaVaults)

## Metadatos

- **Task ID:** SE-281
- **PBI padre:** Era 200 — Savia Intelligence Layer
- **developer_type:** agent-single
- **status:** draft
- **stack:** bash + TypeScript
- **estimacion:** 8h (4 slices)

## Gaps encontrados

### GAP-01: Sin soporte multi-vault (HIGH)
El servidor MCP actual solo expone un vault. Para usar Savia como backend de conocimiento completo, necesitamos multi-vault (ej: `savia-docs`, `savia-memory`, `savia-specs`).

### GAP-02: Sin archivo de configuracion (HIGH)
No hay `savia-vaults.config.json` para persistir configuracion (vaults, puertos, limites, deny/allow lists). Todo se pasa por CLI.

### GAP-03: Sin autenticacion A2A (HIGH)
El servidor A2A no tiene auth — cualquiera en la red local puede leer/escribir. Necesita token compartido o API key.

### GAP-04: Search index sin persistencia (MEDIUM)
El indice BM25 se reconstruye en cada arranque. Para vaults grandes (>1000 archivos), esto es lento.

### GAP-05: Sin rate limiting (MEDIUM)
Sin proteccion contra abuso en A2A. Un agente podria saturar el servidor con busquedas.

### GAP-06: Lectura de archivos raw no expuesta (LOW)
`vault_read` devuelve JSON con metadatos + contenido. Falta un endpoint para descargar el archivo raw.

### GAP-07: No hay hooks de post-escritura (LOW)
No se puede ejecutar acciones tras un `vault_write` (ej: notificar, reindexar, validar).

## Implementacion

### Slice 1 — Archivo de configuracion + multi-vault (2h)
- `savia-vaults.config.json` schema
- Multi-vault en MCP server (tools aceptan parametro `vault` opcional)
- `vault_list_all` tool para listar vaults disponibles

### Slice 2 — A2A authentication + rate limiting (2h)
- Token compartido via `SAVIA_VAULTS_TOKEN` o header `Authorization: Bearer`
- Rate limiter: 100 req/min por IP (configurable)

### Slice 3 — Search index persistence (2h)
- Guardar indice BM25 serializado en `.savia-vault/search-index.json`
- Cargar en caliente si el archivo existe (saltar rebuild)
- `vault_index --force` para rebuild explicito

### Slice 4 — Config script + raw file access (2h)
- `savia-vaults config init` — genera config template
- `savia-vaults config validate` — valida config contra schema
- `vault_read_raw` tool — devuelve contenido del archivo directamente

## Criterios de Aceptacion

**AC-1**: `savia-vaults.config.json` valida con schema JSON.

**AC-2**: Servidor MCP acepta `vault` parameter en tools para multi-vault.

**AC-3**: A2A requiere `Authorization: Bearer <token>` si `SAVIA_VAULTS_TOKEN` esta configurado.

**AC-4**: Rate limiter bloquea tras 100 req/min por IP.

**AC-5**: Indice BM25 persiste en `.savia-vault/search-index.json` y carga en caliente.

**AC-6**: `vault_read_raw` devuelve contenido raw sin metadatos JSON.

## File Inventory

| Accion | Path |
|---|---|
| CREATE | `projects/savia-vaults/src/config/schema.json` |
| CREATE | `projects/savia-vaults/src/config/index.ts` |
| CREATE | `projects/savia-vaults/src/server/ratelimit.ts` |
| MODIFY | `projects/savia-vaults/src/server/mcp.ts` (multi-vault + raw) |
| MODIFY | `projects/savia-vaults/src/server/a2a.ts` (auth + rate limit) |
| MODIFY | `projects/savia-vaults/src/search/index.ts` (persistence) |
| MODIFY | `projects/savia-vaults/src/cli/index.ts` (config commands) |
