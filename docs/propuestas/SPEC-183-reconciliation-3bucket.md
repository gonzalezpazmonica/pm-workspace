---
spec_id: SPEC-183
title: Reconciliation 3-bucket resolution in drift-auditor
status: IMPLEMENTED
tier: 2
priority: P3
effort: 5-7h
era: 199
wave: 3
deps:
  - SPEC-182
unblocks: []
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain `/obsidian-reconcile` (4 parallel subagents, 3-outcome decision tree)
---

# SPEC-183 — Reconciliation 3-bucket en drift-auditor

> Estado: PROPOSED · Tier 2 · P3 · Estimación 5-7h · Era 199 · Wave 3 · Dep: SPEC-182

## Resumen

Extender `drift-auditor` (hoy solo flagea contradicciones) con un sub-agente `reconciler` que aplica un árbol de decisión de 3 outcomes: **auto-resolve** (ganador claro), **conflict-doc** (ambiguo, requiere humano), **evolution** (cambio temporal legítimo, no contradicción). Requiere `timeline:` de SPEC-182 para distinguir evolution de conflict.

## Motivación

- drift-auditor hoy emite reporte y termina. Humano debe leer, decidir, aplicar. Latencia alta.
- coherence-validator detecta inconsistencias pero tampoco resuelve.
- Patrón obsidian demuestra que ~60-70% de las contradicciones son auto-resolubles (más reciente + más autoritativo gana) y ~20% son evolution (no contradicción). Solo ~10-20% requieren humano.

## Scope

1. Sub-agente nuevo `reconciler` en `.opencode/agents/reconciler.md` (mid, L1).
2. Árbol de decisión documentado en `docs/rules/domain/reconciliation-decision-tree.md`:
   - Paso 1: ¿hay timeline? Si SÍ y diferencia es temporal-coherente → evolution.
   - Paso 2: ¿hay ganador claro? (más reciente AND más autoritativo) → auto-resolve.
   - Paso 3: caso contrario → conflict-doc.
3. Outputs:
   - Auto-resolve: rewrite + bloque `## History` con old→new + source/fecha.
   - Evolution: append timeline entry (vía SPEC-182).
   - Conflict-doc: crear `output/conflicts/{topic}-{YYYYMMDD}.md` con `status: open`.
4. Métricas en log: `found=N auto=X evolution=Y conflict=Z`.
5. Integración con drift-auditor existente: invoca reconciler tras detectar contradicciones.

## Acceptance Criteria

- AC1: Árbol de decisión documentado con 6 ejemplos (2 por bucket).
- AC2: Agente reconciler ejecutable standalone (input: 2 fragments + context).
- AC3: drift-auditor delega a reconciler automáticamente cuando detecta contradicción.
- AC4: Conflict-docs llevan frontmatter `status: open` + `topic` + `sources: []` + `detected_at`.
- AC5: BATS test con 9 fixtures (3 por bucket) verifica clasificación correcta.
- AC6: Métricas log en formato JSON line append a `.savia/reconciliation-stats.jsonl`.
- AC7: Auto-resolve REQUIERE log y enlace al cambio (audit trail).
- AC8: Conflict-docs NO se auto-resuelven aunque pase tiempo (siempre humano).

## Slices

1. **Slice 1 (1h)** — Documentar árbol + ejemplos.
2. **Slice 2 (2h)** — Crear agente reconciler + BATS fixtures.
3. **Slice 3 (2h)** — Integración con drift-auditor + métricas.
4. **Slice 4 (1-2h)** — Piloto: correr en pm-workspace, medir bucket distribution real.

## Out of scope

- Reconciliación cross-proyecto.
- Auto-aprobación de conflict-docs por antigüedad (rule #8: nunca autónomo en decisiones).
- UI de revisión de conflict-docs.
