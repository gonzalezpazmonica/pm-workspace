---
spec_id: SPEC-182
title: Bi-temporal timeline frontmatter on specs and decisions
status: APPROVED
tier: 1
priority: P2
effort: 6-8h
era: 199
wave: 2
deps: []
unblocks:
  - SPEC-183
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain timeline frontmatter (bi-temporal facts)
---

# SPEC-182 — Bi-temporal `timeline:` frontmatter on specs and decisions

> Estado: PROPOSED · Tier 1 · P2 · Estimación 6-8h · Era 199 · Wave 2

## Resumen

Introducir frontmatter `timeline:` array en specs y entradas MEMORY que distingue **transaction time** (cuándo se aprendió) de **event time** (cuándo era cierto). Top-level fields (`status:`, `priority:`) siempre reflejan el estado actual; `timeline:` preserva la historia completa. Permite responder "¿qué status tenía SPEC-X en abril?" sin git log.

## Motivación

- Hoy `status: APPROVED` en un SPEC borra el dato "estuvo PROPOSED hasta el 2026-04-15".
- MEMORY entries (`auto/MEMORY.md`) son slugs con fecha pero sin estructura — no responden "¿qué creíamos antes?".
- Alineamiento con `legalize-es`: legislación consolidada = current; versiones = timeline. Mismo principio formal.
- Audit trail para SE-094 y compliance enterprise.

## Scope

1. Schema YAML `timeline:` array. Cada entrada: `from`, `until` (opcional, ausencia = vigente), `learned`, `value`, `source`.
2. Aplicar a `docs/propuestas/SPEC-*.md` (status transitions).
3. Aplicar a `.claude/external-memory/auto/decision/*.md` (mutación de decisiones).
4. Script utility `scripts/timeline-append.sh` que añade entrada preservando top-level y rotando `until` del anterior.
5. BATS test que verifica: schema válido, top-level consistente con última entrada de timeline, sin gaps temporales, sin overlaps.

## Acceptance Criteria

- AC1: Schema documentado en `docs/rules/domain/bitemporal-timeline-schema.md` con ejemplos.
- AC2: `scripts/timeline-append.sh status SPEC-XYZ APPROVED "PR #800"` añade entrada al timeline y actualiza top-level `status:` atómicamente.
- AC3: BATS valida: 100% de SPECs con `status` cambiado en últimos 30 días tienen entrada timeline correspondiente.
- AC4: Query `scripts/timeline-query.sh SPEC-156 --at 2026-04-01` devuelve el `status` que tenía en esa fecha.
- AC5: Top-level `status:` SIEMPRE === última entrada del timeline (gate BATS).
- AC6: Migración: 5 SPECs piloto reciben timeline reconstruido desde git log.
- AC7: MEMORY decision entries soportan timeline opcional (compatibilidad con existentes).

## Slices

1. **Slice 1 (1h)** — Schema + doc + 3 ejemplos.
2. **Slice 2 (2h)** — `timeline-append.sh` + `timeline-query.sh` + BATS schema validation.
3. **Slice 3 (2h)** — Migración 5 SPECs piloto desde git log.
4. **Slice 4 (1-2h)** — Hook PostCommit que sugiere `timeline-append` si detecta `status:` cambiado sin entrada timeline.

## Out of scope

- Migrar TODOS los SPECs (incremental, sprint a sprint).
- UI temporal/visualización.
- Aplicar a reglas (`docs/rules/`) — futuro SPEC.
- Reconciliación automática de timelines contradictorios (eso es SPEC-183).
