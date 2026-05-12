"""f2/completeness_judge.py — F2 semantic judge: document completeness.

Checks that important document types have the expected sections:
- Specs: must have ## Objetivo, ## Criterios de Aceptación (or ## Acceptance Criteria)
- Agents: must have a description paragraph and ## Usage (or ## Uso)
- Commands: must have ## Prerequisitos (or ## Prerequisites) and at least one example
- Rules/domain docs: must have at least one H2 section

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

_H2_RE = re.compile(r"^##\s+(.+)", re.MULTILINE)

# Required section tokens per document type (case-insensitive substring match)
_REQUIRED_SECTIONS: list[tuple[str, list[str], str]] = [
    # (path_fragment, [required section tokens], severity)
    (".spec.md",            ["objetivo", "criterios", "acceptance"],         "WARNING"),
    (".opencode/agents",    ["description", "descripci"],                    "INFO"),
    (".opencode/commands",  ["prerequisit", "ejemplo", "example", "uso", "usage"], "INFO"),
    ("docs/rules",          [],                                              "INFO"),  # just needs ≥1 H2
]


def _get_sections(text: str) -> list[str]:
    return [m.group(1).lower() for m in _H2_RE.finditer(text)]


def _path_matches(path_str: str, fragment: str) -> bool:
    return fragment in path_str


def run(files: list[dict]) -> dict:
    """Assess completeness of document structure.

    Returns:
        dict with findings and summary.
    """
    findings: list[dict[str, Any]] = []
    incomplete_count = 0

    for f in files:
        path_str = f["path"]
        try:
            text = Path(path_str).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        sections = _get_sections(text)

        for fragment, required_tokens, severity in _REQUIRED_SECTIONS:
            if not _path_matches(path_str, fragment):
                continue

            # Must have at least one H2
            if not sections:
                incomplete_count += 1
                findings.append({
                    "job": "completeness_judge",
                    "severity": severity,
                    "confidence": "HIGH",
                    "file": path_str,
                    "message": "Document has no H2 sections — likely incomplete",
                    "auto_applicable": False,
                })
                break

            # Check required tokens
            if required_tokens:
                found = any(
                    any(tok in sec for tok in required_tokens)
                    for sec in sections
                )
                if not found:
                    incomplete_count += 1
                    findings.append({
                        "job": "completeness_judge",
                        "severity": severity,
                        "confidence": "MEDIUM",
                        "file": path_str,
                        "message": (
                            f"Missing expected section. "
                            f"Expected one of: {required_tokens}. "
                            f"Found: {sections[:5]}"
                        ),
                        "auto_applicable": False,
                    })
            break  # matched one pattern, stop checking

    return {
        "job": "completeness_judge",
        "findings": findings,
        "summary": {
            "incomplete_count": incomplete_count,
            "findings_count": len(findings),
        },
    }
