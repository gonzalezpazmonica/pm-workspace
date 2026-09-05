#!/usr/bin/env python3
"""capability-entropy.py — SE-380: métrica de entropía arquitectónica (v0).

Fórmula provisional (pesos 1.0, congelados en baseline hasta validación):
    entropy = active_capabilities + overlap_pairs + mirror_pairs
            + dependency_edges + manual_sync_surfaces + exception_count
Componentes medibles hoy desde el registry SE-375 y el árbol. routing_ambiguity
queda a 0 hasta integrar RESOLVER OVERRIDE (documentado como límite).

--check: falla si entropy > baseline congelado (ratchet: solo puede bajar).
Baseline: tests/baselines/capability-entropy.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    reg = json.load(open(os.path.join(root, ".scm", "registry.json"), encoding="utf-8"))
    caps = reg["capabilities"]

    active = sum(1 for c in caps if c.get("status") != "deprecated")
    # overlap: mismo basename con distinta extensión/kind en scripts y skills
    stems = Counter(
        os.path.basename(c["source"]).rsplit(".", 1)[0].lower()
        for c in caps if c["kind"] in ("script", "skill", "agent", "cmd")
    )
    overlap_pairs = sum(v - 1 for v in stems.values() if v > 1)
    # mirrors: pares skill/agent/hook con mismo basename en .claude y .opencode
    claude = {c["id"] for c in caps if str(c["source"]).startswith(".claude")}
    opencode = {c["id"] for c in caps if str(c["source"]).startswith(".opencode")}
    mirror_pairs = len(claude & opencode)
    dep_edges = sum(len(c.get("depends_on") or []) for c in caps)
    sync_surfaces = sum(
        os.path.exists(os.path.join(root, f)) for f in
        (".scm/INDEX.scm", "AGENTS.md", "SKILLS.md", "docs/RESOLVER.md")
    )
    exceptions = 0  # SE-376: excepciones aprobadas (ninguna aún)

    entropy = (active + overlap_pairs + mirror_pairs
               + dep_edges + sync_surfaces + exceptions)
    components = {
        "active_capabilities": active,
        "overlap_pairs": overlap_pairs,
        "mirror_pairs": mirror_pairs,
        "dependency_edges": dep_edges,
        "routing_ambiguity": 0,
        "manual_sync_surfaces": sync_surfaces,
        "exception_count": exceptions,
    }
    payload = {"entropy_version": 0, "weights": "all-1.0-provisional",
               "entropy": entropy, "components": components}

    base_path = os.path.join(root, "tests", "baselines", "capability-entropy.json")
    if args.check:
        base = json.load(open(base_path, encoding="utf-8"))
        if entropy > base["entropy"]:
            print(f"FAIL: entropía {entropy} > baseline {base['entropy']} — consolidar antes de crecer")
            return 1
        print(f"PASS: entropía {entropy} <= baseline {base['entropy']}")
        return 0

    if os.path.exists(base_path):
        print(f"entropy v0 = {entropy} (baseline congelado: "
              f"{json.load(open(base_path))['entropy']}); usa --check para ratchet")
    else:
        with open(base_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, sort_keys=True)
            f.write("\n")
        print(f"entropy v0 = {entropy} congelado en {base_path} (primera medición)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
