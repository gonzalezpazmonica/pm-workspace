#!/usr/bin/env python3
"""_router_telemetry_helper.py — SPEC-163 internal helper.

Reads extracted payload + classification from stdin (separated by \x1e record separator),
plus CLI args for ts/turn_id/session_id/router_mode.
Prints single JSONL telemetry entry. Always exits 0 (fail-soft).

Usage: python3 _router_telemetry_helper.py <ts> <turn_id> <session_id> <router_mode> <<< "<extracted>\x1e<classification>"
"""
from __future__ import annotations
import hashlib
import json
import sys


def main() -> None:
    args = sys.argv[1:]
    ts = args[0] if len(args) > 0 else ""
    turn_id = args[1] if len(args) > 1 else ""
    session_id = args[2] if len(args) > 2 else "unknown"
    router_mode = args[3] if len(args) > 3 else "shadow"

    raw = sys.stdin.read()
    parts = raw.split("\x1e", 1)
    extracted_raw = parts[0].strip() if parts else ""
    classification_raw = parts[1].strip() if len(parts) > 1 else ""

    try:
        extracted = json.loads(extracted_raw) if extracted_raw else {}
    except Exception:
        extracted = {}

    try:
        cls = json.loads(classification_raw) if classification_raw else {}
    except Exception:
        cls = {}

    intent = extracted.get("intent", "")
    intent_hash = hashlib.md5(intent.encode("utf-8", errors="replace")).hexdigest()[:8]

    entry = {
        "ts": ts,
        "turn_id": turn_id,
        "session_id": session_id,
        "intent_hash": intent_hash,
        "detected_mode": cls.get("mode", "mode2"),
        "command": extracted.get("command", ""),
        "confidence": cls.get("confidence", 0.0),
        "tokens_estimate": int(extracted.get("estimated_tokens", 0)),
        "reason": cls.get("reason", ""),
        "complexity_tier": cls.get("complexity_tier", "auto"),
        "mode_enforced": router_mode == "enforce",
    }
    print(json.dumps(entry, separators=(",", ":")))


if __name__ == "__main__":
    main()
