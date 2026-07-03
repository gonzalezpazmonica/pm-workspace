---
id: SE-249
title: "RotatE Link Prediction — dependencias implícitas entre agentes y skills"
status: IMPLEMENTED
priority: P2
effort: S (5h — S1 2h training loop + S2 2h integración + S3 1h tests)
origin: Investigación output/research/20260628-kg-optimization-state-of-art-2024-2025.md §1
author: Savia
related:
  - SE-248 (kg-topology-analysis, misma pipeline de export)
  - scripts/knowledge-graph.sh
  - drift-auditor agent
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
era: 249
roi: Medio — detecta coupling implícito no documentado; requiere ~500 triples para que sea útil
---

# SE-249 — RotatE Link Prediction para dependencias implícitas

## Objective

Implementar `scripts/kg-link-prediction.py` que entrena un modelo RotatE mínimo sobre el KG
de pm-workspace y predice triples faltantes: dependencias entre agentes, skills sin spec asociada,
o agentes que deberían usar skills que no usan.

El problema que resuelve: la documentación de relaciones entre agentes y skills es manual y
deriva con el tiempo. Un agente que debería usar `codebase-memory` pero no tiene esa relación
documentada es un gap real de arquitectura. RotatE (embedding relacional en espacio complejo)
puede detectar estos gaps con evidencia empírica, no con inspección manual.

Condición de utilidad real: el KG necesita ≥ 200 triples conocidos para que el modelo entrene
con señal. Con el KG actual de pm-workspace (~500 edges), debería funcionar. Si el KG tiene
< 100 triples, el script lo detecta y avisa sin entrenar.

## Principles affected

- #5 Humans decide — las predicciones son sugerencias. El drift-auditor puede incorporarlas
  como "gaps a verificar", no como cambios automáticos.
- #2 Vendor independence — numpy puro, sin PyKEEN ni PyTorch.
- #1 Data sovereignty — el modelo entrenado (matrices numpy) es local, no se exporta.

## Design

### Overview

```
kg-export.json (de SE-248)
        ↓
scripts/kg-link-prediction.py --train --epochs 200
        ↓
output/research/kg-rotate-model-YYYYMMDD.npz  (pesos: entity+relation embeddings)
output/research/kg-missing-links-YYYYMMDD.md  (top-20 triples predichos faltantes)
```

### RotatE mínimo (numpy)

Entidades: vectores en ℂᵈ (d=50 por defecto). Relaciones: rotaciones |r|=1.
Score: `-|| h ∘ r - t ||` (distancia en espacio complejo).

Loss: BCE con negative sampling (10 negativas por positiva).
Optimizer: Adam con lr=0.01.
Epochs: 200 (convergencia típica en ~100 para grafos pequeños).

Validación: MRR y Hits@10 en split 80/10/10. Si MRR < 0.15 → aviso "modelo no convergió,
KG demasiado pequeño o demasiado denso". No bloquea — muestra igual las predicciones
con calidad estimada.

### Interpretación de predicciones

Un triple predicho `(agent-X, USES_SKILL, skill-Y)` con score alto indica que, dado el
patrón de relaciones en el grafo, se esperaría que agent-X tuviese esa relación documentada.
Esto puede ser:
1. Un gap real (agent-X debería tener esa relación → añadir al agente).
2. Una relación existente no documentada en el KG → documentar.
3. Un falso positivo → descartar con nota.

El humano clasifica. El script sólo puntúa.

### Components

| Name | Kind | Purpose |
|---|---|---|
| `scripts/kg-link-prediction.py` | script Python | RotatE train + predict (numpy puro) |
| `scripts/kg-link-prediction.sh` | wrapper bash | Gate de dependencias + invocación |
| `tests/test-se249-link-prediction.bats` | test suite | Smoke tests + validación de output format |

### Contracts

Input: mismo JSON de SE-248 (`nodes` + `edges`).

Output JSON:
```json
{
  "model": {"mrr": 0.34, "hits_at_10": 0.61, "epochs": 200, "embedding_dim": 50},
  "missing_links": [
    {"head": "architect", "relation": "USES_SKILL", "tail": "codebase-memory",
     "score": 0.82, "confidence": "high"},
    ...
  ]
}
```

## Acceptance criteria

1. `scripts/kg-link-prediction.sh --help` sale con código 0.
2. Con el KG real (≥100 triples), el script entrena y produce `kg-missing-links-*.md` en < 60 segundos.
3. El JSON tiene `model.mrr` (float), `missing_links` (lista no vacía).
4. Con KG de < 50 triples, el script sale con código 3 y mensaje "insufficient data".
5. El modelo entrenado en el mismo KG dos veces produce el mismo top-5 de predicciones (determinismo con seed fijo).
6. BATS suite: ≥ 6 tests, calidad ≥ 80.
7. Sin dependencias fuera de `python3 + numpy`.

## Out of scope

- Entrenamiento con PyKEEN o PyTorch (overhead de setup injustificado para este tamaño de KG).
- Actualización automática del KG con los triples predichos (requiere aprobación humana explícita).
- Soporte para relaciones negativas o triples con pesos variables.

## Dependencies

- Blocked by: SE-248 (necesita el mismo formato de export JSON).
- Blocks: ninguno actualmente.

## Migration path

Script nuevo. Sin modificaciones a código existente.

## Impact statement

El primer sistema de detección automática de gaps de documentación en el grafo de agentes
de pm-workspace. Si detecta que `security-guardian` no tiene documentada la relación
`REVIEWS → typescript-developer` pero sí la tiene para `dotnet-developer`, ese gap es
un bug de documentación real. MRR > 0.3 en el KG real indicaría que el modelo tiene señal
suficiente para ser útil. Esfuerzo: 5h. Script base ya existe en `output/research/`.
