#!/usr/bin/env python3
"""
evidence-capture.py — SE-364: captura intervenciones humanas → corpus de evals.

Lee ledgers locales (focal-decisions, audit SE-355) y detecta casos con
intervención humana o resultado fallido/rechazado. Esos casos se convierten en
un corpus de evals discriminantes: si tras un cambio de prompt/skill el agente
vuelve a producir lo rechazado, el eval falla.

Filtro de nivel: solo casos sin datos N3+ entran al corpus (CRIT-001).

Uso:
  evidence-capture.py --audit data/audit/actions.jsonl --corpus data/evidence-corpus
  evidence-capture.py --to-evals --corpus data/evidence-corpus --output output/evals.json

Ref: SE-364 — bucle de evidencia
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def capture(audit_path: Path, corpus_dir: Path, sources: list[str] | None = None) -> list[dict]:
    """Captura casos de intervención/rechazo desde el audit ledger."""
    records = load_jsonl(audit_path)
    cases = []
    corpus_dir.mkdir(parents=True, exist_ok=True)

    for i, rec in enumerate(records):
        outcome = rec.get("outcome", "")
        # solo casos con intervención/rechazo/failure
        if outcome not in ("failure", "enforced_deny", "error"):
            continue
        # filtro de nivel: no entran datos personales (N3/N3b/N4b) al corpus de evals
        level = str(rec.get("level", "N1"))
        if level in ("N3", "N3b", "N4b"):
            continue
        case = {
            "id": f"ev-{i:03d}",
            "source": "audit",
            "input": str(rec.get("target", "")),
            "output_rejected": outcome,
            "human_correction": rec.get("detail", ""),
            "ts": rec.get("ts", ""),
            "status": "open",
        }
        cases.append(case)
        (corpus_dir / f"{case['id']}.json").write_text(
            json.dumps(case, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    return cases


def to_evals(cases: list[dict]) -> list[dict]:
    """Convierte casos cerrados a formato eval (input/output_rejected como discriminante)."""
    evals = []
    for c in cases:
        if c.get("status") != "open":
            continue
        evals.append({
            "id": c["id"],
            "input": c["input"],
            "output_rejected": c["output_rejected"],
            "human_correction": c.get("human_correction", ""),
        })
    return evals


def main() -> int:
    parser = argparse.ArgumentParser(description="Captura de evidencia (SE-364)")
    parser.add_argument("--audit", default="data/audit/actions.jsonl")
    parser.add_argument("--corpus", default="data/evidence-corpus")
    parser.add_argument("--to-evals", action="store_true", help="convierte corpus a evals")
    parser.add_argument("--output", default="output/evals.json")
    args = parser.parse_args()

    if args.to_evals:
        corpus_dir = Path(args.corpus)
        cases = []
        if corpus_dir.exists():
            for f in corpus_dir.glob("*.json"):
                try:
                    cases.append(json.loads(f.read_text(encoding="utf-8")))
                except Exception:
                    continue
        evals = to_evals(cases)
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(evals, indent=2), encoding="utf-8")
        print(f"Evals generados: {len(evals)} en {out}")
        return 0

    cases = capture(Path(args.audit), Path(args.corpus))
    print(f"Casos capturados: {len(cases)} en {args.corpus}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
