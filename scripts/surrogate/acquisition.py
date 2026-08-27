"""Funciones de adquisición (SE-346) — firmas estándar BO, maximización.

UCB  -> mean + kappa*std            (exploración controlada)
EI   -> mejora esperada sobre `best` con margen xi
PI   -> probabilidad de mejora sobre `best`
variance -> std puro

Todas aceptan arrays y devuelven score por candidato.
"""

import numpy as np
from scipy import stats


def ucb(mean, std, kappa: float = 2.0):
    return np.asarray(mean, dtype=float) + kappa * np.asarray(std, dtype=float)


def ei(mean, std, best: float, xi: float = 0.01):
    mean = np.asarray(mean, dtype=float)
    std = np.maximum(np.asarray(std, dtype=float), 1e-9)
    z = (mean - best - xi) / std
    return (mean - best - xi) * stats.norm.cdf(z) + std * stats.norm.pdf(z)


def pi(mean, std, best: float, xi: float = 0.01):
    std = np.maximum(np.asarray(std, dtype=float), 1e-9)
    return stats.norm.cdf((np.asarray(mean, dtype=float) - best - xi) / std)


def variance(mean, std):
    return np.asarray(std, dtype=float)


REGISTRY = {"ucb": ucb, "ei": ei, "pi": pi, "variance": variance}


def get(name: str):
    if name not in REGISTRY:
        raise KeyError(f"función de adquisición desconocida: {name} (ucb|ei|pi|variance)")
    return REGISTRY[name]
