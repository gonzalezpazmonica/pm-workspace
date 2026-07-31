# SE-282 — Savia Federate: Cross-Dome Federation Layer

> **Parent**: SE-280 (SaviaVaults), SE-281 (Gap Corrections)
> **Inspiration**: A2A protocol, ActivityPub federation model, Elasticsearch cross-cluster search

## Metadatos

- **Task ID:** SE-282
- **PBI padre:** Era 200 — Savia Intelligence Layer
- **developer_type:** agent-team
- **status:** draft
- **stack:** TypeScript + Node.js 22+ + A2A client
- **estimacion:** 12h (6 slices)

## Problema

Un solo dome de contexto cubre un dominio. Pero el conocimiento real esta distribuido: documentacion en un dome, specs en otro, memoria operativa en un tercero. Sin federacion, cada dome es una isla. El usuario tiene que saber QUE dome contiene QUE informacion y cambiar de herramienta/endpoint para cada busqueda.

## Objetivo

**Savia Federate** permite conectar cupulas de contexto remotas en modo solo-lectura. Una busqueda en el dome local se expande transparentemente a todas las cupulas federadas. Los resultados se fusionan, deduplican y rankean como si todo el conocimiento estuviera en un solo dome.

```
┌──────────────────────────────────────────────────────┐
│                  Savia Federate                       │
│                                                       │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐            │
│  │ Dome A  │   │ Dome B  │   │ Dome C  │            │
│  │ (local) │   │(remote) │   │(remote) │            │
│  │ docs/   │   │ specs/  │   │ memory/ │            │
│  └────┬────┘   └────┬────┘   └────┬────┘            │
│       │              │              │                  │
│       │    A2A/HTTP  │    A2A/HTTP  │                  │
│       └──────┬───────┴──────┬───────┘                  │
│              │              │                          │
│  ┌───────────▼──────────────▼──────────────────┐      │
│  │         Federation Engine                    │      │
│  │  ┌──────────┐ ┌───────────┐ ┌────────────┐  │      │
│  │  │ Registry │ │ Federated │ │   Cache    │  │      │
│  │  │ (who)    │ │  Search   │ │ (results)  │  │      │
│  │  └──────────┘ └───────────┘ └────────────┘  │      │
│  └────────────────────┬────────────────────────┘      │
│                       │                               │
│  ┌────────────────────▼────────────────────────┐      │
│  │          Local Search Engine (BM25)          │      │
│  └─────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────┘
```

## Diseno

### Federation Registry

Cada dome federado se registra con:

```json
{
  "id": "savia-specs",
  "name": "Savia Specifications",
  "url": "http://192.168.1.100:8923",
  "authToken": "optional-shared-secret",
  "timeout": 5000,
  "enabled": true,
  "weight": 1.0,
  "tags": ["specs", "technical", "savia"],
  "lastHealthCheck": "2026-07-30T20:00:00Z",
  "status": "healthy"
}
```

### Federated Search Flow

```
User: vault_search_federated "microservices architecture"
  ↓
1. Local search (BM25, fast, always available)
  ↓
2. Parallel A2A queries to all healthy federated domes
   GET /search?q=microservices+architecture&maxResults=20
   (timeout per dome: 5s, abort all if local results > 0 after 2s)
  ↓
3. Result merging:
   - Deduplicate by content hash (SHA256 of snippet)
   - Interleave results (round-robin from each source, local prioritized)
   - Cap total at maxResults × (1 + federated domes)
  ↓
4. Cache results (TTL: 5 min for remote, 1 min for local)
  ↓
5. Return merged results with source attribution
```

### Cache Strategy

- **Local results**: cached 1 min (fast, no network)
- **Remote results per query+params**: cached 5 min (avoids hammering federated domes)
- **Health checks**: cached 60s
- **Cache invalidation**: on `vault_index --force`, on federation config change
- **Max cache size**: 1000 entries, LRU eviction

### Security Model

- **Read-only**: federated domes NUNCA reciben writes, solo GET /search y GET /health
- **Auth per dome**: cada dome federado puede tener su propio token (pasado como `Authorization: Bearer`)
- **Timeout**: max 5s por dome remoto (configurable), evita que un dome lento bloquee todo
- **No cascading**: un dome federado no propaga busquedas a sus propios federados (1 hop max)
- **Local fallback**: si todos los federados fallan, se devuelven solo resultados locales

## Architecture Decisions

- **Parallel queries, not sequential**: todos los domes se consultan en paralelo (Promise.all con timeout individual)
- **Interleaving, not score merge**: los scores BM25 no son comparables entre domes distintos. Se usa round-robin para dar visibilidad equitativa.
- **Deduplication by content hash**: evita resultados duplicados cuando el mismo contenido existe en multiples domes
- **Weight system**: cada dome tiene un peso (0.1-2.0) que afecta cuantos resultados se piden y como se intercalan
- **Health-aware routing**: domes en estado `unhealthy` se saltan; `degraded` reciben timeout reducido
- **1-hop only**: no hay federacion transitiva (dome A federado con B no ve los federados de B)

