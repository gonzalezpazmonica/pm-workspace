#!/usr/bin/env python3
"""Context Optimization Measure - recompute d7/d14 hit rates per monitored file.

Implements SPEC-CONTEXT-OPT-GATE section 6.

For each row in context_baselines with status in (measuring, baseline_ready):
  - Recompute global d7 and d14 cache hit rates from turns table.
  - Update cache_hit_rate_d7, cache_hit_rate_d14, delta_d7_pp, delta_d14_pp.
  - If delta_d14_pp <= -5.0 -> set status='alert'.
  - If delta_d14_pp > -5.0 and current status='alert' -> status='measuring'.
  - Write summary to stdout (table) and JSONL audit event.

Usage:
  python3 scripts/context-opt-measure.py [--json] [--db PATH]
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def usage_db_path() -> Path:
    return Path.home() / ".savia/usage.db"


def audit_log_path() -> Path:
    workspace = os.environ.get("SAVIA_WORKSPACE_DIR") or os.environ.get(
        "CLAUDE_PROJECT_DIR") or os.environ.get("OPENCODE_PROJECT_DIR") or os.getcwd()
    p = Path(workspace) / "output/context-opt-audit.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def hit_rate_window(conn: sqlite3.Connection, days: int) -> float | None:
    """Compute global cache hit rate over last N days from turns table.

    Hit rate = sum(cache_read_tokens) / sum(cache_read_tokens + cache_write_tokens)
    Returns None when denominator is zero.
    """
    cutoff_ms = int((time.time() - days * 86400) * 1000)
    row = conn.execute(
        """
        SELECT
          COALESCE(SUM(cache_read_tokens), 0),
          COALESCE(SUM(cache_read_tokens + cache_write_tokens), 0)
        FROM turns
        WHERE ts_ms >= ?
        """,
        (cutoff_ms,),
    ).fetchone()
    if not row or not row[1]:
        return None
    return float(row[0]) / float(row[1])


def log_event(event: dict) -> None:
    event = {"ts": datetime.now(timezone.utc).isoformat(), **event}
    try:
        with audit_log_path().open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event, ensure_ascii=False) + "\n")
    except OSError:
        pass


def update_baseline_row(
    conn: sqlite3.Connection,
    file_path: str,
    baseline: float | None,
    d7: float | None,
    d14: float | None,
    current_status: str,
) -> tuple[str, float | None, float | None]:
    """Return (new_status, delta_d7_pp, delta_d14_pp)."""
    delta_d7 = None
    delta_d14 = None
    if baseline is not None and d7 is not None:
        delta_d7 = (d7 - baseline) * 100.0
    if baseline is not None and d14 is not None:
        delta_d14 = (d14 - baseline) * 100.0

    new_status = current_status
    if current_status in ("measuring", "baseline_ready", "alert"):
        if delta_d14 is not None and delta_d14 <= -5.0:
            new_status = "alert"
        elif current_status == "alert" and delta_d14 is not None and delta_d14 > -5.0:
            new_status = "measuring"
        elif current_status == "baseline_ready":
            new_status = "measuring"

    conn.execute(
        """
        UPDATE context_baselines
        SET cache_hit_rate_d7 = ?,
            cache_hit_rate_d14 = ?,
            delta_d7_pp = ?,
            delta_d14_pp = ?,
            status = ?,
            updated_at = ?
        WHERE file_path = ?
        """,
        (
            d7,
            d14,
            delta_d7,
            delta_d14,
            new_status,
            datetime.now(timezone.utc).isoformat(),
            file_path,
        ),
    )
    return new_status, delta_d7, delta_d14


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=None, help="Override usage.db path")
    parser.add_argument("--json", action="store_true", help="Emit JSON to stdout")
    args = parser.parse_args(argv)

    db_path = args.db or usage_db_path()
    if not db_path.exists():
        print(f"usage.db not found: {db_path}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(str(db_path))
    try:
        rows = conn.execute(
            """
            SELECT file_path, file_sha256, cache_hit_rate_baseline, status
            FROM context_baselines
            """
        ).fetchall()
    except sqlite3.OperationalError:
        print("context_baselines table missing. Run gate first to create schema.",
              file=sys.stderr)
        return 1

    d7 = hit_rate_window(conn, 7)
    d14 = hit_rate_window(conn, 14)

    results = []
    for file_path, sha, baseline, status in rows:
        new_status, delta_d7, delta_d14 = update_baseline_row(
            conn, file_path, baseline, d7, d14, status
        )
        results.append({
            "file_path": file_path,
            "sha256": sha,
            "baseline": baseline,
            "d7": d7,
            "d14": d14,
            "delta_d7_pp": delta_d7,
            "delta_d14_pp": delta_d14,
            "status_before": status,
            "status_after": new_status,
        })
    conn.commit()
    conn.close()

    log_event({"event": "measure", "rows": len(results),
               "d7": d7, "d14": d14})

    if args.json:
        print(json.dumps({"d7": d7, "d14": d14, "rows": results}, indent=2))
    else:
        if not results:
            print("No monitored files. Run a baseline snapshot first.")
            return 0
        print(f"Global hit rate d7={d7:.3f}  d14={d14:.3f}" if d7 and d14 else
              f"Global hit rate d7={d7}  d14={d14}")
        print()
        print(f"{'file':<60} {'baseline':>9} {'d14':>7} {'Δpp':>7} {'status':>12}")
        for r in results:
            b = f"{r['baseline']:.3f}" if r['baseline'] is not None else "n/a"
            d = f"{r['d14']:.3f}" if r['d14'] is not None else "n/a"
            dd = f"{r['delta_d14_pp']:+.2f}" if r['delta_d14_pp'] is not None else "n/a"
            print(f"{r['file_path']:<60} {b:>9} {d:>7} {dd:>7} {r['status_after']:>12}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
