#!/usr/bin/env python3
"""causal-confidence-scorer.py — SPEC-188 Phase 3 MVP

Calculates confidence in an identified root cause given evidence and alternatives.

Usage:
    python3 scripts/causal-confidence-scorer.py \
        --cause "Connection pool exhausted" \
        --evidence '["Metrics show pool at max", "Logs confirm timeout", "Reproduced in staging"]' \
        --alternatives '["Memory leak", "Network issue"]'

Output JSON:
    {
        "cause": "...",
        "confidence_score": 0.75,
        "supporting_evidence": [...],
        "contradicting_evidence": [...],
        "alternative_causes": [{"cause": "...", "probability": 0.10}],
        "verdict": "high" | "medium" | "low" | "insufficient"
    }

Heuristics:
    0 evidence            -> confidence=0.0, verdict="insufficient"
    1-2 evidence          -> confidence=0.4-0.6, verdict="medium"
    3+ coherent evidence  -> confidence>=0.7, verdict="high"
    Plausible alternatives reduce confidence proportionally

Ref: SPEC-188 docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any


_CONTRADICTION_KEYWORDS = frozenset({
    "but", "however", "although", "except", "unless", "not",
    "no evidence", "contradicts", "disproves", "rules out",
    "inconsistent", "unrelated", "independent of",
})


def _classify_evidence(items: list[str]) -> tuple[list[str], list[str]]:
    supporting: list[str] = []
    contradicting: list[str] = []
    for item in items:
        if any(kw in item.lower() for kw in _CONTRADICTION_KEYWORDS):
            contradicting.append(item)
        else:
            supporting.append(item)
    return supporting, contradicting


def _base_confidence(n_sup: int, n_contra: int) -> float:
    if n_sup == 0:
        return 0.0
    if n_sup >= 5:
        base = 0.90
    elif n_sup >= 3:
        base = 0.75
    elif n_sup == 2:
        base = 0.55
    else:
        base = 0.40
    return round(max(0.0, base - 0.12 * n_contra), 4)


def _apply_alternative_penalty(score: float, n_alts: int) -> float:
    return round(max(0.0, score - 0.07 * n_alts), 4)


def _verdict(score: float) -> str:
    if score == 0.0:
        return "insufficient"
    if score >= 0.70:
        return "high"
    if score >= 0.40:
        return "medium"
    return "low"


def _assign_alt_probabilities(alts: list[Any], main_conf: float) -> list[dict]:
    if not alts:
        return []
    budget = round(max(0.0, 1.0 - main_conf), 4)
    n = len(alts)
    prob = round(budget / n, 4) if n else 0.0
    result = []
    for a in alts:
        cause_str = a.get("cause", str(a)) if isinstance(a, dict) else str(a)
        result.append({"cause": cause_str, "probability": prob})
    return result


def score(cause: str, evidence: list[str], alternatives: list[Any]) -> dict:
    if not evidence:
        return {
            "cause": cause,
            "confidence_score": 0.0,
            "supporting_evidence": [],
            "contradicting_evidence": [],
            "alternative_causes": _assign_alt_probabilities(alternatives, 0.0),
            "verdict": "insufficient",
        }

    sup, contra = _classify_evidence(evidence)
    base = _base_confidence(len(sup), len(contra))
    final = _apply_alternative_penalty(base, len(alternatives))

    return {
        "cause": cause,
        "confidence_score": final,
        "supporting_evidence": sup,
        "contradicting_evidence": contra,
        "alternative_causes": _assign_alt_probabilities(alternatives, final),
        "verdict": _verdict(final),
    }


def _parse_list(s: str) -> list:
    try:
        r = json.loads(s)
        return r if isinstance(r, list) else [r]
    except json.JSONDecodeError:
        return [s] if s else []


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Causal confidence scorer (SPEC-188 P3)")
    p.add_argument("--cause", required=True)
    p.add_argument("--evidence", default="[]")
    p.add_argument("--alternatives", default="[]")
    p.add_argument("--pretty", action="store_true", default=False)
    args = p.parse_args(argv)

    result = score(
        cause=args.cause,
        evidence=_parse_list(args.evidence),
        alternatives=_parse_list(args.alternatives),
    )
    print(json.dumps(result, indent=2 if args.pretty else None, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
