# SPEC-034: Temporal Memory — Hechos con Validez Temporal

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.75
> Origen: Graphiti (24K stars) — temporal knowledge graphs
> Impacto: Elimina decisiones obsoletas que contradicen las actuales

---

## Problema

Las decisiones y memorias de Savia no caducan. El context-aging comprime
por edad pero no invalida hechos. Resultado: una decision de enero puede
contradecir una de marzo sin que Savia lo detecte.

Graphiti resuelve esto con bi-temporalidad: cada hecho tiene
`valid_from` / `valid_to`. No se borra — se marca como superado.

## Principio inmutable

**Los ficheros .md son la fuente de verdad.** La temporalidad se anade
como metadata en frontmatter o inline, nunca en una base de datos externa.
Si se pierde el indice, se reconstruye desde los .md.

## Solucion

Anadir campos temporales al memory-store y al decision-log.

### Formato en memory-store (JSONL)

```json
{
  "title": "Adoptamos GraphQL para frontend",
  "type": "decision",
  "valid_from": "2026-01-15",
  "valid_to": null,
  "superseded_by": null,
  "content": "..."
}
```

Cuando una decision se supera:
```json
{
  "title": "Adoptamos GraphQL para frontend",
  "valid_to": "2026-03-20",
  "superseded_by": "topic_key:api-strategy-v2"
}
```

### Formato en decision-log.md

```markdown
- 2026-03-20: Volver a REST para frontend [supersedes: 2026-01-15 GraphQL]
- ~~2026-01-15: Adoptar GraphQL para frontend~~ [superseded: 2026-03-20]
```

### Formato en auto-memory (.md con frontmatter)

```yaml
---
name: api-strategy
valid_from: 2026-03-20
supersedes: api-strategy-v1
---
REST para frontend, GraphQL solo para mobile.
```

## Consulta temporal

Al buscar memoria, Savia filtra por validez:
1. Si `valid_to` es null → hecho vigente
2. Si `valid_to` < hoy → hecho historico (no usar para decisiones)
3. Si el usuario pregunta "que decidimos sobre X" → mostrar vigente + historico

## Deteccion de contradicciones

Cuando se guarda una decision nueva:
1. Buscar decisions con topic_key similar
2. Si existe una vigente que contradice → preguntar:
   "Esto contradice la decision del {fecha}: {titulo}. ¿La supera?"
3. Si confirma → marcar la anterior con valid_to = hoy

## Implementacion

1. Extender `scripts/memory-save.sh` con `--supersedes {topic_key}`
2. Extender `scripts/memory-search.sh` con `--active-only` (default)
3. Modificar session-memory-protocol para detectar contradicciones
4. Los .md existentes sin temporalidad se tratan como `valid_from: fecha_creacion, valid_to: null`

## Esfuerzo

Medio — 1 sprint. Compatible con memoria existente (campos opcionales).
