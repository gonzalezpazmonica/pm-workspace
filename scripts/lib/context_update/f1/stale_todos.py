"""f1/stale_todos.py — F1 job: detect stale TODO/FIXME/HACK/PENDING markers.

A TODO is "stale" when:
  - It has been in the file for > STALE_DAYS days (using mtime as proxy), OR
  - It contains an explicit date that is in the past by > STALE_DAYS days.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
"""
from __future__ import annotations

import datetime
import re
from pathlib import Path
from typing import Any

STALE_DAYS = 30  # threshold for reporting a TODO as stale
MARKERS = ("TODO", "FIXME", "HACK", "PENDING", "XXX")

# Match: <!-- TODO: ... --> or <!-- TODO(author): ... -->
# Also matches inline: # TODO: ...  or plain text TODO: ...
_MARKER_RE = re.compile(
    r"(?:<!--\s*|#\s*|>\s*|\*\s*)?\b({markers})\b(?:\([^)]*\))?[:\s]+(.{{0,120}})".format(
        markers="|".join(MARKERS)
    ),
    re.IGNORECASE,
)

# Optional explicit date in TODO body, e.g. "TODO(2026-01-15):" or "TODO: fix by 2025-12-01"
_DATE_RE = re.compile(r"\b(\d{{4}}-\d{{2}}-\d{{2}})\b")


def _file_age_days(mtime_iso: str, now: datetime.datetime) -> float | None:
    if not mtime_iso:
        return None
    try:
        mtime = datetime.datetime.fromisoformat(mtime_iso.replace("Z", "+00:00"))
        return (now - mtime).total_seconds() / 86400
    except ValueError:
        return None


def run(files: list[dict]) -> dict:
    """Scan markdown files for stale TODO/FIXME/HACK markers.

    Args:
        files: list of file dicts from discovery (must include 'path', 'mtime_iso').

    Returns:
        dict with findings and summary.
    """
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    findings: list[dict[str, Any]] = []
    total_todos = 0
    stale_count = 0

    for f in files:
        path = Path(f["path"])
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        file_age = _file_age_days(f.get("mtime_iso", ""), now)

        for lineno, line in enumerate(lines, start=1):
            for m in _MARKER_RE.finditer(line):
                total_todos += 1
                marker = m.group(1).upper()
                body = m.group(2).strip()

                # Check explicit date in body
                date_match = _DATE_RE.search(body)
                is_stale = False
                reason = ""

                if date_match:
                    try:
                        marker_date = datetime.datetime.strptime(
                            date_match.group(1), "%Y-%m-%d"
                        ).replace(tzinfo=datetime.timezone.utc)
                        age = (now - marker_date).days
                        if age > STALE_DAYS:
                            is_stale = True
                            reason = f"date {date_match.group(1)} is {age}d ago"
                    except ValueError:
                        pass

                if not is_stale and file_age is not None and file_age > STALE_DAYS:
                    is_stale = True
                    reason = f"file not modified in {int(file_age)}d"

                if is_stale:
                    stale_count += 1
                    findings.append({
                        "job": "stale_todos",
                        "severity": "INFO",
                        "confidence": "MEDIUM",
                        "file": f["path"],
                        "message": (
                            f"Stale {marker} at line {lineno} ({reason}): "
                            + body[:80]
                        ),
                        "auto_applicable": False,
                    })

    return {
        "job": "stale_todos",
        "findings": findings,
        "summary": {
            "total_todos_found": total_todos,
            "stale_count": stale_count,
            "stale_threshold_days": STALE_DAYS,
            "findings_count": len(findings),
        },
    }
