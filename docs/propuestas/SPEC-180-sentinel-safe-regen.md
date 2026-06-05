---
spec_id: SPEC-180
title: Sentinel-safe regeneration primitive
status: IMPLEMENTED
tier: 1
priority: P1
effort: 2-3h
era: 199
wave: 1
deps: []
unblocks:
  - SPEC-181
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain `write-rules.md` (@generated/@user markers)
---

# SPEC-180 — Sentinel-safe regeneration primitive

> Estado: PROPOSED · Tier 1 · P1 · Estimación 2-3h · Era 199 · Wave 1

## Resumen

Definir una primitiva universal de marcadores HTML que permite a scripts de regeneración modificar SOLO bloques marcados como `@generated`, preservando intactos los bloques `@user`. Aplica a cualquier documento del workspace: AGENTS.md, ROADMAP.md, CLAUDE.md, twin.md (SPEC-169).

## Motivación

- Hoy `scripts/agents-md-auto-regenerate.sh` reescribe AGENTS.md entero. Si alguien añade notas humanas, se pierden.
- `managed-content` skill aborda el problema parcialmente pero no está documentado como primitiva reusable.
- SPEC-169 Project Twin necesita bloques regenerables (`Estado`, `Predicciones`) junto a bloques humanos (`Notas`) en el mismo fichero.

## Scope

1. Documentar el contrato de markers en `docs/rules/domain/sentinel-safe-regen.md`:
   - `<!-- @generated:{section-id} START hash={sha} -->` ... `<!-- @generated:{section-id} END -->`
   - `<!-- @user:{section-id} -->` (marcador inicio sin END — todo lo posterior es humano hasta el siguiente sentinel).
2. Script utility `scripts/sentinel-regen.sh` con tres modos: `inject`, `extract`, `verify-hash`.
3. Migrar `scripts/agents-md-auto-regenerate.sh` a usar sentinels (piloto).
4. BATS test `tests/structure/test-sentinel-regen.bats` con casos: inject preserva user, extract devuelve solo generated, hash drift detectado.

## Acceptance Criteria

- AC1: Re-generar AGENTS.md con sentinels NO destruye bloques `@user` añadidos manualmente.
- AC2: Hash en cada bloque generated permite detectar drift (alguien editó manualmente lo que es generado).
- AC3: Script `verify-hash` exit 1 si detecta drift, exit 0 si limpio.
- AC4: Contrato documentado <50 líneas, copy-pasteable en otros docs.
- AC5: BATS test cubre 6 casos mínimo (inject limpio, inject con user, drift detectado, missing END, malformed marker, idempotencia).
- AC6: README de la regla incluye ejemplo mínimo de 10 líneas.

## Slices

1. **Slice 1 (1h)** — Documentar contrato + ejemplos. Sin código.
2. **Slice 2 (1h)** — `scripts/sentinel-regen.sh` con 3 modos + BATS.
3. **Slice 3 (1h)** — Migrar AGENTS.md auto-regen como piloto. Validar idempotencia.

## Out of scope

- Migrar TODOS los documentos auto-generados en este SPEC (cada uno será su propio SPEC follow-up).
- UI/visualización de bloques generated vs user.
- Versionado de contenido generado (es responsabilidad de git).
