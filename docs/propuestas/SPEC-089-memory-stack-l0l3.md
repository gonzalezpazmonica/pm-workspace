---
spec_id: SPEC-089
title: Memory Stack L0-L3 — carga progresiva con presupuesto tokenizado
status: Proposed
origin: mempalace research (2026-04-08)
severity: Media
effort: ~3h
---

# SPEC-089: Memory Stack L0-L3

## Principio

La memoria se carga en 4 capas con presupuesto fijo de tokens por capa.
SQLite local como cache de acceso rapido. Texto plano (.md) como verdad.

## Arquitectura

```
L0 — Identidad (~50 tokens) — SIEMPRE cargado
  Nombre, rol, idioma del usuario activo
  Fuente: active-user.md + identity.md

L1 — Hechos criticos (~150 tokens) — SIEMPRE cargado
  Top 5-8 memorias mas relevantes (por importance score)
  Fuente: MEMORY.md index (ya existe, cap 200 lineas)

L2 — Recall por tema (~500 tokens max) — BAJO DEMANDA
  Memorias del topic relevante al comando actual
  Fuente: topic files en auto-memory/

L3 — Busqueda profunda (~1000 tokens max) — SOLO SI SE PIDE
  Busqueda semantica en memory-store o SQLite cache
  Fuente: data/memory-store.jsonl + SQLite cache
```

## SQLite como cache (NO como verdad)

Fichero: `~/.savia/memory-cache.db` (gitignored, por maquina)

Tablas:
- `memory_entries`: id, topic_key, type, content, importance, tokens_est, created, accessed, hits
- `memory_index`: keyword → entry_id (indice invertido para busqueda rapida)

Regenerable desde: MEMORY.md + topic files + memory-store.jsonl
Comando: `bash scripts/memory-cache-rebuild.sh`

Si SQLite no existe o esta corrupto: degradacion a lectura directa de .md (sin cache).

## Implementacion

1. `scripts/memory-cache-rebuild.sh` — lee .md files, genera SQLite
2. `scripts/memory-stack-load.sh L0|L1|L2|L3 [topic]` — devuelve tokens para esa capa
3. Integrar en session-init.sh: cargar L0+L1 al inicio (~200 tokens)
4. Integrar en comandos: L2 bajo demanda cuando el tema lo requiera

## Criterios de aceptacion

- [ ] Script memory-cache-rebuild.sh genera SQLite desde .md
- [ ] Script memory-stack-load.sh devuelve contenido por capa
- [ ] L0+L1 total <= 200 tokens
- [ ] L2 <= 500 tokens por consulta
- [ ] Degradacion sin SQLite funciona (lectura directa .md)
- [ ] Tests BATS >= 10 casos
- [ ] .md sigue siendo la fuente de verdad (Principio #1)
