"""GPSurrogate — envoltura de GaussianProcessRegressor (SE-346).

Patrón SmartSim / modelo-del-mundo (rainvare): model sustituto que estima
media Y desvío estándar por punto. Determinista (random_state=0), local,
CRIT-001 (sin red, sin datos a proveedor cloud).

Contrato:
    fit(history: list[(features, outcome)])  -> self
    predict(points) -> (mean: np.ndarray, std: np.ndarray)
"""

import numpy as np
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import ConstantKernel, Matern, WhiteKernel


class GPSurrogate:
    def __init__(self, random_state: int = 0):
        self.random_state = int(random_state)
        kernel = ConstantKernel(1.0) * Matern(nu=2.5, length_scale=1.0) + WhiteKernel(1e-4)
        self.gp = GaussianProcessRegressor(
            kernel=kernel,
            normalize_y=True,
            n_restarts_optimizer=2,
            random_state=self.random_state,
            alpha=1e-6,
        )
        self._feat_min = None
        self._feat_max = None
        self._out_mean = 0.0
        self._out_std = 1.0
        self.fitted = False

    def fit(self, history):
        items = list(history)
        if not items:
            raise ValueError("historial vacío: no se puede ajustar el GP")
        X = np.atleast_2d(np.array([h[0] for h in items], dtype=float))
        y = np.array([h[1] for h in items], dtype=float)
        if X.ndim == 1:
            X = X.reshape(-1, 1)
        self._feat_min = X.min(axis=0)
        self._feat_max = X.max(axis=0)
        span = self._feat_max - self._feat_min
        span[span == 0] = 1.0
        Xn = (X - self._feat_min) / span
        self._out_mean = float(np.mean(y))
        self._out_std = float(np.std(y)) or 1.0
        yn = (y - self._out_mean) / self._out_std
        self.gp.fit(Xn, yn)
        self.fitted = True
        return self

    def predict(self, points):
        if not self.fitted:
            raise RuntimeError("GPSurrogate no ajustado: llama a fit() primero")
        P = np.atleast_2d(np.array(points, dtype=float))
        span = self._feat_max - self._feat_min
        span[span == 0] = 1.0
        Pn = (P - self._feat_min) / span
        m, s = self.gp.predict(Pn, return_std=True)
        return m * self._out_std + self._out_mean, s * self._out_std
