#!/usr/bin/env python3
"""scripts/pending-user-input.py — SPEC-076: PENDING_USER_INPUT Protocol

Manages "waiting for user input" state for autonomous agents.

DB: ~/.savia/zeroclaw/pending/{session-id}.json

Commands:
    --create --session SESSION_ID --question "text"
    --check  --session SESSION_ID        → exit 0 if answered, exit 1 if pending
    --resolve --session SESSION_ID --answer "text"
    --list                               → list all sessions with pending state
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


# ── Constants ─────────────────────────────────────────────────────────────────

PENDING_DIR_DEFAULT = Path.home() / ".savia" / "zeroclaw" / "pending"

REQUIRED_FIELDS = ("question", "ts", "session_id")


def get_pending_dir() -> Path:
    """Return the pending directory, honouring SAVIA_PENDING_DIR env override (for tests)."""
    override = os.environ.get("SAVIA_PENDING_DIR")
    if override:
        return Path(override)
    return PENDING_DIR_DEFAULT


# ── File helpers ──────────────────────────────────────────────────────────────

def _session_path(pending_dir: Path, session_id: str) -> Path:
    return pending_dir / f"{session_id}.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def _save(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_create(session_id: str, question: str) -> int:
    """Create (or overwrite) a pending-input record for session_id."""
    pending_dir = get_pending_dir()
    path = _session_path(pending_dir, session_id)
    data = {
        "session_id": session_id,
        "question": question,
        "ts": _now_iso(),
        "status": "waiting",
        "answer": None,
        "ts_resolved": None,
    }
    _save(path, data)
    print(f"Created pending input for session '{session_id}'")
    return 0


def cmd_check(session_id: str) -> int:
    """Exit 0 if answered, exit 1 if still waiting."""
    pending_dir = get_pending_dir()
    path = _session_path(pending_dir, session_id)

    if not path.exists():
        print(f"ERROR: No pending record for session '{session_id}'", file=sys.stderr)
        return 2

    data = _load(path)
    if data.get("answer") is not None and data.get("status") == "answered":
        print(f"ANSWERED: session '{session_id}' has a response")
        return 0
    else:
        print(f"PENDING: session '{session_id}' is still waiting")
        return 1


def cmd_resolve(session_id: str, answer: str) -> int:
    """Write the user's answer into the pending record."""
    pending_dir = get_pending_dir()
    path = _session_path(pending_dir, session_id)

    if not path.exists():
        print(
            f"ERROR: No pending record for session '{session_id}'. "
            "Create it first with --create.",
            file=sys.stderr,
        )
        return 1

    data = _load(path)
    data["answer"] = answer
    data["status"] = "answered"
    data["ts_resolved"] = _now_iso()
    _save(path, data)
    print(f"Resolved session '{session_id}'")
    return 0


def cmd_list() -> int:
    """List all sessions with their status."""
    pending_dir = get_pending_dir()

    if not pending_dir.exists():
        print("No pending sessions found (directory does not exist)")
        return 0

    records = sorted(pending_dir.glob("*.json"))
    if not records:
        print("No pending sessions found")
        return 0

    waiting = []
    answered = []

    for p in records:
        try:
            data = _load(p)
        except (json.JSONDecodeError, OSError):
            continue
        session = data.get("session_id", p.stem)
        status = data.get("status", "unknown")
        ts = data.get("ts", "?")
        question = data.get("question", "?")
        if status == "waiting":
            waiting.append((session, ts, question))
        else:
            answered.append((session, ts, question, data.get("ts_resolved", "?")))

    if waiting:
        print(f"WAITING ({len(waiting)}):")
        for session, ts, question in waiting:
            print(f"  [{session}] since {ts}: {question}")
    else:
        print("WAITING: none")

    if answered:
        print(f"ANSWERED ({len(answered)}):")
        for session, ts, question, ts_resolved in answered:
            print(f"  [{session}] resolved {ts_resolved}: {question}")

    return 0


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="pending-user-input.py",
        description="SPEC-076: PENDING_USER_INPUT — manage async agent input requests",
    )

    # Mutually exclusive top-level commands
    cmd_group = p.add_mutually_exclusive_group(required=True)
    cmd_group.add_argument(
        "--create",
        action="store_true",
        help="Create a new pending input record (requires --session and --question)",
    )
    cmd_group.add_argument(
        "--check",
        action="store_true",
        help="Check if a session has been answered (exit 0=yes, 1=waiting, 2=not found)",
    )
    cmd_group.add_argument(
        "--resolve",
        action="store_true",
        help="Write user answer into pending record (requires --session and --answer)",
    )
    cmd_group.add_argument(
        "--list",
        action="store_true",
        help="List all sessions with their status",
    )

    p.add_argument("--session", metavar="SESSION_ID", help="Session identifier")
    p.add_argument("--question", metavar="TEXT", help="Question to ask the user")
    p.add_argument("--answer", metavar="TEXT", help="User's answer to the question")
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list:
        return cmd_list()

    if args.create:
        if not args.session:
            parser.error("--create requires --session")
        if not args.question:
            parser.error("--create requires --question")
        return cmd_create(args.session, args.question)

    if args.check:
        if not args.session:
            parser.error("--check requires --session")
        return cmd_check(args.session)

    if args.resolve:
        if not args.session:
            parser.error("--resolve requires --session")
        if not args.answer:
            parser.error("--resolve requires --answer")
        return cmd_resolve(args.session, args.answer)

    return 0


if __name__ == "__main__":
    sys.exit(main())
