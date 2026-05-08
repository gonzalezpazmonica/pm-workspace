#!/usr/bin/env python3
"""
vault-validate.py — Frontmatter parser & validator for Savia project vaults.

SPEC-PROJECT-UPDATE Fase 1 §3.5 — funciones puras reusables desde:
  - hook .claude/hooks/vault-frontmatter-gate.sh (subprocess --check)
  - tests/scripts/test_vault_validate.py (import directo)
  - scripts/vault-init.py (auto-test de plantillas, AC-1.10)

CLI:
    python scripts/vault-validate.py --check FILE [--expected-slug SLUG]
    python scripts/vault-validate.py --check-text - --entity-type pbi  (stdin)

Exit codes:
    0 — OK
    2 — invalid (BLOCK semantics for hook)
    3 — file not found / not readable
    4 — usage error

Sin dependencias externas. Parser YAML minimo (sin pyyaml) — la spec exige
tolerancia a entornos sin pip install (bootstrap del workspace).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────────────
# Schema
# ──────────────────────────────────────────────────────────────────────────────

VALID_CONFIDENTIALITY = {"N1", "N2", "N3", "N4", "N4b"}
VALID_ENTITY_TYPES = {
    "pbi", "decision", "meeting", "person", "risk",
    "spec", "session", "digest", "moc", "inbox",
}

# Common (all entity types)
COMMON_REQUIRED = ("confidentiality", "project", "entity_type", "title", "created", "updated")

# Per-entity required fields (beyond COMMON_REQUIRED)
ENTITY_REQUIRED: dict[str, tuple[str, ...]] = {
    "pbi":      ("pbi_id", "state"),
    "decision": ("decision_id", "decided_at"),
    "meeting":  ("meeting_id", "meeting_date", "attendees", "transcript_source", "digest_status"),
    "person":   ("role",),
    "risk":     ("risk_id", "severity", "status", "owner"),
    "spec":     ("spec_id", "status"),
    "session":  ("session_date", "frontend"),
    "digest":   ("source", "source_id", "digested_at", "digest_agent"),
    "moc":      (),
    "inbox":    (),
}

VALID_DIGEST_STATUS = {"pending", "done"}
VALID_RISK_SEVERITY = {"low", "medium", "high", "critical"}
VALID_RISK_STATUS = {"open", "mitigated", "accepted", "closed"}
VALID_SPEC_STATUS = {"pending", "approved", "implemented"}
VALID_SESSION_FRONTEND = {"claude-code", "opencode"}
VALID_DIGEST_SOURCE = {"meeting", "email", "chat", "file", "devops"}

ISO8601_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}"          # date
    r"(?:[T ]\d{2}:\d{2}(?::\d{2})?"  # optional time
    r"(?:\.\d+)?"                  # optional fractional
    r"(?:Z|[+-]\d{2}:?\d{2})?"     # optional tz
    r")?$"
)

DATE_ONLY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

FRONTMATTER_DELIM = "---"


# ──────────────────────────────────────────────────────────────────────────────
# Frontmatter parser (minimal YAML subset — no external deps)
# ──────────────────────────────────────────────────────────────────────────────

def split_frontmatter(text: str) -> tuple[str, str] | tuple[None, None]:
    """Split a markdown text into (frontmatter_str, body_str).

    Returns (None, None) if no frontmatter delimiters found.
    """
    if not text.startswith(FRONTMATTER_DELIM):
        return (None, None)
    lines = text.split("\n")
    if not lines or lines[0].strip() != FRONTMATTER_DELIM:
        return (None, None)
    end_idx = -1
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == FRONTMATTER_DELIM:
            end_idx = i
            break
    if end_idx == -1:
        return (None, None)
    fm_str = "\n".join(lines[1:end_idx])
    body_str = "\n".join(lines[end_idx + 1:])
    return (fm_str, body_str)


def parse_frontmatter(text: str) -> dict[str, Any] | None:
    """Parse YAML-subset frontmatter into a dict. Returns None if no frontmatter.

    Supports: scalar (str/int/bool/null), inline list `[a, b]`, block list `- item`,
    quoted strings, dates as strings. NO nested mappings beyond first level
    (Fase 1 schema is flat).
    """
    fm_str, _ = split_frontmatter(text)
    if fm_str is None:
        return None
    return _parse_yaml_subset(fm_str)


def _parse_yaml_subset(s: str) -> dict[str, Any]:
    out: dict[str, Any] = {}
    lines = s.split("\n")
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        # Top-level key: value
        m = re.match(r"^([A-Za-z_][\w\-]*)\s*:\s*(.*)$", line)
        if not m:
            i += 1
            continue
        key, val = m.group(1), m.group(2).strip()

        if val == "":
            # Block list follows? scan ahead
            block: list[Any] = []
            j = i + 1
            while j < len(lines):
                nxt = lines[j]
                if not nxt.strip():
                    j += 1
                    continue
                bm = re.match(r"^\s*-\s*(.+?)\s*$", nxt)
                if bm and (nxt.startswith(" ") or nxt.startswith("\t")):
                    block.append(_coerce_scalar(bm.group(1)))
                    j += 1
                else:
                    break
            if block:
                out[key] = block
                i = j
                continue
            out[key] = None
            i += 1
            continue

        # Inline list
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            if not inner:
                out[key] = []
            else:
                out[key] = [_coerce_scalar(x.strip()) for x in _split_inline_list(inner)]
            i += 1
            continue

        out[key] = _coerce_scalar(val)
        i += 1
    return out


def _split_inline_list(s: str) -> list[str]:
    """Split `a, b, "c, d", e` respecting double quotes."""
    items: list[str] = []
    buf: list[str] = []
    in_quote = False
    for ch in s:
        if ch == '"':
            in_quote = not in_quote
            buf.append(ch)
        elif ch == "," and not in_quote:
            items.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    if buf:
        items.append("".join(buf).strip())
    return items


def _coerce_scalar(v: str) -> Any:
    v = v.strip()
    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
        return v[1:-1]
    if v.lower() in ("true", "yes"):
        return True
    if v.lower() in ("false", "no"):
        return False
    if v.lower() in ("null", "~", ""):
        return None
    if re.match(r"^-?\d+$", v):
        try:
            return int(v)
        except ValueError:
            return v
    if re.match(r"^-?\d+\.\d+$", v):
        try:
            return float(v)
        except ValueError:
            return v
    return v


# ──────────────────────────────────────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────────────────────────────────────

def validate_frontmatter(
    fm: dict[str, Any] | None,
    *,
    expected_slug: str | None = None,
    expected_path_n_level: str | None = None,
) -> list[str]:
    """Return list of error strings. Empty list = valid.

    expected_slug: if provided, fm["project"] MUST equal it.
    expected_path_n_level: one of "N1","N2","N3","N4","N4b" derived from destination
        path. If fm.confidentiality is N4|N4b but path is not N4|N4b, BLOCK.
    """
    errors: list[str] = []

    if fm is None:
        return ["frontmatter missing or malformed (no `---` block found)"]

    if not isinstance(fm, dict):
        return [f"frontmatter is not a mapping (got {type(fm).__name__})"]

    # Common required
    for field in COMMON_REQUIRED:
        if field not in fm or fm[field] in (None, "", []):
            errors.append(f"missing required field: `{field}`")

    # confidentiality value
    if "confidentiality" in fm and fm["confidentiality"] not in (None, "", []):
        if fm["confidentiality"] not in VALID_CONFIDENTIALITY:
            errors.append(
                f"`confidentiality` invalid: `{fm['confidentiality']}` "
                f"(expected one of {sorted(VALID_CONFIDENTIALITY)})"
            )

    # entity_type value
    et = fm.get("entity_type")
    if et and et not in VALID_ENTITY_TYPES:
        errors.append(
            f"`entity_type` invalid: `{et}` "
            f"(expected one of {sorted(VALID_ENTITY_TYPES)})"
        )
        et = None  # don't try per-entity validation with invalid type

    # project slug match
    if expected_slug is not None and fm.get("project") not in (None, "", []):
        if fm["project"] != expected_slug:
            errors.append(
                f"`project` mismatch: frontmatter says `{fm['project']}`, "
                f"path expects `{expected_slug}`"
            )

    # date-shape fields
    for fld in ("created", "updated"):
        if fm.get(fld) and not _looks_like_iso(fm[fld]):
            errors.append(f"`{fld}` not ISO-8601 shape: `{fm[fld]}`")

    # confidentiality leak check (N4 frontmatter on non-N4 path)
    conf = fm.get("confidentiality")
    if conf in ("N4", "N4b") and expected_path_n_level not in (None, "N4", "N4b"):
        errors.append(
            f"confidentiality `{conf}` cannot be written to path level "
            f"`{expected_path_n_level}` (would leak)"
        )

    # SPEC-128: N1 cannot live inside any project vault (vault is N2-N4b only).
    # When expected_slug is set (path-derived), the file is inside a vault.
    if conf == "N1" and expected_slug is not None:
        errors.append(
            "confidentiality `N1` is not allowed inside a project vault "
            "(vault holds only N2-N4b; N1 belongs in the public workspace)"
        )

    # Per-entity required
    if et:
        for field in ENTITY_REQUIRED.get(et, ()):
            if field not in fm or fm[field] in (None, "", []):
                errors.append(f"missing required field for `{et}`: `{field}`")

        # Per-entity enum checks
        if et == "meeting":
            if fm.get("digest_status") and fm["digest_status"] not in VALID_DIGEST_STATUS:
                errors.append(
                    f"`digest_status` invalid: `{fm['digest_status']}` "
                    f"(expected {sorted(VALID_DIGEST_STATUS)})"
                )
            if fm.get("attendees") is not None and not isinstance(fm["attendees"], list):
                errors.append("`attendees` must be a list")
            if fm.get("meeting_date") and not _looks_like_iso(fm["meeting_date"]):
                errors.append(f"`meeting_date` not ISO-8601 shape: `{fm['meeting_date']}`")
        elif et == "risk":
            if fm.get("severity") and fm["severity"] not in VALID_RISK_SEVERITY:
                errors.append(
                    f"`severity` invalid: `{fm['severity']}` (expected {sorted(VALID_RISK_SEVERITY)})"
                )
            if fm.get("status") and fm["status"] not in VALID_RISK_STATUS:
                errors.append(
                    f"`status` invalid: `{fm['status']}` (expected {sorted(VALID_RISK_STATUS)})"
                )
        elif et == "spec":
            if fm.get("status") and fm["status"] not in VALID_SPEC_STATUS:
                errors.append(
                    f"`status` invalid: `{fm['status']}` (expected {sorted(VALID_SPEC_STATUS)})"
                )
        elif et == "session":
            if fm.get("frontend") and fm["frontend"] not in VALID_SESSION_FRONTEND:
                errors.append(
                    f"`frontend` invalid: `{fm['frontend']}` "
                    f"(expected {sorted(VALID_SESSION_FRONTEND)})"
                )
            if fm.get("session_date") and not _looks_like_iso(fm["session_date"]):
                errors.append(f"`session_date` not ISO-8601 shape: `{fm['session_date']}`")
        elif et == "digest":
            if fm.get("source") and fm["source"] not in VALID_DIGEST_SOURCE:
                errors.append(
                    f"`source` invalid: `{fm['source']}` (expected {sorted(VALID_DIGEST_SOURCE)})"
                )
        elif et == "decision":
            if fm.get("decided_at") and not _looks_like_iso(fm["decided_at"]):
                errors.append(f"`decided_at` not ISO-8601 shape: `{fm['decided_at']}`")

    return errors


def _looks_like_iso(v: Any) -> bool:
    if isinstance(v, str):
        return bool(ISO8601_RE.match(v.strip()))
    return False


# ──────────────────────────────────────────────────────────────────────────────
# Path-level inference (for hook gate)
# ──────────────────────────────────────────────────────────────────────────────

def infer_path_n_level(path: str) -> str:
    """Infer confidentiality level of a destination path.

    Heuristics:
      - paths under projects/ or tenants/ -> N4 (tenant/project private)
      - paths under .savia/ or personal-vault -> N3
      - paths with .local. or settings.local.json -> N2
      - paths under output/ -> N2 (operational, not for repo)
      - everything else (workspace) -> N1
    """
    p = path.replace("\\", "/").lower()
    if "/projects/" in p or p.startswith("projects/"):
        return "N4"
    if "/tenants/" in p or p.startswith("tenants/"):
        return "N4"
    if "/.savia/" in p or "personal-vault" in p:
        return "N3"
    if "/private-agent-memory/" in p or "/config.local/" in p:
        return "N3"
    if ".local." in p or "settings.local.json" in p:
        return "N2"
    if "/output/" in p or p.startswith("output/"):
        return "N2"
    return "N1"


def infer_slug_from_path(path: str) -> str | None:
    """Extract project slug from `projects/{slug}_main/...` or `tenants/{slug}/...`.

    Returns None if no slug detectable.
    """
    norm = path.replace("\\", "/")
    m = re.search(r"(?:^|/)projects/([a-z0-9][\w-]*)_main(?:/|$)", norm)
    if m:
        return m.group(1)
    m = re.search(r"(?:^|/)tenants/([a-z0-9][\w-]*)(?:/|$)", norm)
    if m:
        return m.group(1)
    return None


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def _cmd_check(args: argparse.Namespace) -> int:
    if args.check_text == "-":
        text = sys.stdin.read()
        path_for_inference = args.path or ""
    else:
        target = Path(args.check)
        if not target.is_file():
            print(f"vault-validate: file not found: {target}", file=sys.stderr)
            return 3
        try:
            text = target.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"vault-validate: cannot read {target}: {exc}", file=sys.stderr)
            return 3
        path_for_inference = str(target)

    fm = parse_frontmatter(text)

    expected_slug = args.expected_slug
    if expected_slug is None and path_for_inference:
        expected_slug = infer_slug_from_path(path_for_inference)

    expected_n_level = args.expected_n_level
    if expected_n_level is None and path_for_inference:
        expected_n_level = infer_path_n_level(path_for_inference)

    errors = validate_frontmatter(
        fm,
        expected_slug=expected_slug,
        expected_path_n_level=expected_n_level,
    )

    if args.json:
        out = {
            "ok": not errors,
            "errors": errors,
            "expected_slug": expected_slug,
            "expected_n_level": expected_n_level,
            "entity_type": (fm or {}).get("entity_type"),
        }
        print(json.dumps(out, ensure_ascii=False))
    else:
        if errors:
            print(f"vault-validate: INVALID ({len(errors)} error(s))", file=sys.stderr)
            for e in errors:
                print(f"  - {e}", file=sys.stderr)
        else:
            if not args.quiet:
                print("vault-validate: OK")

    return 0 if not errors else 2


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="vault-validate",
        description="Validate Savia vault note frontmatter.",
    )
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--check", metavar="FILE", help="Validate a markdown file")
    src.add_argument(
        "--check-text",
        metavar="-",
        choices=["-"],
        help="Read text from stdin (use `-`)",
    )
    p.add_argument("--path", help="Hint path for inference when reading from stdin")
    p.add_argument("--expected-slug", help="Override slug check")
    p.add_argument(
        "--expected-n-level",
        choices=sorted(VALID_CONFIDENTIALITY),
        help="Override path N-level inference",
    )
    p.add_argument("--json", action="store_true", help="Emit JSON to stdout")
    p.add_argument("--quiet", action="store_true", help="Suppress OK message")
    args = p.parse_args(argv)
    return _cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
