"""f1/frontmatter_lint.py — F1 job: validate frontmatter against schema by file type."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any


# Minimal required fields per file type (detected by path pattern)
SCHEMA_RULES: list[tuple[re.Pattern, list[str]]] = [
    (re.compile(r"\.spec\.md$"), ["title"]),
    (re.compile(r"/agents/"), ["description"]),
    (re.compile(r"/skills/"), ["description"]),
    (re.compile(r"/commands/"), []),
    (re.compile(r"/rules/"), []),
    (re.compile(r"/vault/"), []),
]

VALID_CONF_LEVELS = {"N1", "N2", "N3", "N4", "N4b"}


def _parse_frontmatter(path: Path) -> dict | None:
    """Extract YAML frontmatter dict. Returns None if no frontmatter."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None

    if not text.startswith("---"):
        return None

    lines = text.splitlines()
    end = None
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            end = i
            break
    if end is None:
        return None

    fm: dict = {}
    for line in lines[1:end]:
        m = re.match(r'^(\w[\w\-_]*):\s*(.*)$', line)
        if m:
            key = m.group(1).strip()
            val = m.group(2).strip().strip('"').strip("'")
            fm[key] = val
    return fm


def run(files: list[dict]) -> dict:
    findings = []

    for f in files:
        path = Path(f["path"])
        fm = _parse_frontmatter(path)
        rel = f["rel_path"]

        if fm is None:
            # No frontmatter — only flag for types that should have it
            if any(pat.search(rel) for pat, _ in SCHEMA_RULES):
                findings.append({
                    "job": "frontmatter-lint",
                    "severity": "warning",
                    "confidence": "HIGH",
                    "file": rel,
                    "message": "Missing frontmatter — expected for this file type.",
                    "auto_aplicable": False,
                })
            continue

        # Check confidentiality field is valid if present
        conf = fm.get("confidentiality", "")
        if conf and conf.upper() not in VALID_CONF_LEVELS:
            findings.append({
                "job": "frontmatter-lint",
                "severity": "warning",
                "confidence": "HIGH",
                "file": rel,
                "message": f"Invalid confidentiality value: '{conf}'. Expected one of {sorted(VALID_CONF_LEVELS)}.",
                "auto_aplicable": False,
            })

        # Check required fields per schema
        for pat, required in SCHEMA_RULES:
            if pat.search(rel):
                for field in required:
                    if field not in fm or not fm[field]:
                        findings.append({
                            "job": "frontmatter-lint",
                            "severity": "warning",
                            "confidence": "HIGH",
                            "file": rel,
                            "message": f"Required frontmatter field missing: '{field}'.",
                            "auto_aplicable": False,
                        })
                break

    return {
        "job": "frontmatter-lint",
        "status": "ok",
        "files_checked": len(files),
        "findings": findings,
    }
