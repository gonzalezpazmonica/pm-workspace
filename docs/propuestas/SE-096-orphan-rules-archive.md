---
spec_id: SE-096
title: Archive 9 orphan rules (zero cross-references)
status: IMPLEMENTED
approved_by: operator (2026-05-27)
priority: P1
effort: S
estimated_time: 60 min
depends_on: SE-048 (rule-orphan-detector)
applied_at: "2026-06-24"
source: output/20260527-auditoria-obsoleto-legado.md (Tier 2.4)
---

# SE-096 — Archive orphan rules

## Problema

`rule-orphan-detector.sh` detecta 9 reglas en `docs/rules/domain/` con 0 referencias cruzadas:

- hook-event-equivalence.md
- image-relevance-filter.md
- portfolio-as-graph.en.md
- receipts-protocol.en.md
- savia-memory-architecture.md
- session-state-location.md
- slm-consolidation-pattern.md
- slm-training-pipeline.en.md
- vault-frontmatter.md

Documentación de gobierno sin consumidores → ruido cognitivo y mantenimiento.

## Solución

Para cada regla:
1. `grep -r` exhaustivo (incluyendo specs, CHANGELOG, agents internos) para confirmar 0 uso real
2. Decidir por categoría:
   - **archive**: mover a `docs/archive/rules/YYYYMMDD-<name>.md` con nota de razón
   - **integrate**: añadir referencia en agent/skill/script relevante (deja de ser huérfana)
   - **keep-as-reference**: si es regla documental sin consumidor por diseño (raro), añadir frontmatter `usage: reference-only`

## Aceptación

- `rule-orphan-detector.sh` reporta 0 huérfanas
- CHANGELOG documenta destino de cada una
- Ningún test/script roto por las movidas
