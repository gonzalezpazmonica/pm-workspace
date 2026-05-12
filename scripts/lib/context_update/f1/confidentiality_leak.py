"""f1/confidentiality_leak.py — F1 job: detect notes referencing content of higher conf level."""
from __future__ import annotations

import re
from pathlib import Path

CONF_LEVELS = {"N1": 1, "N2": 2, "N3": 3, "N4": 4, "N4b": 5}

# Patterns that suggest higher-conf content inlined into a lower-conf file
CONF_SIGNALS: list[tuple[re.Pattern, str, str]] = [
    (re.compile(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+\b'), "N3", "Possible full name triple (PII)"),
    (re.compile(r'\b\d{2}/\d{2}/\d{4}\b.*(?:nacimiento|birthday|birth)', re.IGNORECASE), "N3", "Possible birthdate"),
    (re.compile(r'\bsalary\b|\bsueldo\b|\bnómina\b', re.IGNORECASE), "N4", "Salary reference"),
    (re.compile(r'\bpm.only\b|\bconfidential.*n4b\b', re.IGNORECASE), "N4b", "PM-only marker"),
]


def _get_file_conf(f: dict) -> int:
    return CONF_LEVELS.get(f.get("conf_level", "N1"), 1)


def run(files: list[dict]) -> dict:
    findings = []

    for f in files:
        file_level = _get_file_conf(f)
        # Only audit files that are N1 or N2 — higher levels are expected to have sensitive content
        if file_level > 2:
            continue

        path = Path(f["path"])
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue

        for pattern, min_conf, description in CONF_SIGNALS:
            if pattern.search(text):
                signal_level = CONF_LEVELS.get(min_conf, 1)
                if signal_level > file_level:
                    findings.append({
                        "job": "confidentiality-leak",
                        "severity": "error",
                        "confidence": "MEDIUM",
                        "file": f["rel_path"],
                        "message": f"File declared {f.get('conf_level','N1')} but may contain {min_conf}+ content: {description}.",
                        "auto_aplicable": False,
                    })
                    break  # one finding per file is enough

    return {
        "job": "confidentiality-leak",
        "status": "ok",
        "files_checked": len(files),
        "findings": findings,
    }
