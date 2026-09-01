#!/usr/bin/env python3
"""
review-policy-parse.py — SE-359: parsea REVIEW.md (política canónica de review).

Extrae de REVIEW.md:
  - passes (secciones con instrucciones)
  - severidad (Important vs Nit)
  - cap de nits
  - exclusiones (paths a no reportar)

Salida JSON consumible por el Code Review Court.

Uso:
  review-policy-parse.py --file REVIEW.md [--json]

Si REVIEW.md no existe → fail-soft con defaults (no rompe el court).

Ref: SE-359 — REVIEW.md policy (playbook Anthropic Stage 5)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULTS = {
    "passes": ["Bugs", "Security", "Compliance"],
    "important": "findings that break behavior, leak data or breach a policy",
    "nit_cap": 5,
    "exclusions": ["generated", "src/gen", "CI-enforced"],
}


def parse_policy(path: str | Path) -> dict:
    """Extrae la política de REVIEW.md (o defaults si no existe)."""
    p = Path(path)
    if not p.exists():
        return {**DEFAULTS, "source": str(p), "exists": False}

    text = p.read_text(encoding="utf-8")

    # Passes: secciones "## X" bajo un "## Passes" o secciones h2/h3 con verbo
    passes = []
    m = re.search(r"(?is)## Passes\s*\n(.*?)(?=\n## |\Z)", text)
    if m:
        block = m.group(1)
        for line in block.splitlines():
            line = line.strip()
            if re.match(r"^[-*]?\s*[A-Za-z]+:", line) or (
                line and not line.startswith("#") and "passes" not in line.lower()
            ):
                name = re.sub(r"^[-*]\s*", "", line).split(":")[0].strip()
                name = name.replace("**", "").strip()  # quitar markdown bold
                if name and name.lower() not in [x.lower() for x in passes]:
                    passes.append(name)

    # Severidad: "## What Important means here"
    important = DEFAULTS["important"]
    m = re.search(r"(?is)## What Important means here\s*\n(.*?)(?=\n## |\Z)", text)
    if m:
        important = m.group(1).strip().split("\n")[0].strip()

    # Cap de nits: "Report at most N nits"
    nit_cap = DEFAULTS["nit_cap"]
    m = re.search(r"(?i)at most\s+(\d+)\s+nits", text)
    if m:
        nit_cap = int(m.group(1))

    # Exclusiones: sección "## Do not report"
    exclusions = []
    m = re.search(r"(?is)## Do not report\s*\n(.*?)(?=\n## |\Z)", text)
    if m:
        for line in m.group(1).splitlines():
            line = line.strip().lstrip("-").strip()
            if line and not line.startswith("#"):
                exclusions.append(line)

    if not passes:
        passes = DEFAULTS["passes"]

    return {
        "source": str(p),
        "exists": True,
        "passes": passes,
        "important": important,
        "nit_cap": nit_cap,
        "exclusions": exclusions or DEFAULTS["exclusions"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Parser de REVIEW.md (SE-359)")
    parser.add_argument("--file", required=True, help="ruta a REVIEW.md")
    parser.add_argument("--json", action="store_true", help="salida JSON")
    args = parser.parse_args()

    policy = parse_policy(args.file)

    if args.json:
        print(json.dumps(policy, indent=2, ensure_ascii=False))
    else:
        print(f"REVIEW policy ({policy['source']}):")
        print(f"  passes: {', '.join(policy['passes'])}")
        print(f"  nit_cap: {policy['nit_cap']}")
        print(f"  important: {policy['important']}")
        print(f"  exclusions: {', '.join(policy['exclusions'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
