---
context_tier: L2
token_budget: 400
spec_ref: SE-236
---

# Court Numeric Scoring — Code Review Court (SE-236)

> Scoring numérico inspirado en Proto (Arc Institute, 2026): constraints f(x) ∈ [0.0, 1.0].
> Permite comparar PRs por calidad, detectar bottleneck judge, y parar anticipadamente.

## Schema por juez

```yaml
scoring:
  score: 0.0        # float ∈ [0.0, 1.0]. 0.0 = perfecto, 1.0 = fallo total
  weight: 1.0       # peso en la energía total
  blocking: false   # si score > blocking_threshold, bloquea independientemente
  blocking_threshold: 0.5
  rationale: ""     # texto corto
```

## Pesos y thresholds por defecto

| Juez | Weight | Blocking | Blocking threshold |
|------|--------|----------|--------------------|
| security-judge | 2.0 | true | 0.3 |
| correctness-judge | 1.5 | true | 0.5 |
| spec-judge | 1.5 | true | 0.5 |
| architecture-judge | 1.0 | false | 0.5 |
| cognitive-judge | 0.5 | false | 0.8 |

## Energía total

```
total_energy = Σ (score_i × weight_i) / Σ weight_i
convergence_score = 1.0 - total_energy
```

## Veredictos

| Condición | Veredicto |
|-----------|-----------|
| any blocking judge con score > threshold | FAIL |
| total_energy ≥ COURT_CONDITIONAL_THRESHOLD (0.5) | FAIL |
| total_energy ≥ COURT_ENERGY_THRESHOLD (0.2) | CONDITIONAL |
| total_energy < COURT_ENERGY_THRESHOLD (0.2) | PASS |
| sin jueces | PASS (por defecto) |

## Configuración

```bash
COURT_ENERGY_THRESHOLD=0.2       # umbral de pass (configurable)
COURT_CONDITIONAL_THRESHOLD=0.5  # umbral de fail directo
COURT_OUTPUT_FORMAT=json          # "json" o "text"
```

## Output del court-orchestrator

```json
{
  "review_id": "CRC-20260628-001",
  "total_energy": 0.15,
  "bottleneck_judge": "security-judge",
  "convergence_score": 0.85,
  "verdict": "PASS",
  "judge_scores": {
    "security-judge": {"score": 0.1, "weight": 2.0, "blocking": false}
  }
}
```

## Script de agregación

`scripts/court-score-aggregator.sh` — lee JSONL de jueces, calcula energía, reporta veredicto.

Exit codes: 0=PASS, 1=FAIL, 2=CONDITIONAL, 3=error.

## Integración con code-review-court.md

Ver sección `## Scoring Numérico (SE-236)` en `docs/rules/domain/code-review-court.md`.
