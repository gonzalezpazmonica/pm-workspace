---
id: SE-325
title: "SE-325 — Vault adjacency inline + relaciones tipadas para SaviaVaults"
status: IMPLEMENTED
priority: alta
---

# SE-325 — Vault adjacency inline + relaciones tipadas para SaviaVaults

**Status:** IMPLEMENTED
**Fecha:** 2026-08-12
**Area:** Knowledge graph / SaviaVaults / Search
**Branch sugerida:** `agent/se325-vault-adjacency`
**Estimacion total:** ~24h (4 slices)
**Inspiracion:** Azure Cosmos DB Graph API (Gremlin/TinkerPop) — patrón de
modelo de datos, no de escala.

---

## Contexto y evidencia (2026-08-12)

Azure Cosmos DB Graph (API Gremlin) persiste cada vértice **con su adyacencia
inline** (`outE`/`inE` dentro del JSON del vértice), etiqueta vértices y
aristas (`label: person`, `knows`), usa **traversal breadth-first** con nivel
explícito, indexa automáticamente todas las propiedades (schema-agnostic) y
expone `executionProfile()` para medir el coste de cada paso de una traversal.

Savia tiene:
- `knowledge-graph.py` (SQLite, `relations` en tabla separada `entity_a,
  relation, entity_b`),
- `vaults-graph-query.sh` (traverse/query vía CLI node de SaviaVaults),
- notas markdown con frontmatter `entity: {type, id}` y tags,
- `docs/rules/domain/knowledge-graph.md` (SE-162).

**El hueco.** Las relaciones de SaviaVaults viven en una tabla relacional
separada, por lo que cada traversal profunda es N queries (una por salto). Las
aristas no tienen label/vocabulario tipado por par de tipos. No hay medida del
coste de una traversal (explosión combinatoria indetectada). Y el frontmatter
(title, status, version) no está indexado para filtros tipados.

---

## Objetivo

Aplicar los aprendizajes de Cosmos Graph al modelo de datos de SaviaVaults:

1. **Adyacencia inline**: el frontmatter de cada nota declara sus aristas
   (`links: [{to, rel}]`), denormalizadas para lectura en 1 query. El índice
   relacional (knowledge-graph) sigue siendo la fuente de verdad derivada.
2. **Labels tipados**: vocabulario de relaciones por par de tipos
   (`derived-from`, `supports`, `contradicts`, `implements`, `depends-on`),
   validado en ingesta.
3. **Traversal BFS con nivel explícito** y telemetría del coste.

---

## Out of scope

- NO migrar a Gremlin/TinkerPop ni a un motor de grafo externo.
- NO tocar el storage git-backed ni BM25 de SaviaVaults.
- NO particionado, multi-región ni SLA distribuido (Cosmos escala no aplica).

---

## Diseno

### S1 — Adyacencia inline en frontmatter

`scripts/vault-links.sh extract <vault-path>`:
- lee notas markdown, extrae el bloque `entity:` y un nuevo bloque `links:`:
  ```yaml
  links:
    - to: otro-documento
      rel: derived-from
  ```
- soporta dos fuentes: (a) `links:` explícito en frontmatter, (b) wikilinks
  `[[otro-documento]]` convertidos a `derived-from` por defecto,
- emite JSONL `output/vault-graph/{vault}-links.jsonl` con
  `{from, from_type, to, to_type, rel}` para cada arista.

### S2 — Vocabulario de relaciones tipadas

`projects/savia-vaults/schema/relations.yaml`:
- reglas `from_type → to_type → [rel...]` permitidas (schema-driven),
- `scripts/vault-links.sh validate <jsonl>`: valida cada arista contra el
  vocabulario; aristas fuera de vocabulario → warning con sugerencia,
- `--strict` convierte warnings en error (para CI).

### S3 — Traversal BFS + telemetría

`scripts/vault-links.sh traverse <id> --depth N`:
- construye el grafo desde el JSONL de adyacencia y hace **BFS con nivel
  explícito** (no DFS), listando `{level, node}`,
- emite telemetría `vault.traverse` (schema savia.event/1.0, SE-313) con
  vértices visitados, profundidad y tiempo — detecta traversals explosivas.

### S4 — Integración + comando

- `scripts/vault-links.sh query --filter 'status:approved'`: filtra entidades
  por propiedades de frontmatter indexadas (title, status, version, type),
- comando `/vault-graph` envuelve extract/validate/traverse/query,
- job CI `Vault Graph (report-only)` con `continue-on-error: true`.

---

## Criterios de aceptacion

### AC-S1: Adyacencia inline

- [ ] AC-S1.1: nota con `links:` explícito → arista en JSONL con from/to/rel.
- [ ] AC-S1.2: nota con wikilink `[[x]]` → arista `derived-from` auto.
- [ ] AC-S1.3: sin links → no aristas (no inventa).

### AC-S2: Vocabulario

- [ ] AC-S2.1: arista con rel fuera del vocab para el par → warning.
- [ ] AC-S2.2: `--strict` con arista inválida → exit 1.
- [ ] AC-S2.3: arista válida → pasa sin warning.

### AC-S3: Traversal

- [ ] AC-S3.1: traverse depth 2 → niveles listados con profundidad.
- [ ] AC-S3.2: `vault.traverse` aparece en telemetry-events.jsonl.
- [ ] AC-S3.3: nodo sin vecinos → solo level 0, exit 0.

### AC-S4: Integración

- [ ] AC-S4.1: query `--filter status:approved` devuelve solo aprobadas.
- [ ] AC-S4.2: comando `/vault-graph` invocable.
- [ ] AC-S4.3: job CI report-only registrado.

---

## Ref

- Azure Cosmos DB for Gremlin support (learn.microsoft.com): adyacencia
  `outE`/`inE` inline, labels, BFS traversal, `executionProfile()`.
- `scripts/knowledge-graph.py`, `scripts/vaults-graph-query.sh`
- `projects/savia-vaults/schema/entities/*.yaml`

## Implementación (2026-08-12)

- `scripts/vault-links.sh` con subcomandos `extract` / `validate` / `traverse`
  / `query` (determinista, stdlib python, sin LLM).
- `projects/savia-vaults/schema/relations.yaml`: vocabulario de relaciones
  por par de tipos.
- Comando `/vault-graph` + job CI `Vault Graph (report-only)`.
- 14 tests BATS (`tests/test-vault-links.bats`).
