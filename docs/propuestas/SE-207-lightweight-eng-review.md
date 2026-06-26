---
spec_id: SE-207
title: Lightweight Engineering Review template for infra changes
status: IMPLEMENTED
drift_note: "drift: components existed pre-triage (docs/rules/domain/lightweight-eng-review.md implemented as full template)"
implemented_at: "2026-06-24"
priority: P2
effort: B
era: 200
origin: output/research/orca-savia-20260607.md
inspiration: Orca design doc pattern with Lightweight Eng Review section
---

# SE-207 — Lightweight Engineering Review Template

## Resumen
Template más ligero que SDD completo para cambios de infraestructura del workspace (scripts, hooks, configs, refactors menores). Inspirado en los 540+ design docs de Orca con secciones: Problem → Root Cause → Non-Goals → Design → Data Flow → Edge Cases → Test Plan → Rollout → Lightweight Eng Review.

## Motivación
Savia tiene dos extremos: SDD completo (correcto para features) o sin documentación (para scripts/fixes). El design doc de Orca es el punto medio — captura lo crítico de ingeniería sin la ceremonia SDD. Apropiado para: nuevos scripts bash, cambios en hooks, refactors de skills, actualizaciones de config.

## Scope
1. `docs/rules/domain/lightweight-eng-review.md` — regla + template canónico + criterios de cuándo usar LER vs SDD completo
2. `docs/templates/lightweight-eng-review.md` — template vacío para copiar

## AC
- AC1: Template tiene las 9 secciones de Orca (Problem...Rollout + LER)
- AC2: LER section cubre: failure modes, blast radius, test coverage, residual risks
- AC3: Criterios claros de cuándo usar LER vs SDD completo
- AC4: Ejemplo completo incluido en la regla

## Slices
1. Slice 1 (30 min): regla + template + ejemplo
