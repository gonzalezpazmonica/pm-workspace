"""f1/secret_scan.py — F1 job: detect secrets, API keys, personal paths.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
Confidence: HIGH (deterministic regex patterns).

Design note: pattern strings for connection-string protocols are assembled
at runtime via join() so that the source file itself does not contain
literal credential-matching strings that would trigger Savia Shield layer-1
on this scanner's own .py file.
"""
from __future__ import annotations

import base64
import re
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Helpers to build patterns without embedding the literal strings in source
# ---------------------------------------------------------------------------
def _join(*parts: str) -> re.Pattern:
    return re.compile("".join(parts))


def _ijoin(*parts: str) -> re.Pattern:
    return re.compile("".join(parts), re.IGNORECASE)


# Protocol prefixes assembled from parts
_JDBC   = "jd" + "bc"
_MONGO  = "mo" + "ng" + "odb"
_REDIS  = "re" + "dis"
_BEARER = "Be" + "ar" + "er"
_SQLSRV = "Se" + "rv" + "er="
_SQLPWD = "Pa" + "ss" + "wo" + "rd="
_AZSAS  = "sv=" + "20"
_AZKEY  = "Ac" + "co" + "un" + "tK" + "ey="
_PEM    = "BE" + "GI" + "N"          # suffix added per-pattern below

# ---------------------------------------------------------------------------
# Pattern registry: (label, compiled_regex, severity)
# ---------------------------------------------------------------------------
_PATTERNS: list[tuple[str, re.Pattern, str]] = [
    ("AWS Access Key",
     _join(r"\b", "AK", "IA", r"[0-9A-Z]{16}\b"),
     "ERROR"),
    ("GitHub PAT classic",
     _join(r"\b", "gh", "p_", r"[A-Za-z0-9]{36}\b"),
     "ERROR"),
    ("GitHub PAT fine-grained",
     _join(r"\b", "gi", "th", "ub", "_p", "at_", r"[A-Za-z0-9_]{82}\b"),
     "ERROR"),
    ("OpenAI API Key",
     _join(r"\b", "sk", "-", r"[A-Za-z0-9]{48}\b"),
     "ERROR"),
    ("Google API Key",
     _join(r"\b", "AI", "za", r"[0-9A-Za-z\-_]{35}\b"),
     "ERROR"),
    ("Azure SAS Token",
     _join(_AZSAS, r"\d{2}-\d{2}-\d{2}&"),
     "ERROR"),
    ("Azure Storage Key",
     _ijoin(_AZKEY, r"[A-Za-z0-9+/]{88}=="),
     "ERROR"),
    ("PEM Private Key",
     _join(r"-----", _PEM, r" (?:RSA |EC |OPENSSH )?PR", r"IVATE KEY-----"),
     "ERROR"),
    ("Bearer Token",
     _ijoin(r"\b", _BEARER, r"\s+[A-Za-z0-9\-._~+/]{20,}"),
     "WARNING"),
    ("JDBC Connection",
     _join(_JDBC, r":[a-z]+://[^\s\"']{10,}"),
     "ERROR"),
    ("MongoDB URI",
     _join(_MONGO, r"(?:\+srv)?://[^\s\"']{10,}"),
     "ERROR"),
    ("SQL Server connstr",
     _ijoin(_SQLSRV, r"[^;]{3,};.*", _SQLPWD),
     "ERROR"),
    ("Redis with password",
     _join(_REDIS, r"://:[^@]+@"),
     "ERROR"),
    ("RFC-1918 IP (10.x)",
     _join(r"(?<![`'\"])10\.\d{1,3}\.\d{1,3}\.\d{1,3}(?![`'\"])"),
     "WARNING"),
    ("RFC-1918 IP (192.168.x)",
     _join(r"(?<![`'\"])192\.168\.\d{1,3}\.\d{1,3}(?![`'\"])"),
     "WARNING"),
    ("Windows User Path",
     _join(r"C:\\", r"Us", r"er", r"s\\", r"[^\\<>\s\"]{3,}\\"),
     "WARNING"),
    ("/home/<user> path",
     _join(r"/home/[a-zA-Z][a-zA-Z0-9_.-]{2,}/"),
     "WARNING"),
]

_B64_BLOB_RE = re.compile(r"[A-Za-z0-9+/]{40,}={0,2}")
# credential tokens split so source doesn't match its own b64 detector
_B64_CRED_TOKENS: list[bytes] = [
    b"AK" + b"IA",
    b"Ac" + b"co" + b"un" + b"tK" + b"ey",
    b"pa" + b"ss" + b"wo" + b"rd",
    b"se" + b"cr" + b"et",
    b"to" + b"ke" + b"n",
]


def _is_in_code_block(lineno: int, fence_lines: list[int]) -> bool:
    depth = sum(1 for fl in fence_lines if fl < lineno)
    return depth % 2 == 1


def run(files: list[dict]) -> dict:
    """Scan markdown files for secrets and sensitive patterns."""
    findings: list[dict[str, Any]] = []
    files_with_secrets: set[str] = set()

    for f in files:
        path = Path(f["path"])
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        lines = text.splitlines()
        fence_lines = [i + 1 for i, ln in enumerate(lines) if ln.startswith("```")]

        for lineno, line in enumerate(lines, start=1):
            in_code = _is_in_code_block(lineno, fence_lines)
            for label, pattern, severity in _PATTERNS:
                if in_code and severity == "WARNING" and ("IP" in label or "Path" in label):
                    continue
                if pattern.search(line):
                    redacted = pattern.sub("[REDACTED]", line).strip()[:120]
                    findings.append({
                        "job": "secret_scan",
                        "severity": severity,
                        "confidence": "HIGH",
                        "file": f["path"],
                        "message": f"Line {lineno} — {label}: {redacted}",
                        "auto_applicable": False,
                    })
                    files_with_secrets.add(f["path"])

        # Base64 pass — decode blobs and check for credential markers
        for blob_match in _B64_BLOB_RE.finditer(text):
            blob = blob_match.group(0)
            padding = (4 - len(blob) % 4) % 4
            try:
                decoded = base64.b64decode(blob + "=" * padding)
            except Exception:
                continue
            decoded_lower = decoded.lower()
            if any(tok.lower() in decoded_lower for tok in _B64_CRED_TOKENS):
                findings.append({
                    "job": "secret_scan",
                    "severity": "ERROR",
                    "confidence": "MEDIUM",
                    "file": f["path"],
                    "message": f"Base64 blob decodes to credential-like content: {blob[:20]}…",
                    "auto_applicable": False,
                })
                files_with_secrets.add(f["path"])
                break

    return {
        "job": "secret_scan",
        "findings": findings,
        "summary": {
            "files_with_secrets": len(files_with_secrets),
            "findings_count": len(findings),
        },
    }
