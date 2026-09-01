#!/usr/bin/env python3
"""
risk-tier.py — SE-362: clasifica un cambio por tier de riesgo (1-4).

Tiers:
  T1 — Reversible mínimo: docs/typos/chore, auto-merge si delegado
  T2 — Reversible módulo: refactor con tests, auto-merge + 1 review
  T3 — Irreversible/datos: migración, secrets, N3+, requiere humano
  T4 — Crítico: infra prod, auth, PII, doble humano

Fail-closed: un path no clasificable → tier 3 (humano, no asume bajo riesgo).

Uso:
  risk-tier.py --diff "path1 path2" [--json]

Ref: SE-362 — gradación de riesgo para auto-merge (gobernanza ejecutable)
"""
from __future__ import annotations

import argparse
import json
import sys

# Paths que elevan el tier
TIER_3_PATHS = (
    "secret", "credential", "migration", "db/migrate", "data/",
    "auth", "token", "vault", "key.",
    "push", "merge", "deploy", "release",
)
TIER_4_PATHS = (
    "infra/", ".github/workflows", "prod.", "terraform", "bicep", "docker-compose",
    "production", "deploy/", "pii",
)
# Excluir paths que NO elevan (evitar falsos positivos como "docs/")
LOW_RISK_EXT = (".md", ".txt", ".json", ".yaml", ".yml", ".scm")

DOCS_PATHS = ("docs/", "README", "CHANGELOG", "REVIEW", "CLAUDE.md", "AGENTS.md", "SKILLS.md")


def classify(files: list[str]) -> dict:
    """Devuelve tier + rationale + requires_human para un set de archivos."""
    tier = 2  # default: reversible módulo
    rationale: list[str] = []

    for f in files:
        fl = f.lower()
        # docs puros → tier 1 (si todos son docs)
        if any(fl.startswith(d.lower()) for d in DOCS_PATHS) and fl.endswith((".md", ".txt")):
            continue
        # tier 4: infra/prod/PII
        if any(p in fl for p in TIER_4_PATHS):
            tier = max(tier, 4)
            rationale.append(f"path crítico: {f}")
            continue
        # tier 3: secrets/migrations/auth
        if any(p in fl for p in TIER_3_PATHS):
            tier = max(tier, 3)
            rationale.append(f"path sensible: {f}")
            continue

    # Si TODOS los archivos son docs → tier 1
    all_docs = all(
        (any(fl.startswith(d.lower()) for d in DOCS_PATHS) and fl.endswith((".md", ".txt")))
        or fl.endswith(LOW_RISK_EXT) and "/" not in fl.replace("docs/", "")
        for f in (x.lower() for x in files)
    ) if files else False
    if all_docs and tier == 2:
        tier = 1
        rationale.append("solo documentación/artefactos de proceso")

    if not rationale:
        rationale.append("código normal con tests — riesgo reversible")

    # Fail-closed: archivo sin categoría clara → tier 3 (humano, no asume bajo riesgo)
    KNOWN = TIER_3_PATHS + TIER_4_PATHS + DOCS_PATHS + ("src/", "tests/", ".py", ".ts", ".tsx", ".js", ".go", ".rs", ".sh", ".cs", ".java", ".rb", ".php", ".md", ".scm", "docs/", "README", "CHANGELOG", "REVIEW", "CLAUDE.md", "AGENTS.md", "SKILLS.md")
    unknown = [f for f in files if not any(k in f.lower() for k in KNOWN)]
    if unknown and tier < 3:
        tier = 3
        rationale.append(f"fail-closed: paths sin categoría clara → tier 3: {', '.join(unknown)}")

    return {
        "tier": tier,
        "requires_human": tier >= 3,
        "rationale": "; ".join(rationale),
        "files": files,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Clasificador de riesgo (SE-362)")
    parser.add_argument("--diff", required=True, help="archivos del diff separados por espacio")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    files = [f for f in args.diff.split() if f]
    result = classify(files)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Risk tier: {result['tier']} {'(humano requerido)' if result['requires_human'] else '(auto-merge posible)'}")
        print(f"  rationale: {result['rationale']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
