#!/usr/bin/env python3
"""Context Optimization Gate - PreToolUse logic for CLAUDE.md writes.

Implements SPEC-CONTEXT-OPT-GATE section 5.

Reads tool_input JSON from stdin (Edit|Write) and decides:
  exit 0 -> allow
  exit 2 -> BLOCK (only in enforcing mode + status='alert')

In dry-run mode (prerequisites section 0 not met), always exit 0 with logging.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def usage_db() -> Path:
    return Path.home() / ".savia/usage.db"


def snapshot_dir() -> Path:
    d = Path.home() / ".savia/context-opt-snapshots"
    d.mkdir(parents=True, exist_ok=True)
    return d


def audit_log() -> Path:
    workspace = os.environ.get("SAVIA_WORKSPACE_DIR") or os.environ.get(
        "CLAUDE_PROJECT_DIR") or os.environ.get("OPENCODE_PROJECT_DIR") or os.getcwd()
    p = Path(workspace) / "output/context-opt-audit.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


PREREQ_MIN_TURNS = 1000
PREREQ_WINDOW_DAYS = 14


SCHEMA = """
CREATE TABLE IF NOT EXISTS context_baselines (
  file_path TEXT PRIMARY KEY,
  file_sha256 TEXT NOT NULL,
  baseline_started_at TEXT NOT NULL,
  baseline_window_days INTEGER NOT NULL DEFAULT 14,
  cache_hit_rate_baseline REAL,
  cache_hit_rate_d7 REAL,
  cache_hit_rate_d14 REAL,
  delta_d7_pp REAL,
  delta_d14_pp REAL,
  status TEXT NOT NULL CHECK (status IN ('baseline_pending','baseline_ready','measuring','alert','reverted')),
  snapshot_path TEXT,
  notes TEXT,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_context_baselines_status ON context_baselines(status);
"""


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    conn.commit()


_PATTERN = re.compile(r"(^|/)(CLAUDE\.md|projects/[^/]+/CLAUDE\.md)$", re.IGNORECASE)


def is_monitored(file_path: str, workspace: Path) -> bool:
    try:
        p = Path(file_path).resolve()
        rel = p.relative_to(workspace.resolve())
    except (ValueError, OSError):
        return False
    return bool(_PATTERN.search(str(rel).replace("\\", "/")))


def prereqs_met(conn: sqlite3.Connection) -> bool:
    try:
        cutoff_ms = int((time.time() - PREREQ_WINDOW_DAYS * 86400) * 1000)
        row = conn.execute(
            "SELECT COUNT(*) FROM turns WHERE ts_ms >= ?", (cutoff_ms,)
        ).fetchone()
        return bool(row and row[0] >= PREREQ_MIN_TURNS)
    except sqlite3.Error:
        return False


def log_event(event: dict) -> None:
    event = {"ts": datetime.now(timezone.utc).isoformat(), **event}
    try:
        with audit_log().open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event, ensure_ascii=False) + "\n")
    except OSError:
        pass


def take_snapshot(file_path: Path):
    if not file_path.exists():
        return None, None
    data = file_path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    dest = snapshot_dir() / f"{sha}.md"
    if not dest.exists():
        dest.write_bytes(data)
    return sha, dest


def warn(msg: str) -> None:
    sys.stderr.write(f"[context-opt-gate] {msg}\n")


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    tool_input = payload.get("tool_input") or payload.get("input") or payload
    file_path = (
        tool_input.get("file_path")
        or tool_input.get("path")
        or tool_input.get("filePath")
        or ""
    )
    if not file_path:
        return 0

    workspace_env = (
        os.environ.get("SAVIA_WORKSPACE_DIR")
        or os.environ.get("CLAUDE_PROJECT_DIR")
        or os.environ.get("OPENCODE_PROJECT_DIR")
        or os.getcwd()
    )
    workspace = Path(workspace_env)

    if not is_monitored(file_path, workspace):
        return 0

    if os.environ.get("SAVIA_CONTEXT_OPT_BYPASS") == "1":
        log_event({
            "event": "bypass",
            "file_path": file_path,
            "reason": os.environ.get("BYPASS_REASON", ""),
        })
        return 0

    db = usage_db()
    if not db.exists():
        warn("usage.db not found - dry-run")
        log_event({"event": "dry_run", "reason": "no_usage_db", "file_path": file_path})
        return 0

    try:
        conn = sqlite3.connect(str(db))
        conn.row_factory = sqlite3.Row
        ensure_schema(conn)
    except sqlite3.Error as exc:
        warn(f"usage.db open failed: {exc} - dry-run")
        log_event({"event": "dry_run", "reason": "db_open_failed", "error": str(exc)})
        return 0

    enforcing = prereqs_met(conn)

    if not enforcing:
        log_event({
            "event": "dry_run",
            "reason": "prereqs_not_met",
            "file_path": file_path,
        })
        warn(
            f"dry-run: prerequisites not met (<{PREREQ_MIN_TURNS} turns in "
            f"{PREREQ_WINDOW_DAYS}d). Edit allowed without enforcement."
        )
        try:
            sha, dest = take_snapshot(Path(file_path))
            if sha:
                log_event({"event": "snapshot", "file_path": file_path, "sha256": sha})
        except OSError:
            pass
        conn.close()
        return 0

    row = conn.execute(
        "SELECT * FROM context_baselines WHERE file_path = ?", (file_path,)
    ).fetchone()

    if row is None:
        warn(
            f"No baseline for {file_path}. Run "
            f"`/context-opt-baseline {file_path}` to enable monitoring."
        )
        log_event({"event": "no_baseline", "file_path": file_path})
        conn.close()
        return 0

    if row["status"] == "alert":
        warn(
            f"BLOCKED: {file_path} is in ALERT state "
            f"(delta_d7={row['delta_d7_pp']}pp)."
        )
        log_event({"event": "blocked", "file_path": file_path, "status": "alert"})
        conn.close()
        return 2

    try:
        sha, dest = take_snapshot(Path(file_path))
        if sha:
            conn.execute(
                "UPDATE context_baselines SET file_sha256=?, snapshot_path=?, "
                "updated_at=? WHERE file_path=?",
                (sha, str(dest), datetime.now(timezone.utc).isoformat(), file_path),
            )
            conn.commit()
            log_event({"event": "snapshot", "file_path": file_path, "sha256": sha})
    except OSError as exc:
        warn(f"snapshot failed: {exc}")

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
