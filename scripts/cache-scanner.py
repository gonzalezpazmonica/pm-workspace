#!/usr/bin/env python3
"""Cache Scanner — read-only incremental sync from opencode.db to usage.db.

Implements SPEC-CACHE-HIT-TRACKING v2 (2026-05-13).

Source : ~/.local/share/opencode/opencode.db   (OpenCode's own SQLite, RO)
Target : ~/.savia/usage.db                     (aggregated mirror, indexed)

Usage:
  python3 scripts/cache-scanner.py
  python3 scripts/cache-scanner.py --force-full
  python3 scripts/cache-scanner.py --db /tmp/test.db --source /path/to/oc.db
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

SCHEMA_VERSION = 1

DDL = [
    """CREATE TABLE IF NOT EXISTS turns (
        message_id   TEXT PRIMARY KEY,
        session_id   TEXT NOT NULL,
        project_id   TEXT,
        directory    TEXT,
        ts           INTEGER NOT NULL,
        agent        TEXT,
        mode         TEXT,
        model        TEXT,
        provider     TEXT,
        input        INTEGER NOT NULL DEFAULT 0,
        output       INTEGER NOT NULL DEFAULT 0,
        cache_read   INTEGER NOT NULL DEFAULT 0,
        cache_write  INTEGER NOT NULL DEFAULT 0,
        reasoning    INTEGER NOT NULL DEFAULT 0,
        cost         REAL NOT NULL DEFAULT 0
    )""",
    "CREATE INDEX IF NOT EXISTS idx_turns_ts        ON turns(ts)",
    "CREATE INDEX IF NOT EXISTS idx_turns_session   ON turns(session_id)",
    "CREATE INDEX IF NOT EXISTS idx_turns_agent     ON turns(agent)",
    "CREATE INDEX IF NOT EXISTS idx_turns_model     ON turns(model)",
    "CREATE INDEX IF NOT EXISTS idx_turns_directory ON turns(directory)",
    """CREATE TABLE IF NOT EXISTS sessions (
        id           TEXT PRIMARY KEY,
        project_id   TEXT,
        directory    TEXT,
        title        TEXT,
        agent        TEXT,
        model        TEXT,
        started_at   INTEGER NOT NULL,
        updated_at   INTEGER NOT NULL
    )""",
    "CREATE INDEX IF NOT EXISTS idx_sessions_directory ON sessions(directory)",
    """CREATE TABLE IF NOT EXISTS scan_state (
        source           TEXT PRIMARY KEY,
        last_message_ts  INTEGER NOT NULL,
        last_run_at      INTEGER NOT NULL,
        messages_seen    INTEGER NOT NULL DEFAULT 0
    )""",
]


def default_source() -> Path:
    return Path.home() / ".local/share/opencode/opencode.db"


def default_target() -> Path:
    return Path.home() / ".savia/usage.db"


def init_target(dst: sqlite3.Connection) -> None:
    cur = dst.cursor()
    for stmt in DDL:
        cur.execute(stmt)
    cur.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    dst.commit()


def _extract_ts(time_field) -> int:
    """OpenCode stores time either as int epoch_ms or as {'created': ...}."""
    if isinstance(time_field, dict):
        return int(time_field.get("created") or 0)
    if isinstance(time_field, (int, float)):
        return int(time_field)
    return 0


def scan(source: Path, target: Path, force_full: bool = False) -> dict:
    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        sys.exit(2)

    target.parent.mkdir(parents=True, exist_ok=True)

    src_uri = f"file:{source}?mode=ro"
    src = sqlite3.connect(src_uri, uri=True)
    dst = sqlite3.connect(target)

    try:
        init_target(dst)

        if force_full:
            last_ts = 0
        else:
            row = dst.execute(
                "SELECT last_message_ts FROM scan_state WHERE source='opencode'"
            ).fetchone()
            last_ts = row[0] if row else 0

        # 1) Sync sessions (idempotent INSERT OR REPLACE)
        sessions_synced = 0
        for s in src.execute(
            "SELECT id, project_id, directory, title, agent, model, "
            "time_created, time_updated FROM session"
        ):
            dst.execute(
                "INSERT OR REPLACE INTO sessions "
                "(id, project_id, directory, title, agent, model, started_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                s,
            )
            sessions_synced += 1

        # 2) Sync new assistant turns
        inserted = 0
        max_ts = last_ts
        cur = src.execute(
            """SELECT m.id, m.session_id, s.project_id, s.directory,
                      m.time_updated, m.data
               FROM message m
               JOIN session s ON m.session_id = s.id
               WHERE m.time_updated > ?""",
            (last_ts,),
        )
        for mid, sid, pid, dirpath, t_upd, blob in cur:
            try:
                j = json.loads(blob) if blob else {}
            except (json.JSONDecodeError, TypeError):
                continue
            if j.get("role") != "assistant":
                continue
            tok = j.get("tokens") or {}
            cache = tok.get("cache") or {}
            # Prefer message.data.time.created when present, fallback to time_updated
            ts = _extract_ts(j.get("time")) or int(t_upd or 0)
            dst.execute(
                """INSERT OR REPLACE INTO turns
                   (message_id, session_id, project_id, directory, ts,
                    agent, mode, model, provider,
                    input, output, cache_read, cache_write, reasoning, cost)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    mid, sid, pid, dirpath, ts,
                    j.get("agent"), j.get("mode"),
                    j.get("modelID"), j.get("providerID"),
                    int(tok.get("input") or 0),
                    int(tok.get("output") or 0),
                    int(cache.get("read") or 0),
                    int(cache.get("write") or 0),
                    int(tok.get("reasoning") or 0),
                    float(j.get("cost") or 0),
                ),
            )
            inserted += 1
            if t_upd and t_upd > max_ts:
                max_ts = t_upd

        # 3) Persist scan state (accumulate messages_seen)
        prev = dst.execute(
            "SELECT messages_seen FROM scan_state WHERE source='opencode'"
        ).fetchone()
        prev_seen = prev[0] if prev else 0
        dst.execute(
            "INSERT OR REPLACE INTO scan_state "
            "(source, last_message_ts, last_run_at, messages_seen) "
            "VALUES ('opencode', ?, ?, ?)",
            (max_ts, int(time.time() * 1000), prev_seen + inserted),
        )
        dst.commit()

        return {
            "sessions_synced": sessions_synced,
            "turns_inserted": inserted,
            "last_message_ts": max_ts,
            "target": str(target),
        }
    finally:
        src.close()
        dst.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="OpenCode → usage.db incremental scanner")
    ap.add_argument("--source", type=Path, default=default_source(),
                    help="Path to opencode.db (default: ~/.local/share/opencode/opencode.db)")
    ap.add_argument("--db", type=Path, default=default_target(),
                    help="Path to aggregated usage.db (default: ~/.savia/usage.db)")
    ap.add_argument("--force-full", action="store_true",
                    help="Ignore scan_state and reprocess all messages")
    ap.add_argument("--quiet", action="store_true", help="Suppress summary output")
    args = ap.parse_args()

    t0 = time.time()
    result = scan(args.source, args.db, force_full=args.force_full)
    elapsed = time.time() - t0

    if not args.quiet:
        print(f"Sessions synced : {result['sessions_synced']}")
        print(f"Turns inserted  : {result['turns_inserted']}")
        print(f"Last message ts : {result['last_message_ts']}")
        print(f"Target          : {result['target']}")
        print(f"Elapsed         : {elapsed:.2f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
