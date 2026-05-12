"""f1/wikilink_check.py — F1 job: detect broken [[wikilinks]]."""
from __future__ import annotations

import re
from pathlib import Path


WIKILINK_RE = re.compile(r'\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]')


def _build_name_index(files: list[dict]) -> set[str]:
    """Build set of lowercase stem names for fast lookup."""
    index: set[str] = set()
    for f in files:
        p = Path(f["path"])
        index.add(p.stem.lower())
        index.add(p.name.lower())
    return index


def run(files: list[dict]) -> dict:
    name_index = _build_name_index(files)
    findings = []

    for f in files:
        path = Path(f["path"])
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue

        for m in WIKILINK_RE.finditer(text):
            target = m.group(1).strip()
            target_lower = target.lower()
            # Check if target resolves to a known file
            if (
                target_lower not in name_index
                and (target_lower + ".md") not in name_index
            ):
                findings.append({
                    "job": "wikilink-check",
                    "severity": "warning",
                    "confidence": "MEDIUM",
                    "file": f["rel_path"],
                    "message": f"Broken wikilink: [[{target}]] — no matching file found.",
                    "evidence": target,
                    "auto_aplicable": False,
                })

    return {
        "job": "wikilink-check",
        "status": "ok",
        "files_checked": len(files),
        "findings": findings,
    }
