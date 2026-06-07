---
spec_id: SE-211
title: Typed memory schema — 13 semantic types in Knowledge Graph
status: APPROVED
priority: P1
effort: M
era: 202
origin: output/research/memanto-savia-20260607.md
inspiration: Memanto typed memory (fact/decision/instruction/preference/goal/commitment/event/learning/error/observation/relationship/context/artifact)
---

# SE-211 — Typed memory schema (13 semantic types) in KG

## Problema

El KG actual no distingue semánticamente el tipo de entidad almacenada. Una `decision` y un `bug` coexisten sin clasificación, lo que impide filtrado por tipo, retrieval específico y diagnóstico de la memoria. Memanto demuestra que 13 tipos semánticos mejoran la calidad de retrieval y el diagnóstico.

## Solución

Añadir columna `memory_type TEXT` al schema SQLite del KG y al MEMORY.md index. Los 13 tipos semánticos de Memanto permiten filtrado por tipo en queries, retrieval específico, y mejor diagnóstico de la memoria.

## Scope

### 1. `scripts/knowledge-graph.py`

Añadir columna `memory_type TEXT` a la tabla `entities` con `ALTER TABLE IF NOT EXISTS` o en `CREATE TABLE` (migration safe). Validar contra enum de 13 tipos en `upsert_entity`. Pasar `--memory-type <type>` en el subcomando `build`.

### 2. `scripts/memory-store.sh`

Al hacer `save`, detectar el tipo implícito desde el campo `<tipo>` del comando:

| Tipo de entrada | memory_type |
|---|---|
| decision | decision |
| discovery | observation |
| session-summary | context |
| bug | error |
| architecture | artifact |
| pattern | learning |

### 3. `docs/rules/domain/memory-type-schema.md`

Enum de 13 tipos documentado (≤60 líneas).

### 4. `scripts/knowledge-graph.sh entities --type decision`

Filtrar por tipo.

## Acceptance Criteria

- **AC1**: `knowledge-graph.py entities` acepta `--type <memory_type>` y filtra correctamente
- **AC2**: `memory-store.sh save decision "..."` registra `memory_type=decision` en el KG
- **AC3**: tipos inválidos producen WARN (no error) — compatibilidad con entradas antiguas
- **AC4**: `docs/rules/domain/memory-type-schema.md` documenta los 13 tipos con criterios de cuándo usar cada uno

## Los 13 tipos semánticos (Memanto)

| Tipo | Descripción |
|---|---|
| fact | Hecho objetivo verificable |
| decision | Decisión tomada con justificación |
| instruction | Regla operativa o instrucción de comportamiento |
| preference | Preferencia del usuario o del sistema |
| goal | Objetivo a alcanzar |
| commitment | Compromiso asumido con fecha o condición |
| event | Evento puntual (merge, deploy, reunión) |
| learning | Aprendizaje o patrón descubierto |
| error | Bug, fallo o error detectado |
| observation | Observación sin juicio de valor |
| relationship | Relación entre entidades |
| context | Resumen de sesión o contexto situacional |
| artifact | Artefacto producido (fichero, spec, doc) |

## OpenCode Implementation Plan

```yaml
classification: PYTHON_BASH
files_touched:
  - scripts/knowledge-graph.py
  - scripts/memory-store.sh
  - docs/rules/domain/memory-type-schema.md
requires_restart: false
verification: python scripts/knowledge-graph.py entities --type decision
```

## Referencias

- `docs/rules/domain/memory-type-schema.md` — schema canónico (creado por esta spec)
- `scripts/knowledge-graph.py` — implementación actual del KG
- `scripts/memory-store.sh` — store de memoria persistente
- `docs/ROADMAP.md#era-202` — Era 202 Memory intelligence upgrade
