#!/usr/bin/env python3
"""memory-two-speed.py — SE-268 Slice 4: Two-speed memory (episodic + semantic).

Extends the bi-temporal memory system with explicit storage tiers:
- Episodic store (fast, hippocampal): session-level events, high resolution, cheap write
- Semantic store (slow, cortical): consolidated patterns, validity-time indexed

Supports selective replay consolidation: only recurrent/valuable engrams promote.
Dome-context-indexed retrieval. Quality metric tracking.

Storage: ~/.savia/memory-two-speed.db (SQLite)
Usage:
  python3 scripts/memory-two-speed.py --add --text "..." --store episodic --dome sales
  python3 scripts/memory-two-speed.py --query --dome sales
  python3 scripts/memory-two-speed.py --consolidate  # selective replay
  python3 scripts/memory-two-speed.py --stats
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DB_PATH = Path.home() / ".savia" / "memory-two-speed.db"

def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def _now_dt() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _connect(path: Path = DB_PATH) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS episodic (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            dome TEXT DEFAULT 'default',
            occurred TEXT NOT NULL,
            learned TEXT NOT NULL,
            recurrence INT DEFAULT 1,
            value_score REAL DEFAULT 0.0,
            promoted_to TEXT,
            tombstone TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS semantic (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            dome TEXT DEFAULT 'default',
            valid_from TEXT NOT NULL,
            valid_until TEXT,
            consolidated_at TEXT NOT NULL,
            source_episodic_ids TEXT,
            access_count INT DEFAULT 0,
            last_accessed TEXT,
            quality_score REAL DEFAULT 0.0,
            tombstone TEXT
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_ep_dome ON episodic(dome)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_ep_learned ON episodic(learned)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sm_dome ON semantic(dome)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sm_valid ON semantic(valid_from)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sm_accessed ON semantic(last_accessed)")
    conn.commit()
    return conn


# ── Add ───────────────────────────────────────────────────────────────────────
def add(text: str, store: str = "episodic", dome: str = "default",
        occurred: str | None = None, value: float = 0.0) -> dict:
    conn = _connect()
    eid = str(uuid.uuid4())[:8]
    occurred = occurred or _now_dt()
    learned = _now_iso()

    if store == "episodic":
        conn.execute(
            "INSERT INTO episodic (id,text,dome,occurred,learned,value_score) VALUES (?,?,?,?,?,?)",
            (eid, text.strip(), dome, occurred, learned, value),
        )
    elif store == "semantic":
        conn.execute(
            "INSERT INTO semantic (id,text,dome,valid_from,consolidated_at,quality_score) VALUES (?,?,?,?,?,?)",
            (eid, text.strip(), dome, occurred, learned, value),
        )
    conn.commit()
    conn.close()
    return {"id": eid, "store": store, "text": text[:60]}


# ── Query ─────────────────────────────────────────────────────────────────────
def query(dome: str | None = None, store: str = "semantic",
          limit: int = 20) -> list[dict]:
    conn = _connect()
    if store == "episodic":
        table = "episodic"
        if dome:
            cur = conn.execute(
                f"SELECT * FROM {table} WHERE dome=? AND tombstone IS NULL "
                "ORDER BY learned DESC LIMIT ?", (dome, limit))
        else:
            cur = conn.execute(
                f"SELECT * FROM {table} WHERE tombstone IS NULL "
                "ORDER BY learned DESC LIMIT ?", (limit,))
    else:
        table = "semantic"
        if dome:
            cur = conn.execute(
                f"SELECT * FROM {table} WHERE dome=? AND tombstone IS NULL "
                "ORDER BY last_accessed DESC, quality_score DESC LIMIT ?",
                (dome, limit))
        else:
            cur = conn.execute(
                f"SELECT * FROM {table} WHERE tombstone IS NULL "
                "ORDER BY last_accessed DESC, quality_score DESC LIMIT ?",
                (limit,))

    rows = [dict(r) for r in cur.fetchall()]
    conn.close()

    # Update access counters for semantic results
    if store == "semantic" and rows:
        conn2 = _connect()
        now = _now_iso()
        for r in rows:
            conn2.execute(
                "UPDATE semantic SET access_count=access_count+1, last_accessed=? "
                "WHERE id=?", (now, r["id"]))
        conn2.commit()
        conn2.close()

    return rows


# ── Consolidate (selective replay) ────────────────────────────────────────────
def consolidate(dome: str | None = None, min_recurrence: int = 2,
                min_value: float = 0.3, dry_run: bool = False) -> dict:
    """Selective replay: promote episodic engrams that meet criteria to semantic.

    Returns: {promoted: N, discarded: N, total_processed: N}
    """
    conn = _connect()
    where = "WHERE tombstone IS NULL AND promoted_to IS NULL"
    params: tuple = ()
    if dome:
        where += " AND dome=?"
        params = (dome,)

    cur = conn.execute(
        f"SELECT id, text, dome, occurred, recurrence, value_score FROM episodic {where} "
        "ORDER BY learned", params)
    candidates = [dict(r) for r in cur.fetchall()]

    promoted = 0
    discarded = 0

    for c in candidates:
        should_promote = (c["recurrence"] >= min_recurrence or
                         c["value_score"] >= min_value)

        if should_promote:
            if not dry_run:
                sid = str(uuid.uuid4())[:8]
                now = _now_iso()
                conn.execute(
                    "INSERT INTO semantic (id,text,dome,valid_from,consolidated_at,source_episodic_ids) "
                    "VALUES (?,?,?,?,?,?)",
                    (sid, c["text"], c["dome"], c["occurred"], now, c["id"]))
                conn.execute(
                    "UPDATE episodic SET promoted_to=? WHERE id=?",
                    (sid, c["id"]))
            promoted += 1
        else:
            # Mark for quarantine, not immediate deletion (CRIT-024)
            if not dry_run:
                conn.execute(
                    "UPDATE episodic SET tombstone=? WHERE id=?",
                    (f"consolidation-{_now_iso()}", c["id"]))
            discarded += 1

    conn.commit()
    conn.close()
    return {
        "total_processed": len(candidates),
        "promoted": promoted,
        "discarded": discarded,
        "dry_run": dry_run,
    }


# ── Stats ─────────────────────────────────────────────────────────────────────
def stats() -> dict:
    conn = _connect()
    ep_count = conn.execute(
        "SELECT COUNT(*) as c FROM episodic WHERE tombstone IS NULL").fetchone()["c"]
    ep_promoted = conn.execute(
        "SELECT COUNT(*) as c FROM episodic WHERE promoted_to IS NOT NULL").fetchone()["c"]
    sm_count = conn.execute(
        "SELECT COUNT(*) as c FROM semantic WHERE tombstone IS NULL").fetchone()["c"]
    sm_used = conn.execute(
        "SELECT COUNT(*) as c FROM semantic WHERE access_count > 0 AND tombstone IS NULL"
    ).fetchone()["c"]
    conn.close()

    quality = (sm_used / sm_count) if sm_count > 0 else 0.0

    return {
        "episodic_active": ep_count,
        "episodic_promoted": ep_promoted,
        "semantic_total": sm_count,
        "semantic_used": sm_used,
        "quality_ratio": round(quality, 3),
        "promoted_to_used_ratio": f"{sm_used}/{sm_count}",
    }


# ── Quality feedback ──────────────────────────────────────────────────────────
def quality_feedback() -> dict:
    """AC-4.6: Measure quality — promoted that got used vs those that did not."""
    conn = _connect()
    cur = conn.execute(
        "SELECT id, text, dome, quality_score, access_count FROM semantic "
        "WHERE tombstone IS NULL ORDER BY access_count DESC LIMIT 20")
    used = [dict(r) for r in cur.fetchall()]

    cur = conn.execute(
        "SELECT id, text, dome, quality_score, access_count FROM semantic "
        "WHERE tombstone IS NULL AND access_count = 0 ORDER BY consolidated_at DESC LIMIT 20")
    unused = [dict(r) for r in cur.fetchall()]

    total = conn.execute(
        "SELECT COUNT(*) as c FROM semantic WHERE tombstone IS NULL").fetchone()["c"]
    used_count = conn.execute(
        "SELECT COUNT(*) as c FROM semantic WHERE tombstone IS NULL AND access_count > 0"
    ).fetchone()["c"]
    conn.close()

    return {
        "semantic_total": total,
        "used": used_count,
        "unused": total - used_count,
        "quality_ratio": round(used_count / total, 3) if total > 0 else 0,
        "top_used": used[:5],
        "never_used": len(unused),
    }


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="SE-268 Two-Speed Memory")
    sub = p.add_subparsers(dest="cmd")

    add_p = sub.add_parser("add")
    add_p.add_argument("--text", required=True)
    add_p.add_argument("--store", default="episodic", choices=["episodic", "semantic"])
    add_p.add_argument("--dome", default="default")
    add_p.add_argument("--occurred", default=None)
    add_p.add_argument("--value", type=float, default=0.0)

    qp = sub.add_parser("query")
    qp.add_argument("--dome", default=None)
    qp.add_argument("--store", default="semantic", choices=["episodic", "semantic"])
    qp.add_argument("--limit", type=int, default=20)

    cp = sub.add_parser("consolidate")
    cp.add_argument("--dome", default=None)
    cp.add_argument("--min-recurrence", type=int, default=2)
    cp.add_argument("--min-value", type=float, default=0.3)
    cp.add_argument("--dry-run", action="store_true")

    sub.add_parser("stats")
    sub.add_parser("quality")

    args = p.parse_args()

    if args.cmd == "add":
        result = add(args.text, args.store, args.dome, args.occurred, args.value)
        print(json.dumps(result, indent=2))
    elif args.cmd == "query":
        rows = query(args.dome, args.store, args.limit)
        print(json.dumps(rows, indent=2, ensure_ascii=False))
        print(f"results: {len(rows)}", file=sys.stderr)
    elif args.cmd == "consolidate":
        result = consolidate(args.dome, args.min_recurrence, args.min_value, args.dry_run)
        print(json.dumps(result, indent=2))
    elif args.cmd == "stats":
        print(json.dumps(stats(), indent=2))
    elif args.cmd == "quality":
        print(json.dumps(quality_feedback(), indent=2))
    else:
        p.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
