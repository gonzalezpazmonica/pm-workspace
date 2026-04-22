# Domain: Memvid Backup

> Evalua portable memory format vs tar-gzip actual.
> Spec: SE-041 — `docs/propuestas/SE-041-memvid-portable-memory.md`

## Problema

Stack actual de backup/travel (`travel-pack`, `vault-export`) usa tar-gzip:
- No tiene WAL embebido → backups parciales pueden corromperse silenciosamente
- Indices se regeneran en destino (slow cold-start)
- No hay timeline auditable append-only

Cost of inaction bajo-medio: stack funciona para scale actual. Pero con 1000s de engrams el cold-start regenerando indices se nota, y sin WAL un fallo de disco durante backup puede perder estado.

## Solucion evaluada

`memvid` (github.com/memvid/memvid, 15k stars, Apache 2.0): formato `.mv2` single-file que embebe:
- Header metadata + version
- WAL para crash recovery
- Smart frames append-only versioned
- Lex index (Tantivy BM25)
- Vec index (HNSW + BGE-small ONNX 384d)
- Time index temporal

## Arquitectura Slice 2

| Componente | Responsabilidad |
|---|---|
| `scripts/memvid-backup.py` | Wrapper 3 subcomandos con fallback |
| `pack` | Directorio → fichero (memvid o tar-gzip) |
| `restore` | Fichero → directorio |
| `verify` | Integrity check sin extract |
| `try_memvid_available()` | Detect package sin cargar |
| SHA256 integrity | Round-trip byte-identical check |

## Estado actual

**Slice 2 hace**: scaffolding + contract + round-trip SHA256 con tar-gzip como implementacion. Memvid detectado pero NO integrado aun (pendiente Slice 3).

**Slice 3 hara**: integracion real con memvid API (build .mv2, read frames, query indices).

**Slice 4 opcional**: integracion con `travel-pack` / `vault-export` si Slice 3 valida criterios acceptance.

## Criterios de evaluacion SE-041

| # | Criterio | Target | Estado Slice 2 |
|---|---|---|---|
| a | Ingest 100 engrams | <30s | pendiente (requiere memvid) |
| b | Retrieval top-5 latencia | p50 <50ms offline | pendiente |
| c | Round-trip byte-identical | SHA256 match | **implementado** |
| d | Integracion travel-pack sin servicios | zero cloud | implementado (via tar-gzip) |

## Tradeoffs

**Pros**:
- Single-file portabilidad
- WAL crash recovery si memvid
- Indices embebidos → cold-start rapido
- Apache 2.0 permissive

**Contras**:
- Dependencia Python memvid (~200MB con ONNX)
- Formato nuevo — menos herramientas estandard
- Proyecto pre-1.0 (maintainer activo pero young)
- Para corpora pequenos (<100 docs) tar-gzip es simpler

## Decisiones

- `pack --format auto` default: memvid si disponible, tar-gzip si no
- SHA256 se computa siempre (ambos formatos) para integrity verification
- Restore solo tar-gzip actualmente (Slice 3 anade memvid)
- Verify es read-only (no write side effects)

## No reemplaza

- SPEC-027 knowledge-graph (estructura logica de memoria)
- SPEC-018 vector memory (search runtime)
- SPEC-035 hybrid search (query optimization)
- Git (version control de texto)

## Roadmap futuro

- Slice 2 (done): wrapper + tar-gzip + SHA256 + skill
- Slice 3: integracion real memvid API (si probe valida criterios)
- Slice 4: hook into `travel-pack` workflow
- Slice 5: GO/NO-GO decision documentado en ADR
