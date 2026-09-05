#!/usr/bin/env python3
"""consolidation-advisor.py — SE-380 §18: advisor de consolidación propose-only.

Genera PROPUESTAS (jamás ejecuta) de MERGE / DELETE / GENERALIZE / DEPRECATE
cruzando registry (SE-375), similitud de intents e inventario de deuda (SE-376).
Determinista. Salida: output/consolidation-proposals.md
"""
from __future__ import annotations

import csv
import json
import os
import sys
from collections import defaultdict


def jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    reg_path = os.path.join(root, ".scm", "registry.json")
    reg = json.load(open(reg_path, encoding="utf-8"))
    caps = reg["capabilities"]

    proposals = []

    # 1. DEPRECATE/DELETE: skills marcadas en el inventario SE-376 como DELETE
    inv_path = os.path.join(root, "docs", "propuestas", "SE-376-debt-inventory.tsv")
    if os.path.exists(inv_path):
        for row in csv.DictReader(open(inv_path, encoding="utf-8"), delimiter="\t"):
            if row.get("clasificacion") in ("DELETE", "MERGE"):
                proposals.append(("DEPRECATE" if row["clasificacion"] == "DELETE" else "MERGE",
                                  f"skill:{row['skill']}",
                                  f"inventario SE-376: {row.get('justificacion', '')[:60]}"))

    # 2. MERGE: skills con intents muy solapados (jaccard >= 0.55)
    skills = [c for c in caps if c["kind"] == "skill"]
    seen = set()
    for i, a in enumerate(skills):
        ta = set(a["intents"])
        if len(ta) < 3:
            continue
        for b in skills[i + 1:]:
            if b["id"] in seen:
                continue
            j = jaccard(ta, set(b["intents"]))
            if j >= 0.55:
                proposals.append(("MERGE_CANDIDATE", f"{a['id']} ~ {b['id']}",
                                  f"jaccard={j:.2f}"))
                seen.add(b["id"])

    # 3. GENERALIZE: mismo stem en kinds distintos (script vs hook-like duplicado)
    by_stem = defaultdict(list)
    for c in caps:
        stem = os.path.basename(c["source"]).rsplit(".", 1)[0].lower()
        by_stem[stem].append(c)
    for stem, group in sorted(by_stem.items()):
        kinds = {c["kind"] for c in group}
        if len(group) > 1 and len(kinds) > 1 and len(group) <= 3:
            proposals.append(("GENERALIZE", stem,
                              "existe en kinds: " + ",".join(sorted(kinds))))

    counts = defaultdict(int)
    lines = ["# Consolidation Proposals (SE-380) — PROPUESTAS, no ejecutar", "",
             "Fuente: registry SE-375 + inventario SE-376 + similitud de intents. "
             "Toda ejecución requiere decisión humana explícita.", "",
             "| Acción | Objetivo | Detalle |", "|---|---|---|"]
    for action, target, detail in proposals:
        lines.append(f"| {action} | {target} | {detail} |")
        counts[action] += 1
    lines += ["", "Resumen: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) or "sin propuestas"]

    outdir = os.path.join(root, "output")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "consolidation-proposals.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"consolidation-advisor: {len(proposals)} propuestas (propose-only) → output/consolidation-proposals.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
