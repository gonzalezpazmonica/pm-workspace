#!/usr/bin/env python3
"""Benchmark numérico SE-346 (REQ-05/REQ-06): Branin 2D.

Compara aprendizaje activo con GP vs muestreo aleatorio con el MISMO presupuesto
de evaluaciones reales. Criterios (AC-02/AC-03):
  - GP alcanza un best ≤ al de aleatorio con >=40% MENOS evaluaciones reales.
  - Calibración del GP: >=85% de predicciones dentro de μ±2σ (sobre el histórico).

Exit 0 = PASS · exit 1 = FAIL. Determinista (seed fija).
"""

import sys
import os
import json
import math
import warnings

import numpy as np

warnings.filterwarnings("ignore", category=UserWarning)  # sklearn ConvergenceWarning (noise)

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "surrogate"))

from orchestrator import ActiveLearner  # noqa: E402
from sampling import uniform_candidates  # noqa: E402


def branin(xy):
    """Branin en [0,1]^2 escalado a [−5,10]×[0,15]. Mínimo conocido ≈ 0.3979."""
    x, y = xy[0] * 15.0 - 5.0, xy[1] * 15.0
    a, b, c, r, s, t = 1.0, 5.1 / (4 * math.pi**2), 5.0 / math.pi, 6.0, 10.0, 1.0 / (8 * math.pi)
    return a * (y - b * x * x + c * x - r) ** 2 + s * (1 - t) * math.cos(x) + s


def random_baseline(budget, seed):
    best = float("inf")
    for p in uniform_candidates(budget, 2, seed=seed):
        best = min(best, branin(p))
    return best


def main():
    seed = 42
    learner = ActiveLearner(
        objective=branin,
        dim=2,
        n_initial=8,
        max_iterations=25,
        acquisition="ei",
        minimize=True,
        n_candidates=2000,
        seed=seed,
        uncertainty_stop_threshold=None,
    )
    history, gp, summary = learner.run()
    gp_best = summary["best"]["value"]
    gp_evals = summary["n_real_calls"]
    calibration = summary["calibration"]

    rand_budget = gp_evals
    rand_best = random_baseline(rand_budget, seed=seed)

    # ¿cuántas evaluaciones reales necesitaría aleatorio para igualar al GP?
    # (cap 200: si no lo alcanza en 200, se reporta 200 y la reducción es ≥)
    RAND_CAP = 200
    needed = 0
    cur = float("inf")
    for p in uniform_candidates(RAND_CAP, 2, seed=seed + 1):
        cur = min(cur, branin(p))
        needed += 1
        if cur <= gp_best:
            break
    reduction = 1.0 - gp_evals / float(needed) if needed else 1.0

    ok_req05 = (needed - gp_evals) >= 0.4 * needed  # >=40% menos evaluaciones
    ok_req06 = calibration >= 0.85

    out = {
        "gp_best": gp_best,
        "gp_evals": gp_evals,
        "rand_best_same_budget": rand_best,
        "rand_evals_to_match": needed,
        "reduction": round(reduction, 3),
        "calibration_mu2sigma": round(calibration, 3),
        "REQ05_ge40pct_fewer": ok_req05,
        "REQ06_ge85pct_calibrated": ok_req06,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    ok = ok_req05 and ok_req06
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
