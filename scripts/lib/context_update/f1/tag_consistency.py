"""f1/tag_consistency.py — F1 job: detect orphan tags and frontmatter tag inconsistencies."""
from __future__ import annotations

import re
from collections import Counter
from pathlib import Path


TAG_LINE_RE = re.compile(r'^tags\s*:\s*\[([^\]]*)\]', re.IGNORECASE)
TAG_ITEM_RE = re.compile(r'^\s*-\s+(.+)$')


def _extract_tags(path: Path) -> list[str]:
    """Extract tags from YAML frontmatter (inline list or block list)."""
    tags: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return tags

    if not lines or not lines[0].startswith("---"):
        return tags

    in_fm = False
    in_tags = False
    for line in lines[1:]:
        if line.strip() == "---":
            if not in_fm:
                in_fm = True
            else:
                break
        if not in_fm:
            continue

        # Inline: tags: [a, b, c]
        m = TAG_LINE_RE.match(line)
        if m:
            for t in m.group(1).split(","):
                t = t.strip().strip('"').strip("'")
                if t:
                    tags.append(t)
            in_tags = False
            continue

        # Block list start
        if re.match(r'^tags\s*:', line, re.IGNORECASE):
            in_tags = True
            continue

        if in_tags:
            m2 = TAG_ITEM_RE.match(line)
            if m2:
                tags.append(m2.group(1).strip().strip('"').strip("'"))
            elif line.strip() and not line.startswith(" "):
                in_tags = False

    return tags


def run(files: list[dict]) -> dict:
    all_tags: Counter = Counter()
    findings = []

    for f in files:
        path = Path(f["path"])
        tags = _extract_tags(path)
        for t in tags:
            all_tags[t] += 1

    # Tags used only once may be typos
    singleton_tags = [t for t, c in all_tags.items() if c == 1]
    for f in files:
        path = Path(f["path"])
        tags = _extract_tags(path)
        for t in tags:
            if t in singleton_tags:
                findings.append({
                    "job": "tag-consistency",
                    "severity": "info",
                    "confidence": "MEDIUM",
                    "file": f["rel_path"],
                    "message": f"Singleton tag '{t}' — possible typo or orphan tag.",
                    "auto_aplicable": False,
                })

    return {
        "job": "tag-consistency",
        "status": "ok",
        "files_checked": len(files),
        "unique_tags": len(all_tags),
        "findings": findings,
    }
