"""scripts/skill-usage-tracker.py — SPEC-SE-030 Skill Self-Improvement (Phase 1)

Registers each skill invocation in data/skill-invocations.jsonl.
Also reads output/router-decisions.jsonl for additional signals.

CLI:
    python3 skill-usage-tracker.py --skill SKILL_NAME --command COMMAND --session SESSION_ID

Appends: {ts, skill, command, session_id}
Rolling window: max 1000 entries (oldest trimmed automatically).
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

MAX_ENTRIES = 1000


def _load_jsonl(path: Path) -> list[dict]:
    records: list[dict] = []
    if not path.exists():
        return records
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return records


def track_invocation(
    skill: str,
    command: str,
    session_id: str,
    invocations_path: Path,
) -> None:
    """Append one invocation entry; trim to MAX_ENTRIES."""
    existing = _load_jsonl(invocations_path)

    entry = {
        "ts": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "skill": skill,
        "command": command,
        "session_id": session_id,
    }
    existing.append(entry)

    # Rolling window: keep only the last MAX_ENTRIES
    if len(existing) > MAX_ENTRIES:
        existing = existing[-MAX_ENTRIES:]

    invocations_path.parent.mkdir(parents=True, exist_ok=True)
    with invocations_path.open("w", encoding="utf-8") as fh:
        for rec in existing:
            fh.write(json.dumps(rec) + "\n")


def read_router_signals(router_path: Path) -> list[dict]:
    """Read output/router-decisions.jsonl for additional skill signals."""
    return _load_jsonl(router_path)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Track skill invocations for SE-030 pattern detection"
    )
    parser.add_argument("--skill", required=True, help="Skill name")
    parser.add_argument("--command", required=True, help="Command or trigger used")
    parser.add_argument("--session", required=True, help="Session identifier")
    parser.add_argument(
        "--invocations-file",
        default=None,
        help="Path to skill-invocations.jsonl (default: data/skill-invocations.jsonl)",
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root (default: .)",
    )
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    if args.invocations_file:
        inv_path = Path(args.invocations_file).resolve()
    else:
        inv_path = repo_root / "data" / "skill-invocations.jsonl"

    track_invocation(
        skill=args.skill,
        command=args.command,
        session_id=args.session,
        invocations_path=inv_path,
    )
    print(f"Tracked: skill={args.skill} command={args.command} session={args.session}")


if __name__ == "__main__":
    main()
