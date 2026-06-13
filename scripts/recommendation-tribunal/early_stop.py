#!/usr/bin/env python3
"""early_stop.py — SPEC-195: Multi-criteria early stop for iterative tribunal.

Evaluates whether the iterative tribunal loop should stop based on three
deterministic criteria (no LLM calls):

1. Token stability: draft_n == draft_n-1 (sha256 hash). Converged.
2. Entropy threshold: stddev of judge scores across the 7 judges < threshold.
   Low stddev means strong consensus -> no value iterating more.
3. Max iterations: hard cap. Last resort.

The aggregator AND'es the three results (any single stop reason triggers stop).

Pattern adapted from DiffusionGemma `ChainedEarlyStop` (sequence of stop
functions with AND aggregation). Adapted to text instead of token tensors:
draft text vs token batch, judge scores vs logit entropy.

Usage:
    python3 scripts/recommendation-tribunal/early_stop.py \
        --iteration N \
        --max-iter 3 \
        --draft-hash <sha256 of current draft> \
        --previous-draft-hash <sha256 of previous draft or empty> \
        --judge-scores 85,92,78,88,95,81,90 \
        --entropy-threshold 5.0 \
        --json

Output (--json):
    {
      "should_stop": bool,
      "stop_reason": "stability|entropy|max_iter|none",
      "criteria": {
        "stability": bool,
        "entropy": bool,
        "max_iter": bool
      },
      "metrics": {
        "iteration": int,
        "max_iter": int,
        "score_stddev": float,
        "entropy_threshold": float
      }
    }

Exit: always 0 (stop decision is in JSON).

Ref: SPEC-195 docs/propuestas/SPEC-195-iterative-tribunal-early-stop.md
"""
from __future__ import annotations

import argparse
import json
import math
import sys


def stddev(values: list[float]) -> float:
    """Sample standard deviation. Returns 0.0 for n<=1."""
    n = len(values)
    if n <= 1:
        return 0.0
    mean = sum(values) / n
    var = sum((v - mean) ** 2 for v in values) / (n - 1)
    return math.sqrt(var)


def token_stability_stop(draft_hash: str, previous_draft_hash: str) -> bool:
    """Returns True iff hashes match and previous is non-empty."""
    return bool(previous_draft_hash) and draft_hash == previous_draft_hash


def entropy_stop(scores: list[float], threshold: float) -> bool:
    """Returns True iff stddev of scores is below threshold (consensus)."""
    return stddev(scores) < threshold


def max_iter_stop(iteration: int, max_iter: int) -> bool:
    """Returns True iff iteration count reached max."""
    return iteration >= max_iter


def should_stop(
    *,
    iteration: int,
    max_iter: int,
    draft_hash: str,
    previous_draft_hash: str,
    judge_scores: list[float],
    entropy_threshold: float,
) -> dict:
    """Evaluate all 3 criteria. Returns dict with decision + reason + metrics.

    Stop priority (when multiple trigger): stability > entropy > max_iter.
    This matters for the reported `stop_reason`; the boolean decision is
    OR of all three (any True stops).
    """
    crit_stability = token_stability_stop(draft_hash, previous_draft_hash)
    crit_entropy = entropy_stop(judge_scores, entropy_threshold)
    crit_max = max_iter_stop(iteration, max_iter)

    if crit_stability:
        reason = "stability"
    elif crit_entropy:
        reason = "entropy"
    elif crit_max:
        reason = "max_iter"
    else:
        reason = "none"

    return {
        "should_stop": crit_stability or crit_entropy or crit_max,
        "stop_reason": reason,
        "criteria": {
            "stability": crit_stability,
            "entropy": crit_entropy,
            "max_iter": crit_max,
        },
        "metrics": {
            "iteration": iteration,
            "max_iter": max_iter,
            "score_stddev": round(stddev(judge_scores), 3),
            "entropy_threshold": entropy_threshold,
            "judges_count": len(judge_scores),
        },
    }


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="early_stop",
        description="SPEC-195: multi-criteria early stop for iterative tribunal",
    )
    p.add_argument("--iteration", type=int, required=True,
                   help="Current iteration count (0-based)")
    p.add_argument("--max-iter", type=int, default=3,
                   help="Hard cap on iterations (default 3)")
    p.add_argument("--draft-hash", required=True,
                   help="SHA256 hash of current draft")
    p.add_argument("--previous-draft-hash", default="",
                   help="SHA256 hash of previous draft (empty for first iteration)")
    p.add_argument("--judge-scores", required=True,
                   help="Comma-separated scores from the 7 judges, e.g. 85,92,78")
    p.add_argument("--entropy-threshold", type=float, default=5.0,
                   help="Stddev threshold for consensus (default 5.0 = good agreement)")
    p.add_argument("--json", action="store_true",
                   help="Emit JSON to stdout")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        scores = [float(s) for s in args.judge_scores.split(",") if s.strip()]
    except ValueError:
        print(f"ERROR: invalid --judge-scores: {args.judge_scores!r}", file=sys.stderr)
        return 2

    result = should_stop(
        iteration=args.iteration,
        max_iter=args.max_iter,
        draft_hash=args.draft_hash,
        previous_draft_hash=args.previous_draft_hash,
        judge_scores=scores,
        entropy_threshold=args.entropy_threshold,
    )
    if args.json:
        sys.stdout.write(json.dumps(result) + "\n")
    else:
        sys.stdout.write(f"should_stop={result['should_stop']} reason={result['stop_reason']}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
