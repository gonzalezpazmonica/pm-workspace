#!/usr/bin/env python3
"""
memory-feedback-compactor.py — Compact recurring lessons in MEMORY.md.
Spec: SPEC-164 Slice 3

Reads MEMORY.md entries of the form:
  - outcome:{outcome} agent:{agent} lesson:{lesson} [...]
  - pr_merged:#NNN spec:{spec_id} ...

Identifies entries with same agent + outcome repeated >= 3 times.
Promotes the most recent lesson to docs/rules/learned/{agent}-pattern.md.
Removes repeated entries, keeping only the most recent.
Enforces cap: if MEMORY.md > 190 lines, compacts oldest entries.

Usage:
  python3 scripts/memory-feedback-compactor.py [--dry-run] [--memory PATH]
"""
import sys
import os
import re
import argparse
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone


REPEAT_THRESHOLD = 3
CAP_TRIGGER = 190


def parse_args():
    p = argparse.ArgumentParser(description="Compact MEMORY.md recurring lessons")
    p.add_argument("--dry-run", action="store_true", help="Show what would change without writing")
    p.add_argument("--memory", default=None, help="Path to MEMORY.md (default: auto-detect)")
    return p.parse_args()


def find_memory_file(override: str | None) -> Path:
    if override:
        return Path(override)
    # Check env var
    env_path = os.environ.get("MEMORY_FILE")
    if env_path:
        return Path(env_path)
    # Default: workspace root detection
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    candidates = [
        repo_root / ".claude" / "external-memory" / "auto" / "MEMORY.md",
        Path.home() / ".savia-memory" / "auto" / "MEMORY.md",
    ]
    for c in candidates:
        if c.exists():
            return c
    # Return default even if not existing (will fail gracefully)
    return candidates[0]


def find_learned_dir(memory_path: Path) -> Path:
    # Walk up from memory_path to find repo root (has docs/rules/learned/)
    current = memory_path.parent
    for _ in range(10):
        candidate = current / "docs" / "rules" / "learned"
        if candidate.parent.parent.exists():
            return candidate
        parent = current.parent
        if parent == current:
            break
        current = parent
    # Fallback: relative to script
    script_dir = Path(__file__).parent
    return script_dir.parent / "docs" / "rules" / "learned"


def read_memory(path: Path) -> tuple[list[str], list[str], list[str]]:
    """
    Returns (before_entries, entries, after_entries).
    Lines inside <!-- ENTRIES_START --> / <!-- ENTRIES_END --> are 'entries'.
    """
    if not path.exists():
        return [], [], []

    content = path.read_text(encoding="utf-8").splitlines(keepends=True)
    before, entries, after = [], [], []
    state = "before"
    for line in content:
        stripped = line.rstrip("\n")
        if stripped == "<!-- ENTRIES_START -->":
            state = "in"
            before.append(line)
            continue
        if stripped == "<!-- ENTRIES_END -->":
            state = "after"
            after.append(line)
            continue
        if state == "before":
            before.append(line)
        elif state == "in":
            entries.append(line)
        else:
            after.append(line)
    return before, entries, after


def parse_outcome_entry(line: str) -> dict | None:
    """
    Parse lines like:
      - outcome:success agent:dotnet-developer lesson:...  [2026-06-24T...]
    Returns dict with outcome, agent, lesson, ts, raw_line or None.
    """
    stripped = line.strip()
    if not stripped.startswith("- outcome:"):
        return None
    m = re.match(
        r"^- outcome:(\S+)\s+agent:(\S+)\s+lesson:(.*?)\s+\[([^\]]+)\]",
        stripped,
    )
    if not m:
        return None
    return {
        "outcome": m.group(1),
        "agent": m.group(2),
        "lesson": m.group(3),
        "ts": m.group(4),
        "raw": line,
    }


def group_by_agent_outcome(entries: list[str]) -> dict:
    """
    Returns {(agent, outcome): [parsed_entry, ...]} sorted newest-first by ts.
    Non-matching entries are preserved but not grouped.
    """
    groups: dict = defaultdict(list)
    for line in entries:
        parsed = parse_outcome_entry(line)
        if parsed:
            key = (parsed["agent"], parsed["outcome"])
            groups[key].append(parsed)
    # Sort each group: newest first (ts desc)
    for key in groups:
        groups[key].sort(key=lambda x: x["ts"], reverse=True)
    return groups


