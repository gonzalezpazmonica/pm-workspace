"""Muestreo (SE-346): Latin Hypercube + candidatos uniformes. Determinista."""

import numpy as np
from scipy.stats.qmc import LatinHypercube


def lhs(n: int, dim: int, seed: int = 0) -> np.ndarray:
    """Latin Hypercube en [0,1]^dim, determinista (seed)."""
    sampler = LatinHypercube(d=dim, seed=int(seed))
    return sampler.random(n=int(n))


def uniform_candidates(n: int, dim: int, seed: int = 0) -> np.ndarray:
    """Candidatos uniformes en [0,1]^dim, determinista (seed)."""
    rng = np.random.default_rng(int(seed))
    return rng.random((int(n), int(dim)))
