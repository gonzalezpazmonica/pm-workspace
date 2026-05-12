"""f1/staleness.py — F1 job: detect stale notes by last-modified date.

A note is "stale" when it has not been modified in more than N days,
where N depends on the document type:

| Document type         | Stale threshold |
|-----------------------|-----------------|
| Specs (*.spec.md)     | 180 days        |
| Rules / domain docs   | 365 days        |
| Agent / command / skill| 180 days       |
| Vault notes           | 90 days         |
| Raw ingested content  | 60 days         |
| Default               | 120 days        |

Files with `status: archived|superseded|deprecated` are exempt.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
Confidence: HIGH (uses actual mtime from discovery manifest).
"""
from __future__ import annotations

import datetime
import re
from pathlib import Path
from typing import Any

# (path_fragment, stale_days)
_THRESHOLDS: list[tuple[str, int]] = [
    (".spec.md",             180),
    ("docs/rules",           365),
    ("docs/decisions",       365),
    (".opencode/agents",     180),
    (".opencode/commands",   180),
    (".opencode/skills",     180),
    (".claude/agents",       180),
    (".claude/commands",     180),
    (".claude/skills",       180),
    ("/vault/",               90),
    ("/raw/",                 60),
]
_DEFAULT_THRESHOLD = 120

_FM_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_STATUS_RE = re.compile(r"^\s*status:\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)
_EXEMPT_STATUSES = {"archived", "superseded", "deprecated", "done", "cancelled"}


def _threshold_for(path_str: str) -> int:
    for fragment, days in _THRESHOLDS:
        if fragment in path_str:
            return days
    return _DEFAULT_THRESHOLD


def _is_exempt(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    fm_m = _FM_RE.match(text)
    if not fm_m:
        return False
    status_m = _STATUS_RE.search(fm_m.group(1))
    if status_m:
        return status_m.group(1).strip("'\"").lower() in _EXEMPT_STATUSES
    return False


def run(files: list[dict]) -> dict:
    """Detect stale notes by last-modified age.

    Args:
        files: list of file dicts from discovery (must include 'path', 'mtime_iso').

    Returns:
        dict with findings and summary.
    """
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    findings: list[dict[str, Any]] = []
    stale_count = 0
    exempt_count = 0

    for f in files:
        mtime_iso = f.get("mtime_iso", "")
        if not mtime_iso:
            continue

        try:
            mtime = datetime.datetime.fromisoformat(
                mtime_iso.replace("Z", "+00:00")
            )
        except ValueError:
            continue

        age_days = (now - mtime).days
        threshold = _threshold_for(f["path"])

        if age_days <= threshold:
            continue

        # Check exempt status
        if _is_exempt(Path(f["path"])):
            exempt_count += 1
            continue

        stale_count += 1
        severity = "WARNING" if age_days >= threshold * 2 else "INFO"
        findings.append({
            "job": "staleness",
            "severity": severity,
            "confidence": "HIGH",
            "file": f["path"],
            "message": (
                f"Not modified in {age_days} days "
                f"(threshold: {threshold}d for this doc type) — review or archive"
            ),
            "auto_applicable": False,
        })

    return {
        "job": "staleness",
        "findings": findings,
        "summary": {
            "stale_count": stale_count,
            "exempt_count": exempt_count,
            "findings_count": len(findings),
        },
    }
