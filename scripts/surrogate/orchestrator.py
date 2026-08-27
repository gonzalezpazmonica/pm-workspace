"""Orquestador de aprendizaje activo (SE-346).

Bucle: muestreo inicial LHS -> fit GP -> adquisición -> evaluación real ->
refit -> parada por umbral de incertidumbre. La evaluación `objective` es el
"simulador caro" (nunca se sustituye; solo se evita ejecutarlo cuando el
sustituto ya está seguro). Determinista y local (CRIT-001).
"""

import numpy as np

from gp_surrogate import GPSurrogate
from acquisition import get as get_acq
from sampling import lhs, uniform_candidates
from storage import History


class ActiveLearner:
    def __init__(
        self,
        objective,
        dim: int = 2,
        n_initial: int | None = None,
        max_iterations: int = 30,
        acquisition: str = "ucb",
        minimize: bool = True,
        n_candidates: int = 200,
        seed: int = 0,
        uncertainty_stop_threshold: float | None = None,
    ):
        self.objective = objective
        self.dim = int(dim)
        self.n_initial = int(n_initial) if n_initial is not None else max(4, 4 * self.dim)
        self.max_iterations = int(max_iterations)
        self.acq_name = acquisition
        self.acq = get_acq(acquisition)
        self.minimize = bool(minimize)
        self.n_candidates = int(n_candidates)
        self.seed = int(seed)
        self.uncertainty_stop_threshold = uncertainty_stop_threshold
        self.history = History()
        self.surrogate = None
        self.log = []

    def _eval(self, point):
        return float(self.objective(np.asarray(point, dtype=float)))

    def _best(self):
        vals = [h[1] for h in self.history]
        idx = int(np.argmin(vals)) if self.minimize else int(np.argmax(vals))
        return self.history.items[idx]

    def run(self):
        X0 = lhs(self.n_initial, self.dim, seed=self.seed)
        for p in X0:
            self.history.add(p, self._eval(p))
        self.surrogate = GPSurrogate(random_state=self.seed).fit(self.history)

        best_feats, best_val = self._best()
        iterations = 0
        while iterations < self.max_iterations:
            mean, std = self.surrogate.predict(
                uniform_candidates(self.n_candidates, self.dim, seed=self.seed + iterations)
            )
            if self.uncertainty_stop_threshold is not None and float(np.max(std)) < self.uncertainty_stop_threshold:
                self.log.append({"stop": "uncertainty_threshold", "max_std": float(np.max(std))})
                break
            # Trabajar en utilidad (negada si minimizamos): adquisiciones BO maximizan.
            utility = -mean if self.minimize else mean
            u_best = -best_val if self.minimize else best_val
            if self.acq_name in ("ei", "pi"):
                score = self.acq(utility, std, u_best)
            else:
                score = self.acq(utility, std)
            pick = int(np.argmax(score))
            cand = uniform_candidates(self.n_candidates, self.dim, seed=self.seed + iterations)[pick]
            val = self._eval(cand)
            self.history.add(cand, val)
            self.surrogate.fit(self.history)
            if (val < best_val) == self.minimize:
                best_feats, best_val = cand, val
            self.log.append({"iteration": iterations, "std": float(std[pick]), "best": best_val})
            iterations += 1

        self.summary_data = self.summary()
        return self.history, self.surrogate, self.summary_data

    def summary(self):
        """Métricas: n_real_calls, best, calibración (fracción en μ±2σ)."""
        if self.surrogate is None:
            return {"n_real_calls": 0, "best": None, "calibration": 0.0, "iterations": 0}
        pts = np.array([h[0] for h in self.history])
        y = np.array([h[1] for h in self.history])
        mu, sigma = self.surrogate.predict(pts)
        inside = np.mean(np.abs(y - mu) <= 2 * sigma)
        best = self._best()
        return {
            "n_real_calls": len(self.history),
            "best": {"point": best[0], "value": best[1]},
            "calibration": float(inside),
            "iterations": len(self.log),
        }
