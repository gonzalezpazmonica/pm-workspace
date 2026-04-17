---
id: SPEC-113
title: Knowledge-graph query modes (local/global/hybrid)
status: ACCEPTED
origin: Research raphaelmansuy/edgequake (2026-04-17)
author: Savia
---

# SPEC-113 — Graph Query Modes

## Why

`raphaelmansuy/edgequake` implementa 6 modos de query (naive/local/global/hybrid/mix/bypass) en su RAG engine, con SQL pre-filter que afirma reduce ~90% scans innecesarios.

Pm-workspace tiene `/graph-query` pero sin modos explícitos. Añadir modos guía al LLM en el tipo de traversal correcto, mejora precisión, y documenta intent.

## Scope

Extender `/graph-query` con flag `--mode`:

- `local` (default) — query entidad puntual, traversal 1-2 hops. Ej: "¿quién sabe X?"
- `global` — query agregado/summary, escanea multiples entidades. Ej: "¿qué skills dominan el equipo?"
- `hybrid` — combina local + global. Ej: "¿quién sabe X en el contexto del proyecto Y?"
- `bypass` — sin graph, lookup directo. Ej: obtener metadata concreta.

## Implementation

### 1. `graph-query.md` extensión

Añadir:
```
## Modos

- `--mode=local` (default) — pregunta sobre entidad específica, 1-2 hops.
- `--mode=global` — agregación/summary, traversal amplio.
- `--mode=hybrid` — combina local + global.
- `--mode=bypass` — lookup directo sin traversal.
```

El `graph-query` skill/agent usa el modo para calibrar profundidad de traversal y número de entidades retornadas.

### 2. Docs en skill `knowledge-graph`

Añadir sección "Query Modes" en `.claude/skills/knowledge-graph/DOMAIN.md` explicando cuándo usar cada modo.

## Acceptance criteria

1. `/graph-query "..." --mode=local` devuelve resultados específicos de entidad (default behavior).
2. `/graph-query "..." --mode=global` devuelve agregaciones (nuevo comportamiento).
3. `--mode=hybrid` y `--mode=bypass` documentados aunque no implementados full en esta spec.
4. README o help del comando menciona los modos.

## Rejected from EdgeQuake

- pgvector + Apache AGE infra — pm-workspace es zero-dep al arranque.
- GPT-4o/Claude/Gemini per-page vision — incompatible con cache strategy.
- React frontend — pm-workspace es CLI-first.

## Risks

- **BAJO**: cambio additive, `--mode` sin especificar = local (backward compatible).
- **BAJO**: modos `hybrid` y `bypass` son stubs documentados, no implementados.
