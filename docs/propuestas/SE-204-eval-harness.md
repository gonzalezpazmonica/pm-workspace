---
spec_id: SE-204
title: Evaluation harness minimo para agentes
status: IMPLEMENTED
drift_note: "drift: components existed pre-triage (tests/evals/ with 3+ agents + scripts/run-agent-evals.sh + .opencode/skills/evaluations-framework/ all implemented)"
implemented_at: "2026-06-24"
tier: 1
priority: P2
effort: M
era: 200
wave: 1
deps:
  - SE-203
unblocks: []
origin: output/research/openhands-savia-20260607.md
inspiration: OpenHands eval harness — LLM-as-judge with rubric-graded agent evals
---

# SE-204 — Evaluation harness mínimo para agentes

> Estado: APPROVED · Tier 1 · P2 · Estimación M · Era 200 · Wave 1

## Resumen

Directorio `tests/evals/` con eval cases para 3 agentes críticos (sdd-spec-writer, court-orchestrator, business-analyst), un runner `run-agent-evals.sh` que puntúa con LLM-as-judge, y un threshold de aceptación del 80%. Permite detectar regresión en calidad de agentes antes de que los usuarios la noten.

## Motivación

- Los agentes de pm-workspace no tienen tests de calidad — solo se detectan problemas por feedback humano post-hecho.
- OpenHands usa eval harnesses con LLM-as-judge para medir si los agentes cumplen sus objetivos declarados.
- El patrón EvalCase (input + criteria) es declarativo, versionable en git, y extensible a más agentes.
- Un threshold de 80% crea una señal binaria usable en CI/CD: pasa o falla.

## Scope

1. `tests/evals/` — directorio raíz de eval cases, con subdirectorios por agente.
2. Formato EvalCase: `input.md` (task description + context) + `criteria.md` (rúbrica LLM-as-judge con dimensiones y pesos).
3. `tests/evals/sdd-spec-writer/` — ≥3 eval cases con inputs de specs reales y criteria de calidad SDD.
4. `tests/evals/court-orchestrator/` — ≥3 eval cases con veredictos de tribunal y criteria de orquestación.
5. `tests/evals/business-analyst/` — ≥3 eval cases con PBIs y criteria de descomposición y ACs.
6. `scripts/run-agent-evals.sh` — ejecuta todos los eval cases, puntúa con LLM-as-judge, genera `output/eval-report-{fecha}.md`.
7. Threshold: 80% de casos deben superar su rúbrica para que el runner salga con exit 0.

## Acceptance Criteria

- AC1: `tests/evals/sdd-spec-writer/` contiene ≥3 eval cases (input.md + criteria.md cada uno).
- AC2: `tests/evals/court-orchestrator/` contiene ≥3 eval cases.
- AC3: `tests/evals/business-analyst/` contiene ≥3 eval cases.
- AC4: `run-agent-evals.sh` genera `output/eval-report-{fecha}.md` con score por agente y score agregado.
- AC5: `run-agent-evals.sh --agent sdd-spec-writer` ejecuta solo ese agente.
- AC6: Exit 0 si score agregado >= 80%, exit 1 si < 80%.
- AC7: Rúbrica LLM-as-judge evalúa 3 dimensiones: precisión (no inventa), completitud (cubre todos los ACs), ausencia de alucinaciones (referencias reales).

## Slices

1. **Slice 1 (2h)** — Estructura `tests/evals/` + 3 eval cases para `sdd-spec-writer` (input + criteria) + BATS que verifica que los ficheros existen.
2. **Slice 2 (2h)** — 3 eval cases para `court-orchestrator` + 3 para `business-analyst`.
3. **Slice 3 (2h)** — `run-agent-evals.sh` core: invocación por eval case + puntuación LLM-as-judge + acumulación de scores.
4. **Slice 4 (1h)** — Generación de `eval-report-{fecha}.md` + `--agent` flag + exit codes + threshold 80%.

## Out of scope

- Evals para todos los agentes del catálogo (solo 3 agentes críticos en esta spec).
- Evals de rendimiento / latencia (solo calidad de output).
- Integración con Azure Pipelines CI/CD (manual en esta spec, futuro SPEC).
- Generación automática de eval cases desde histórico de sesiones.

## Riesgo principal

El LLM-as-judge puede puntuar de forma inconsistente entre ejecuciones, haciendo el threshold 80% poco fiable. Mitigación: usar `temperature=0` en el juez, ejecutar cada caso 2 veces y promediar, y documentar la varianza esperada en el reporte.
