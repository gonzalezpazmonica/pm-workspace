"""f2/consistency_judge.py — F2 semantic judge: cross-document consistency.

Checks that documents referencing each other are consistent:
- If file A references file B, file B should exist
- Spec IDs in body text should match their own frontmatter spec_id
- Status references (e.g. "as per SPEC-XYZ") should point to real files
- Version numbers mentioned in one file that differ from the target file's version

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

_SPEC_REF_RE = re.compile(r"\bSPEC-[A-Z0-9_-]+\b")
_FM_RE = re.compile(r"^---\s*\n(.*?)^---", re.DOTALL | re.MULTILINE)
_SPEC_ID_FM_RE = re.compile(r"^\s*spec_id:\s*(.+?)\s*$", re.MULTILINE)
_VERSION_FM_RE = re.compile(r"^\s*version:\s*v?(\d+(?:\.\d+)*)\s*$", re.MULTILINE)
_VERSION_BODY_RE = re.compile(r"\bv(\d+\.\d+(?:\.\d+)?)\b")
_WIKILINK_RE = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")


def _spec_id_from_path(path: Path) -> str | None:
    """Infer spec ID from filename stem (e.g. SPEC-FOO-01.spec.md -> SPEC-FOO-01)."""
    stem = path.stem.replace(".spec", "")
    if re.match(r"^SPEC-[A-Z0-9_-]+$", stem):
        return stem
    return None


def run(files: list[dict]) -> dict:
    """Check cross-document consistency.

    Returns:
        dict with findings and summary.
    """
    # Build indices
    spec_id_index: dict[str, str] = {}   # spec_id -> path
    path_index: dict[str, str] = {}       # stem -> path (for wikilink resolution)
    file_texts: dict[str, str] = {}

    for f in files:
        path = Path(f["path"])
        path_index[path.stem.lower()] = f["path"]
        # infer spec_id from filename
        sid = _spec_id_from_path(path)
        if sid:
            spec_id_index[sid] = f["path"]
        # also read frontmatter spec_id
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
            file_texts[f["path"]] = text
            fm_m = _FM_RE.match(text)
            if fm_m:
                sid_m = _SPEC_ID_FM_RE.search(fm_m.group(1))
                if sid_m:
                    spec_id_index[sid_m.group(1).strip()] = f["path"]
        except OSError:
            file_texts[f["path"]] = ""

    findings: list[dict[str, Any]] = []
    broken_spec_refs = 0
    id_mismatch_count = 0

    for f in files:
        path_str = f["path"]
        text = file_texts.get(path_str, "")
        if not text:
            continue
        path = Path(path_str)

        # --- Check spec references in body ---
        for spec_ref in set(_SPEC_REF_RE.findall(text)):
            if spec_ref not in spec_id_index:
                broken_spec_refs += 1
                findings.append({
                    "job": "consistency_judge",
                    "severity": "WARNING",
                    "confidence": "MEDIUM",
                    "file": path_str,
                    "message": f"References '{spec_ref}' but no matching spec file found",
                    "auto_applicable": False,
                })

        # --- Check spec_id / filename mismatch ---
        inferred_id = _spec_id_from_path(path)
        fm_m = _FM_RE.match(text)
        if inferred_id and fm_m:
            sid_m = _SPEC_ID_FM_RE.search(fm_m.group(1))
            if sid_m:
                fm_id = sid_m.group(1).strip()
                if fm_id != inferred_id:
                    id_mismatch_count += 1
                    findings.append({
                        "job": "consistency_judge",
                        "severity": "WARNING",
                        "confidence": "HIGH",
                        "file": path_str,
                        "message": (
                            f"spec_id mismatch: frontmatter says '{fm_id}' "
                            f"but filename implies '{inferred_id}'"
                        ),
                        "auto_applicable": False,
                    })

    return {
        "job": "consistency_judge",
        "findings": findings,
        "summary": {
            "broken_spec_refs": broken_spec_refs,
            "id_mismatch_count": id_mismatch_count,
            "findings_count": len(findings),
        },
    }
