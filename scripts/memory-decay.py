#!/usr/bin/env python3
"""memory-decay.py — SE-270 S6: time-based confidence decay for memory entries.

Reads memory entries (JSONL format), applies exponential time decay to
confidence scores, applies reinforcement boost for recently-used entries,
and outputs updated entries.

Configurable decay rate and confidence threshold.

Usage:
  python3 scripts/memory-decay.py --store output/.memory-store.jsonl
  python3 scripts/memory-decay.py --store output/.memory-store.jsonl --decay-rate 0.01 --threshold 0.3
  python3 scripts/memory-decay.py --store output/.memory-store.jsonl --reinforce output/session-action-log.jsonl
  python3 scripts/memory-decay.py --store output/.memory-store.jsonl --dry-run
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_DECAY_RATE = 0.01
DEFAULT_CONFIDENCE_THRESHOLD = 0.3
DEFAULT_REINFORCEMENT_BOOST = 0.15
REINFORCEMENT_WINDOW_DAYS = 7

QUALITY_TO_CONFIDENCE = {
    "high": 0.9,
    "medium": 0.7,
    "low": 0.4,
    "unverified": 0.3,
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _now_epoch() -> float:
    return datetime.now(timezone.utc).timestamp()


def _days_since(ts_str: str, now_epoch: float) -> float:
    try:
        if "T" in ts_str:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        else:
            ts = datetime.strptime(ts_str[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
        return max((now_epoch - ts.timestamp()) / 86400.0, 0.0)
    except (ValueError, TypeError, OSError):
        return 999.0


def _get_confidence(entry: dict) -> float:
    conf = entry.get("confidence")
    if conf is not None and isinstance(conf, (int, float)):
        return float(conf)
    quality = entry.get("quality", "")
    return QUALITY_TO_CONFIDENCE.get(quality, 0.5)


def _extract_recent_topics(reinforce_file: Path, now_epoch: float, window_days: int) -> set[str]:
    if not reinforce_file.exists():
        return set()
    recent: set[str] = set()
    cutoff = now_epoch - (window_days * 86400)
    try:
        with reinforce_file.open(encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = obj.get("ts", "")
                try:
                    tse = datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
                except (ValueError, TypeError, OSError):
                    continue
                if tse < cutoff:
                    continue
                for field in ("topic_key", "memory_topic", "topic"):
                    tk = obj.get(field, "")
                    if tk:
                        recent.add(tk)
                content = obj.get("content", obj.get("text", ""))
                for kw in _extract_noun_phrases(content):
                    recent.add(kw)
    except (OSError, IOError):
        pass
    return recent


def _extract_noun_phrases(text: str) -> list[str]:
    import re
    words = re.findall(r"[a-zA-Z][a-z]{3,}", text)
    phrases = []
    for i in range(len(words) - 1):
        if words[i][0].isupper() and words[i + 1][0].isupper():
            phrases.append(f"{words[i]}_{words[i+1]}".lower())
    return phrases


def apply_decay(
    entries: list[dict],
    decay_rate: float,
    now_epoch: float,
    threshold: float,
    reinforce_topics: set[str] | None = None,
    boost: float = DEFAULT_REINFORCEMENT_BOOST,
) -> tuple[list[dict], int, int]:
    output: list[dict] = []
    decayed = 0
    reinforced = 0

    for entry in entries:
        if not isinstance(entry, dict):
            output.append(entry)
            continue

        # Skip entries without valid timestamps
        ts = entry.get("ts", entry.get("valid_from", ""))
        if not ts or ts == "null":
            output.append(entry)
            continue

        initial_conf = _get_confidence(entry)
        days = _days_since(ts, now_epoch)
        if days > 365 * 5:
            output.append(entry)
            continue

        # Exponential decay: confidence = initial * exp(-rate * days)
        decayed_conf = initial_conf * pow(2.718281828, -decay_rate * days)

        # Reinforcement: if topic was recently accessed, boost
        if reinforce_topics:
            topic = entry.get("topic_key", "")
            content = entry.get("content", "")
            matched = False
            if topic and topic in reinforce_topics:
                matched = True
            else:
                content_lower = content.lower()
                for rt in reinforce_topics:
                    if rt in content_lower:
                        matched = True
                        break
            if matched:
                decayed_conf = min(decayed_conf + boost, 1.0)
                reinforced += 1

        if abs(decayed_conf - initial_conf) > 0.001:
            decayed += 1

        decayed_conf = round(decayed_conf, 4)
        new_entry = dict(entry)
        new_entry["confidence"] = decayed_conf
        new_entry["confidence_decayed_at"] = _now_iso()
        if decayed_conf < threshold:
            new_entry["confidence_below_threshold"] = True
        elif "confidence_below_threshold" in new_entry:
            del new_entry["confidence_below_threshold"]
        output.append(new_entry)

    return output, decayed, reinforced


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SE-270 S6: memory confidence decay")
    p.add_argument(
        "--store",
        default="output/.memory-store.jsonl",
        help="Path to JSONL memory store",
    )
    p.add_argument(
        "--decay-rate",
        type=float,
        default=DEFAULT_DECAY_RATE,
        help=f"Exponential decay rate per day (default: {DEFAULT_DECAY_RATE})",
    )
    p.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_CONFIDENCE_THRESHOLD,
        help=f"Confidence threshold for flagging (default: {DEFAULT_CONFIDENCE_THRESHOLD})",
    )
    p.add_argument(
        "--reinforce",
        default=None,
        help="Path to session-action log for reinforcement boosts",
    )
    p.add_argument(
        "--boost",
        type=float,
        default=DEFAULT_REINFORCEMENT_BOOST,
        help=f"Confidence boost for reinforced entries (default: {DEFAULT_REINFORCEMENT_BOOST})",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would change without writing",
    )
    p.add_argument(
        "--output",
        default=None,
        help="Write to file instead of stdout (default: stdout)",
    )
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    store_path = Path(args.store)

    if not store_path.exists():
        print(f"Store file not found: {store_path}", file=sys.stderr)
        return 1

    entries: list[dict] = []
    with store_path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                entries.append(line)

    now_epoch = _now_epoch()
    reinforce_topics: set[str] | None = None
    if args.reinforce:
        reinforce_topics = _extract_recent_topics(
            Path(args.reinforce), now_epoch, REINFORCEMENT_WINDOW_DAYS
        )

    updated, decayed, reinforced = apply_decay(
        entries, args.decay_rate, now_epoch, args.threshold,
        reinforce_topics, args.boost,
    )

    output_lines = []
    for entry in updated:
        if isinstance(entry, dict):
            output_lines.append(json.dumps(entry, ensure_ascii=False))
        else:
            output_lines.append(str(entry))

    output_text = "\n".join(output_lines)

    if args.dry_run:
        print(f"[DRY RUN] entries={len(entries)} decayed={decayed} reinforced={reinforced}")
        below = sum(1 for e in updated if isinstance(e, dict) and e.get("confidence_below_threshold"))
        print(f"[DRY RUN] below threshold: {below}")
        if args.output:
            Path(args.output).write_text(output_text + "\n", encoding="utf-8")
        else:
            print(output_text)
    elif args.output:
        Path(args.output).write_text(output_text + "\n", encoding="utf-8")
    else:
        store_path.write_text(output_text + "\n", encoding="utf-8")

    if not args.quiet:
        print(f"entries={len(entries)} decayed={decayed} reinforced={reinforced}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
