#!/usr/bin/env python3
"""reconciliation-resolver.py — SPEC-183: 3-bucket drift classifier + auto-apply.

Input : JSON file produced by drift-auditor (or manually crafted)
Output: JSON with auto / evolution / conflicts buckets
        Optionally applies auto-resolve corrections with --apply flag.

Usage:
  python3 scripts/reconciliation-resolver.py --input drift.json
  python3 scripts/reconciliation-resolver.py --input drift.json --apply
  python3 scripts/reconciliation-resolver.py --input drift.json --apply --stats-file /tmp/stats.jsonl
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Constants ─────────────────────────────────────────────────────────────────

AUTHORITY_RANK: dict[str, int] = {
    "spec": 4,
    "decision": 3,
    "adr": 3,
    "changelog": 2,
    "note": 1,
    "comment": 0,
}

AUTO_RESOLVE_PATTERNS: list[tuple[re.Pattern, str]] = [
    # stale counter: "N commands" where N is a small integer
    (re.compile(r"\b(\d{1,4})\s+(commands?|agents?|skills?|hooks?|scripts?)\b", re.I),
     "stale_counter"),
    # stale date: references to a past YYYY-MM-DD or YYYY-MM
    (re.compile(r"\b(20\d{2}-\d{2}(?:-\d{2})?)\b"), "stale_date"),
    # version bump: vX.Y.Z
    (re.compile(r"\bv(\d+\.\d+(?:\.\d+)?)\b"), "version"),
]

CHANGELOG_KEYWORDS = frozenset(
    ["added", "changed", "fixed", "removed", "deprecated", "security",
     "refactor", "bump", "update", "migrate", "introduce"]
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _today() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y%m%d")


def _authority(path: str) -> int:
    """Return authority rank based on file path heuristics."""
    p = path.lower()
    if "propuestas/spec-" in p or "/spec-" in p:
        return AUTHORITY_RANK["spec"]
    if "decision" in p or "adr" in p:
        return AUTHORITY_RANK["decision"]
    if "changelog" in p or "roadmap" in p:
        return AUTHORITY_RANK["changelog"]
    if "note" in p:
        return AUTHORITY_RANK["note"]
    return AUTHORITY_RANK["comment"]


def _has_timeline(drift_item: dict) -> bool:
    """True if any source references a timeline, CHANGELOG entry, or ADR."""
    text = " ".join([
        drift_item.get("value_a", ""),
        drift_item.get("value_b", ""),
        drift_item.get("context", ""),
        drift_item.get("file_a", ""),
        drift_item.get("file_b", ""),
    ]).lower()
    if any(kw in text for kw in ["changelog", "timeline:", "history:", "adr-", "decision:"]):
        return True
    # Check file paths
    for key in ("file_a", "file_b"):
        p = drift_item.get(key, "").lower()
        if any(x in p for x in ["changelog", "adr", "decision", "roadmap", "timeline"]):
            return True
    return False


def _is_minor_counter_drift(value_a: str, value_b: str) -> bool:
    """True when the only difference is a stale integer counter."""
    for pat, kind in AUTO_RESOLVE_PATTERNS:
        ma = pat.findall(value_a)
        mb = pat.findall(value_b)
        if ma and mb and ma != mb and kind in ("stale_counter", "stale_date", "version"):
            return True
    return False


def _newer(item: dict) -> str:
    """Return 'a' | 'b' | 'equal' based on dates."""
    date_a = item.get("date_a", "")
    date_b = item.get("date_b", "")
    if date_a and date_b:
        return "b" if date_b > date_a else ("a" if date_a > date_b else "equal")
    return "equal"


def _classify(item: dict) -> dict:
    """Apply 3-bucket decision tree. Returns classification dict."""
    file_a = item.get("file_a", item.get("path", "unknown"))
    file_b = item.get("file_b", file_a)
    value_a = item.get("value_a", item.get("old_value", item.get("value", "")))
    value_b = item.get("value_b", item.get("new_value", ""))
    description = item.get("description", item.get("context", ""))

    auth_a = _authority(file_a)
    auth_b = _authority(file_b)
    newer = _newer(item)

    # ── Step 1: EVOLUTION — temporal-coherent change explained by history ──
    if _has_timeline(item):
        return {
            "bucket": "evolution",
            "file": file_a,
            "file_b": file_b,
            "justification": (
                "Temporal change documented in CHANGELOG/ADR/timeline. "
                f"Context: {description[:120] if description else 'see source files'}"
            ),
            "action": "append_timeline_entry",
        }

    # ── Step 2: AUTO-RESOLVE — clear winner (newer + more authoritative) ───
    # Minor counter drift is always auto-resolvable regardless of authority.
    # For semantic differences both authority AND recency must agree unambiguously.
    minor_drift = _is_minor_counter_drift(value_a, value_b)
    authority_gap = abs(auth_b - auth_a)  # significant when >= 2
    auth_advantage_b = auth_b > auth_a
    auth_advantage_a = auth_a > auth_b

    clear_winner = minor_drift or (
        (newer == "b" and (auth_advantage_b or authority_gap >= 2)) or
        (newer == "a" and (auth_advantage_a or authority_gap >= 2))
    )

    if clear_winner:
        winner_file = file_b if (newer == "b" or (newer == "equal" and auth_b >= auth_a)) else file_a
        winner_value = value_b if winner_file == file_b else value_a
        loser_file = file_a if winner_file == file_b else file_b
        loser_value = value_a if winner_file == file_b else value_b
        return {
            "bucket": "auto-resolve",
            "file": loser_file,
            "winner_file": winner_file,
            "old_value": loser_value,
            "new_value": winner_value,
            "action": f"rewrite {loser_file} with value from {winner_file}",
        }

    # ── Step 3: CONFLICT-DOC — ambiguous, requires human decision ─────────
    topic = re.sub(r"[^a-z0-9_-]", "-", description[:40].lower().strip()) or "unknown"
    topic = re.sub(r"-{2,}", "-", topic).strip("-")
    return {
        "bucket": "conflict-doc",
        "file": file_a,
        "file_b": file_b,
        "description": description or f"Divergence between {file_a} and {file_b}",
        "topic": topic,
        "conflict_doc": f"output/conflicts/{topic}-{_today()}.md",
        "action": "create_conflict_doc",
    }


def _apply_auto_resolve(entry: dict, workspace: Path, stats_file: Path | None) -> str:
    """Apply the auto-resolve action: rewrite file + append History block + log stats."""
    target = workspace / entry.get("file", "")
    new_val = entry.get("new_value", "")
    old_val = entry.get("old_value", "")
    winner = entry.get("winner_file", "unknown")

    if not target.exists():
        return f"SKIP (file not found): {target}"

    original = target.read_text(encoding="utf-8")
    # Only patch if old_value appears literally
    if old_val and old_val in original:
        patched = original.replace(old_val, new_val, 1)
        # Append ## History block at end
        history_block = (
            f"\n\n<!-- reconciler auto-resolve {_now_iso()} -->\n"
            f"<!-- old: {old_val[:100]} -->\n"
            f"<!-- new: {new_val[:100]} -->\n"
            f"<!-- source: {winner} -->\n"
        )
        patched += history_block
        target.write_text(patched, encoding="utf-8")
        status = "APPLIED"
    else:
        status = "SKIP (value not found literally in file)"

    # Log stats
    stat = {
        "ts": _now_iso(),
        "bucket": "auto-resolve",
        "file": str(entry.get("file", "")),
        "status": status,
        "winner_file": winner,
    }
    if stats_file:
        stats_file.parent.mkdir(parents=True, exist_ok=True)
        with stats_file.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(stat) + "\n")

    return status


def _apply_conflict_doc(entry: dict, workspace: Path, stats_file: Path | None) -> str:
    """Create conflict-doc with required frontmatter."""
    doc_path = workspace / entry.get("conflict_doc",
                                     f"output/conflicts/unknown-{_today()}.md")
    doc_path.parent.mkdir(parents=True, exist_ok=True)
    if doc_path.exists():
        return f"EXISTS: {doc_path}"

    content = (
        f"---\n"
        f"status: open\n"
        f"topic: {entry.get('topic', 'unknown')}\n"
        f"sources:\n"
        f"  - {entry.get('file', '')}\n"
        f"  - {entry.get('file_b', '')}\n"
        f"detected_at: {_now_iso()}\n"
        f"---\n\n"
        f"# Conflict: {entry.get('topic', 'unknown')}\n\n"
        f"{entry.get('description', 'Divergence detected by reconciler.')}\n\n"
        f"## Files involved\n\n"
        f"- `{entry.get('file', '')}`\n"
        f"- `{entry.get('file_b', '')}`\n\n"
        f"## Decision required\n\n"
        f"Choose one of: supersede / retain / annotate. Assign owner and date.\n"
    )
    doc_path.write_text(content, encoding="utf-8")

    stat = {
        "ts": _now_iso(),
        "bucket": "conflict-doc",
        "file": str(entry.get("file", "")),
        "conflict_doc": str(doc_path),
    }
    if stats_file:
        stats_file.parent.mkdir(parents=True, exist_ok=True)
        with stats_file.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(stat) + "\n")

    return f"CREATED: {doc_path}"


# ── Core public API ───────────────────────────────────────────────────────────

def classify_drift(drift_items: list[dict]) -> dict[str, list]:
    """Classify a list of drift items into the 3 buckets."""
    result: dict[str, list] = {"auto": [], "evolution": [], "conflicts": []}
    for item in drift_items:
        c = _classify(item)
        bucket = c["bucket"]
        if bucket == "auto-resolve":
            result["auto"].append(c)
        elif bucket == "evolution":
            result["evolution"].append(c)
        else:
            result["conflicts"].append(c)
    return result


def resolve(
    drift_items: list[dict],
    apply: bool = False,
    workspace: Path | None = None,
    stats_file: Path | None = None,
) -> dict[str, Any]:
    """Classify + optionally apply corrections. Returns full output dict."""
    workspace = workspace or Path.cwd()
    classified = classify_drift(drift_items)

    applied_log: list[dict] = []
    if apply:
        for entry in classified["auto"]:
            status = _apply_auto_resolve(entry, workspace, stats_file)
            applied_log.append({"file": entry.get("file"), "status": status})
        for entry in classified["conflicts"]:
            status = _apply_conflict_doc(entry, workspace, stats_file)
            applied_log.append({"conflict_doc": entry.get("conflict_doc"), "status": status})

    return {
        "auto": classified["auto"],
        "evolution": classified["evolution"],
        "conflicts": classified["conflicts"],
        "metrics": {
            "found": len(drift_items),
            "auto": len(classified["auto"]),
            "evolution": len(classified["evolution"]),
            "conflict": len(classified["conflicts"]),
        },
        "applied": applied_log if apply else None,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SPEC-183 reconciliation-resolver")
    p.add_argument("--input", required=True, help="Path to drift JSON file")
    p.add_argument("--apply", action="store_true", help="Apply auto-resolve and create conflict docs")
    p.add_argument("--workspace", default=".", help="Workspace root (default: cwd)")
    p.add_argument(
        "--stats-file",
        default=".savia/reconciliation-stats.jsonl",
        help="Path to JSONL stats file",
    )
    p.add_argument("--quiet", action="store_true", help="Suppress metrics log line")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: input file not found: {input_path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(input_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON: {exc}", file=sys.stderr)
        return 1

    # Accept either a list directly or {"drifts": [...]}
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = data.get("drifts", data.get("items", data.get("drift_items", [])))
    else:
        print("ERROR: JSON must be a list or object with 'drifts' key", file=sys.stderr)
        return 1

    workspace = Path(args.workspace).resolve()
    stats_file = Path(args.stats_file) if args.stats_file else None
    if stats_file and not stats_file.is_absolute():
        stats_file = workspace / stats_file

    output = resolve(items, apply=args.apply, workspace=workspace, stats_file=stats_file)

    print(json.dumps(output, indent=2))

    if not args.quiet:
        m = output["metrics"]
        print(
            f'\n{{"found":{m["found"]},"auto":{m["auto"]},'
            f'"evolution":{m["evolution"]},"conflict":{m["conflict"]}}}',
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
