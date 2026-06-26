# SE-201 — Critic scoring cuantitativo en tribunales

Date: 2026-06-24
Spec: docs/propuestas/SE-201-critic-scoring.md
Status: APPROVED → IMPLEMENTED

## Ficheros

- `scripts/tribunal-critic.sh` — score 0-100 (correctness+completeness+security+spec_compliance), feedback, --rubric
- `docs/rules/domain/tribunal-critic-rubric.md` — rúbrica documentada con criterios por dimensión
- `.opencode/agents/court-orchestrator.md` — mención de tribunal-critic en flujo de ejecución
- `tests/scripts/test_se201_tribunal_critic.py` — 7 tests

## ACs cubiertos

- AC1: JSON con campos score (0-100), breakdown (4 dims), feedback
- AC2: exit 0 si score >= threshold; exit 1 si score < threshold
- AC3: tribunal-critic.sh mencionado en court-orchestrator.md
- AC4: --rubric <file.json> flag aceptado con pesos custom
- AC5: scores registrados en output/tribunal-scores.jsonl con timestamp, score, breakdown, feedback
- AC6: feedback generado con descripción de dimensiones que no alcanzan el máximo

## Cambios vs implementación previa

- Añadido campo `feedback` al JSON de salida y al log JSONL
- Ruta de logs cambiada de `.savia/tribunal-scores.jsonl` a `output/tribunal-scores.jsonl` (AC5 del spec)
- Nueva doc: `docs/rules/domain/tribunal-critic-rubric.md`
