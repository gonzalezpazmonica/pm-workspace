#!/usr/bin/env python3
"""_router_extract_helper.py — SPEC-163 internal helper.

Reads hook stdin JSON and extracts {intent, command, has_code_change, estimated_tokens}.
Prints single JSON line to stdout. Always exits 0 (fail-soft).
"""
from __future__ import annotations
import json
import re
import sys


def main() -> None:
    raw = sys.stdin.read().strip()
    try:
        d = json.loads(raw) if raw else {}
    except Exception:
        d = {}

    tool_input = d.get("tool_input", d.get("input", d))
    if not isinstance(tool_input, dict):
        tool_input = {}

    tool_name = d.get("tool_name", d.get("tool", ""))

    intent = (
        tool_input.get("description", "")
        or tool_input.get("prompt", "")
        or tool_input.get("task", "")
        or d.get("intent", "")
        or ""
    )

    command = tool_input.get("command", d.get("command", ""))
    if command.startswith("/"):
        command = command[1:]

    has_code_change = tool_name in ("Edit", "Write", "MultiEdit") or bool(
        re.search(r"\b(edit|write|create file|modify|patch)\b", intent, re.I)
    )

    raw_len = len(intent) + len(str(tool_input))
    estimated_tokens = max(0, raw_len // 4)

    result = {
        "intent": intent[:500],
        "command": command,
        "has_code_change": has_code_change,
        "estimated_tokens": estimated_tokens,
    }
    print(json.dumps(result))


if __name__ == "__main__":
    main()
