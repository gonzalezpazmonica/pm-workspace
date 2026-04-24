---
id: SPEC-123
title: Patrón temporal Graphiti en knowledge-graph skill
status: PROPOSED
origin: Savia autonomous roadmap — Top pick #5 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
priority: media
---

# SPEC-123 — Temporal Pattern en knowledge-graph

## Why

Graphiti (getzep, 25.1k ⭐) demostró que **cada edge en un knowledge graph debe tener validez temporal**: `valid_from` y `invalid_at`. Esto resuelve:

- Re-estimación de PBIs sin reescribir historia ("quién poseía qué cuando")
- Velocity histórica con trazabilidad
- Audit trail de transiciones de estado (compliance)
- Benchmark +18.5% accuracy y -90% latencia vs MemGPT en LongMemEval

Savia ya tiene `knowledge-graph` skill. Portar el patrón temporal **sin infraestructura externa** (usando solo file-based graph) le da memoria temporal sobre el backlog PM.

## Scope

1. **Extender** schema del knowledge-graph de Savia (`.claude/skills/knowledge-graph/`) para incluir en cada edge:
   - `valid_from: ISO-8601 datetime`
   - `invalid_at: ISO-8601 datetime | null` (null = vigente)

2. **Retro-compat**: edges existentes sin `valid_from` reciben fecha del primer commit que los introdujo (via git blame).

3. **Helpers** en `scripts/graph-temporal-ops.sh`:
   - `add_edge_temporal` (sets valid_from=now)
   - `invalidate_edge` (sets invalid_at=now, NO borra)
   - `query_at_time` (reconstruye estado del graph a un instante)

4. **Query samples** documentados:
   - "¿Quién era owner de PBI-001 el 2026-03-15?"
   - "Velocity del sprint 2026-Q1 según estado a fin de sprint"
   - "Ediciones de PBI-005 últimas 7 días"

5. **Integrar** con `knowledge-graph/build.sh`, `knowledge-graph/query.sh`.

## Design

### Schema edge extendido (JSON)

```json
{
  "from": "person:laura",
  "to": "pbi:PBI-001",
  "relation": "owns",
  "valid_from": "2026-03-15T09:00:00Z",
  "invalid_at": null,
  "evidence": "commit:abc123",
  "meta": {"confidence": 0.95}
}
```

### Ejemplo temporal query

```bash
./scripts/graph-temporal-ops.sh query_at_time \
  --when "2026-03-20T17:00:00Z" \
  --entity "pbi:PBI-001" \
  --relation "owns"

# Output:
# person:laura (valid 2026-03-15T09:00:00Z → present)
```

### Retro-compat con edges sin valid_from

Al ejecutar `build.sh`, edges sin timestamp reciben:
1. `valid_from` del primer commit git que tocó el fichero de origen
2. Log warning: "Backfilled N edges with git timestamps"

Permite trazabilidad parcial sin romper consumers.

## Acceptance Criteria

- [ ] AC-01 Schema JSON del knowledge-graph documenta `valid_from` + `invalid_at` como campos opcionales pero recomendados
- [ ] AC-02 `scripts/graph-temporal-ops.sh` implementa add_edge_temporal, invalidate_edge, query_at_time
- [ ] AC-03 `build.sh` backfills edges legacy con git blame timestamps
- [ ] AC-04 3 queries samples documentados con output esperado
- [ ] AC-05 Integración con `/knowledge-prime` skill (edges temporales priorizados en priming)
- [ ] AC-06 Test bats `tests/graph-temporal.bats` con 5 cases (add, invalidate, query-at-time, retro-compat, edge sin temporal)
- [ ] AC-07 CHANGELOG entry

## Agent Assignment

Capa: Infrastructure + skills
Agente: architect + python-developer (o dotnet-developer si implementación es C#)

## Slicing

- Slice 1: Schema + helpers (add, invalidate, query) + tests
- Slice 2: Retro-compat backfill via git blame
- Slice 3: Integración con build + query + knowledge-prime + docs

## Feasibility Probe

Time-box: 75 min. Riesgo principal: parser de git blame no preserva historia tras renames. Mitigación: usar `git log --follow` para preservar.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Graph JSON grow sin bound | Alta | Medio | Compression + compaction periódica |
| Backfill incorrecto por renames | Media | Medio | `git log --follow` |
| Query lenta sobre graphs grandes | Media | Alto | Índice secundario por timestamp |
| Edges contradictorios (valid_from > invalid_at) | Baja | Bajo | Validator rechaza inputs malformados |

## Referencias

- [getzep/graphiti](https://github.com/getzep/graphiti) — patrón original
- [arXiv 2501.13956](https://arxiv.org/abs/2501.13956) — paper Zep
- `.claude/skills/knowledge-graph/` — skill actual
