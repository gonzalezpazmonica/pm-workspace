---
version_bump: minor
section: Added
---

### Added

- SE-325 Vault adjacency inline + relaciones tipadas — aprendizajes de Azure
  Cosmos DB Graph (Gremlin) aplicados al modelo de datos de SaviaVaults:
  - `scripts/vault-links.sh extract <vault>`: extrae aristas del frontmatter
    (`links: [{to, rel}]`) y de wikilinks `[[x]]` (→ `derived-from`), emite
    JSONL `{from, from_type, to, to_type, rel}` (AC-S1).
  - `projects/savia-vaults/schema/relations.yaml`: vocabulario de relaciones
    por par de tipos (schema-driven). `vault-links.sh validate [--strict]`
    valida aristas contra el vocabulario; `--strict` convierte warnings en
    error para CI (AC-S2).
  - `vault-links.sh traverse <jsonl> <id> --depth N`: traversal **BFS con
    nivel explícito** (aprendizaje Cosmos: breadth-first), lista
    `{level, node}` y emite telemetría `vault.traverse` (schema
    savia.event/1.0) con vértices visitados y profundidad (AC-S3).
  - `vault-links.sh query <vault> --filter 'key:value'`: filtra entidades por
    propiedades de frontmatter indexadas (title, status, version, type)
    (AC-S4.1).
  - Comando `/vault-graph` (AC-S4.2) + job CI `Vault Graph (report-only)`
    con `continue-on-error: true` (AC-S4.3).
  - 14 tests BATS (`tests/test-vault-links.bats`): AC-S1..S4 + zero-secrets.

### Notes

- Los aprendizajes de Cosmos aplicados son de **modelo de datos** (adyacencia
  inline, labels de arista, BFS, telemetría de coste), no de escala (Cosmos
  distribuido multi-región no aplica a cúpulas locales).
- El índice relacional de `knowledge-graph.py` sigue siendo la fuente de
  verdad derivada; la adyacencia inline en frontmatter es la capa de lectura
  de 1 query para traversals.
