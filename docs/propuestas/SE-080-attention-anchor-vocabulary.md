---
id: SE-080
title: SE-080 — Attention-anchor vocabulary (Genesis B8/B9/A7/A9 patterns)
status: APPROVED
origin: Genesis review (danielmeppiel/genesis) — sub-agent report 2026-04-26
author: Savia
priority: media
effort: S 2h
related: SE-079, SE-074, SPEC-124 (Court), autonomous-safety
approved_at: "2026-04-26"
applied_at: null
expires: "2026-06-26"
era: 189
---

# SE-080 — Attention-anchor vocabulary

## Why

pm-workspace ya implementa varios primitives canónicos del catálogo Genesis sin nombrarlos:

- **B8 ATTENTION ANCHOR**: re-inyección del goal/constraint en sesiones largas. Hoy lo hace el orquestador SE-074 cuando arranca cada worker pasando `{spec_id}` y el budget — implícito.
- **B9 GOAL STEWARD**: agente que defiende el alcance del request original frente a drift. Hoy lo hace `radical-honesty.md` Rule #24 ("don't add features beyond what the task requires") — informal, no enforced.
- **A7 ADVERSARIAL REVIEW**: panel adversarial pre-merge. Hoy lo hace el Court de 5 jueces (SPEC-124) — implementado pero sin etiqueta cross-repo.
- **A9 SUPERVISED EXECUTION**: humano siempre en el loop para acciones irreversibles. Hoy lo hace `autonomous-safety.md` (AUTONOMOUS_REVIEWER, agent/* branches, draft PRs) — robusto pero sin nombre estándar.

Coste de no nombrar: cuando integramos con OpenCode (SE-077), Codex u otros frontends que adoptan el vocabulario Genesis, nuestros primitives quedan "anónimos" — el otro lado no reconoce que ya cumplimos los patrones. Friction de interoperabilidad.

Coste de nombrar: una doc de ~30 líneas + cross-references desde 4 reglas existentes. Sin código nuevo. Sub-1h efectivo.

## Scope (Slice único, S 2h)

### 1. Doc canónico

`docs/rules/domain/attention-anchor.md` (~80 líneas):

- Definición de los 4 patrones (B8, B9, A7, A9) con vocabulario Genesis
- Mapeo a la implementación existente en pm-workspace:
  - B8 → orquestador SE-074 worker spawn, `Spec ref:` line en G11
  - B9 → `radical-honesty.md` Rule #24, SE-079 G13 scope-trace gate
  - A7 → Court 5 jueces (`docs/rules/domain/code-review-court.md`)
  - A9 → `docs/rules/domain/autonomous-safety.md`
- Notas: NO portar el resto del catálogo Genesis (R-tier refactors, A1-A6) — sólo los 4 que ya tenemos. Adopciones futuras requieren spec separado.

### 2. Cross-references (mínimas)

Añadir UNA línea en cada uno de:

- `docs/rules/domain/radical-honesty.md` → "Implementa Genesis B9 GOAL STEWARD" en sección "Source of truth"
- `docs/rules/domain/autonomous-safety.md` → "Implementa Genesis A9 SUPERVISED EXECUTION" en el header
- `docs/rules/domain/code-review-court.md` → "Implementa Genesis A7 ADVERSARIAL REVIEW" en el header (si existe; si no, omitir)
- `docs/propuestas/SE-079-pr-plan-scope-trace-gate.md` → "Pattern ref: Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR" en sección "Referencias"

### 3. SE-079 acoplamiento

La implementación de SE-079 (G13 scope-trace gate) emite el mensaje `B8 attention-anchor present` en el output del gate cuando pasa, en lugar de un check anónimo. Cambio de UNA cadena de texto, sin lógica nueva.

## Acceptance criteria

- [ ] AC-01 `docs/rules/domain/attention-anchor.md` existe, ≤150 líneas, describe los 4 patrones con su mapeo a pm-workspace
- [ ] AC-02 Cross-reference añadida en `radical-honesty.md` (1 línea, no rompe Rule #24 source-of-truth)
- [ ] AC-03 Cross-reference añadida en `autonomous-safety.md` (1 línea en header)
- [ ] AC-04 Cross-reference añadida en SE-079 spec (sección Referencias)
- [ ] AC-05 SE-079 implementación (cuando se haga) emite `B8 attention-anchor present` en G13 output
- [ ] AC-06 Test BATS estático: el doc canónico cita Genesis explícitamente con URL fuente
- [ ] AC-07 CHANGELOG entry

## No hace

- NO porta el resto del catálogo Genesis (R-tier, A1-A6, B1-B7, B10) — fuera de scope
- NO crea un agente "genesis-architect" — duplicaría `spec-driven-development` skill
- NO adopta `apm`/`npx skills add` distribution — incompatible con autonomous-safety
- NO renombra archivos existentes — sólo añade cross-references
- NO bloquea SE-079: SE-079 puede mergear sin SE-080 (los nombres "B8/B9" son aditivos)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Drift entre vocabulario Genesis upstream y nuestra interpretación | Media | Bajo | Doc cita commit hash de Genesis al referenciar |
| Cross-references quedan rotas si Genesis renombra | Baja | Bajo | Sólo 4 referencias, fácil de actualizar |
| Tentación de portar más patrones sin spec | Alta | Medio | "No hace" lo prohíbe explícitamente; nuevo spec por adopción |

## Dependencias y pre-requisitos

- ✅ Genesis review completado (sub-agent 2026-04-26)
- ✅ SE-079 APPROVED (acoplamiento ligero, no bloqueante)
- ✅ Court doc existe (SPEC-124 implementado)
- ✅ radical-honesty.md y autonomous-safety.md son canonical sources estables

## Slicing approval gate

Slice único S 2h NO arranca hasta que:
1. La usuaria apruebe el spec (este doc en APPROVED ya cumple)
2. SE-079 esté APPROVED o IMPLEMENTED (para poder cerrar AC-04 y AC-05 con coherencia)

## Comparativa vs status quo

| Métrica | Hoy | Con SE-080 |
|---|---|---|
| Patrones nombrados cross-repo | 0 | 4 (B8, B9, A7, A9) |
| Friction interop OpenCode/Codex | Alta (primitives anónimos) | Baja (vocabulario compartido) |
| Esfuerzo mantener vocab | n/a | ~10min/sprint (cross-ref drift) |
| LOC añadidas | 0 | ~120 (1 doc + 4 cross-refs + CHANGELOG) |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Doc canónico | `docs/rules/domain/attention-anchor.md` | mismo path (lazy-loaded en CLAUDE.md) |
| Cross-references | 4 archivos `docs/rules/domain/*.md` | mismos archivos (compartidos) |
| Output del gate G13 (SE-079) | bash echo en `pr-plan-gates.sh` | idéntico |

### Verification protocol

- [ ] Smoke test: leer `attention-anchor.md` desde sesión OpenCode v1.14 — debe cargar igual que Claude Code
- [ ] Test BATS estático verifica que las 4 cross-references existen y citan el patrón correcto
- [ ] Output del G13 contiene la cadena "B8 attention-anchor present" cuando aplica

### Portability classification

- [x] **PURE_DOCS**: ningún archivo es ejecutable. Adopción es 100% vocabulary, 0 código nuevo. Cross-frontend trivial.

## Referencias

- danielmeppiel/genesis — repo upstream (review sub-agent 2026-04-26)
- `skills/genesis/assets/design-patterns.md` — definición original B8/B9
- `skills/genesis/assets/architectural-patterns.md` — definición original A7/A9
- SE-079 spec — `docs/propuestas/SE-079-pr-plan-scope-trace-gate.md` (acoplamiento ligero)
- `docs/rules/domain/radical-honesty.md` — Rule #24 (B9 GOAL STEWARD existente)
- `docs/rules/domain/autonomous-safety.md` — gates (A9 SUPERVISED EXECUTION existente)
- `docs/rules/domain/code-review-court.md` — Court (A7 ADVERSARIAL REVIEW existente; SPEC-124)
- SE-074 — orquestador worker spawn (B8 ATTENTION ANCHOR existente)
