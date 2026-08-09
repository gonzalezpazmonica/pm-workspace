---
id: SE-316
title: "SE-316 — Eval-lint de golden sets: cierre de SE-274 (S2/S4)"
status: IMPLEMENTED
priority: alta
---

# SE-316 — Eval-lint de golden sets: cierre de SE-274 (S2/S4)

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Agent governance / Eval infrastructure / CI
**Branch sugerida:** `agent/se316-eval-lint`
**Estimacion total:** ~24h (3 slices)
**Inspiracion:** `ericrisco/rsc-harness` → scripts/eval-lint.sh, schema/frontmatter.schema.json

---

## Contexto y evidencia (2026-08-09)

SE-274 (agent quality framework, PROPOSED) define en S2 golden sets para los
tres tribunales y en S4 un lint de cobertura en CI, pero quedó pendiente de
cierre. La pieza que falta es la **validación determinista de los casos**:

- rsc-harness exige por skill: ≥5 `should_trigger` (incl. no obvios), ≥4
  `should_not_trigger` **cada uno con `route_to` resoluble** (id real del
  catálogo, `none`, o `external:<name>`), y ≥1 `capability` con `must_include`.
  Se valida con `eval-lint.sh` que devuelve PASS/FAIL.

Savia tiene `tests/evals/` con casos de tribunales (code-review-court,
truth-tribunal, recommendation-tribunal), pero **no hay un linter que valide
que cada caso tiene los campos obligatorios y que los `route_to` referencian
skills reales**. Un caso con typo en un id de skill pasa desapercibido.

**El hueco.** Los golden sets existen; su *calidad estructural* no se valida en
CI. Un `should_not_trigger` cuyo `route_to` apunta a un skill inexistente
enmascara un caso que debería enrutar a otro agente.

---

## Objetivo

Implementar `scripts/eval-lint.sh` (patrón rsc-harness adaptado) que valide los
golden sets de los tribunales: campos mínimos por caso, `route_to` resoluble
contra `RESOLVER.md`/catálogo real, y cobertura mínima por modo. Integrarlo en
CI como gate G16 (blocking para cambios en `tests/evals/`).

---

## Out of scope

- NO crear casos nuevos (eso es trabajo de contenido, no de infra).
- NO ejecutar los evals (solo validar estructura y referencias).
- NO reemplazar el rubric de SE-274 S1 (ya definido).

---

## Diseno

### S1 — `scripts/eval-lint.sh`

Modo `--check <evals-dir>`: para cada `.jsonl` de `tests/evals/`:
- valida JSONL parseable,
- por caso: presencia de `should_trigger`/`should_not_trigger` con los
  contadores mínimos según el tipo de tribunal,
- cada `should_not_trigger` tiene `route_to` no vacío,
- `route_to` (salvo `none`/`external:`) resuelve contra
  `docs/RESOLVER.md` + catálogo de skills (`SKILLS.md`).

Exit 0 = PASS, 1 = FAIL (con listado de violaciones), 2 = usage.

### S2 — Schema JSON para casos

`config/eval-case.schema.json`: define `id`, `input`, `expected`,
`should_trigger[]`, `should_not_trigger[] {case, route_to}`,
`capabilities[] {name, must_include}`. El linter valida contra este schema
(librería `jsonschema` si está disponible, si no validación manual).

### S3 — Integración CI + gate G16

- `scripts/pr-plan-gates.sh` añade G16: si el PR toca `tests/evals/` o
  `config/eval-case.schema.json`, corre `eval-lint.sh --check` y exige PASS.
- Job `Eval Lint` en CI (blocking, a diferencia de Scope Creep — los evals
  rotos degradan la confianza de los tribunales).

---

## Criterios de aceptacion

### AC-S1: Linter operativo

- [x] AC-S1.1: `eval-lint.sh --check tests/evals/` pasa con los golden sets
  actuales (0 violaciones) o lista las violaciones reales pendientes de fix.
- [x] AC-S1.2: un caso con `route_to: skill-inexistente` produce FAIL.
- [x] AC-S1.3: un caso sin `should_not_trigger` en tribunal que lo requiere
  produce FAIL (según regla por tipo).

### AC-S2: Schema

- [x] AC-S2.1: `config/eval-case.schema.json` valida un caso bien formado.
- [x] AC-S2.2: el linter reporta el caso y campo concreto de cada violación.

### AC-S3: Integración

- [x] AC-S3.1: G16 añadido a `pr-plan-gates.sh` y documentado en el catálogo.
- [x] AC-S3.2: CI job `Eval Lint` corre en PRs y bloquea si FAIL.
- [x] AC-S3.3: los golden sets actuales quedan limpios (o con violaciones
  documentadas y ticket asociado).

---

## Ref

- `ericrisco/rsc-harness` → `scripts/eval-lint.sh`, `schema/frontmatter.schema.json`
- `docs/propuestas/SE-274-agent-quality-framework.md` (S2/S4)
- `docs/RESOLVER.md`, `SKILLS.md`

---

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Linter | `scripts/eval-lint.sh` (bash, standalone) | Mismo script — sin plugin TS |
| Gate G16 | `scripts/pr-plan-gates.sh` + `scripts/pr-plan.sh` | Mismo (bash sourced) |
| CI job Eval Lint | `.github/workflows/ci.yml` | Mismo workflow |

### Verification protocol

- [x] Funciona en runtime OpenCode (no solo Claude Code): linter puro bash, sin bindings de frontend
- [x] Tests cubren ambos paths: `tests/test-eval-lint.bats` (20 casos)
- [x] No añade hooks — solo script + gate bash + job CI

### Portability classification

- [x] **PURE_BASH**: lógica en bash sin bindings de frontend, runs idéntico en cualquier motor
