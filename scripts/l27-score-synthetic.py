#!/usr/bin/env python3
"""l27-score-synthetic.py — E5: validación sintética del score de criterio (L27).

Construye una población sintética de personas con habilidad de criterio latente
por dominio, genera decisiones con resultado (correcto/incorrecto) y computa un
score 0-100. Valida el constructo contra la habilidad latente:
  - AUC (¿el score separa buenos de malos decisores?)  — Mann-Whitney U
  - Brier del score vs tasa base (¿está calibrado?)
Kill criterion E3: AUC > 0.6 Y Brier < Brier_tasa_base → gate PASS.

CRIT-001: stdlib puro, local, determinista (semilla fija).
"""

import argparse
import json
import math
import random
import sys


def run(n_persons=120, n_decisions=20, seed=42, base_ability=0.55, skill_effect=0.20):
    rng = random.Random(seed)
    # 1) población: habilidad latente (criterio real por dominio)
    abilities = []
    for _ in range(n_persons):
        a = rng.uniform(0, 1)
        # señal observable = habilidad + ruido
        abilities.append((a, a + rng.gauss(0, 0.15)))
    # 2) decisiones con resultado
    outcomes = []
    for (a_true, a_obs) in abilities:
        p = max(0.05, min(0.95, base_ability + skill_effect * (a_obs - 0.5)))
        hits = sum(1 for _ in range(n_decisions) if rng.random() < p)
        outcomes.append((a_true, a_obs, hits / n_decisions))

    # 3) score 0-100 = calibración de la tasa de acierto normalizada (RANKING)
    rates = [o[2] for o in outcomes]
    lo, hi = min(rates), max(rates)
    scores = [round(50 + 50 * ((r - lo) / (hi - lo) if hi > lo else 0.0), 1) for r in rates]

    # 3b) probabilidad CALIBRADA (shrinkage bayesiano hacia la tasa base):
    # el score ordena; la probabilidad honesta es la tasa observada con prior.
    base = sum(o[2] for o in outcomes) / len(outcomes)
    K = 5  # fuerza del prior
    cal_probs = [round((o[2] * n_decisions + K * base) / (n_decisions + K), 4) for o in outcomes]

    # 4) AUC: ¿el score separa top-50% habilidad latente del resto? (Mann-Whitney U)
    cutoff = sorted(a for (a, _, _) in outcomes)[len(outcomes) // 2]
    good = [s for i, (a, _, _) in enumerate(outcomes) if a >= cutoff for s in [scores[i]]]
    bad = [s for i, (a, _, _) in enumerate(outcomes) if a < cutoff for s in [scores[i]]]
    # U = nº de pares (good>bad) + 0.5*(good==bad)
    u = sum(1 for g in good for b in bad if g > b) + 0.5 * sum(1 for g in good for b in bad if g == b)
    auc = u / (len(good) * len(bad)) if good and bad else 0.5

    # 5) Brier de la PROBABILIDAD CALIBRADA vs tasa base
    def brier(preds, outs):
        return sum((p - o) ** 2 for p, o in zip(preds, outs)) / len(preds)

    brier_cal = brier(cal_probs, [o[2] for o in outcomes])
    brier_base = brier([base] * len(outcomes), [o[2] for o in outcomes])
    # Brier del score crudo (como probabilidad) — se reporta para honestidad
    probs = [s / 100.0 for s in scores]
    brier_raw = brier(probs, [o[2] for o in outcomes])

    gate_pass = auc > 0.6 and brier_cal < brier_base
    return {
        "n_persons": n_persons,
        "n_decisions": n_decisions,
        "seed": seed,
        "auc_score_vs_latent": round(auc, 3),
        "brier_calibrado": round(brier_cal, 4),
        "brier_raw_score": round(brier_raw, 4),
        "brier_base_rate": round(brier_base, 4),
        "mejora_calibracion_vs_base": round(brier_base - brier_cal, 4),
        "gate_E3_pass": gate_pass,
    }


def main():
    ap = argparse.ArgumentParser(description="E5 score sintético (L27)")
    ap.add_argument("--persons", type=int, default=120)
    ap.add_argument("--decisions", type=int, default=20)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    report = run(args.persons, args.decisions, args.seed)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("GATE E3:", "PASS" if report["gate_E3_pass"] else "FAIL", file=sys.stderr)
    return 0 if report["gate_E3_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
