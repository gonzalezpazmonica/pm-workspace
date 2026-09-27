---
bump: patch
section: Fixed
---

- `court-score-aggregator.sh` (SE-236) fallaba en abierto: una salida de juez ilegible, sin `score`, con `score` fuera de [0,1] o `weight` negativo, o un fichero de entrada inexistente, acababa en `PASS`. Ahora sale con 3 (error), como ya fijaba `court-numeric-scoring.md`. Sin jueces sigue siendo `PASS`.
