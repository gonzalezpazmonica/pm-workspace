"""f2/actionability_judge.py — F2 semantic judge: actionability of specs/decisions.

A spec/decision is "low actionability" when:
- It has no clear acceptance criteria (no checkbox list, no numbered list, no table)
- It is a spec but has no owner assigned
- It has `status: draft` and has not been updated in > 60 days
- It mentions "TBD" or "TODO" in critical sections (Objective, Criteria)

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import datetime
import re
from pathlib import Path
from typing import Any

STALE_DRAFT_DAYS = 60

_FM_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_STATUS_RE = re.compile(r"^\s*status:\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)
_OWNER_RE = re.compile(r"^\s*(?:owner|author|assignee):\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)
_UPDATED_RE = re.compile(r"^\s*updated:\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)

# Patterns that indicate acceptance criteria presence
_AC_PATTERNS = [
    re.compile(r"^\s*-\s*\[[ x]\]", re.MULTILINE),     # checkbox list
    re.compile(r"^\s*AC-\d+", re.MULTILINE),             # AC-01, AC-02 style
    re.compile(r"\|\s*AC\s*\|", re.IGNORECASE),          # table with AC column
    re.compile(r"criterios de aceptaci", re.IGNORECASE),
    re.compile(r"acceptance criteria", re.IGNORECASE),
]
_TBD_RE = re.compile(r"\bTBD\b|\bPOR DEFINIR\b|\bPENDIENTE\b", re.IGNORECASE)


def _parse_fm(text: str) -> dict[str, str]:
    fm_m = _FM_RE.match(text)
    if not fm_m:
        return {}
    fm = fm_m.group(1)
    result: dict[str, str] = {}
    for pattern, key in [
        (_STATUS_RE, "status"),
        (_OWNER_RE, "owner"),
        (_UPDATED_RE, "updated"),
    ]:
        m = pattern.search(fm)
        if m:
            result[key] = m.group(1).strip("'\"").strip()
    return result


def run(files: list[dict]) -> dict:
    """Evaluate actionability of specs and decision files.

    Returns:
        dict with findings and summary.
    """
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    findings: list[dict[str, Any]] = []
    no_ac_count = 0
    no_owner_count = 0
    stale_draft_count = 0
    tbd_count = 0

    spec_files = [
        f for f in files
        if ".spec.md" in f["path"]
        or "/decisions/" in f["path"]
        or "/specs/" in f["path"]
    ]

    for f in spec_files:
        path_str = f["path"]
        try:
            text = Path(path_str).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        fm = _parse_fm(text)
        status = fm.get("status", "").lower()
        owner = fm.get("owner", "")
        updated_str = fm.get("updated", "") or f.get("mtime_iso", "")

        # --- No acceptance criteria ---
        has_ac = any(p.search(text) for p in _AC_PATTERNS)
        if not has_ac:
            no_ac_count += 1
            findings.append({
                "job": "actionability_judge",
                "severity": "WARNING",
                "confidence": "MEDIUM",
                "file": path_str,
                "message": "Spec/decision has no acceptance criteria (no checklist, AC-NN, or criteria section)",
                "auto_applicable": False,
            })

        # --- No owner ---
        if not owner:
            no_owner_count += 1
            findings.append({
                "job": "actionability_judge",
                "severity": "INFO",
                "confidence": "MEDIUM",
                "file": path_str,
                "message": "Spec/decision has no owner/author/assignee in frontmatter",
                "auto_applicable": False,
            })

        # --- Stale draft ---
        if status == "draft" and updated_str:
            try:
                updated = datetime.datetime.fromisoformat(
                    updated_str[:10]
                ).replace(tzinfo=datetime.timezone.utc)
                age_days = (now - updated).days
                if age_days > STALE_DRAFT_DAYS:
                    stale_draft_count += 1
                    findings.append({
                        "job": "actionability_judge",
                        "severity": "WARNING",
                        "confidence": "HIGH",
                        "file": path_str,
                        "message": (
                            f"Spec is status=draft and has not been updated in {age_days}d "
                            f"(threshold: {STALE_DRAFT_DAYS}d) — approve, defer, or discard"
                        ),
                        "auto_applicable": False,
                    })
            except (ValueError, TypeError):
                pass

        # --- TBD in critical sections ---
        if _TBD_RE.search(text):
            tbd_count += 1
            findings.append({
                "job": "actionability_judge",
                "severity": "INFO",
                "confidence": "MEDIUM",
                "file": path_str,
                "message": "Contains TBD / POR DEFINIR — review before marking as approved",
                "auto_applicable": False,
            })

    return {
        "job": "actionability_judge",
        "findings": findings,
        "summary": {
            "specs_checked": len(spec_files),
            "no_ac_count": no_ac_count,
            "no_owner_count": no_owner_count,
            "stale_draft_count": stale_draft_count,
            "tbd_count": tbd_count,
            "findings_count": len(findings),
        },
    }
