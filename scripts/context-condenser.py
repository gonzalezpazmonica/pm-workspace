#!/usr/bin/env python3
"""
context-condenser.py — SE-200: rolling window context compression
Inspired by OpenHands LLMSummarizingCondenser pattern
Ref: docs/propuestas/SE-200-llm-condenser.md

Reads output/session-action-log.jsonl, applies rolling window:
  head (KEEP_HEAD lines) + tail (KEEP_TAIL lines)
The middle is summarised with a Condensation entry.
Output written to output/condensations-YYYYMMDD.jsonl
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone


def parse_args():
    parser = argparse.ArgumentParser(
        description="SE-200 context condenser: rolling window compression of session logs"
    )
    parser.add_argument("--log", required=True, help="Path to session-action-log.jsonl")
    parser.add_argument("--max-size", type=int, default=120, help="Max events before condensation")
    parser.add_argument("--keep-head", type=int, default=4, help="Number of head events to preserve")
    parser.add_argument("--keep-tail", type=int, default=60, help="Number of tail events to preserve")
    parser.add_argument("--stats", action="store_true", help="Print stats only, do not condense")
    return parser.parse_args()


def read_jsonl(path):
    """Read a .jsonl file; returns list of raw lines (preserves non-JSON lines too)."""
    with open(path, "r", encoding="utf-8") as f:
        return [line.rstrip("\n") for line in f if line.strip()]


def build_condensation_entry(middle_lines, session_log_path):
    """Build a single Condensation entry summarising the compressed middle segment."""
    compressed_count = len(middle_lines)
    # Build a brief textual summary from types/keys found in the middle
    type_counts = {}
    for line in middle_lines:
        try:
            obj = json.loads(line)
            t = obj.get("type", obj.get("action", "unknown"))
        except (json.JSONDecodeError, AttributeError):
            t = "raw"
        type_counts[t] = type_counts.get(t, 0) + 1

    summary_parts = [f"{v}x {k}" for k, v in sorted(type_counts.items(), key=lambda x: -x[1])]
    summary = f"{compressed_count} events compressed: " + ", ".join(summary_parts) if summary_parts else f"{compressed_count} events compressed"

    session_id = os.path.splitext(os.path.basename(session_log_path))[0]

    return json.dumps({
        "type": "condensation",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "session_id": session_id,
        "events_total": compressed_count,
        "events_condensed": compressed_count,
        "summary": summary,
        "spec": "SE-200",
    })


def output_condensation_path(base_dir):
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
    return os.path.join(base_dir, f"condensations-{date_str}.jsonl")


def condense(args):
    log_path = args.log

    if not os.path.exists(log_path):
        print(f"context-condenser: log not found at {log_path}", file=sys.stderr)
        sys.exit(0)

    lines = read_jsonl(log_path)
    total = len(lines)

    if args.stats:
        middle = max(0, total - args.keep_head - args.keep_tail)
        print(f"context-condenser stats: events={total} max_size={args.max_size} keep_head={args.keep_head} keep_tail={args.keep_tail}")
        if total > args.max_size:
            print(f"  would compress: middle={middle} events")
        else:
            print("  no compression needed")
        return

    if total <= args.max_size:
        print(f"context-condenser: {total} events <= {args.max_size} threshold — no condensation needed")
        return

    # Split into head / middle / tail
    head_end = min(args.keep_head, total)
    tail_start = max(total - args.keep_tail, head_end)

    head = lines[:head_end]
    middle = lines[head_end:tail_start]
    tail = lines[tail_start:]

    if not middle:
        print("context-condenser: no middle segment to compress — skipping")
        return

    condensation_entry = build_condensation_entry(middle, log_path)

    # Assemble condensed result: head + condensation_entry + tail
    condensed_lines = head + [condensation_entry] + tail

    # Write condensation entry to output/condensations-YYYYMMDD.jsonl
    output_dir = os.path.dirname(log_path)
    condensation_out = output_condensation_path(output_dir)

    with open(condensation_out, "a", encoding="utf-8") as f:
        f.write(condensation_entry + "\n")

    # Rewrite the session log with the condensed version
    with open(log_path, "w", encoding="utf-8") as f:
        for line in condensed_lines:
            f.write(line + "\n")

    compressed_count = len(middle)
    new_total = len(condensed_lines)
    print(
        f"context-condenser: condensed {total} → {new_total} events "
        f"(compressed {compressed_count} middle events). "
        f"Condensation entry written to {condensation_out}"
    )


if __name__ == "__main__":
    args = parse_args()
    condense(args)
