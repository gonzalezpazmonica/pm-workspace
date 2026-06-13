#!/usr/bin/env python3
"""quality-gate-adaptive.py — SPEC-200: Adaptive quality gate threshold.

Computes a quality threshold proportional to the score distribution of the
tests in a PR. Replaces the fixed SPEC-055 threshold (80) with one that
adapts to the set:

- High-mean set (mean >= 85): threshold = max(fixed_min, mean - 1.5*stddev).
  Outliers in good sets fail.
- Low-mean set (mean < 85): threshold = mean - 0.5*stddev.
  Tolerated with WARN; modules being onboarded are not punished by an
  arbitrary fixed bar.
- Clamped to [floor, ceil] always.

Pattern adapted from DiffusionGemma SampleFromPredictions entropy_bound:
selection threshold proportional to the confidence distribution of the
candidate set, not a fixed absolute.

Stdlib only.

Usage:
    python3 scripts/quality-gate-adaptive.py \
        --scores 85 92 78 88 95 81 \
        [--fixed-min 80] [--floor 60] [--ceil 90] [--json]

Output (--json):
    {
      "threshold": int,
      "strategy": "high_mean_strict|low_mean_tolerant|empty",
      "metrics": { "mean": float, "stddev": float, "n_scores": int,
                   "fixed_min": int, "floor": int, "ceil": int }
    }

Exit: 0 always. Decision is in the JSON.

Ref: SPEC-200 docs/propuestas/SPEC-200-adaptive-quality-gate-threshold.md
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


def adaptive_threshold(
    scores: list[int | float],
    *,
    fixed_min: int = 80,
    floor: int = 60,
    ceil: int = 90,
) -> dict:
    """Compute adaptive threshold + metrics.

    Args:
        scores: List of test quality scores (0-100).
        fixed_min: Minimum threshold in high_mean_strict mode. Default 80.
        floor: Absolute minimum threshold. Default 60.
        ceil: Absolute maximum threshold. Default 90.

    Returns:
        dict with keys: threshold, strategy, metrics.
        Strategy is one of: high_mean_strict, low_mean_tolerant, empty.
    """
    n = len(scores)
    if n == 0:
        return {
            "threshold": fixed_min,
            "strategy": "empty",
            "metrics": {
                "mean": 0.0,
                "stddev": 0.0,
                "n_scores": 0,
                "fixed_min": fixed_min,
                "floor": floor,
                "ceil": ceil,
            },
        }

    mean = sum(scores) / n
    sd = stddev([float(s) for s in scores])

    if mean >= 85:
        raw = mean - 1.5 * sd
        threshold = max(fixed_min, int(raw))
        strategy = "high_mean_strict"
    else:
        raw = mean - 0.5 * sd
        threshold = int(raw)
        strategy = "low_mean_tolerant"

    # Clamp to [floor, ceil]
    threshold = max(floor, min(ceil, threshold))

    return {
        "threshold": threshold,
        "strategy": strategy,
        "metrics": {
            "mean": round(mean, 2),
            "stddev": round(sd, 2),
            "n_scores": n,
            "fixed_min": fixed_min,
            "floor": floor,
            "ceil": ceil,
            "raw_pre_clamp": round(raw, 2),
        },
    }


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="quality-gate-adaptive",
        description="SPEC-200: adaptive quality gate threshold based on score distribution",
    )
    p.add_argument("--scores", nargs="+", type=int, required=True,
                   help="Space-separated test quality scores (0-100)")
    p.add_argument("--fixed-min", type=int, default=80,
                   help="Minimum threshold in high_mean_strict mode (default 80)")
    p.add_argument("--floor", type=int, default=60,
                   help="Absolute minimum threshold (default 60)")
    p.add_argument("--ceil", type=int, default=90,
                   help="Absolute maximum threshold (default 90)")
    p.add_argument("--json", action="store_true",
                   help="Emit full JSON to stdout")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.floor > args.ceil:
        print(f"ERROR: --floor ({args.floor}) must be <= --ceil ({args.ceil})", file=sys.stderr)
        return 2
    if args.fixed_min > args.ceil:
        print(f"ERROR: --fixed-min ({args.fixed_min}) must be <= --ceil ({args.ceil})", file=sys.stderr)
        return 2

    result = adaptive_threshold(
        args.scores, fixed_min=args.fixed_min, floor=args.floor, ceil=args.ceil
    )
    if args.json:
        sys.stdout.write(json.dumps(result) + "\n")
    else:
        sys.stdout.write(f"threshold={result['threshold']} strategy={result['strategy']}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
