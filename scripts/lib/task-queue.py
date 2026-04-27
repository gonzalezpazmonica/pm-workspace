#!/usr/bin/env python3
"""task-queue.py — SE-075 Slice 1.

Serial-execution job queue with SQLite persistence and auto-recovery of
stale (running) jobs at startup. Re-implementation of the pattern in
`jamiepine/voicebox` `backend/services/task_queue.py` (MIT license, ©
voicebox contributors); this is a clean-room rewrite — no source code is
copied — adapted to bash + python rather than the original FastAPI runtime.

Attribution: pattern from voicebox/backend/services/task_queue.py (MIT).

Storage:
  output/task-queue/<queue_name>.sqlite

Usage (CLI):
  python3 scripts/lib/task-queue.py enqueue <queue> <command> [--payload JSON]
  python3 scripts/lib/task-queue.py dequeue <queue> [--worker WORKER]
  python3 scripts/lib/task-queue.py complete <queue> <job_id> [--ok|--fail MSG]
  python3 scripts/lib/task-queue.py status <queue> [--json]
  python3 scripts/lib/task-queue.py recover <queue>
  python3 scripts/lib/task-queue.py drain <queue>           # delete completed jobs

Programmatic (sourced from other Python):
  from task_queue import TaskQueue
  q = TaskQueue("se074-orchestrator")
  job_id = q.enqueue("run-spec", payload={"spec": "SE-073"})
  job = q.dequeue(worker="worker-1")
  q.complete(job["id"], ok=True)

Reference: SE-075 Slice 1 (docs/propuestas/SE-075-voicebox-adoption.md)
Reference: docs/rules/domain/autonomous-safety.md
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

ROOT = Path(os.environ.get("PROJECT_ROOT", str(Path(__file__).resolve().parents[2])))
DEFAULT_QUEUE_DIR = ROOT / "output" / "task-queue"
STALE_HEARTBEAT_SEC = int(os.environ.get("TASK_QUEUE_STALE_SEC", "300"))


def _queue_path(queue_name: str, queue_dir: Path = DEFAULT_QUEUE_DIR) -> Path:
    queue_dir.mkdir(parents=True, exist_ok=True)
    safe = "".join(c for c in queue_name if c.isalnum() or c in "._-")
    if not safe:
        raise ValueError(f"invalid queue name: {queue_name!r}")
    return queue_dir / f"{safe}.sqlite"


_SCHEMA = """
CREATE TABLE IF NOT EXISTS jobs (
    id          TEXT PRIMARY KEY,
    queue       TEXT NOT NULL,
    command     TEXT NOT NULL,
    payload     TEXT,
    status      TEXT NOT NULL DEFAULT 'pending',  -- pending | running | done | failed
    worker      TEXT,
    error       TEXT,
    created_at  REAL NOT NULL,
    started_at  REAL,
    finished_at REAL,
    heartbeat   REAL
);
CREATE INDEX IF NOT EXISTS jobs_queue_status_created
    ON jobs (queue, status, created_at);
