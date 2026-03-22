# SPEC-027: Graph Memory Layer — Entity-Relation Extraction

> Status: **RESEARCH** · Fecha: 2026-03-22 · Score: 4.85
> Origen: LightRAG (hkuds/lightrag) — knowledge graph + vector hybrid
> Impacto: Recall semantico superior. "auth" encuentra "token refresh".

---

## Problema

SPEC-018 (vector index) mejoro recall de 40% a 90%. Pero la busqueda
vectorial sigue siendo "bolsa de palabras con significado". No entiende
relaciones: "quien decidio usar PostgreSQL?" requiere saber que
PostgreSQL fue una DECISION tomada por el EQUIPO para el PROYECTO.

LightRAG demuestra que un grafo de entidades+relaciones sobre el
mismo texto mejora significativamente la precision en queries complejas.

## Vision

Sobre el JSONL existente (fuente de verdad), extraer:

```
Entidades: [PostgreSQL, OAuth2, TeamAlpha, Sprint-06, AuthService]
Relaciones: [TeamAlpha -DECIDED-> PostgreSQL, AuthService -USES-> OAuth2]
```

Busqueda dual: vector similarity + graph traversal.
El grafo es derivado (regenerable desde JSONL), igual que el indice vector.

## Arquitectura

```
JSONL (verdad) → extract_entities() → graph.json (derivado, gitignored)
                → vector index (ya existe, SPEC-018)

Query → vector search (top K) + graph traversal (relations) → rerank → results
```

## Fase 1 — Extraccion de entidades (implementable sin LLM)

Regex + heuristicas para extraer entidades de las memorias:
- Nombres propios (capitalized words en titulo)
- Topic key families como categorias (decision/*, bug/*)
- Proyectos (campo project)
- Conceptos (campo concepts)

Formato: `output/.memory-graph.json`
```json
{
  "entities": {"PostgreSQL": {"type": "technology", "mentions": 3}},
  "relations": [{"from": "Sprint-06", "to": "PostgreSQL", "type": "decided"}]
}
```

## Fase 2 — Extraccion con LLM local (requiere SPEC-023)

Usar el LLM entrenado en Fase 4 de SPEC-023 para extraccion semantica
de entidades y relaciones — mucho mas preciso que regex.

## Fase 3 — Dual retrieval

Combinar vector search + graph traversal en memory-search.sh.
Reranker opcional (SPEC-028) para ordenar resultados combinados.

## Tests

- Entity extraction encuentra nombres en titulos
- Graph JSON es valido y regenerable
- Dual search mejora recall vs vector solo (benchmark)
