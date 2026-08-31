#!/usr/bin/env python3
"""
ci-duration-agg.py — SE-361: agrega duración de jobs de CI desde runs locales.

Calcula por job: duración, p50/p95 sobre ventana rodante, y detección de
jobs que superan el presupuesto (CI_TIME_BUDGET_MIN, default 5 min).

Entrada: JSONL con {name, duration_ms, conclusion} (producido por ci-duration.sh
o por el propio agg desde cache local).

Uso:
  ci-duration-agg.py --input data/ci-duration/jobs.jsonl [--budget 5] [--json]

Ref: SE-361 — presupuesto de tiempo de CI (bottleneck explícito)
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path


def load_jobs(path: Path) -> list[dict]:
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


def aggregate(jobs: list[dict], budget_min: int = 5) -> dict:
    by_name: dict[str, list[int]] = {}
    for j in jobs:
        name = j.get("name", "unknown")
        ms = int(j.get("duration_ms", 0))
        by_name.setdefault(name, []).append(ms)

    budget_ms = budget_min * 60_000
    result = {"budget_min": budget_min, "jobs": {}, "over_budget_count": 0}
    for name, durations in by_name.items():
        durations_sorted = sorted(durations)
        p50 = statistics.median(durations_sorted)
        p95 = durations_sorted[min(len(durations_sorted) - 1, int(len(durations_sorted) * 0.95))]
        over = p50 > budget_ms
        result["jobs"][name] = {
            "runs": len(durations),
            "p50_ms": round(p50, 1),
            "p95_ms": round(p95, 1),
            "p50_min": round(p50 / 60_000, 2),
            "over_budget": over,
            "budget_ms": budget_ms,
        }
        if over:
            result["over_budget_count"] += 1

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Agregador ci-duration (SE-361)")
    parser.add_argument("--input", default="data/ci-duration/jobs.jsonl")
    parser.add_argument("--budget", type=int, default=5)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    jobs = load_jobs(Path(args.input))
    result = aggregate(jobs, args.budget)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"CI duration (SE-361) — presupuesto {args.budget} min")
        for name, d in result["jobs"].items():
            flag = "OVER" if d["over_budget"] else "ok"
            print(f"  {name:<20} p50={d['p50_min']:>5}min  p95={d['p95_ms']/60000:>5.1f}min  [{flag}]")
        print(f"  jobs sobre presupuesto: {result['over_budget_count']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
