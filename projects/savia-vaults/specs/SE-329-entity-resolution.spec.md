# Spec: SE-329 — Entity resolution: canonicalización y sinónimos

**Task ID:**        SE-329
**PBI padre:**      SE-329 — Entity resolution (naming consistente)
**Sprint:**        2026-08
**Fecha creacion:** 2026-08-14
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         IMPLEMENTED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 3 h |
| Human effort | 2 h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

Comentario de DIRENTIS en el artículo de referencia ("RAG vs Agentic Graph"):
"Antes de conectar entidades hace falta poder nombrarlas de forma consistente.
Los contratos, las obligaciones y los clientes viven en carpetas sueltas, con
versiones distintas y sin ningún vínculo explícito."

SaviaVaults tiene `alias` como propiedad de entidad (SE-288 S1) pero:
- no hay canonicalización en ingesta (el mismo concepto con dos grafías =
  dos entidades distintas),
- el query `Entidad.propiedad` y la búsqueda difusa no resuelven sinónimos.

Objetivo: **entity resolution determinista** en ingesta y consulta:
- canonicalización de IDs (normalización de espacio, acentos, case, guiones)
- tabla de sinónimos declarada en schema + derivada de alias
- resolución en query y en search (alias → id canónico)

## 2. Contrato Tecnico

### 2.1 Canonicalización

```typescript
// src/knowledge/entity-resolution.ts
function canonicalizeId(raw: string): string {
  // NFKD strip diacritics → lowercase → trim → collapse whitespace
  // → replace [ _]+ with '-'
}

interface EntityResolutionIndex {
  canonicalId: Map<string, string>;   // canonical id -> real entity id
  synonyms: Map<string, string>;      // alias/canonical variant -> canonical id
}

class EntityResolver {
  build(entities: { id: string; alias?: string[] }[]): EntityResolutionIndex;
  resolve(input: string): string | undefined;   // input -> canonical id
}
```

### 2.2 Ingesta

Al indexar (vault index / build), se genera el índice de resolución:
- `canonicalId`: `canonicalizeId(entity.id)` → entity.id
- `synonyms`: cada alias (canonicalizado) → entity.id

### 2.3 Integración en query y search

- `QueryEngine.query("Entidad...")`: antes de resolver, pasa por
  `resolver.resolve("entidad")`; si coincide con alias/canonical, usa el id real.
- `SearchEngine.search`: expande el query con sinónimos del índice (OR léxico).
- Colisiones (dos entidades con el mismo canonical): se reporta en health-report
  como warning `entity-resolution-collision`.

## 3. Criterios de aceptacion

- [ ] AC-1: `canonicalizeId("Área De Negocio")` == `canonicalizeId("area-de-negocio")`.
- [ ] AC-2: alias resuelve al id canónico (`resolve(alias) === entity.id`).
- [ ] AC-3: input sin alias coincide → resuelve a sí mismo.
- [ ] AC-4: input inexistente → undefined (no lanza).
- [ ] AC-5: query por alias devuelve los resultados de la entidad real.
- [ ] AC-6: search expande con sinónimos.
- [ ] AC-7: colisión de canonicalización → warning en health-report.
- [ ] AC-8: determinista.

## 4. Tests

`tests/entity-resolution.test.ts` (vitest): canonicalización, alias, query,
search, colisiones, vacío, determinismo.
