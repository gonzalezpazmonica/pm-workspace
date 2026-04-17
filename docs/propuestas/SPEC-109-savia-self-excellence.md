---
id: SPEC-109
title: Savia Self-Excellence — Opus 4.7 audit remediation (10 actions)
status: IN_PROGRESS
origin: Opus 4.7 self-audit (2026-04-17), score 7.2/10
author: Savia
---

# SPEC-109 — Savia Self-Excellence

## Why

Auditoría profunda de Opus 4.7 (`output/audit-savia-self-20260417.md` + `audit-prompts-identity-20260417.md`) reveló puntuación **7.2/10** con patología principal:

> Arquitectura correcta + disciplina técnica, pero **sin disciplina de mantenimiento propio**.

- CLAUDE.md con conteos desactualizados (56→64 agents, 55→59 hooks)
- Radical Honesty redundante en 7 archivos sin jerarquía
- 27 agents sin `model:` canónico declarado
- Contradicción tono base en `savia.md`
- `autonomous-safety.md:82` usa emoji ❌ violando Rule #24
- `savia.md` 223 líneas, over-engineered
- Prompts con workarounds obsoletos de modelos pre-Opus-4.7

Objetivo: pasar de **7.2 → 8.5+** en el mismo eje de auditoría.

## Scope — 10 acciones priorizadas

| # | Acción | Impacto | Esfuerzo | PR |
|---|---|---|---|---|
| 1 | Fix drift CLAUDE.md (conteos reales) | Alto | 5min | A |
| 2 | Resolver contradicción tono savia.md | Alto | 5min | A |
| 3 | Eliminar emoji en autonomous-safety.md:82 | Medio | 2min | A |
| 4 | Consolidar Radical Honesty en 1 source-of-truth | Alto | 2h | B |
| 5 | Reducir savia.md a ~90 líneas (modo agente a fichero separado) | Alto | 1h | B |
| 6 | Declarar `model:` canónico en los 27 agents sin modelo | Medio | 1h | C |
| 7 | `scripts/drift-auto-check.sh` integrado en readiness | Alto | 2h | D |
| 8 | Consolidar 12 `*-developer` en 1 `polyglot-developer` | Medio | 8h | E (spec only, defer impl) |
| 9 | Hook latency benchmark + baseline | Medio | 6h | F |
| 10 | Skills usage audit + deprecar muertos | Medio | 4h | G |

## Strategy — bundled PRs

- **PR A (trivial)**: items 1-3 — drift + contradicción + emoji
- **PR B**: items 4-5 — identity consolidation
- **PR C**: item 6 — model normalization
- **PR D**: item 7 — drift CI
- **PR E**: item 8 — SPEC-only, defer implementation (riesgo alto, ahorro -12 agents)
- **PR F**: item 9 — hook bench script + baseline report
- **PR G**: item 10 — skills audit script + deprecation list

Cada PR: pr-plan → push → CI → admin-merge (si Verify Audit Signature falla por bug ambiental conocido). Versión CHANGELOG incremental desde 5.7.0.

## Acceptance Criteria

1. ✅ Los 10 items resueltos (item 8 queda como spec SPEC-110 para sprint futuro)
2. ✅ Re-auditoría mide score ≥ 8.5/10 en mismos ejes
3. ✅ Sin regresiones: BATS tests pasan, confidentiality scan limpio
4. ✅ CLAUDE.md counts match realidad en CI (drift-check en readiness)
5. ✅ Radical Honesty definida en un único archivo canónico, otros referencian vía @-import

## Non-goals

- NO migrar a otro runtime (openclaude research descartó — ver `output/research-openclaude-compatibility-20260416.md`)
- NO renombrar archivos de rules (rompería N+1 referencias)
- NO introducir nuevas dependencias externas
- NO cambiar modelos Opus→otro (solo declararlos correctamente)

## Rollback

Cada PR es independiente y pequeño. Rollback = `git revert <sha>` del commit squash. 
CHANGELOG descriptivo permite identificar el commit a revertir.

## Deadline

Sesión actual. User autoriza merge autónomo con admin bypass para el bug ambiental de Verify Audit Signature.
