---
version_bump: minor
section: Added
---

### Added (Labs L27 — E3/E5 gate de la ronda)

- **E3 hechos vs humo** (`scripts/l27-facts-ledger.py`): extrae los HECHOS
  verificados del corpus FxC (cúpula Fronesia, madurez verified/calibrated +
  resultado) y marca HUMO todo lo no verificado. Gate: sin hechos → FAIL.
  Resultado: 6 hechos / 0 humo (ratio 1.0).
- **E5 score sintético** (`scripts/l27-score-synthetic.py`): población
  sintética con habilidad de criterio latente; score 0-100 (ranking) + AUC
  (Mann-Whitney) + probabilidad calibrada (shrinkage bayesiano). Resultado
  seed 42: AUC 0.794, Brier calibrado 0.0008 << base 0.0194, **GATE PASS**.
  Hallazgo honesto: el score crudo no es probabilidad (requiere calibración).
- Research: `labs/research/l27-e3e5-gate-20260827.md` · hipótesis L27 →
  validated.
- Tests: `tests/test-l27-e3e5.bats` (5).
