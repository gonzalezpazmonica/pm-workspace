#!/usr/bin/env python3
"""micmac.py — L30-F1: micro-MICMAC local (stdlib puro, determinista).

Matriz de influencias directas M (enteros 0..scale, diagonal nula; filas
influyen a columnas) -> clasificacion indirecta por potencias sucesivas
(Godet): S_k = M + M^2 + ... + M^k en aritmetica entera exacta, sin tope.
Se para cuando la jerarquia (orden de influencia, orden de dependencia y
cuadrantes) se repite STABLE_RUNS potencias seguidas, cuando M^k se anula
(sistema aciclico: S_k ya es exacta) o en MAX_POWER (converged=false).
Clasificacion por cuadrantes (motriz / enlace / dependiente / autonomo)
con la media de influencia y de dependencia como ejes (>= media = alto).
Influencia y dependencia se publican como % del total de S_k; la
clasificacion directa (sobre M) acompaña a cada variable.

Preregistro: labs/roadmaps/l30-prospectiva-sistemica.md (F1, prueba P1).
CRIT-001: 100% local, sin red, salida determinista (sin timestamps).

Uso:
  micmac.py --matrix FIXTURE.json [--json OUT.json]
  micmac.py --self-test
Exit: 0 ok · 2 input invalido o salida no escribible · 1 self-test fallido.
"""
import argparse
import json
import sys

MAX_POWER = 30
STABLE_RUNS = 2
SHARE_DECIMALS = 2


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def load_matrix(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("el documento debe ser un objeto con variables y matrix")
    names = data["variables"]
    m = data["matrix"]
    if not isinstance(names, list) or not isinstance(m, list):
        raise ValueError("variables y matrix deben ser listas")
    if any(not isinstance(x, str) or not x for x in names):
        raise ValueError("los nombres de variable deben ser textos no vacios")
    if len(set(names)) != len(names):
        raise ValueError("nombres de variable duplicados")
    n = len(names)
    if len(m) != n or any(not isinstance(row, list) or len(row) != n for row in m):
        raise ValueError(f"matriz debe ser {n}x{n}")
    if not (4 <= n <= 20):
        raise ValueError("micmac micro: entre 4 y 20 variables")
    scale = data.get("scale_max", 3)
    if not _is_int(scale) or scale < 1:
        raise ValueError("scale_max debe ser un entero >= 1")
    for i, row in enumerate(m):
        for j, v in enumerate(row):
            if not _is_int(v) or not (0 <= v <= scale):
                raise ValueError(f"valores deben ser enteros en 0..{scale}: "
                                 f"{names[i]}->{names[j]} = {v!r}")
        if row[i] != 0:
            raise ValueError(f"la diagonal debe ser 0 (sin auto-influencia): {names[i]}")
    if not any(any(row) for row in m):
        raise ValueError("matriz sin influencias: nada que clasificar")
    return names, m, scale


def mat_mul(a, b):
    n = len(a)
    return [[sum(a[i][k] * b[k][j] for k in range(n)) for j in range(n)] for i in range(n)]


def sums(e):
    n = len(e)
    return [sum(row) for row in e], [sum(e[i][j] for i in range(n)) for j in range(n)]


def quadrants(influence, dependence):
    """Cuadrante por variable; comparacion exacta x*n >= total (sin flotantes)."""
    n = len(influence)
    ti, td = sum(influence), sum(dependence)
    out = []
    for inf, dep in zip(influence, dependence):
        hi, hd = inf * n >= ti, dep * n >= td
        if hi and not hd:
            out.append("motriz")
        elif hd and not hi:
            out.append("dependiente")
        elif hi and hd:
            out.append("enlace")
        else:
            out.append("autonomo")
    return out


def shares(values):
    total = sum(values)
    return [round(100.0 * v / total, SHARE_DECIMALS) if total else 0.0 for v in values]


def hierarchy(e):
    """Firma de estabilidad: orden por cuota redondeada (empates por posicion) + cuadrantes."""
    influence, dependence = sums(e)
    si, sd = shares(influence), shares(dependence)
    idx = range(len(e))
    return (tuple(sorted(idx, key=lambda i: (-si[i], i))),
            tuple(sorted(idx, key=lambda i: (-sd[i], i))),
            tuple(quadrants(influence, dependence)))


def indirect(m):
    """S_k = M + ... + M^k hasta jerarquia estable. Devuelve (S_k, k, converged)."""
    n = len(m)
    power = [row[:] for row in m]
    total = [row[:] for row in m]
    prev, stable = hierarchy(total), 0
    for k in range(2, MAX_POWER + 1):
        power = mat_mul(power, m)
        if not any(any(row) for row in power):
            return total, k - 1, True
        total = [[total[i][j] + power[i][j] for j in range(n)] for i in range(n)]
        sig = hierarchy(total)
        stable = stable + 1 if sig == prev else 0
        if stable >= STABLE_RUNS:
            return total, k, True
        prev = sig
    return total, MAX_POWER, False


def run(matrix_path):
    names, m, _scale = load_matrix(matrix_path)
    e, power, converged = indirect(m)
    influence, dependence = sums(e)
    quads = quadrants(influence, dependence)
    d_inf, d_dep = sums(m)
    d_quads = quadrants(d_inf, d_dep)
    si, sd = shares(influence), shares(dependence)
    detail = {}
    by_q = {"motriz": [], "dependiente": [], "enlace": [], "autonomo": []}
    for i, name in enumerate(names):
        detail[name] = {"influence": si[i], "dependence": sd[i], "quadrant": quads[i],
                        "direct_influence": d_inf[i], "direct_dependence": d_dep[i],
                        "direct_quadrant": d_quads[i]}
        by_q[quads[i]].append(name)
    mean_share = round(100.0 / len(names), SHARE_DECIMALS)
    return {
        "tool": "micmac",
        "variables": len(names),
        "power": power,
        "stability_iterations": power,
        "converged": converged,
        "mean_influence": mean_share,
        "mean_dependence": mean_share,
        "motrices": by_q["motriz"],
        "dependientes": by_q["dependiente"],
        "enlace": by_q["enlace"],
        "autonomos": by_q["autonomo"],
        "detail": detail,
    }


def self_test():
    # Cadena A->B->C->D calculada a mano: S = M + M^2 + M^3, M^4 = 0.
    chain = [[0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1], [0, 0, 0, 0]]
    e, power, converged = indirect(chain)
    influence, dependence = sums(e)
    return (power == 3 and converged and influence == [3, 2, 1, 0]
            and dependence == [0, 1, 2, 3]
            and quadrants(influence, dependence) == ["motriz", "motriz", "dependiente", "dependiente"])


def main():
    ap = argparse.ArgumentParser(description="micro-MICMAC local (L30-F1)")
    ap.add_argument("--matrix", help="fixture JSON con variables + matrix")
    ap.add_argument("--json", dest="json_out", help="escribe resultado a fichero")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        ok = self_test()
        print("SELF-TEST OK" if ok else "SELF-TEST FALLO")
        sys.exit(0 if ok else 1)
    if not args.matrix:
        ap.error("--matrix es obligatorio")
    try:
        result = run(args.matrix)
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