## Implementacion

### Slice 1 — Federation Registry (2h)
- `src/federation/registry.ts` — CRUD de domes federados
- Almacenado en `savia-vaults.config.json` seccion `federation.domes`
- Validacion contra JSON Schema

### Slice 2 — A2A Client (2h)
- `src/federation/a2a-client.ts` — HTTP client para queries A2A
- Soporte para auth token, timeout, retry (1 retry en timeout)
- Health check: GET /health con timeout 2s

### Slice 3 — Federated Search Engine (3h)
- `src/federation/search.ts` — orquestador de busqueda federada
- Parallel queries, merge, dedup, interleave
- Cache layer (`src/federation/cache.ts`)

### Slice 4 — MCP Tool (2h)
- Nuevo tool: `vault_search_federated` — como vault_search pero incluye federados
- Parametro `federated: boolean` (default true) en vault_search existente
- Nuevo tool: `vault_federation_status` — estado de todos los domes federados

### Slice 5 — CLI Commands (1h)
- `savia-vaults federate add <id> <url>` — registrar dome remoto
- `savia-vaults federate list` — listar domes federados
- `savia-vaults federate remove <id>` — eliminar dome
- `savia-vaults federate health` — health check de todos

### Slice 6 — Tests + Config (2h)
- Unit tests: registry (8), cache (6), search merge (8), a2a client (4)
- Integration: 2 domes locales, federated search parity
- Config schema update: `federation` section

## Criterios de Aceptacion

**AC-1**: `savia-vaults federate add specs http://localhost:8924` registra un dome remoto.

**AC-2**: `vault_search_federated "architecture"` devuelve resultados locales + remotos fusionados.

**AC-3**: Resultados duplicados (mismo contentHash) aparecen solo una vez.

**AC-4**: Si un dome federado esta caido, la busqueda no falla — devuelve solo resultados locales + otros federados sanos.

**AC-5**: Cache TTL: busqueda repetida en <1min devuelve resultados cacheados sin llamadas remotas.

**AC-6**: No hay federacion transitiva (1 hop max).

**AC-7**: Token de autenticacion se envia como `Authorization: Bearer <token>` en cada request A2A.

**AC-8**: 26+ tests unitarios pasan.

## File Inventory

| Accion | Path |
|---|---|
| CREATE | `projects/savia-vaults/src/federation/registry.ts` |
| CREATE | `projects/savia-vaults/src/federation/a2a-client.ts` |
| CREATE | `projects/savia-vaults/src/federation/search.ts` |
| CREATE | `projects/savia-vaults/src/federation/cache.ts` |
| MODIFY | `projects/savia-vaults/src/server/mcp.ts` (2 new tools) |
| MODIFY | `projects/savia-vaults/src/cli/index.ts` (federate commands) |
| MODIFY | `projects/savia-vaults/src/config/schema.json` (federation section) |
| CREATE | `projects/savia-vaults/tests/unit/federation/registry.test.ts` |
| CREATE | `projects/savia-vaults/tests/unit/federation/cache.test.ts` |
| CREATE | `projects/savia-vaults/tests/unit/federation/search.test.ts` |
| CREATE | `projects/savia-vaults/tests/integration/federated-search.test.ts` |
| CREATE | `projects/savia-vaults/specs/SE-282-savia-federate.spec.md` |

## Self-Review — Edge Cases & Improvements

### Edge Cases Considered

1. **Dome offline**: timeout 5s + skip + return partial results ✓
2. **Dome lento**: Promise.race con timeout individual, no bloquea a otros ✓
3. **Dome devuelve error 500**: tratado como unhealthy, skip en siguiente busqueda ✓
4. **Dome con auth requerida pero sin token configurado**: skip + warning log ✓
5. **Dome con certificado TLS invalido**: `rejectUnauthorized: false` (configurable) + warning ✓
6. **Cache lleno**: LRU eviction, max 1000 entries ✓
7. **Deduplication cross-dome**: SHA256 del snippet como huella, no depende de scores ✓
8. **Resultado local identico a remoto**: dedup via contentHash, gana el local ✓
9. **Federated dome en misma maquina (localhost)**: timeout reducido a 1s ✓
10. **Recursion accidental**: 1-hop max, no se propagan busquedas ✓

### Design Improvements Applied

1. **Weight system**: domes con peso 2.0 piden el doble de resultados y aparecen mas arriba en interleave
2. **Health-aware**: 3 estados (healthy/degraded/unhealthy) con comportamiento distinto
3. **Cache warming**: al registrar un dome, pre-cachear su /health y /stats
4. **Source attribution**: cada resultado incluye `source` (local o dome ID) para trazabilidad
5. **Graceful degradation**: si 0/N domes responden, se devuelven resultados locales sin error
