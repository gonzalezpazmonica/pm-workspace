#!/usr/bin/env python3
"""l27-facts-ledger.py — E3: hechos vs humo (gate L27).

Principio anti-humo: una afirmación es un HECHO solo si proviene de un fronema
con consecuencia VERIFICADA (madurez verified/calibrated y resultado != null).
Todo lo no verificado (draft/pending) es HUMO: no sirve como evidencia.

Lee la cúpula Fronesia (fronema.py persistencia) y emite:
  - ledger de hechos (JSONL, N2) → output/l27-facts-ledger.jsonl
  - lista de humo (no evidencia)
  - reporte {hechos, humo, ratio}

Uso: l27-facts-ledger.py [--vault DIR] [--out FILE]
CRIT-001: local; sin red.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_VAULT = os.path.join(ROOT, "vaults", "Fronesia")

VERIFIED = {"verified", "calibrated"}


def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_frontmatter(text):
    import re
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    case = {}
    cur_list = None
    for raw in m.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("- "):
            if cur_list:
                case.setdefault(cur_list, []).append(line[2:].strip())
            continue
        if ":" in line:
            k, _, v = line.partition(":")
            k, v = k.strip(), v.strip()
            cur_list = None
            if v.startswith("{") and v.endswith("}"):
                d = {}
                for pair in v[1:-1].split(","):
                    if ":" in pair:
                        a, _, b = pair.partition(":")
                        d[a.strip()] = b.strip().strip('"')
                case[k] = d
            elif v == "":
                case.setdefault(k, [])
                cur_list = k
            else:
                case[k] = v.strip('"')
    return case


def cid(case):
    return (case.get("entity") or {}).get("id") or case.get("id") or "?"


def scan(vault):
    cases = []
    if not os.path.isdir(vault):
        return cases
    for f in sorted(os.listdir(vault)):
        if not f.endswith(".md"):
            continue
        c = parse_frontmatter(open(os.path.join(vault, f), encoding="utf-8").read())
        if (c.get("entity") or {}).get("type") == "phronesis-case":
            c["_file"] = f
            cases.append(c)
    return cases


def main():
    ap = argparse.ArgumentParser(description="E3 hechos vs humo (L27)")
    ap.add_argument("--vault", default=DEFAULT_VAULT)
    ap.add_argument("--out", default=os.path.join(ROOT, "output", "l27-facts-ledger.jsonl"))
    args = ap.parse_args()

    cases = scan(args.vault)
    if not cases:
        print("ERROR: sin fronemas en la cúpula", file=sys.stderr)
        sys.exit(1)

    hechos, humo = [], []
    for c in cases:
        mad = str(c.get("madurez", "draft"))
        cons = c.get("consequence", {}) or {}
        if mad in VERIFIED and cons.get("resultado"):
            hechos.append(c)
        else:
            humo.append(c)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        for c in hechos:
            rec = {
                "id": cid(c),
                "tension": c.get("tension", ""),
                "decision": c.get("decision", ""),
                "razon": c.get("razon", ""),
                "resultado": (c.get("consequence", {}) or {}).get("resultado", ""),
                "dominio": c.get("dominio", []),
                "madurez": c.get("madurez", ""),
                "fuente": c.get("fuente", ""),
            }
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    report = {
        "ts": iso_now(),
        "vault": args.vault,
        "hechos": len(hechos),
        "humo": len(humo),
        "ratio_hechos": round(len(hechos) / len(cases), 2) if cases else 0,
        "hechos_out": args.out,
        "humo_ids": [cid(h) for h in humo],
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not hechos:
        print("GATE E3: FALL — sin hechos verificados (no hay evidencia anti-humo)", file=sys.stderr)
        sys.exit(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
