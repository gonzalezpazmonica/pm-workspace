#!/usr/bin/env python3
"""mactor.py — L30-F1: micro-MACTOR local (stdlib puro, determinista).

Simplificacion de MACTOR (Godet): no usa la matriz de influencias entre
actores (MID) ni la escala -3..+3 de posiciones; trabaja con 2-6 actores,
posicion por eje (0..1), stake por eje (0..1, default 0.5) y poder
(0..1, default 0.5).
- Divergencia(A,B) = distancia media de posiciones ponderada por el stake
  comun (min de ambos stakes por eje) — solo pesa lo que a ambos les importa.
  Sin stake comun la divergencia es null: el par no es alianza ni conflicto.
- Alianza: convergencia (1 - divergencia) >= umbral (default 0.7).
- Conflicto: divergencia >= 0.5.
- Zona de acuerdo: centroide ponderado por poder + spread por eje
  (max - min de posiciones, sin ponderar).

Preregistro: labs/roadmaps/l30-prospectiva-sistemica.md (F1, prueba P2).
CRIT-001: 100% local, sin red, salida determinista.

Uso:
  mactor.py --actors FIXTURE.json [--threshold 0.7] [--json OUT.json]
  mactor.py --self-test
Exit: 0 ok · 2 input invalido o salida no escribible · 1 self-test fallido.
"""
import argparse
import json
import sys

DIVERGENCE_THRESHOLD = 0.5


def _unit(value, label):
    """Numero real en 0..1 (booleanos y textos se rechazan)."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{label} debe ser un numero: {value!r}")
    if not (0.0 <= value <= 1.0):
        raise ValueError(f"{label} fuera de 0..1: {value}")
    return float(value)


def load_actors(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("el documento debe ser un objeto con axes y actors")
    actors = data["actors"]
    axes = data["axes"]
    if not isinstance(actors, list) or not (2 <= len(actors) <= 6):
        raise ValueError("mactor micro: entre 2 y 6 actores")
    if not isinstance(axes, list) or not axes:
        raise ValueError("axes debe ser una lista no vacia")
    if len(set(axes)) != len(axes):
        raise ValueError("ejes duplicados")
    names = [a["name"] for a in actors]
    if len(set(names)) != len(names):
        raise ValueError("nombres de actor duplicados")
    for a in actors:
        for ax in axes:
            _unit(a["positions"][ax], f"posicion {a['name']}/{ax}")
            _unit(a.get("stake", {}).get(ax, 0.5), f"stake {a['name']}/{ax}")
        _unit(a.get("power", 0.5), f"poder {a['name']}")
    if sum(float(a.get("power", 0.5)) for a in actors) <= 0:
        raise ValueError("poder total 0: no hay centroide de acuerdo")
    return axes, actors


def divergence(a, b, axes):
    """Distancia ponderada por stake comun; None si no comparten ningun stake."""
    num = den = 0.0
    for ax in axes:
        sa = float(a.get("stake", {}).get(ax, 0.5))
        sb = float(b.get("stake", {}).get(ax, 0.5))
        common = min(sa, sb)
        num += common * abs(a["positions"][ax] - b["positions"][ax])
        den += common
    return round(num / den, 4) if den > 0 else None


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
            conv = None if d is None else round(1.0 - d, 4)
            rel = {"pair": f"{a['name']}-{b['name']}", "divergence": d,
                   "convergence": conv}
            pairs.append(rel)
            if d is None:
                continue
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
                    help="umbral de convergencia para alianza, 0..1 (default 0.7)")
    ap.add_argument("--json", dest="json_out", help="escribe resultado a fichero")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        ok = self_test()
        print("SELF-TEST OK" if ok else "SELF-TEST FALLO")
        sys.exit(0 if ok else 1)
    if not args.actors:
        ap.error("--actors es obligatorio")
    if not (0.0 <= args.threshold <= 1.0):
        ap.error("--threshold debe estar en 0..1")
    try:
        result = run(args.actors, args.threshold)
        blob = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True)
        if args.json_out:
            with open(args.json_out, "w", encoding="utf-8") as f:
                f.write(blob + "\n")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        # json.JSONDecodeError es subclase de ValueError.
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
    print(blob)


if __name__ == "__main__":
    main()