"""


class TaskQueue:
    def __init__(self, name: str, queue_dir: Path = DEFAULT_QUEUE_DIR):
        self.name = name
        self.path = _queue_path(name, queue_dir)
        self._init_schema()
        self.recover()

    @contextmanager
    def _conn(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(str(self.path), timeout=10, isolation_level=None)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        try:
            yield conn
        finally:
            conn.close()

    def _init_schema(self) -> None:
        with self._conn() as conn:
            conn.executescript(_SCHEMA)

    def enqueue(self, command: str, payload: Any | None = None) -> str:
        job_id = uuid.uuid4().hex
        now = time.time()
        with self._conn() as conn:
            conn.execute(
                "INSERT INTO jobs (id, queue, command, payload, created_at) VALUES (?, ?, ?, ?, ?)",
                (job_id, self.name, command, json.dumps(payload) if payload is not None else None, now),
            )
        return job_id

    def dequeue(self, worker: str = "default") -> dict | None:
        """Atomically claim the oldest pending job for this worker."""
        now = time.time()
        with self._conn() as conn:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT id, command, payload FROM jobs "
                "WHERE queue=? AND status='pending' ORDER BY created_at LIMIT 1",
                (self.name,),
            ).fetchone()
            if row is None:
                conn.execute("COMMIT")
                return None
            conn.execute(
                "UPDATE jobs SET status='running', worker=?, started_at=?, heartbeat=? WHERE id=?",
                (worker, now, now, row["id"]),
            )
            conn.execute("COMMIT")
            return {"id": row["id"], "command": row["command"],
                    "payload": json.loads(row["payload"]) if row["payload"] else None}

    def heartbeat(self, job_id: str) -> None:
        with self._conn() as conn:
            conn.execute("UPDATE jobs SET heartbeat=? WHERE id=? AND status='running'", (time.time(), job_id))

    def complete(self, job_id: str, ok: bool = True, error: str | None = None) -> None:
        status = "done" if ok else "failed"
        now = time.time()
        with self._conn() as conn:
            conn.execute(
                "UPDATE jobs SET status=?, finished_at=?, error=? WHERE id=?",
                (status, now, error, job_id),
            )

    def status(self) -> dict:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT status, COUNT(*) AS n FROM jobs WHERE queue=? GROUP BY status",
                (self.name,),
            ).fetchall()
        out: dict[str, int] = {"pending": 0, "running": 0, "done": 0, "failed": 0}
        for r in rows:
            out[r["status"]] = r["n"]
        return out

    def recover(self) -> int:
        """Reset stale running jobs (heartbeat older than STALE_HEARTBEAT_SEC) to pending.

        Auto-runs at TaskQueue() construction to recover from worker crashes.
        Returns the number of jobs recovered.
        """
        cutoff = time.time() - STALE_HEARTBEAT_SEC
        with self._conn() as conn:
            cursor = conn.execute(
                "UPDATE jobs SET status='pending', worker=NULL, started_at=NULL, heartbeat=NULL "
                "WHERE queue=? AND status='running' AND (heartbeat IS NULL OR heartbeat < ?)",
                (self.name, cutoff),
            )
            return cursor.rowcount

    def drain(self) -> int:
        """Delete all completed (done|failed) jobs. Returns number deleted."""
        with self._conn() as conn:
            cursor = conn.execute(
                "DELETE FROM jobs WHERE queue=? AND status IN ('done','failed')", (self.name,)
            )
            return cursor.rowcount

    def list_jobs(self, status: str | None = None, limit: int = 50) -> list[dict]:
        with self._conn() as conn:
            if status:
                rows = conn.execute(
                    "SELECT * FROM jobs WHERE queue=? AND status=? ORDER BY created_at LIMIT ?",
                    (self.name, status, limit),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM jobs WHERE queue=? ORDER BY created_at LIMIT ?",
                    (self.name, limit),
                ).fetchall()
        return [dict(r) for r in rows]


def _cli() -> int:
    p = argparse.ArgumentParser(prog="task-queue.py")
    sp = p.add_subparsers(dest="cmd", required=True)

    e = sp.add_parser("enqueue"); e.add_argument("queue"); e.add_argument("command")
    e.add_argument("--payload", default=None)

    d = sp.add_parser("dequeue"); d.add_argument("queue"); d.add_argument("--worker", default="default")

    c = sp.add_parser("complete"); c.add_argument("queue"); c.add_argument("job_id")
    g = c.add_mutually_exclusive_group(required=True)
    g.add_argument("--ok", action="store_true")
    g.add_argument("--fail", metavar="MSG")

    s = sp.add_parser("status"); s.add_argument("queue"); s.add_argument("--json", action="store_true")
    r = sp.add_parser("recover"); r.add_argument("queue")
    dr = sp.add_parser("drain"); dr.add_argument("queue")
    li = sp.add_parser("list"); li.add_argument("queue"); li.add_argument("--status", default=None)
    li.add_argument("--limit", type=int, default=50)

    args = p.parse_args()
    try:
        q = TaskQueue(args.queue)
    except ValueError as ex:
        print(f"ERROR: {ex}", file=sys.stderr); return 2

    if args.cmd == "enqueue":
        payload = json.loads(args.payload) if args.payload else None
        print(q.enqueue(args.command, payload))
    elif args.cmd == "dequeue":
        job = q.dequeue(args.worker)
        if job is None: return 1
        print(json.dumps(job))
    elif args.cmd == "complete":
        if args.ok: q.complete(args.job_id, ok=True)
        else: q.complete(args.job_id, ok=False, error=args.fail)
        print("ok")
    elif args.cmd == "status":
        st = q.status()
        if args.json: print(json.dumps(st))
        else:
            for k, v in st.items(): print(f"  {k}: {v}")
    elif args.cmd == "recover":
        print(f"recovered={q.recover()}")
    elif args.cmd == "drain":
        print(f"deleted={q.drain()}")
    elif args.cmd == "list":
        for row in q.list_jobs(args.status, args.limit):
            print(json.dumps(row, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
