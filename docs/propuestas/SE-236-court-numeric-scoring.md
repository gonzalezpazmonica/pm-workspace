---
spec_id: SE-236
title: "Scoring Numérico en Code Review Court"
status: PROPOSED
created: 2026-06-28
author: savia
context_tier: L2
token_budget: 580
inspired_by: "Proto (Arc Institute, 2026) — constraint scores f(x) ∈ [0.0, 1.0], energía agregada"
---

# SE-236: Scoring Numérico en Code Review Court

## Motivación

Proto usa un modelo de energía donde cada constraint devuelve `f(x) ∈ [0.0, 1.0]` (0.0 = perfecto, 1.0 = violación máxima). La energía total es la suma ponderada. Esto permite:

- **Ordenar propuestas** por calidad total (energía baja = mejor)
- **Identificar el cuello de botella**: qué constraint tiene mayor contribución a la energía
- **Parar anticipadamente** cuando la energía supera un umbral antes de agotar el budget

El Code Review Court actual produce texto libre (PASS/FAIL/CONDITIONAL + comentarios). El court-orchestrator agrega cualitativamente. No hay manera programática de comparar dos PRs o detectar cuál juez es el bottleneck.

## Schema de Scoring

### Por juez

Cada juez añade a su output un objeto `scoring`:

```yaml
scoring:
  score: 0.0        # float ∈ [0.0, 1.0]. 0.0 = perfecto, 1.0 = fallo total
  weight: 1.0       # peso del juez en la energía total (configurable por juez)
  blocking: false   # si score > 0.5, bloquea independientemente de la energía total
  rationale: ""     # texto corto explicando el score
```

### Pesos por defecto de cada juez

| Juez | Weight | Blocking threshold |
|------|--------|-------------------|
| security-judge | 2.0 | score > 0.3 |
| correctness-judge | 1.5 | score > 0.5 |
| spec-judge | 1.5 | score > 0.5 |
| architecture-judge | 1.0 | score > 0.5 |
| cognitive-judge | 0.5 | score > 0.8 |

### Energía total

```
total_energy = Σ (score_i × weight_i) / Σ weight_i
```

La energía normalizada está en [0.0, 1.0].

### Veredicto

```
total_energy < COURT_ENERGY_THRESHOLD (default 0.2)  → PASS
total_energy ≥ 0.2 y < 0.5                          → CONDITIONAL
total_energy ≥ 0.5                                  → FAIL
any judge con blocking=true y score > threshold     → FAIL (independiente de energía)
```

### Output del court-orchestrator

```json
{
  "review_id": "CRC-20260628-001",
  "total_energy": 0.15,
  "bottleneck_judge": "security-judge",
  "convergence_score": 0.85,
  "verdict": "PASS",
  "judge_scores": {
    "security-judge": {"score": 0.1, "weight": 2.0, "blocking": false},
    "correctness-judge": {"score": 0.2, "weight": 1.5, "blocking": false}
  }
}
```

`convergence_score = 1.0 - total_energy` — cuánto de bueno es el PR (0.0 pésimo, 1.0 perfecto).

## Implementación

### Script de agregación

`scripts/court-score-aggregator.sh` — lee output JSONL de los jueces, calcula energía total, reporta veredicto.

### Regla de dominio

`docs/rules/domain/court-numeric-scoring.md` — define el sistema de scoring numérico, pesos, y configuración.

### Actualización de code-review-court.md

Sección adicional `## Scoring Numérico (SE-236)` en `docs/rules/domain/code-review-court.md`.

## Tests

Ver `tests/test-se236-court-scoring.bats` — 12 tests.

## Configuración

```bash
COURT_ENERGY_THRESHOLD=0.2        # umbral de pass (configurable)
COURT_JUDGE_WEIGHTS='{"security-judge":2.0,"correctness-judge":1.5}'
```

## Criterio de éxito

- El script `court-score-aggregator.sh` procesa JSONL de jueces y devuelve total_energy, bottleneck_judge, convergence_score y veredicto
- Con todos scores 0.0 → veredicto PASS
- Con un juez blocking y score alto → veredicto FAIL
- COURT_ENERGY_THRESHOLD es configurable via variable de entorno
- Los 12 tests BATS pasan en verde
