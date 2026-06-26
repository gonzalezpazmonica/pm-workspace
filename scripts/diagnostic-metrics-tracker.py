#!/usr/bin/env python3
"""diagnostic-metrics-tracker.py — SPEC-188 Phase 4 MVP

Tracks diagnostic quality metrics for the root-cause investigation process.
Append-only JSONL log + CLI for record / report / list.

Usage:
    # Record a new investigation entry
    python3 scripts/diagnostic-metrics-tracker.py \
        --record \
        --investigation-id INV-001 \
        --time-to-identify 45 \
        --confidence 0.85 \
        --correct true

    # Report aggregate statistics
    python3 scripts/diagnostic-metrics-tracker.py --report

    # List last N entries (default 10)
    python3 scripts/diagnostic-metrics-tracker.py --list [--n 5]

JSONL schema per entry:
    {
        "ts": "ISO-8601",
        "investigation_id": "INV-001",
        "time_to_identify_min": 45,
        "confidence_score": 0.85,
        "was_correct": true,
        "rework_needed": false
    }

Report output:
    {
        "total_investigations": N,
        "mean_confidence": 0.72,
        "accuracy_rate": 0.83,
        "mean_time_to_identify": 38.5,
        "rework_rate": 0.17
    }

Ref: SPEC-188 Phase 4 — docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_LOG_PATH = Path("output/diagnostic-metrics.jsonl")


def _resolve_log_path(path_str: str | None) -> Path:
    p = Path(path_str) if path_str else DEFAULT_LOG_PATH
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _parse_bool(value: str) -> bool:
    return value.lower() in {"true", "1", "yes", "y"}


def _load_entries(log_path: Path) -> list[dict]:
    if not log_path.exists():
        return []
    entries = []
    with log_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return entries


def cmd_record(args: argparse.Namespace, log_path: Path) -> int:
    entry: dict[str, Any] = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "investigation_id": args.investigation_id,
        "time_to_identify_min": args.time_to_identify,
        "confidence_score": float(args.confidence),
        "was_correct": _parse_bool(args.correct),
        "rework_needed": _parse_bool(args.rework) if args.rework else False,
    }
    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(json.dumps({"status": "recorded", "entry": entry}, indent=2))
    return 0


def cmd_report(log_path: Path) -> int:
    entries = _load_entries(log_path)
    if not entries:
        print(json.dumps({
            "total_investigations": 0,
            "mean_confidence": 0.0,
            "accuracy_rate": 0.0,
            "mean_time_to_identify": 0.0,
            "rework_rate": 0.0,
        }, indent=2))
        return 0

    n = len(entries)
    confidences = [e.get("confidence_score", 0.0) for e in entries]
    times = [e.get("time_to_identify_min", 0) for e in entries]
    correct_flags = [bool(e.get("was_correct", False)) for e in entries]
    rework_flags = [bool(e.get("rework_needed", False)) for e in entries]

    mean_conf = round(sum(confidences) / n, 4)
    accuracy = round(sum(correct_flags) / n, 4)
    mean_time = round(sum(times) / n, 2)
    rework_rate = round(sum(rework_flags) / n, 4)

    print(json.dumps({
        "total_investigations": n,
        "mean_confidence": mean_conf,
        "accuracy_rate": accuracy,
        "mean_time_to_identify": mean_time,
        "rework_rate": rework_rate,
    }, indent=2))
    return 0


def cmd_list(log_path: Path, n_entries: int) -> int:
    entries = _load_entries(log_path)
    recent = entries[-n_entries:] if n_entries > 0 else entries
    print(json.dumps(recent, indent=2, ensure_ascii=False))
    return 0


def build_cli() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Diagnostic metrics tracker for root-cause investigations (SPEC-188 P4)"
    )
    p.add_argument("--log", default=None, help="Path to JSONL log file")

    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("--record", action="store_true", help="Record a new entry")
    group.add_argument("--report", action="store_true", help="Print aggregate statistics")
    group.add_argument("--list", action="store_true", help="List last N entries")

    p.add_argument("--investigation-id", default="")
    p.add_argument("--time-to-identify", type=int, default=0)
    p.add_argument("--confidence", type=float, default=0.0)
    p.add_argument("--correct", default="false")
    p.add_argument("--rework", default="false")
    p.add_argument("--n", type=int, default=10, help="Number of entries for --list")
    return p


def main(argv=None) -> int:
    parser = build_cli()
    args = parser.parse_args(argv)
    log_path = _resolve_log_path(args.log)

    if args.record:
        if not args.investigation_id:
            print("ERROR: --investigation-id is required for --record", file=sys.stderr)
            return 1
        return cmd_record(args, log_path)
    elif args.report:
        return cmd_report(log_path)
    elif args.list:
        return cmd_list(log_path, args.n)

    return 0


if __name__ == "__main__":
    sys.exit(main())
