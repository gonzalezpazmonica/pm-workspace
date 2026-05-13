#!/usr/bin/env python3
"""Generate tests/fixtures/opencode-mini.db — synthetic OpenCode DB for BATS.

Schema mirrors real opencode.db:
  - project(id, worktree, vcs, name)
  - session(id, project_id, directory, title, agent, model, time_created, time_updated)
  - message(id, session_id, time_created, time_updated, data)  -- data = JSON blob

Content shape (50 messages total across 3 sessions):
  - 30 role=assistant (mix of agents/models/cache patterns)
  - 18 role=user
  - 1 role=assistant with INVALID JSON blob (tolerance test)
  - 1 role=tool   (must be skipped)

Run:
  python3 tests/fixtures/generate-opencode-mini.py
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

OUT = Path(__file__).parent / "opencode-mini.db"

DDL = [
    """CREATE TABLE project (
        id TEXT PRIMARY KEY,
        worktree TEXT,
        vcs TEXT,
        name TEXT
    )""",
    """CREATE TABLE session (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        directory TEXT,
        title TEXT,
        agent TEXT,
        model TEXT,
        time_created INTEGER,
        time_updated INTEGER
    )""",
    """CREATE TABLE message (
        id TEXT PRIMARY KEY,
        session_id TEXT,
        time_created INTEGER,
        time_updated INTEGER,
        data TEXT
    )""",
]

PROJECTS = [
    ("prj_savia", "/home/test/savia", "git", "savia"),
    ("prj_trazabios", "/home/test/trazabios", "git", "trazabios"),
]

SESSIONS = [
    # (id, project_id, directory, title, agent, model, time_created, time_updated)
    ("ses_a", "prj_savia",     "/home/test/savia",     "Refactor scanner",  "general",        "claude-sonnet-4-6", 1_700_000_000_000, 1_700_000_100_000),
    ("ses_b", "prj_savia",     "/home/test/savia",     "Architect review",  "architect",      "claude-opus-4-7",   1_700_000_200_000, 1_700_000_300_000),
    ("ses_c", "prj_trazabios", "/home/test/trazabios", "Weekly report",     "azure-operator", "claude-haiku-4-5",  1_700_000_400_000, 1_700_000_500_000),
]


def make_assistant(idx: int, session_id: str, ts: int, agent: str, model: str,
                   cache_read: int, cache_write: int, cost: float) -> dict:
    return {
        "id": f"msg_a_{idx}",
        "session_id": session_id,
        "time_created": ts,
        "time_updated": ts,
        "data": json.dumps({
            "role": "assistant",
            "agent": agent,
            "modelID": model,
            "providerID": "anthropic",
            "mode": "build",
            "time": {"created": ts},
            "tokens": {
                "input": 1200,
                "output": 450,
                "reasoning": 0,
                "cache": {"read": cache_read, "write": cache_write},
            },
            "cost": cost,
        }),
    }


def make_user(idx: int, session_id: str, ts: int) -> dict:
    return {
        "id": f"msg_u_{idx}",
        "session_id": session_id,
        "time_created": ts,
        "time_updated": ts,
        "data": json.dumps({"role": "user", "time": {"created": ts}}),
    }


def make_tool(idx: int, session_id: str, ts: int) -> dict:
    return {
        "id": f"msg_t_{idx}",
        "session_id": session_id,
        "time_created": ts,
        "time_updated": ts,
        "data": json.dumps({"role": "tool", "time": {"created": ts}}),
    }


def make_invalid(session_id: str, ts: int) -> dict:
    return {
        "id": "msg_invalid",
        "session_id": session_id,
        "time_created": ts,
        "time_updated": ts,
        "data": "{not valid json,,",
    }


def build_messages() -> list[dict]:
    msgs: list[dict] = []
    ts = 1_700_000_010_000

    # Session A: 12 assistant + 8 user (general/sonnet, mostly hit)
    for i in range(12):
        msgs.append(make_assistant(
            idx=i, session_id="ses_a", ts=ts,
            agent="general", model="claude-sonnet-4-6",
            cache_read=8000 + i * 100,
            cache_write=400,
            cost=0.012,
        ))
        ts += 1000
    for i in range(8):
        msgs.append(make_user(i, "ses_a", ts)); ts += 500

    # Session B: 10 assistant + 6 user (architect/opus, lower hit)
    ts = 1_700_000_210_000
    for i in range(10):
        msgs.append(make_assistant(
            idx=100 + i, session_id="ses_b", ts=ts,
            agent="architect", model="claude-opus-4-7",
            cache_read=3000,
            cache_write=2000,
            cost=0.085,
        ))
        ts += 1000
    for i in range(6):
        msgs.append(make_user(100 + i, "ses_b", ts)); ts += 500

    # Session C: 8 assistant + 4 user (azure-operator/haiku, perfect hit)
    ts = 1_700_000_410_000
    for i in range(8):
        msgs.append(make_assistant(
            idx=200 + i, session_id="ses_c", ts=ts,
            agent="azure-operator", model="claude-haiku-4-5",
            cache_read=12000,
            cache_write=100,
            cost=0.002,
        ))
        ts += 1000
    for i in range(4):
        msgs.append(make_user(200 + i, "ses_c", ts)); ts += 500

    # Edge cases
    msgs.append(make_invalid("ses_a", 1_700_000_099_000))  # JSON inválido
    msgs.append(make_tool(0, "ses_c", 1_700_000_499_000))   # role=tool

    return msgs


def main() -> None:
    if OUT.exists():
        OUT.unlink()
    conn = sqlite3.connect(OUT)
    cur = conn.cursor()
    for stmt in DDL:
        cur.execute(stmt)

    cur.executemany(
        "INSERT INTO project (id, worktree, vcs, name) VALUES (?,?,?,?)",
        PROJECTS,
    )
    cur.executemany(
        "INSERT INTO session (id, project_id, directory, title, agent, model, "
        "time_created, time_updated) VALUES (?,?,?,?,?,?,?,?)",
        SESSIONS,
    )

    msgs = build_messages()
    rows = [(m["id"], m["session_id"], m["time_created"], m["time_updated"], m["data"])
            for m in msgs]
    cur.executemany(
        "INSERT INTO message (id, session_id, time_created, time_updated, data) "
        "VALUES (?,?,?,?,?)",
        rows,
    )
    conn.commit()

    # Sanity counts
    assistant_count = sum(1 for m in msgs if '"role": "assistant"' in m["data"])
    print(f"OK fixture written: {OUT}")
    print(f"  projects : {len(PROJECTS)}")
    print(f"  sessions : {len(SESSIONS)}")
    print(f"  messages : {len(msgs)} (assistant valid: {assistant_count - 0}, includes 1 invalid JSON, 1 tool)")
    conn.close()


if __name__ == "__main__":
    main()
