"""f2/relevance_judge.py — F2 semantic judge: relevance & freshness.

Assesses whether each high-priority markdown file (specs, decisions, rules)
is still relevant to the project's current state. Uses heuristics:
- Files not referenced by any other file (isolated nodes)
- Files whose title/slug suggests a completed/superseded status
- Files with `status: done|superseded|archived` in frontmatter

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

# Status values that flag a file as potentially stale
STALE_STATUSES = {"done", "superseded", "archived", "deprecated", "closed", "cancelled"}
STALE_TITLE_TOKENS = {"[deprecated]", "[superseded]", "[archived]", "[done]", "[old]", "[legacy]"}

_FM_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_STATUS_RE = re.compile(r"^\s*status:\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)
_TITLE_RE = re.compile(r"^\s*(?:title|name):\s*(.+?)\s*$", re.MULTILINE | re.IGNORECASE)
_WIKILINK_RE = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")
_MD_LINK_RE = re.compile(r"\[.*?\]\(([^)]+\.md[^)]*)\)")


def _get_fm_field(text: str, pattern: re.Pattern) -> str | None:
    m = _FM_RE.match(text)
    if not m:
        return None
    fm = m.group(1)
    vm = pattern.search(fm)
    return vm.group(1).strip("'\"").strip() if vm else None


def run(files: list[dict]) -> dict:
    """Evaluate relevance and freshness for each file.

    Returns:
        dict with findings and summary.
    """
    # Build name index for reference counting
    name_index: dict[str, str] = {}  # stem -> full path
    for f in files:
        p = Path(f["path"])
        name_index[p.stem.lower()] = f["path"]

    # Build reference map: how many times each file is referenced
    reference_counts: dict[str, int] = {f["path"]: 0 for f in files}
    for f in files:
        try:
            text = Path(f["path"]).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for link in _WIKILINK_RE.findall(text):
            target = link.strip().lower().split("/")[-1]
            if target in name_index:
                reference_counts[name_index[target]] = reference_counts.get(name_index[target], 0) + 1
        for link in _MD_LINK_RE.findall(text):
            target = Path(link).stem.lower()
            if target in name_index:
                reference_counts[name_index[target]] = reference_counts.get(name_index[target], 0) + 1

    findings: list[dict[str, Any]] = []
    stale_status_count = 0
    isolated_count = 0

    for f in files:
        path_str = f["path"]
        try:
            text = Path(path_str).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        # Check explicit stale status
        status = _get_fm_field(text, _STATUS_RE)
        if status and status.lower() in STALE_STATUSES:
            stale_status_count += 1
            findings.append({
                "job": "relevance_judge",
                "severity": "INFO",
                "confidence": "HIGH",
                "file": path_str,
                "message": f"File has status='{status}' — consider archiving or removing",
                "auto_applicable": False,
            })
            continue  # no need for isolation check on already-stale files

        # Check stale title tokens
        title = _get_fm_field(text, _TITLE_RE) or Path(path_str).stem
        if any(tok in title.lower() for tok in STALE_TITLE_TOKENS):
            findings.append({
                "job": "relevance_judge",
                "severity": "INFO",
                "confidence": "MEDIUM",
                "file": path_str,
                "message": f"Title '{title}' contains stale token — verify relevance",
                "auto_applicable": False,
            })

        # Check isolation (not referenced anywhere) — only for specs/decisions/rules
        is_doc = any(seg in path_str for seg in ("/specs/", "/decisions/", "/rules/", ".spec.md"))
        if is_doc and reference_counts.get(path_str, 0) == 0:
            isolated_count += 1
            findings.append({
                "job": "relevance_judge",
                "severity": "INFO",
                "confidence": "LOW",
                "file": path_str,
                "message": "Doc/spec not referenced by any other file — may be orphaned",
                "auto_applicable": False,
            })

    return {
        "job": "relevance_judge",
        "findings": findings,
        "summary": {
            "stale_status_count": stale_status_count,
            "isolated_count": isolated_count,
            "findings_count": len(findings),
        },
    }
