---
spec_id: SE-201
title: Critic scoring cuantitativo en tribunales
status: IMPLEMENTED
tier: 1
priority: P1
effort: M
era: 200
wave: 1
deps:
  - SE-200
unblocks:
  - SE-202
origin: output/research/openhands-savia-20260607.md
inspiration: OpenHands critic-scorer pattern — LLM rubric-based quantitative verdict scoring
---

# SE-201 — Critic scoring cuantitativo en tribunales

> Estado: IMPLEMENTED · Tier 1 · P1 · Estimación M · Era 200 · Wave 1

## Resumen

Script `tribunal-critic.sh` que calcula un score 0-100 para cualquier veredicto `.review.crc` del Code Review Court o Truth Tribunal, usando una rúbrica explícita con 4 dimensiones de 25 puntos cada una. Si el score cae bajo el umbral configurable, el court-orchestrator reconvoca el tribunal con el feedback de la crítica. Máximo `SAVIA_CRITIC_MAX_ITERATIONS=3` ciclos antes de escalar a humano.

## Motivación

- Los tribunales actuales producen veredictos cualitativos sin puntuación objetiva — imposible comparar calidad entre ejecuciones o detectar regresión.
- OpenHands usa un critic scorer para cerrar el loop de mejora: si el output no supera el umbral, se itera.
- Una rúbrica de 4 dimensiones (correctness, completeness, security, spec-compliance) cubre los ejes críticos del Code Review Court.
- El registro histórico permite análisis de tendencia de calidad a lo largo del tiempo.

## Scope

1. `scripts/tribunal-critic.sh` — recibe un fichero `.review.crc`, llama al LLM con la rúbrica explícita y devuelve JSON `{"score": N, "breakdown": {"correctness": N, "completeness": N, "security": N, "spec_compliance": N}, "feedback": "..."}`.
2. Rúbrica: correctness(25) + completeness(25) + security(25) + spec_compliance(25) = 100 puntos total. Criterios documentados en `docs/rules/domain/tribunal-critic-rubric.md`.
3. Integración con `court-orchestrator`: si score < `SAVIA_CRITIC_THRESHOLD` → re-convocar tribunal con `feedback` como contexto adicional.
4. Config: `SAVIA_CRITIC_THRESHOLD=80`, `SAVIA_CRITIC_MAX_ITERATIONS=3` — sobreescribibles via env.
5. Scores registrados en `output/tribunal-scores.jsonl` con campos: `timestamp`, `spec_id`, `score`, `breakdown`, `iteration`, `feedback`.

## Acceptance Criteria

- AC1: `tribunal-critic.sh <veredicto.crc>` produce JSON válido con campos `score` (0-100), `breakdown` (4 dimensiones), `feedback` (string).
- AC2: Si score < `SAVIA_CRITIC_THRESHOLD` → exit 1 con feedback en stderr; si score >= threshold → exit 0.
- AC3: Mención explícita de `tribunal-critic` en el fichero `.opencode/agents/court-orchestrator.md` dentro del flujo de ejecución.
- AC4: Tras `SAVIA_CRITIC_MAX_ITERATIONS` ciclos con score bajo threshold, el script emite señal de escalación a humano (stderr + exit 3) y detiene la iteración.
- AC5: Cada ejecución registra score en `output/tribunal-scores.jsonl` con todos los campos requeridos.
- AC6: `--rubric <fichero.yaml>` flag acepta rúbrica custom en YAML; si no se pasa, usa la rúbrica por defecto.

## Slices

1. **Slice 1 (2h)** — `tribunal-critic.sh` con llamada LLM + output JSON + exit codes + BATS de validación de estructura JSON.
2. **Slice 2 (2h)** — Integración con `court-orchestrator.md`: ciclo de re-convocación con feedback + límite de iteraciones + escalación.
3. **Slice 3 (1h)** — Registro en `output/tribunal-scores.jsonl` + `--rubric` flag con YAML custom + doc de rúbrica.
4. **Slice 4 (1h)** — BATS E2E con veredicto sintético: score bajo → iteración → escalación a humano.

## Out of scope

- Scoring de jueces individuales del Truth Tribunal (se aplica solo al veredicto final agregado).
- Dashboard de evolución de scores.
- Rúbricas por tipo de proyecto (una sola rúbrica global por ahora).
- Integración automática con Azure DevOps work items.

## Riesgo principal

El LLM puede dar scores inconsistentes para el mismo veredicto en ejecuciones distintas (varianza del modelo). Mitigación: usar `temperature=0` en la llamada de crítica y documentar la rúbrica con ejemplos de scoring para reducir ambigüedad.