def promote_to_learned(agent: str, outcome: str, lesson: str, learned_dir: Path, dry_run: bool) -> Path:
    """Write (or show) a pattern file in docs/rules/learned/."""
    safe_agent = re.sub(r"[^a-z0-9-]", "-", agent.lower())
    filename = f"{safe_agent}-pattern.md"
    dest = learned_dir / filename
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    content = f"""---
agent: {agent}
outcome: {outcome}
promoted_at: {ts}
source: memory-feedback-compactor
spec: SPEC-164
---

# Learned Pattern: {agent} ({outcome})

**Promoted automatically** by memory-feedback-compactor (SPEC-164).
Repeated >= {REPEAT_THRESHOLD} times.

## Latest lesson

{lesson}

## Notes

This file is auto-generated. Edit only to add context — it will be updated
on next compaction cycle if the pattern recurs.
"""
    if not dry_run:
        learned_dir.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
    return dest


def compact(args) -> int:
    memory_path = find_memory_file(args.memory)
    learned_dir = find_learned_dir(memory_path)
    dry_run = args.dry_run

    if not memory_path.exists():
        print(f"MEMORY.md not found at {memory_path}", file=sys.stderr)
        return 1

    before, entries, after = read_memory(memory_path)
    if not entries and not before:
        print(f"No ENTRIES block found in {memory_path}", file=sys.stderr)
        return 0

    groups = group_by_agent_outcome(entries)

    # ── Identify keys to compact ──────────────────────────────────────────
    keys_to_compact = {k for k, v in groups.items() if len(v) >= REPEAT_THRESHOLD}

    promoted = []
    lines_to_remove: set[str] = set()

    for key in keys_to_compact:
        agent, outcome = key
        parsed_list = groups[key]
        # Keep only the most recent; remove the rest
        most_recent = parsed_list[0]
        to_remove = parsed_list[1:]  # older duplicates

        # Promote lesson to learned/
        lesson = most_recent["lesson"]
        dest = promote_to_learned(agent, outcome, lesson, learned_dir, dry_run)
        promoted.append((agent, outcome, dest))

        # Mark older entries for removal
        for entry in to_remove:
            lines_to_remove.add(entry["raw"])

    # ── Build new entries list (without removed lines) ──────────────────
    new_entries = [ln for ln in entries if ln not in lines_to_remove]

    # ── Cap enforcement: if > CAP_TRIGGER entry lines, remove oldest ─────
    entry_lines = [ln for ln in new_entries if ln.strip().startswith("- ")]
    non_entry_lines = [ln for ln in new_entries if not ln.strip().startswith("- ")]

    removed_by_cap = 0
    if len(entry_lines) > CAP_TRIGGER:
        excess = len(entry_lines) - CAP_TRIGGER
        # Remove oldest = tail of list (entries prepended newest-first)
        entry_lines = entry_lines[: -excess]
        removed_by_cap = excess

    new_entries = entry_lines + non_entry_lines

    # ── Write updated MEMORY.md ────────────────────────────────────────────
    if dry_run:
        print(f"[DRY-RUN] memory_path: {memory_path}")
        print(f"[DRY-RUN] keys_to_compact: {list(keys_to_compact)}")
        print(f"[DRY-RUN] entries_removed: {len(lines_to_remove)}")
        print(f"[DRY-RUN] entries_removed_by_cap: {removed_by_cap}")
        for agent, outcome, dest in promoted:
            print(f"[DRY-RUN] would promote {agent}/{outcome} → {dest}")
    else:
        new_content = (
            before
            + new_entries
            + after
        )
        memory_path.write_text("".join(new_content), encoding="utf-8")

    # ── Summary ────────────────────────────────────────────────────────────
    print(f"compacted: entries_removed={len(lines_to_remove)} cap_trimmed={removed_by_cap} patterns_promoted={len(promoted)}")
    return 0


def main():
    args = parse_args()
    sys.exit(compact(args))


if __name__ == "__main__":
    main()
