---
spec_id: SPEC-169
title: Project Twin como artefacto versionado
status: PROPOSED
tier: 1B
effort: 10-12h
era: 198
origin: output/research/digital-twins-project-focused-20260601.md
blocking_deps:
  - SPEC-156 (token_budget frontmatter)
  - skill zero-project-leakage
related_specs:
  - SPEC-165 (World Model, compatible no bloqueante)
---

# SPEC-169 — Project Twin como artefacto versionado

> Estado: PROPOSED · Tier 1B · Estimación 10-12 h · Era 198
> Fuente conceptual: `output/research/digital-twins-project-focused-20260601.md`
> Dependencias bloqueantes: SPEC-156 (`token_budget` frontmatter), skill `zero-project-leakage`
> Compatible no bloqueante: SPEC-165 (World Model)

## Resumen

Modelar el estado evolutivo de un proyecto software como artefacto markdown versionado (`projects/{slug}/twin.md`) con frontmatter declarativo, refresh event-driven y predicciones acotadas. Sujeto único: el proyecto. Personas excluidas por diseño y por linter.

## Motivación

- Reframe sobre el informe deprecated `digital-twins-agents-context-domes-20260531.md`, que dispersaba el concepto en 6 tipos.
- Valor real PM: predecir slip, bloqueantes y drift de scope de un proyecto.
- Hueco actual: `CLAUDE.md` por proyecto documenta convenciones estáticas pero no tiene refresh policy ni predicciones.

## Scope (mínimo viable)

1. Schema `projects/{slug}/twin.md` (frontmatter + 4 secciones: Estado, Reglas, Predicciones, Grafo opcional).
2. Comandos `/twin-load`, `/twin-refresh`, `/twin-summary`, `/twin-anonymize`.
3. Hook `PostToolUse` que dispara refresh en eventos: cierre de sprint, cambio de estado de work item, merge de PR.
4. Refresher determinista (sin LLM en v1): lee `evidence_refs`, calcula 4 predicciones (slip sprint actual, próximo bloqueante, drift de scope, salud agregada verde/amarillo/rojo).
5. Decay diario: marca `STALE` si supera `stale_after_days`.
6. Vista N1 vía `/twin-anonymize`: aplica `zero-project-leakage` y genera `docs/case-studies/{slug-anon}.twin.md`.
7. Linter pre-commit: bloquea campos prohibidos en el cuerpo (`assigned_to`, `evaluation`, `competencia`, `1on1`).
8. Tests BATS sobre fixture y sobre proyecto piloto real del workspace.

## Acceptance criteria

- **AC-1**: `projects/{piloto}/twin.md` valida contra schema (frontmatter completo, 3 secciones obligatorias).
- **AC-2**: `/twin-load {slug}` ≤ 2000 tokens (cap enforced por SPEC-156).
- **AC-3**: Las 4 predicciones presentes con `confidence ∈ [0,1]` y `evidence_ref` no-nulo.
- **AC-4**: Hook `PostToolUse` actualiza `last_refresh` tras un cambio simulado de estado de work item (test BATS contra fixture).
- **AC-5**: Resolver rehúsa `/twin-load` de N4 si el contexto activo es N1 (test BATS).
- **AC-6**: `/twin-anonymize` produce vista sin nombre de organización, sin handles, solo métricas relativas.
- **AC-7**: Linter pre-commit detecta y bloquea cualquier campo prohibido (test BATS con fixture).
- **AC-8**: Telemetría append-only en `output/twin-runs/loads.jsonl` y `output/twin-runs/refresh-{slug}.jsonl`.
- **AC-9**: Doc canónica `docs/rules/domain/project-twin-as-code.md` ≤ 150 líneas (Rule #11).
- **AC-10**: Score ≥ 85 en `verification-lattice`.
- **AC-V1** (validación sobre proyecto real): un proyecto piloto del workspace tiene su `twin.md` con `last_refresh` posterior a la merge de este SPEC y refleja el sprint actual declarado en su `CLAUDE.md`.
- **AC-V2**: Refresh sobre el piloto se ejecuta en < 5 s y produce diff auditable en stdout.

## Estimación por slice

| # | Slice | Horas |
|---|-------|-------|
| 1 | Schema + linter de campos prohibidos + doc regla | 2 |
| 2 | Twin piloto sobre proyecto real del workspace | 1 |
| 3 | Loader (`/twin-load`, `/twin-summary`, resolver de capa N4↔N1) | 2 |
| 4 | Refresher (recolección evidencia, cálculo predicciones, escritura, diff) | 3 |
| 5 | Hook `PostToolUse` + cron diario de decay | 1.5 |
| 6 | `/twin-anonymize` + tests BATS + verification-lattice | 1.5 |

Total: 11 h (margen dentro de la horquilla 10-12 h del informe fuente).

## Dependencias

- **SPEC-156** (`token_budget` frontmatter) — bloqueante para AC-2.
- **Skill `zero-project-leakage`** — bloqueante para AC-6.
- **Skill `knowledge-graph`** — suave; piloto puede arrancar sin sección `## Grafo`.
- **SPEC-165** (World Model) — compatible, no bloqueante. Si llega después, el twin pasa a ser estado mutable por el world-model.

## Out of scope (permanente en este branch)

- Twins de personas (team-member, stakeholder, client, sponsor).
- Twins conversacionales que imiten a un humano.
- Modelado o evaluación de competencias individuales.
- Refresh con LLM (diferido a v2 sobre SPEC-165).
- Monte Carlo de fechas de entrega de PBI concretos (futuro SPEC-171).
- Portfolio twin N2 agregado (futuro SPEC-170).

## Riesgos

| Riesgo | Severidad | Mitigación |
|---|---|---|
| Drift twin ↔ realidad | Alta | `decay.half_life_days: 14` + bloqueo `STALE` + refresh event-driven |
| Alucinación de estado | Alta | Cada bullet con `evidence_ref`; `source-traceability-judge` pre-escritura |
| Sobre-confianza en predicciones | Alta | `calibration-judge` enforced; `confidence < 0.7` bloquea reporting ejecutivo |
| Captura accidental de personas en el twin | Alta si no se enforza | Linter pre-commit bloqueante (AC-7) |
| Coste de refresh | Media | Telemetría `refresh-costs.jsonl` + budget mensual por twin |

## Verificación

- `bats tests/twin/*.bats` (8 suites: schema, linter, loader, resolver, refresher, decay, anonymize, telemetry).
- `bash scripts/verification-lattice.sh docs/propuestas/SPEC-169-project-twin.md`.
- Validación manual: `/twin-load {piloto}` en sesión limpia, observar tokens reportados ≤ 2000.

## Referencias

- Informe fuente: `output/research/digital-twins-project-focused-20260601.md` (350 líneas, contiene §1 estado del arte, §3 predicciones, §5 cúpulas, §7 arquitectura concreta).
- `docs/propuestas/SPEC-156-token-budget-frontmatter.md`
- `docs/propuestas/SPEC-165-world-model-simulation.md`
- `docs/rules/domain/context-placement-confirmation.md`
- `docs/rules/domain/zero-project-leakage.md`
- `.opencode/skills/knowledge-graph/SKILL.md`
