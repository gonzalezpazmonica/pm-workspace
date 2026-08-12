---
name: vault-graph
description: "SE-325: adyacencia inline + relaciones tipadas del knowledge graph de SaviaVaults (extract/validate/traverse/query)"
argument-hint: "extract <vault-path> | validate <links.jsonl> [--strict] | traverse <links.jsonl> <id> [--depth N] | query <vault-path> --filter 'k:v'"
tier: core
---

# /vault-graph — Relaciones tipadas del grafo (SE-325)

Aplica aprendizajes de Cosmos DB Graph al modelo de datos de SaviaVaults:
adyacencia inline en frontmatter (`links:`), vocabulario de relaciones por
par de tipos, traversal BFS con nivel explícito y filtros tipados.

## Subcomandos

```
scripts/vault-links.sh extract <vault-path>            # aristas de frontmatter + wikilinks → JSONL
scripts/vault-links.sh validate <links.jsonl> [--strict]  # contra schema/relations.yaml
scripts/vault-links.sh traverse <links.jsonl> <id> [--depth N]  # BFS con niveles + telemetría
scripts/vault-links.sh query <vault-path> --filter 'status:approved'  # entidades por propiedad
```

## Nota en las notas del vault

Para declarar relaciones explícitas, añadir al frontmatter:

```yaml
links:
  - to: otro-documento
    rel: derived-from
```

Los wikilinks `[[otro-documento]]` en el cuerpo se convierten a
`derived-from` automáticamente.

Ref: `docs/propuestas/SE-325-vault-adjacency-inline.md`
