#!/usr/bin/env python3
"""memory-conflict-detector.py — SE-214: semantic conflict detection in MEMORY.md.

Detects memory entries that contradict each other.
Conflict types:
  - direct_contradiction : same entity/topic, opposing claims
  - temporal_overlap     : two active entries claim different states for same period
  - value_disagreement   : same topic, different numeric/enum values

Input : MEMORY.md path (or --store JSONL path)
Output: JSON {conflicts: [{entry_a, entry_b, conflict_type, description}]}

Usage:
  python3 scripts/memory-conflict-detector.py
  python3 scripts/memory-conflict-detector.py --memory-file ~/.savia-memory/auto/MEMORY.md
  python3 scripts/memory-conflict-detector.py --store output/.memory-store.jsonl
  python3 scripts/memory-conflict-detector.py --output conflicts.json
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

# ── Default paths ─────────────────────────────────────────────────────────────

DEFAULT_MEMORY_FILE = Path.home() / ".savia-memory" / "auto" / "MEMORY.md"
DEFAULT_STORE_FILE = Path("output") / ".memory-store.jsonl"

# ── Tokenization ──────────────────────────────────────────────────────────────

STOPWORDS = frozenset([
    "the", "and", "for", "are", "was", "with", "this", "that", "have",
    "has", "been", "from", "not", "but", "its", "into", "via", "per",
    "our", "all", "can", "may", "use", "used", "using", "will", "when",
    "which", "what", "how", "why",
])

NEGATION_WORDS = frozenset(["never", "not", "no", "without", "disable", "disabled",
                             "removed", "deprecated", "broken", "forbidden"])

AFFIRMATION_WORDS = frozenset(["always", "yes", "with", "enabled", "active", "required",
                                "mandatory", "use", "must"])

NUMBER_RE = re.compile(r"\b(\d+(?:\.\d+)?)\s*(%|ms|s|h|days?|hours?|agents?|commands?|hooks?|scripts?|pbi|sp|pts?)?\b")


def _tokenize(text: str) -> set[str]:
    tokens = re.findall(r"[a-z0-9_\-]{3,}", text.lower())
    return {t for t in tokens if t not in STOPWORDS}


def _extract_topic_key(text: str) -> str:
    """Extract a short topic key from entry text (first noun phrase)."""
    clean = re.sub(r"\[.*?\]", "", text)
    words = re.findall(r"[A-Za-z][a-z]{2,}", clean)
    key = " ".join(w.lower() for w in words[:4] if w.lower() not in STOPWORDS)
    return key or clean[:30].lower()


def _jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


def _has_negation_flip(text_a: str, text_b: str) -> bool:
    """True if one text has a negation word and the other an affirmation for same core."""
    neg_a = any(w in text_a.lower() for w in NEGATION_WORDS)
    neg_b = any(w in text_b.lower() for w in NEGATION_WORDS)
    aff_a = any(w in text_a.lower() for w in AFFIRMATION_WORDS)
    aff_b = any(w in text_b.lower() for w in AFFIRMATION_WORDS)
    return (neg_a and aff_b) or (neg_b and aff_a)


def _extract_numbers(text: str) -> list[tuple[float, str]]:
    """Extract (value, unit) pairs from text."""
    results = []
    for m in NUMBER_RE.finditer(text.lower()):
        try:
            results.append((float(m.group(1)), m.group(2) or ""))
        except ValueError:
            pass
    return results


def _dates_overlap(text_a: str, text_b: str) -> bool:
    """Heuristic: both entries mention years/dates in overlapping ranges."""
    year_re = re.compile(r"\b(202[0-9])\b")
    years_a = set(year_re.findall(text_a))
    years_b = set(year_re.findall(text_b))
    return bool(years_a & years_b)


# ── Entry parsing ─────────────────────────────────────────────────────────────

def _parse_memory_md(path: Path) -> list[dict]:
    """Parse MEMORY.md bullet entries. Returns list of {text, type, id} dicts."""
    if not path.exists():
        return []
    entries = []
    with path.open(encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.rstrip()
            # Match "- type: text [key]" or "- text [key]"
            m = re.match(r"^- (?:(\w+):\s+)?(.+?)(?:\s+\[([^\]]+)\])?$", line)
            if not m:
                continue
            entry_type = m.group(1) or "unknown"
            text = m.group(2).strip()
            entry_id = m.group(3) or f"line-{lineno}"
            entries.append({"id": entry_id, "text": text, "type": entry_type})
    return entries


def _parse_store_jsonl(path: Path) -> list[dict]:
    """Parse .memory-store.jsonl entries."""
    if not path.exists():
        return []
    entries = []
    with path.open(encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                entries.append({
                    "id": obj.get("id", f"store-{lineno}"),
                    "text": obj.get("content", obj.get("text", "")),
                    "type": obj.get("memory_type", obj.get("type", "unknown")),
                })
            except json.JSONDecodeError:
                continue
    return entries


# ── Conflict detection ────────────────────────────────────────────────────────

SIMILARITY_THRESHOLD = 0.25   # min Jaccard for candidate pair
CONFLICT_THRESHOLD = 0.35     # min similarity for actual conflict


def detect_conflicts(entries: list[dict]) -> list[dict]:
    """
    Compare all pairs of entries and detect conflicts.
    Returns list of conflict dicts.
    """
    conflicts: list[dict] = []
    n = len(entries)

    for i in range(n):
        a = entries[i]
        tok_a = _tokenize(a["text"])
        nums_a = _extract_numbers(a["text"])

        for j in range(i + 1, n):
            b = entries[j]
            tok_b = _tokenize(b["text"])
            sim = _jaccard(tok_a, tok_b)

            if sim < SIMILARITY_THRESHOLD:
                continue  # too dissimilar — not about same topic

            nums_b = _extract_numbers(b["text"])
            conflict_type = None
            description = ""

            # 1. Direct contradiction: negation flip
            if sim >= CONFLICT_THRESHOLD and _has_negation_flip(a["text"], b["text"]):
                conflict_type = "direct_contradiction"
                description = (
                    f"Entries share topic (sim={sim:.2f}) but one negates the other. "
                    f"A: '{a['text'][:80]}' | B: '{b['text'][:80]}'"
                )

            # 2. Value disagreement: same topic, different numbers
            elif sim >= SIMILARITY_THRESHOLD and nums_a and nums_b:
                vals_a = {round(v) for v, _ in nums_a}
                vals_b = {round(v) for v, _ in nums_b}
                if vals_a != vals_b and not vals_a.issubset(vals_b) and not vals_b.issubset(vals_a):
                    conflict_type = "value_disagreement"
                    description = (
                        f"Same topic (sim={sim:.2f}), different numeric values. "
                        f"A values: {sorted(vals_a)} | B values: {sorted(vals_b)}. "
                        f"A: '{a['text'][:80]}' | B: '{b['text'][:80]}'"
                    )

            # 3. Temporal overlap: same topic, overlapping date references
            elif sim >= CONFLICT_THRESHOLD and _dates_overlap(a["text"], b["text"]):
                conflict_type = "temporal_overlap"
                description = (
                    f"Entries reference overlapping time periods (sim={sim:.2f}) "
                    f"with potentially conflicting states. "
                    f"A: '{a['text'][:80]}' | B: '{b['text'][:80]}'"
                )

            if conflict_type:
                conflicts.append({
                    "entry_a": a["id"],
                    "entry_b": b["id"],
                    "text_a": a["text"][:200],
                    "text_b": b["text"][:200],
                    "conflict_type": conflict_type,
                    "description": description,
                    "similarity": round(sim, 3),
                })

    return conflicts


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SE-214 memory-conflict-detector")
    p.add_argument(
        "--memory-file",
        default=str(DEFAULT_MEMORY_FILE),
        help=f"Path to MEMORY.md (default: {DEFAULT_MEMORY_FILE})",
    )
    p.add_argument("--store", default=None, help="Path to .memory-store.jsonl (overrides --memory-file)")
    p.add_argument("--output", default=None, help="Write JSON output to file instead of stdout")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    if args.store:
        entries = _parse_store_jsonl(Path(args.store))
        source = args.store
    else:
        entries = _parse_memory_md(Path(args.memory_file))
        source = args.memory_file

    conflicts = detect_conflicts(entries)
    output = {"conflicts": conflicts, "total": len(conflicts), "source": source}
    output_json = json.dumps(output, indent=2)

    if args.output:
        Path(args.output).write_text(output_json, encoding="utf-8")
    else:
        print(output_json)

    if not args.quiet:
        print(f"entries={len(entries)} conflicts={len(conflicts)}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
