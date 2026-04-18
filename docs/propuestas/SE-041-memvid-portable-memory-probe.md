---
id: SE-041
title: Memvid portable memory format — Feasibility Probe para backup/travel
status: PROPOSED
origin: Research 2026-04-18 del repo github.com/memvid/memvid (15k stars, Apache 2.0)
author: Savia
related: SPEC-110 memoria externa canónica, travel-pack skill, vault-*, SPEC-018 vector memory, SPEC-035 hybrid search
approved_at: null
applied_at: null
expires: "2026-05-16"
---

# SE-041 — Memvid portable memory format

## Purpose

Si NO hacemos esto: seguimos con memoria como árbol de markdown + índices regenerables. El backup/travel actual (`travel-pack`/`vault-export`) es tar-gzip, válido pero:
- No tiene WAL embebido → backups parciales pueden corromper silenciosamente
- Índices de búsqueda se regeneran en destino (slow cold-start)
- No hay timeline auditable de cambios de memoria (append-only)

Cost of inaction: bajo-medio. Nuestro stack actual funciona. Pero cuando la memoria crece (100s de sesiones, 1000s de engrams) los cold-starts y las regeneraciones se notan. Y sin audit trail append-only, un fallo de disco con WAL a medio escribir puede perder estado reciente.

## Objective

**Único y medible**: evaluar mediante Feasibility Probe empírico si adoptar el formato `.mv2` de memvid (o el patrón que propone) aporta valor concreto sobre el stack actual. Criterio de éxito del probe: (a) ingest de 100 memoria reales en .mv2 < 30s, (b) retrieval top-5 latencia p50 < 50ms offline, (c) single-file portabilidad verificada (backup→restore round-trip byte-identical), (d) integración con `travel-pack` sin depender de servicios externos.

NO es: reemplazar SPEC-027 knowledge-graph, SPEC-018 vector index, SPEC-035 hybrid search. SÍ es: probar si memvid puede sustituir tar-gzip en el path de backup/travel con mejor garantías.

## Design

### Arquitectura memvid relevante

```
.mv2 File (single file)
├── Header (metadata + versión format)
├── Embedded Write-Ahead Log (crash recovery)
├── Smart Frames (append-only, versioned, immutable)
├── Lex Index (Tantivy BM25 — full-text)
├── Vec Index (HNSW + ONNX BGE-small 384d local)
├── Time Index (temporal queries)
└── TOC (table of contents)
```

### 3 usos candidatos evaluables

| # | Uso | Valor si viable | Alternativa actual |
|---|---|---|---|
| U1 | Backup/restore de memoria externa | Alto (WAL + integridad) | tar-gzip (`travel-pack`) |
| U2 | Snapshot inmutable para audit trail | Medio-alto | git commits (lento para queries) |
| U3 | Memoria portátil cross-machine (USB travel) | Medio | `travel-pack` actual |

NO candidatos (ya cubiertos por specs existentes):
- Search production: SPEC-035 hybrid search, SE-032 reranker
- Knowledge graph: SPEC-027, SPEC-123 graphiti
- Vector memory: SPEC-018

### Dependencias

- **Apache 2.0** (permissive, compatible)
- ONNX CPU inference (BGE-small 384d) — zero-egress si evitamos api_embed feature
- Rust core (puede integrarse como binario o wrapper)
- SDK Python disponible para scripting interno
- **NO** requiere GPU, servidor LLM, DB externa

## Slicing

### Slice 1 — Feasibility Probe (OBLIGATORIO, 2h, blocking)

**Entregable**: `output/se-041-probe-{date}.md` con:
- Instalar memvid Python SDK en sandbox aislado (virtualenv)
- Ingestar 100 ficheros markdown reales de `~/.claude/external-memory/auto/` (si existen) o sintéticos
- Medir: ingest time, .mv2 final size vs tar-gz equivalente
- Medir: retrieval top-5 latencia p50 sobre 20 queries ref
- Verificar: backup→restore round-trip byte-identical
- Verificar: offline operation (desenchufar red durante la prueba)
- Decision gate:
  - Continue si U1 + U3 cumplen criterios + portabilidad verificada
  - Abort si latencia > 100ms p50 o si requiere API externa indirecta

Sin probe verde, spec NO avanza a approved.

### Slice 2 — Travel-pack integration (1h, opcional si probe verde)

- Extender `scripts/travel-pack.sh` con flag `--format mv2` (default tar-gzip)
- `scripts/travel-unpack.sh` detecta formato automáticamente
- Tests bats ≥15 (incluyendo round-trip + integridad WAL)
- Doc en `docs/rules/domain/memory-portability.md`

### Slice 3 — Ratchet adoption (futuro, opt-in)

- Si Slice 2 aterriza y demostrativamente mejor → marcar `--format mv2` como default nuevo
- Mantener tar-gzip como fallback permanente (backward compat + degradación zero-deps)

## Acceptance Criteria

- [ ] AC-01 Feasibility Probe ejecutado con los 4 criterios cuantitativos
- [ ] AC-02 Decisión documentada: continue / abort + razones empíricas
- [ ] AC-03 Si continue: integración travel-pack + 15 tests
- [ ] AC-04 Si continue: doc portability documenta trade-offs (size, speed, crash-safety)
- [ ] AC-05 Si abort: spec cerrado con lesson-learned (qué funciona mejor en tar-gzip, cuándo reconsiderar)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Memvid v2 aún joven, breaking changes | Media | Medio | Versión pinneada. Fallback tar-gzip always available |
| ONNX CPU inference lento en hardware antiguo | Baja | Bajo | Slice 1 mide latencia real; si > SLA, abort |
| Format lock-in a .mv2 | Baja | Alto | Slice 3 keep tar-gzip permanent — evita lock-in |
| Embedding drift si cambiamos modelo | Media | Medio | Documentar en slice 2 — rebind es rebuild, aceptable |

## Aplicación Spec Ops

- **Simplicity**: probe evalúa 3 usos discretos, no reemplazo global
- **Purpose separado**: cost of inaction = bajo-medio, probe decide si merece scope
- **Repetition/Probe OBLIGATORIO**: 2h time-boxed, gate blocking
- **Speed/Slicing**: 3 slices, slice 3 opcional/futuro
- **Theory of Relative Superiority**: expires 2026-05-16 — si probe no se ejecuta para esa fecha, abort

## Referencias

- https://github.com/memvid/memvid (15k stars, Apache 2.0, v2.0.139 2026-03)
- SPEC-110 Memoria Externa Canónica (contexto actual)
- `scripts/travel-pack.sh`, `scripts/travel-unpack.sh`
- ROADMAP.md §Tier 2 (este spec añadible como 2.5)

## Veredicto de radical honesty

Memvid es un repo serio (15k stars, activo, Apache 2.0) pero NO resuelve ningún problema bloqueante que tengamos hoy. Nuestro stack de memoria (L0-L3, knowledge-graph, hybrid search) cubre retrieval y contexto. Lo que sí aporta potencialmente es **un mejor formato de backup con WAL + portabilidad single-file**. Adopción global sería duplicar capacidades existentes; adopción narrow (travel/backup) es el único slot con valor marginal positivo claro.

Este spec es una PROPUESTA DE PROBE, no un compromiso de adopción. Si el probe falla (latency, complejidad, maintenance burden), cerramos y seguimos con tar-gzip. Spec Ops Repetition principle aplicado.

## Dependencia

Independiente. Puede iterar en paralelo con SE-032/033/035 probes.
