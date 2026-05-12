"""f1/schema_drift.py — F1 job: detect frontmatter schema drift.

Compares each file's frontmatter keys against the canonical schema
for its path pattern (same rules used by frontmatter_lint.py).
Reports fields that are present but obsolete, and fields that are
missing from files that previously had them (drift relative to the
most common schema in each pattern group).

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
"""
from __future__ import annotations

import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Canonical required/optional keys per path pattern
# (mirrors frontmatter_lint.py but focuses on drift, not single-file lint)
# ---------------------------------------------------------------------------
_SCHEMA: list[tuple[str, set[str], set[str]]] = [
    # (glob_pattern_fragment, required_keys, optional_keys)
    (
        ".opencode/commands",
        {"description"},
        {"usage", "aliases", "model", "permission"},
    ),
    (
        ".opencode/agents",
        {"description", "model"},
        {"permission", "tools"},
    ),
    (
        ".opencode/skills",
        {"description"},
        {"version", "author"},
    ),
    (
        "docs/rules",
        set(),
        {"title", "version", "updated"},
    ),
    (
        "projects/",
        set(),
        {"conf_level", "updated", "slug", "status"},
    ),
]

_FM_BLOCK_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_KEY_RE = re.compile(r"^\s*([a-zA-Z_][a-zA-Z0-9_-]*):", re.MULTILINE)

# Known-obsolete keys that should no longer appear
OBSOLETE_KEYS = {
    "layout",       # Jekyll artifact
    "permalink",    # Jekyll artifact
    "categories",   # replaced by tags
    "date",         # replaced by updated
    "draft",        # replaced by status
    "published",    # replaced by status
}


def _get_fm_keys(path: Path) -> set[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return set()
    m = _FM_BLOCK_RE.match(text)
    if not m:
        return set()
    return {k for k in _KEY_RE.findall(m.group(1))}


def _match_schema(path_str: str) -> tuple[set[str], set[str]]:
    """Return (required, optional) for the best matching schema rule."""
    for fragment, req, opt in _SCHEMA:
        if fragment in path_str:
            return req, opt
    return set(), set()


def run(files: list[dict]) -> dict:
    """Detect frontmatter schema drift.

    1. Reports obsolete keys present in any file.
    2. Groups files by path pattern; within each group reports keys
       used by ≥50% of files but missing in the rest (gradual drift).

    Returns:
        dict with findings and summary.
    """
    findings: list[dict[str, Any]] = []
    obsolete_count = 0
    drift_count = 0

    # --- Pass 1: obsolete keys -----------------------------------------------
    for f in files:
        path = Path(f["path"])
        keys = _get_fm_keys(path)
        found_obsolete = keys & OBSOLETE_KEYS
        for k in sorted(found_obsolete):
            obsolete_count += 1
            findings.append({
                "job": "schema_drift",
                "severity": "WARNING",
                "confidence": "HIGH",
                "file": f["path"],
                "message": f"Obsolete frontmatter key '{k}' — should be removed or migrated",
                "auto_applicable": True,
            })

    # --- Pass 2: per-group majority drift ------------------------------------
    # Group files by matching schema fragment
    groups: dict[str, list[dict]] = defaultdict(list)
    for f in files:
        matched = "other"
        for fragment, _, _ in _SCHEMA:
            if fragment in f["path"]:
                matched = fragment
                break
        groups[matched].append(f)

    for group_key, group_files in groups.items():
        if len(group_files) < 3:
            continue  # too small to detect drift reliably

        # Count key frequency
        key_counts: Counter = Counter()
        file_keys: dict[str, set[str]] = {}
        for f in group_files:
            keys = _get_fm_keys(Path(f["path"]))
            file_keys[f["path"]] = keys
            key_counts.update(keys)

        n = len(group_files)
        majority_keys = {k for k, cnt in key_counts.items() if cnt / n >= 0.5}

        for f in group_files:
            missing = majority_keys - file_keys[f["path"]] - OBSOLETE_KEYS
            if missing:
                drift_count += 1
                findings.append({
                    "job": "schema_drift",
                    "severity": "INFO",
                    "confidence": "MEDIUM",
                    "file": f["path"],
                    "message": (
                        f"Schema drift in group '{group_key}': "
                        f"missing keys present in ≥50% of peers: "
                        + ", ".join(sorted(missing))
                    ),
                    "auto_applicable": False,
                })

    return {
        "job": "schema_drift",
        "findings": findings,
        "summary": {
            "obsolete_key_instances": obsolete_count,
            "drift_instances": drift_count,
            "findings_count": len(findings),
        },
    }
