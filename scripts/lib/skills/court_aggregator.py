"""court_aggregator skill — combines 5 judge scores into weighted verdict.

Used by .scm/flows/code-review-court.flow.yaml. Slice 3 stub: weights all
judges with equal placeholder scores. A future slice will pass node outputs
as args.
"""
from __future__ import annotations

WEIGHTS = {
    "correctness": 0.30,
    "architecture": 0.20,
    "security": 0.25,
    "cognitive": 0.10,
    "spec": 0.15,
}


def run(args: dict, state: dict) -> dict:
    scores = args.get("scores") or {k: 80 for k in WEIGHTS}
    weighted = round(sum(scores.get(k, 0) * w for k, w in WEIGHTS.items()), 2)
    verdict = "approve" if weighted >= 70 else "request-changes"
    return {
        "weighted_score": weighted,
        "verdict": verdict,
        "_state_patch": {
            "weighted_score": weighted,
            "verdict": verdict,
            "scores": scores,
        },
    }
