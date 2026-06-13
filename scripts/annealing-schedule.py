#!/usr/bin/env python3
"""annealing-schedule.py — SPEC-197: Temperature annealing for multi-phase judges.

Computes a temperature value for a given phase index, total phases, max/min
range and exponent. Used by multi-phase agents (e.g. SPEC-194 criterion
simulation with 4 meta-questions) to interpolate between exploration (high T)
and decision (low T).

Formula (adapted from DiffusionGemma AnnealingTemperatureShaper):
    progress = index / (total - 1)             # 0..1
    factor   = 1 - (1 - progress)^exponent     # 0..1 monotonic
    T        = max_t + factor * (min_t - max_t)

For exponent=1: linear decrease.
For exponent>1: fast start, slow end (T drops quickly at first).
For exponent<1: slow start, fast end (T stays high longer).

Special cases:
- total <= 1: returns min_t (degenerate; single phase = decision).

Stdlib only.

Usage:
    python3 scripts/annealing-schedule.py \
        --index 0 --total 4 \
        --max-t 0.8 --min-t 0.4 --exponent 1.0
    # Output: {"temperature": 0.8, "index": 0, "total": 4, ...}

    python3 scripts/annealing-schedule.py --index 3 --total 4
    # Output: {"temperature": 0.4, ...}  # decision phase

Ref: SPEC-197 docs/propuestas/SPEC-197-annealing-schedule-meta-judges.md
"""
from __future__ import annotations

import argparse
import json
import sys


def schedule(
    index: int,
    total: int,
    max_t: float = 0.8,
    min_t: float = 0.4,
    exponent: float = 1.0,
) -> float:
    """Compute temperature for a given phase.

    Args:
        index: Current phase index, 0-based.
        total: Total number of phases.
        max_t: Temperature at phase 0 (exploration). Default 0.8.
        min_t: Temperature at phase total-1 (decision). Default 0.4.
        exponent: Shape of the decay. 1.0 = linear; >1 fast-then-slow
            (T drops quickly); <1 slow-then-fast (T stays high longer).

    Returns:
        Temperature in range [min_t, max_t]. For total<=1, returns min_t.
    """
    if total <= 1:
        return min_t
    if index < 0:
        index = 0
    if index >= total:
        index = total - 1

    progress = index / (total - 1)  # 0..1
    factor = 1 - (1 - progress) ** exponent  # 0..1 monotonic
    temperature = max_t + factor * (min_t - max_t)
    return temperature


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="annealing-schedule",
        description="SPEC-197: temperature annealing for multi-phase judges",
    )
    p.add_argument("--index", type=int, required=True,
                   help="Current phase index (0-based)")
    p.add_argument("--total", type=int, required=True,
                   help="Total number of phases")
    p.add_argument("--max-t", type=float, default=0.8,
                   help="Temperature at phase 0 (exploration). Default 0.8")
    p.add_argument("--min-t", type=float, default=0.4,
                   help="Temperature at last phase (decision). Default 0.4")
    p.add_argument("--exponent", type=float, default=1.0,
                   help="Decay shape exponent. Default 1.0 (linear)")
    p.add_argument("--json", action="store_true",
                   help="Emit JSON to stdout")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.total < 1:
        print(f"ERROR: --total must be >= 1, got {args.total}", file=sys.stderr)
        return 2
    if args.max_t < args.min_t:
        print(f"ERROR: --max-t ({args.max_t}) must be >= --min-t ({args.min_t})", file=sys.stderr)
        return 2

    t = schedule(args.index, args.total, args.max_t, args.min_t, args.exponent)
    if args.json:
        sys.stdout.write(json.dumps({
            "temperature": round(t, 4),
            "index": args.index,
            "total": args.total,
            "max_t": args.max_t,
            "min_t": args.min_t,
            "exponent": args.exponent,
        }) + "\n")
    else:
        sys.stdout.write(f"{t:.4f}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
