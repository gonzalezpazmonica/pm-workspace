#!/usr/bin/env python3
"""micmac.py — L30-F1: micro-MICMAC local (stdlib puro, determinista).

Matriz de influencias directas (0..scale) -> elevacion matricial iterada
hasta estabilidad (E_{k+1} = M + E_k x E_k, tope en scale*2) -> clasificacion
por cuadrantes (motriz / enlace / dependiente / autonomo) usando la media
de influencia y dependencia como umbral.

Preregistro: labs/roadmaps/l30-prospectiva-sistemica.md (F1, prueba P1).
CRIT-001: 100% local, sin red, salida determinista (sin timestamps).

Uso:
  micmac.py --matrix FIXTURE.json [--json OUT.json]
  micmac.py --self-test
Exit: 0 ok · 2 input invalido · 1 self-test contaminado.
"""
import argparse
import json
import sys

MAX_ITER = 8


def load_matrix(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    names = data["variables"]
    m = data["matrix"]
    n = len(names)
    if len(m) != n or any(len(row) != n for row in m):
        raise ValueError(f"matriz debe ser {n}x{n}")
    if not (4 <= n <= 20):
        raise ValueError("micmac micro: entre 4 y 20 variables")
    scale = int(data.get("scale_max", 3))
    for row in m:
        for v in row:
            if not (0 <= v <= scale):
                raise ValueError(f"valores deben estar en 0..{scale}")
    return names, [list(map(int, row)) for row in m], scale


def mat_mul(a, b, cap):
    n = len(a)
    return [[min(sum(a[i][k] * b[k][j] for k in range(n)), cap) for j in range(n)]
            for i in range(n)]


def mat_add(a, b, cap):
    return [[min(a[i][j] + b[i][j], cap) for j in range(len(a))] for i in range(len(a))]


def stabilize(m, scale):
    """E_{k+1} = M + E_k x E_k hasta punto fijo (o MAX_ITER)."""
    cap = scale * scale + scale
    e = [row[:] for row in m]
    for it in range(1, MAX_ITER + 1):
        nxt = mat_add(m, mat_mul(e, e, cap), cap)
        if nxt == e:
            return e, it
        e = nxt
    return e, MAX_ITER


def classify(names, e):
    n = len(names)
    influence = [sum(e[i][j] for j in range(n)) for i in range(n)]
    dependence = [sum(e[i][j] for i in range(n)) for j in range(n)]
    mi = sum(influence) / n
    md = sum(dependence) / n
    out = {}
    for i, name in enumerate(names):
        hi, hd = influence[i] >= mi, dependence[i] >= md
        if hi and not hd:
            q = "motriz"
        elif hd and not hi:
            q = "dependiente"
        elif hi and hd:
            q = "enlace"
        else:
            q = "autonomo"
        out[name] = {"influence": influence[i], "dependence": dependence[i], "quadrant": q}
    return out, round(mi, 4), round(md, 4)


def run(matrix_path):
    names, m, scale = load_matrix(matrix_path)
    e, iters = stabilize(m, scale)
    quads, mi, md = classify(names, e)
    by_q = {}
    for name, info in quads.items():
        by_q.setdefault(info["quadrant"], []).append(name)

    def nat_key(s):
        head, num = s.rsplit("V", 1) if "V" in s else (s, "")
        return (head, int(num) if num.isdigit() else -1)

    for q in by_q:
        by_q[q].sort(key=nat_key)
    return {
        "tool": "micmac",
        "variables": len(names),
        "stability_iterations": iters,
        "mean_influence": mi,
        "mean_dependence": md,
        "motrices": by_q.get("motriz", []),
        "dependientes": by_q.get("dependiente", []),
        "enlace": by_q.get("enlace", []),
        "autonomos": by_q.get("autonomo", []),
        "detail": quads,
    }


def self_test():
    n = 5
    m = [[0 if i == j else 1 for j in range(n)] for i in range(n)]
    e, iters = stabilize(m, 3)
    return e == stabilize(e, 3)[0]


def main():
    ap = argparse.ArgumentParser(description="micro-MICMAC local (L30-F1)")
    ap.add_argument("--matrix", help="fixture JSON con variables + matrix")
    ap.add_argument("--json", dest="json_out", help="escribe resultado a fichero")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        print("SELF-TEST OK" if self_test() else "SELF-TEST FALLO")
        sys.exit(0 if self_test() else 1)
    if not args.matrix:
        ap.error("--matrix es obligatorio")
    try:
        result = run(args.matrix)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
    blob = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True)
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as f:
            f.write(blob + "\n")
    print(blob)


if __name__ == "__main__":
    main()
