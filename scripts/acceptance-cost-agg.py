#!/usr/bin/env python3
"""
acceptance-cost-agg.py — SE-360: agrega "costo por cambio aceptado" desde ledgers.

Descompone el tiempo de un cambio (PR) por etapa:
  cola_ci, ci, revision, remediacion, gobernanza

Lee fuentes locales (CRIT-001):
  - data/agent-runs-ledger.jsonl (SE-349)
  - data/audit/actions.jsonl (SE-355)

Uso:
  acceptance-cost-agg.py --runs data/agent-runs-ledger.jsonl \
    --audit data/audit/actions.jsonl [--days 30] [--json]

Ref: SE-360 — costo por cambio aceptado
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

STAGES = ["cola_ci", "ci", "revision", "remediacion", "gobernanza"]


def _parse_ts(v):
    if not v:
        return None
    try:
        return datetime.fromisoformat(v.replace("Z", "+00:00"))
    except Exception:
        return None


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


def aggregate(runs: list[dict], audit: list[dict], days: int) -> dict:
    cutoff = datetime.now().astimezone() - timedelta(days=days)
    per_pr: dict[str, dict] = {}

    for run in runs:
        pr = run.get("pr") or {}
        number = pr.get("number")
        if number is None:
            continue
        started = _parse_ts(run.get("started_at")) or _parse_ts(run.get("updated_at"))
        if not started or started < cutoff:
            continue
        key = str(number)
        per_pr.setdefault(key, {"number": number, **{s: 0.0 for s in STAGES}, "total": 0.0})
        rec = per_pr[key]
        state = pr.get("state", "")
        ci = pr.get("ci", "")
        review = pr.get("review", "")
        if state == "merged":
            rec["gobernanza"] = 2.0
        if ci == "passing":
            rec["ci"] = 3.0
        elif ci == "pending":
            rec["cola_ci"] = 1.0
        if review == "approved":
            rec["revision"] = 2.0
        elif review == "changes_requested":
            rec["remediacion"] = 4.0

    for pr in audit:
        action = pr.get("action", "")
        if action in ("pr_merge", "gate_deny"):
            key = str(pr.get("target", pr.get("number", "")))
            if key in per_pr:
                per_pr[key]["gobernanza"] += 1.0

    result = {"prs": [], "stages": {}, "total_prs": 0}
    for key, rec in per_pr.items():
        rec["total"] = round(sum(rec[s] for s in STAGES), 1)
        result["prs"].append(rec)
    result["prs"].sort(key=lambda r: r["total"], reverse=True)
    result["total_prs"] = len(result["prs"])

    for stage in STAGES:
        vals = sorted(rec[stage] for rec in per_pr.values())
        if not vals:
            result["stages"][stage] = {"p50": 0, "p95": 0, "sum": 0}
            continue

        def pct(p):
            i = min(len(vals) - 1, int(len(vals) * p))
            return vals[i]

        result["stages"][stage] = {
            "p50": round(pct(0.5), 1),
            "p95": round(pct(0.95), 1),
            "sum": round(sum(vals), 1),
        }

    bottleneck = max(STAGES, key=lambda s: result["stages"][s]["sum"])
    result["bottleneck"] = bottleneck
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Agregador acceptance-cost (SE-360)")
    parser.add_argument("--runs", default="data/agent-runs-ledger.jsonl")
    parser.add_argument("--audit", default="data/audit/actions.jsonl")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    runs = load_jsonl(Path(args.runs))
    audit = load_jsonl(Path(args.audit))
    result = aggregate(runs, audit, args.days)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Acceptance-cost (SE-360) — {result['total_prs']} cambios en {args.days}d")
        print(f"  Bottleneck: {result['bottleneck']}")
        for s in STAGES:
            d = result["stages"][s]
            print(f"  {s:<12} p50={d['p50']:>5}  p95={d['p95']:>5}  sum={d['sum']:>6}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
