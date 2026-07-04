---
spec_id: SE-213
title: Confidence and provenance fields in Knowledge Graph entries
status: IMPLEMENTED
closed_by_pr: "#unknown-backfill"
closed_date: "2026-06-24"
drift_note: "drift: components existed pre-triage (knowledge-graph.py has confidence REAL + provenance TEXT columns with idempotent migration + --min-confidence filter)"
implemented_at: "2026-06-24"
priority: P2
effort: S
era: 202
origin: output/research/memanto-savia-20260607.md
inspiration: Memanto confidence:float + provenance:explicit_statement|inferred|observed
---

# SE-213 — Confidence + provenance fields in KG

## Problema

El KG actual no registra el grado de certeza de una entidad ni de dónde proviene. Una decisión explícita y una inferencia tienen el mismo peso. Memanto añade `confidence:float` y `provenance` (explicit_statement | inferred | observed) para permitir queries de alta confianza y trazabilidad del origen.

## Solución

Añadir dos campos al schema del KG: `confidence REAL` (0.0-1.0) y `provenance TEXT`. Permiten queries filtradas por confianza y trazabilidad del origen de cada entidad.

## Scope

### 1. `scripts/knowledge-graph.py`

Columnas adicionales en `entities`:

```sql
confidence REAL DEFAULT 0.8
provenance TEXT DEFAULT 'unknown'
```

Migration safe (ALTER IF NOT EXISTS). Los valores existentes sin confidence reciben DEFAULT 0.8 (neutro).

### 2. `scripts/knowledge-graph.sh query --min-confidence 0.7`

Filtrar entidades por confidence mínima.

### 3. Inferencia de provenance en `build`

| Origen | provenance |
|---|---|
| Entrada explícita de MEMORY.md | explicit_statement |
| Inferida de relaciones entre entidades | inferred |
| Observada de eventos/commits | observed |
| Sin clasificar | unknown |

### 4. Documentación

Añadir sección a `docs/rules/domain/memory-type-schema.md` (creado en SE-211).

## Acceptance Criteria

- **AC1**: `knowledge-graph.py entities` retorna `confidence` y `provenance` en output JSON
- **AC2**: `knowledge-graph.sh query --min-confidence 0.7` filtra correctamente
- **AC3**: entidades existentes sin confidence tienen DEFAULT 0.8 (neutro)
- **AC4**: provenance `unknown` para entradas sin clasificar (sin romper nada)

## OpenCode Implementation Plan

```yaml
classification: PYTHON_BASH
files_touched:
  - scripts/knowledge-graph.py
  - docs/rules/domain/memory-type-schema.md
requires_restart: false
verification: python scripts/knowledge-graph.py entities --min-confidence 0.7
```

## Referencias

- SE-211 — Typed memory schema (prerequisito para memory-type-schema.md)
- `scripts/knowledge-graph.py` — implementación actual del KG
- `docs/ROADMAP.md#era-202` — Era 202 Memory intelligence upgrade
