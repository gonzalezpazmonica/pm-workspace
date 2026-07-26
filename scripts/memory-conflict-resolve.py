#!/usr/bin/env python3
"""memory-conflict-resolve.py — SE-270 S6: resolve contradictory memory entries.

Detects contradictory entries and applies resolution rules:
  1. Human instruction (source: user:explicit) always wins
  2. Higher confidence + more observations wins
  3. Newer entry wins when all else equal

Reports conflicts and resolution outcome.

Usage:
  python3 scripts/memory-conflict-resolve.py
  python3 scripts/memory-conflict-resolve.py --store output/.memory-store.jsonl
  python3 scripts/memory-conflict-resolve.py --auto-resolve
  python3 scripts/memory-conflict-resolve.py --output conflicts-resolved.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SIMILARITY_THRESHOLD = 0.25
CONFLICT_THRESHOLD = 0.35

NEGATIONS = frozenset([
    "never", "not", "no", "without", "disable", "disabled",
    "remove", "removed", "deprecate", "deprecated", "break", "broken",
    "forbid", "forbidden",
])
AFFIRMATIONS = frozenset([
    "always", "yes", "with", "enable", "enabled", "active", "required",
    "mandatory", "use", "must", "keep", "kept",
])

STOPWORDS = frozenset([
    "the", "and", "for", "are", "was", "with", "this", "that", "have",
    "has", "been", "from", "not", "but", "its", "into", "via", "per",
    "our", "all", "can", "may", "use", "used", "using", "will", "when",
    "which", "what", "how", "why",
])


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _tokenize(text: str) -> set[str]:
    tokens = re.findall(r"[a-z0-9_\-]{3,}", text.lower())
    return {t for t in tokens if t not in STOPWORDS}


def _jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


def _has_negation_flip(text_a: str, text_b: str) -> bool:
    neg_a = any(w in text_a.lower() for w in NEGATIONS)
    neg_b = any(w in text_b.lower() for w in NEGATIONS)
    aff_a = any(w in text_a.lower() for w in AFFIRMATIONS)
    aff_b = any(w in text_b.lower() for w in AFFIRMATIONS)
    return (neg_a and aff_b) or (neg_b and aff_a)


def _get_confidence(entry: dict) -> float:
    conf = entry.get("confidence")
    if conf is not None:
        return float(conf)
    qmap = {"high": 0.9, "medium": 0.7, "low": 0.4, "unverified": 0.3}
    return qmap.get(entry.get("quality", ""), 0.5)


def _is_human_instruction(entry: dict) -> bool:
    return entry.get("source", "") == "user:explicit"


def _get_observation_count(entry: dict) -> int:
    obs = entry.get("observations", entry.get("obs", 0))
    try:
        return int(obs)
    except (ValueError, TypeError):
        return 0


def _get_ts_epoch(entry: dict) -> float:
    ts = entry.get("ts", entry.get("valid_from", ""))
    try:
        if "T" in ts:
            return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
        return datetime.strptime(ts[:10], "%Y-%m-%d").timestamp()
    except (ValueError, TypeError, OSError):
        return 0.0


def resolve_conflict(
    entry_a: dict,
    entry_b: dict,
    conflict_type: str,
    sim: float,
) -> dict:
    human_a = _is_human_instruction(entry_a)
    human_b = _is_human_instruction(entry_b)

    # Rule 1: human instruction always wins
    if human_a and not human_b:
        return _resolution("human_wins", "A", entry_a, entry_b, conflict_type, sim,
                          "Human instruction overrides automated entry")
    if human_b and not human_a:
        return _resolution("human_wins", "B", entry_b, entry_a, conflict_type, sim,
                          "Human instruction overrides automated entry")
    if human_a and human_b:
        # Both human: newer wins
        ts_a = _get_ts_epoch(entry_a)
        ts_b = _get_ts_epoch(entry_b)
        winner = "A" if ts_a >= ts_b else "B"
        return _resolution("human_vs_human", winner, entry_a, entry_b, conflict_type, sim,
                          "Both human — newer wins")

    # Rule 2: higher confidence + more observations wins
    conf_a = _get_confidence(entry_a)
    conf_b = _get_confidence(entry_b)
    obs_a = _get_observation_count(entry_a)
    obs_b = _get_observation_count(entry_b)

    score_a = conf_a * (1 + obs_a * 0.1)
    score_b = conf_b * (1 + obs_b * 0.1)

    reason_parts = [f"score_A={score_a:.3f}(conf={conf_a:.2f}+obs={obs_a})",
                    f"score_B={score_b:.3f}(conf={conf_b:.2f}+obs={obs_b})"]

    if score_a != score_b:
        winner = "A" if score_a > score_b else "B"
        return _resolution("confidence_observation", winner, entry_a, entry_b,
                          conflict_type, sim, "; ".join(reason_parts))

    # Rule 3: newer entry wins
    ts_a = _get_ts_epoch(entry_a)
    ts_b = _get_ts_epoch(entry_b)
    winner = "A" if ts_a >= ts_b else "B"
    return _resolution("newer_wins", winner, entry_a, entry_b, conflict_type, sim,
                      f"Equal scores — newer wins; {reason_parts[0]}; {reason_parts[1]}")


def _resolution(
    rule: str,
    winner: str,
    entry_a: dict,
    entry_b: dict,
    conflict_type: str,
    sim: float,
    reason: str,
) -> dict:
    winning = entry_a if winner == "A" else entry_b
    losing = entry_b if winner == "A" else entry_a
    return {
        "rule": rule,
        "winner": winner,
        "winning_entry": winning.get("topic_key", "?")[:80],
        "losing_entry": losing.get("topic_key", "?")[:80],
        "winning_text": winning.get("content", winning.get("text", ""))[:200],
        "losing_text": losing.get("content", losing.get("text", ""))[:200],
        "conflict_type": conflict_type,
        "similarity": round(sim, 3),
        "reason": reason,
        "action": "keep_winner_flag_loser",
        "resolved_at": _now_iso(),
    }


def detect_and_resolve(entries: list[dict]) -> tuple[list[dict], list[dict]]:
    unresolved: list[dict] = []
    resolutions: list[dict] = []
    n = len(entries)
    resolved_indices: set[int] = set()

    for i in range(n):
        if i in resolved_indices:
            continue
        a = entries[i]
        if not isinstance(a, dict):
            continue
        tok_a = _tokenize(a.get("content", a.get("text", "")))

        for j in range(i + 1, n):
            if j in resolved_indices:
                continue
            b = entries[j]
            if not isinstance(b, dict):
                continue
            tok_b = _tokenize(b.get("content", b.get("text", "")))
            sim = _jaccard(tok_a, tok_b)

            if sim < SIMILARITY_THRESHOLD:
                continue

            conflict_type = None
            if sim >= CONFLICT_THRESHOLD and _has_negation_flip(
                a.get("content", ""), b.get("content", "")
            ):
                conflict_type = "direct_contradiction"
            elif sim >= SIMILARITY_THRESHOLD:
                conflict_type = "value_overlap"

            if conflict_type:
                res = resolve_conflict(a, b, conflict_type, sim)
                resolutions.append(res)
                # Mark loser for removal in auto-resolve mode
                if res["winner"] == "A":
                    resolved_indices.add(j)
                else:
                    resolved_indices.add(i)

        if i not in resolved_indices:
            unresolved.append(entries[i])

    return unresolved, resolutions


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SE-270 S6: resolve memory conflicts")
    p.add_argument("--store", default="output/.memory-store.jsonl", help="JSONL store path")
    p.add_argument("--auto-resolve", action="store_true",
                   help="Remove losing entries from store")
    p.add_argument("--output", default=None, help="Write JSON report to file")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    store_path = Path(args.store)

    if not store_path.exists():
        print(f"Store not found: {store_path}", file=sys.stderr)
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
                entries.append({"raw": line})

    unresolved, resolutions = detect_and_resolve(entries)

    output = {
        "ts": _now_iso(),
        "source": str(store_path),
        "total_entries": len(entries),
        "conflicts_found": len(resolutions),
        "resolutions": resolutions,
    }

    # Auto-resolve: rewrite store without losing entries
    if args.auto_resolve and resolutions:
        # Build set of losing topic_keys
        losing_keys: set[str] = set()
        for res in resolutions:
            losing_keys.add(res.get("losing_entry", ""))
        filtered: list[str] = []
        removed = 0
        for e in entries:
            if isinstance(e, dict) and e.get("topic_key", "") in losing_keys:
                removed += 1
                continue
            if isinstance(e, dict):
                filtered.append(json.dumps(e, ensure_ascii=False))
            else:
                filtered.append(str(e))
        store_path.write_text("\n".join(filtered) + "\n", encoding="utf-8")
        output["auto_resolved"] = True
        output["entries_removed"] = removed

    output_json = json.dumps(output, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(output_json, encoding="utf-8")
    else:
        print(output_json)

    if not args.quiet:
        print(f"entries={len(entries)} conflicts={len(resolutions)}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
