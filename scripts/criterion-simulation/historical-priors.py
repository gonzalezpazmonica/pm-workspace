#!/usr/bin/env python3
"""historical-priors.py — SPEC-194 Criterion Simulation Layer.

Searches for similar tasks that were reverted or failed in the KG
(knowledge-graph SQLite DB) within a configurable lookback window.

Graceful degradation: returns {count: 0, priors: []} if KG is absent
or inaccessible. NEVER raises; NEVER makes network calls.

Output: JSON {count: int, priors: [{id, summary, date}]}

Usage:
    python3 scripts/criterion-simulation/historical-priors.py
    python3 scripts/criterion-simulation/historical-priors.py --lookback 60
    python3 scripts/criterion-simulation/historical-priors.py --task-json '{"tags": ["security"]}'
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR  = Path(__file__).resolve().parent
WORKSPACE   = Path(os.environ.get("CLAUDE_PROJECT_DIR", SCRIPT_DIR.parent.parent))
DEFAULT_DB  = Path(os.environ.get(
    "SAVIA_KG_DB",
    str(WORKSPACE / ".savia-kg" / "graph.db")
))
LOOKBACK_DAYS = int(os.environ.get("SAVIA_CS_LOOKBACK_DAYS", 90))

EMPTY_RESULT: dict = {"count": 0, "priors": []}


def _table_exists(cursor: sqlite3.Cursor, table: str) -> bool:
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,)
    )
    return cursor.fetchone() is not None


def _column_exists(cursor: sqlite3.Cursor, table: str, column: str) -> bool:
    cursor.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cursor.fetchall())


def _extract_tags(task_context: dict) -> list[str]:
    """Extract searchable tags from task_context for similarity matching."""
    tags: list[str] = []
    for key in ("tags", "categories", "modules"):
        val = task_context.get(key)
        if isinstance(val, list):
            tags.extend(str(t) for t in val)
        elif isinstance(val, str):
            tags.append(val)
    # Also include signal flags as implicit tags
    for flag in ("touches_production", "touches_security", "touches_human_safety"):
        if task_context.get(flag):
            tags.append(flag.replace("touches_", ""))
    return [t.lower() for t in tags if t]


def get_recent_failed_frames(task_context: dict, lookback_days: int = LOOKBACK_DAYS) -> dict:
    """Return {count: int, priors: [{id, summary, date}]} from local KG.

    Searches frame_reaffirmations table for reverted/failed tasks with
    tags matching task_context within lookback_days.

    Graceful: returns EMPTY_RESULT if KG absent or table missing.
    """
    db_path = DEFAULT_DB

    if not db_path.exists():
        return dict(EMPTY_RESULT)

    cutoff = (datetime.now(tz=timezone.utc) - timedelta(days=lookback_days)).isoformat()
    tags   = _extract_tags(task_context)

    try:
        conn   = sqlite3.connect(str(db_path))
        cursor = conn.cursor()

        # Graceful: table may not exist yet
        if not _table_exists(cursor, "frame_reaffirmations"):
            conn.close()
            return dict(EMPTY_RESULT)

        has_tags_col = _column_exists(cursor, "frame_reaffirmations", "tags")

        if tags and has_tags_col:
            # Match any record whose tags overlap with task_context tags
            placeholders = ",".join("?" * len(tags))
            query = f"""
                SELECT task_id, reason, ts, verdict_before
                FROM frame_reaffirmations
                WHERE ts >= ?
                  AND verdict_before IN ('FRAME_DOUBT', 'FRAME_REJECT')
                  AND (
                    {" OR ".join(["tags LIKE ?" for _ in tags])}
                  )
                ORDER BY ts DESC
                LIMIT 10
            """
            like_params = [f"%{t}%" for t in tags]
            rows = cursor.execute(query, [cutoff] + like_params).fetchall()
        else:
            # No tags: return any recent doubt/reject frames
            query = """
                SELECT task_id, reason, ts, verdict_before
                FROM frame_reaffirmations
                WHERE ts >= ?
                  AND verdict_before IN ('FRAME_DOUBT', 'FRAME_REJECT')
                ORDER BY ts DESC
                LIMIT 10
            """
            rows = cursor.execute(query, [cutoff]).fetchall()

        conn.close()

        priors = [
            {
                "id":      row[0],
                "summary": row[1] if row[1] else "(no reason recorded)",
                "date":    row[2] if row[2] else "",
            }
            for row in rows
        ]
        return {"count": len(priors), "priors": priors}

    except (sqlite3.Error, OSError):
        return dict(EMPTY_RESULT)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-194 historical-priors — find similar failed frames in KG"
    )
    parser.add_argument(
        "--lookback", type=int, default=LOOKBACK_DAYS,
        help=f"Lookback window in days (default: {LOOKBACK_DAYS})"
    )
    parser.add_argument(
        "--task-json", default=None,
        help="Task context as JSON string (otherwise reads from stdin)"
    )
    parser.add_argument(
        "--db", default=str(DEFAULT_DB),
        help=f"Path to SQLite database (default: {DEFAULT_DB})"
    )
    args = parser.parse_args()

    # Allow overriding DB path
    global DEFAULT_DB  # noqa: PLW0603
    DEFAULT_DB = Path(args.db)

    if args.task_json:
        raw = args.task_json
    elif not sys.stdin.isatty():
        raw = sys.stdin.read().strip()
    else:
        raw = "{}"

    try:
        task_context = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        task_context = {}

    result = get_recent_failed_frames(task_context, lookback_days=args.lookback)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
