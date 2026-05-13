#!/usr/bin/env python3
"""Cache Analytics — query usage.db and report hit rate / cost / top agents.

Implements SPEC-CACHE-HIT-TRACKING §2.4.

Usage:
  python3 scripts/cache-analytics.py                       # last 7d
  python3 scripts/cache-analytics.py --since 30d
  python3 scripts/cache-analytics.py --project savia       # directory contains substring
  python3 scripts/cache-analytics.py --agent build
  python3 scripts/cache-analytics.py --model deepseek-v4-pro
  python3 scripts/cache-analytics.py --export csv
"""
from __future__ import annotations

import argparse
import csv
import re
import sqlite3
import sys
import time
from pathlib import Path


def default_db() -> Path:
    return Path.home() / ".savia/usage.db"


def parse_since(s: str) -> int:
    """Return epoch ms cutoff for an expression like '7d', '24h', '30m', 'all'."""
    if s == "all":
        return 0
    m = re.match(r"^(\d+)([dhm])$", s)
    if not m:
        raise SystemExit(f"--since: bad format {s!r} (expected Nd/Nh/Nm/all)")
    n, unit = int(m.group(1)), m.group(2)
    mult = {"d": 86400, "h": 3600, "m": 60}[unit]
    return int(time.time() * 1000) - n * mult * 1000


def build_where(args) -> tuple[str, list]:
    clauses = ["ts >= ?"]
    params: list = [parse_since(args.since)]
    if args.project:
        clauses.append("directory LIKE ?")
        params.append(f"%{args.project}%")
    if args.agent:
        clauses.append("agent = ?")
        params.append(args.agent)
    if args.model:
        clauses.append("model = ?")
        params.append(args.model)
    return " AND ".join(clauses), params


def hit_rate(cache_read: int, cache_write: int) -> float:
    denom = cache_read + cache_write
    if denom == 0:
        return 0.0
    return 100.0 * cache_read / denom


def report(db_path: Path, args) -> int:
    if not db_path.exists():
        print(f"ERROR: usage.db not found at {db_path}", file=sys.stderr)
        print("Run: python3 scripts/cache-scanner.py", file=sys.stderr)
        return 2

    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    where, params = build_where(args)

    if args.export == "csv":
        cur = conn.execute(
            f"""SELECT message_id, session_id, ts, directory, agent, mode, model,
                       input, output, cache_read, cache_write, reasoning, cost
                FROM turns WHERE {where} ORDER BY ts""",
            params,
        )
        w = csv.writer(sys.stdout)
        w.writerow([d[0] for d in cur.description])
        for row in cur:
            w.writerow(row)
        return 0

    # Aggregate totals
    row = conn.execute(
        f"""SELECT COUNT(DISTINCT session_id), COUNT(*),
                   COALESCE(SUM(cache_read),0), COALESCE(SUM(cache_write),0),
                   COALESCE(SUM(input),0), COALESCE(SUM(output),0),
                   COALESCE(SUM(cost),0)
            FROM turns WHERE {where}""",
        params,
    ).fetchone()
    n_sessions, n_turns, cr, cw, inp, out, cost = row

    print(f"Cache Analytics — since {args.since}")
    print()
    print(f"Sesiones:              {n_sessions:,}")
    print(f"Mensajes assistant:    {n_turns:,}")
    print(f"Tokens cache_read:     {cr:,}")
    print(f"Tokens cache_write:    {cw:,}")
    print(f"Tokens input nuevo:    {inp:,}")
    print(f"Tokens output:         {out:,}")
    print(f"Hit rate:              {hit_rate(cr, cw):.1f}%")
    print(f"Coste total (real):    ${cost:.2f}")

    if n_turns == 0:
        return 0

    # Top 5 agents
    print()
    print("Top 5 agentes por volumen:")
    for ag, n, c in conn.execute(
        f"""SELECT COALESCE(agent,'(none)') AS ag, COUNT(*) AS n, COALESCE(SUM(cost),0) AS c
            FROM turns WHERE {where}
            GROUP BY ag ORDER BY n DESC LIMIT 5""",
        params,
    ):
        print(f"  {ag:<20} {n:>6,} turns   ${c:.2f}")

    # Top 3 models with hit rate
    print()
    print("Top 3 modelos:")
    for mo, n, c, mcr, mcw in conn.execute(
        f"""SELECT COALESCE(model,'(none)') AS mo, COUNT(*) AS n, COALESCE(SUM(cost),0) AS c,
                   COALESCE(SUM(cache_read),0) AS mcr, COALESCE(SUM(cache_write),0) AS mcw
            FROM turns WHERE {where}
            GROUP BY mo ORDER BY n DESC LIMIT 3""",
        params,
    ):
        print(f"  {mo:<20} {n:>6,} turns   ${c:.2f}   hit {hit_rate(mcr, mcw):.1f}%")

    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Query usage.db for cache analytics")
    ap.add_argument("--db", type=Path, default=default_db())
    ap.add_argument("--since", default="7d", help="Time window (e.g. 7d, 24h, 30m, all)")
    ap.add_argument("--project", help="Filter by directory substring")
    ap.add_argument("--agent", help="Filter by agent name (exact match)")
    ap.add_argument("--model", help="Filter by modelID (exact match)")
    ap.add_argument("--export", choices=["csv"], help="Export filtered turns")
    args = ap.parse_args()
    return report(args.db, args)


if __name__ == "__main__":
    sys.exit(main())
