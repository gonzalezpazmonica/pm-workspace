#!/usr/bin/env python3
"""mactor.py — L30-F1: micro-MACTOR local (stdlib puro, determinista).

2-6 actores con posiciones por eje, stake (interes por eje) y poder.
- Divergencia(A,B) = distancia media de posiciones ponderada por el stake
  comun (min de ambos stakes por eje) — solo pesa lo que a ambos les importa.
- Alianza: convergencia (1 - divergencia) >= umbral (default 0.7).
- Zona de acuerdo: centroide ponderado por poder + radio = mitad del spread
  ponderado de posiciones.

Preregistro: labs/roadmaps/l30-prospectiva-sistemica.md (F1, prueba P2).
CRIT-001: 100% local, sin red, salida determinista.

Uso:
  mactor.py --actors FIXTURE.json [--threshold 0.7] [--json OUT.json]
  mactor.py --self-test
Exit: 0 ok · 2 input invalido · 1 self-test contaminado.
"""
import argparse
import json
import sys

DIVERGENCE_THRESHOLD = 0.5


def load_actors(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    actors = data["actors"]
    if not (2 <= len(actors) <= 6):
        raise ValueError("mactor micro: entre 2 y 6 actores")
    axes = data["axes"]
    for a in actors:
        for ax in axes:
            p = a["positions"][ax]
            if not (0.0 <= p <= 1.0):
                raise ValueError(f"posicion {a['name']}/{ax} fuera de 0..1: {p}")
            s = float(a.get("stake", {}).get(ax, 0.5))
            if not (0.0 <= s <= 1.0):
                raise ValueError(f"stake {a['name']}/{ax} fuera de 0..1: {s}")
        pw = float(a.get("power", 0.5))
        if not (0.0 <= pw <= 1.0):
            raise ValueError(f"poder {a['name']} fuera de 0..1: {pw}")
    return axes, actors


def divergence(a, b, axes):
    num = den = 0.0
    for ax in axes:
        sa = float(a.get("stake", {}).get(ax, 0.5))
        sb = float(b.get("stake", {}).get(ax, 0.5))
        common = min(sa, sb)
        num += common * abs(a["positions"][ax] - b["positions"][ax])
        den += common
    return round(num / den, 4) if den > 0 else 0.0


def agreement_zone(actors, axes):
    total_power = sum(float(a.get("power", 0.5)) for a in actors)
    center = {}
    for ax in axes:
        center[ax] = round(sum(a["positions"][ax] * float(a.get("power", 0.5))
                               for a in actors) / total_power, 4)
    spread = {}
    for ax in axes:
        vals = [a["positions"][ax] for a in actors]
        spread[ax] = round(max(vals) - min(vals), 4)
    return {"center": center, "spread": spread}


def run(actors_path, threshold):
    axes, actors = load_actors(actors_path)
    pairs = []
    alliances = []
    divergences = []
    for i in range(len(actors)):
        for j in range(i + 1, len(actors)):
            a, b = actors[i], actors[j]
            d = divergence(a, b, axes)
            conv = round(1.0 - d, 4)
            rel = {"pair": f"{a['name']}-{b['name']}", "divergence": d,
                   "convergence": conv}
            pairs.append(rel)
            if conv >= threshold:
                alliances.append(rel["pair"])
            if d >= DIVERGENCE_THRESHOLD:
                divergences.append(rel["pair"])
    return {
        "tool": "mactor",
        "actors": [a["name"] for a in actors],
        "pairs": pairs,
        "alliances": alliances,
        "divergences": divergences,
        "divergence_detected": bool(divergences),
        "agreement_zone": agreement_zone(actors, axes),
        "threshold_alliance": threshold,
    }


def self_test():
    actors = [
        {"name": "X", "positions": {"a": 0.0}, "stake": {"a": 1.0}, "power": 0.5},
        {"name": "Y", "positions": {"a": 1.0}, "stake": {"a": 1.0}, "power": 0.5},
    ]
    return divergence(actors[0], actors[1], ["a"]) == 1.0


def main():
    ap = argparse.ArgumentParser(description="micro-MACTOR local (L30-F1)")
    ap.add_argument("--actors", help="fixture JSON con axes + actors")
    ap.add_argument("--threshold", type=float, default=0.7,
                    help="umbral de convergencia para alianza (default 0.7)")
    ap.add_argument("--json", dest="json_out", help="escribe resultado a fichero")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        print("SELF-TEST OK" if self_test() else "SELF-TEST FALLO")
        sys.exit(0 if self_test() else 1)
    if not args.actors:
        ap.error("--actors es obligatorio")
    try:
        result = run(args.actors, args.threshold)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
    blob = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True)
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as f:
            f.write(blob + "\n")
    print(blob)


if __name__ == "__main__":
    main()
