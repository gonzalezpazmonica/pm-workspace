"""f1/duplicate_ids.py — F1 job: detect duplicate spec/rule/doc IDs in frontmatter.

Looks for `id:`, `spec_id:`, `rule_id:`, `slug:` fields in frontmatter that appear
in more than one file. Duplicates cause confusion and broken cross-references.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
"""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path
from typing import Any

# Frontmatter fields treated as identifiers
ID_FIELDS = ("id", "spec_id", "rule_id", "slug")
# Regex to extract a frontmatter value: field: value (first --- block only)
_FM_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_FIELD_RE = re.compile(r"^\s*({fields}):\s*(.+?)\s*$".format(fields="|".join(ID_FIELDS)), re.MULTILINE)


def _extract_ids(path: Path) -> dict[str, str]:
    """Return dict of {field: value} found in frontmatter of *path*."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    fm_match = _FM_RE.match(text)
    if not fm_match:
        return {}
    fm_block = fm_match.group(1)
    result: dict[str, str] = {}
    for m in _FIELD_RE.finditer(fm_block):
        field, value = m.group(1), m.group(2).strip("'\"")
        if value and value not in ("null", "~", ""):
            result[field] = value
    return result


def run(files: list[dict]) -> dict:
    """Detect duplicate IDs across all discovered markdown files.

    Args:
        files: list of file dicts from discovery (must include 'path').

    Returns:
        dict with findings list (schema: {job, severity, confidence, file, message, auto_applicable}).
    """
    # field -> value -> [paths]
    index: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))

    for f in files:
        path = Path(f["path"])
        for field, value in _extract_ids(path).items():
            index[field][value].append(f["path"])

    findings: list[dict[str, Any]] = []

    for field, value_map in index.items():
        for value, paths in value_map.items():
            if len(paths) < 2:
                continue
            for p in paths:
                findings.append({
                    "job": "duplicate_ids",
                    "severity": "WARNING",
                    "confidence": "HIGH",
                    "file": p,
                    "message": (
                        f"Duplicate {field}='{value}' also found in "
                        + ", ".join(x for x in paths if x != p)
                    ),
                    "auto_applicable": False,
                })

    return {
        "job": "duplicate_ids",
        "findings": findings,
        "summary": {
            "total_id_fields_scanned": sum(len(v) for v in index.values()),
            "duplicate_groups": sum(
                1
                for value_map in index.values()
                for paths in value_map.values()
                if len(paths) >= 2
            ),
            "findings_count": len(findings),
        },
    }
