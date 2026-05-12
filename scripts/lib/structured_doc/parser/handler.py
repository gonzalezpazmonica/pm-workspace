"""Parser handler — never raises, returns Result."""
from __future__ import annotations
import re
from pathlib import Path
import yaml

from ..registry import get_type
from ..result import Result, Success, Failure
from .spec import ParsedDocument, ParsedSection

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n?", re.DOTALL)
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


def parse_document(type_id: str, file_path: str | Path) -> Result[ParsedDocument]:
    """Parse a file according to the registered doc type's strategy."""
    dt = get_type(type_id)
    if dt is None:
        return Failure("unknown-type", f"Type {type_id!r} not registered")

    p = Path(file_path)
    if not p.exists():
        return Failure("file-not-found", f"File not found: {p}", {"path": str(p)})
    if not p.is_file():
        return Failure("file-not-found", f"Not a file: {p}", {"path": str(p)})

    raw = p.read_text(encoding="utf-8")
    if not raw.strip():
        return Failure("empty-document", f"Document is empty: {p}")

    if dt.parser == "frontmatter-prose":
        return _parse_frontmatter_prose(type_id, p, raw)
    elif dt.parser == "yaml-only":
        return _parse_yaml_only(type_id, p, raw)
    else:
        return Failure("unknown-type", f"Unknown parser strategy: {dt.parser}")


def _parse_frontmatter_prose(type_id: str, p: Path, raw: str) -> Result[ParsedDocument]:
    frontmatter: dict = {}
    prose = raw
    m = _FRONTMATTER_RE.match(raw)
    if m:
        try:
            loaded = yaml.safe_load(m.group(1)) or {}
            if not isinstance(loaded, dict):
                return Failure("invalid-yaml", "Frontmatter is not a mapping",
                               {"path": str(p)})
            frontmatter = loaded
        except yaml.YAMLError as e:
            return Failure("invalid-yaml", f"YAML error: {e}", {"path": str(p)})
        prose = raw[m.end():]
    else:
        # frontmatter-prose can also infer "implicit frontmatter" from
        # bold-key paragraphs ("**Field:** value") — used by spec-md.
        frontmatter = _extract_implicit_frontmatter(raw)
        prose = raw

    sections = _extract_sections(prose, offset=raw.count("\n", 0, len(raw) - len(prose)))
    total_lines = raw.count("\n") + (1 if raw and not raw.endswith("\n") else 0)

    return Success(ParsedDocument(
        type_id=type_id,
        file_path=str(p),
        frontmatter=frontmatter,
        prose=prose,
        sections=sections,
        total_lines=total_lines,
        raw_text=raw,
    ))


def _parse_yaml_only(type_id: str, p: Path, raw: str) -> Result[ParsedDocument]:
    try:
        loaded = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        return Failure("invalid-yaml", f"YAML error: {e}", {"path": str(p)})
    if loaded is None:
        return Failure("empty-document", f"YAML document empty: {p}")
    if not isinstance(loaded, dict):
        return Failure("invalid-yaml", "Top-level YAML must be a mapping",
                       {"path": str(p)})
    total_lines = raw.count("\n") + (1 if raw and not raw.endswith("\n") else 0)
    return Success(ParsedDocument(
        type_id=type_id,
        file_path=str(p),
        frontmatter=loaded,
        prose="",
        sections=[],
        total_lines=total_lines,
        raw_text=raw,
    ))


def _extract_sections(text: str, offset: int = 0) -> list[ParsedSection]:
    """Extract markdown sections by heading. line numbers are 1-indexed in original file."""
    lines = text.splitlines()
    headings = []
    for i, line in enumerate(lines):
        m = _HEADING_RE.match(line)
        if m:
            headings.append((i, len(m.group(1)), m.group(2).strip()))

    sections: list[ParsedSection] = []
    for idx, (line_idx, level, title) in enumerate(headings):
        line_start = line_idx + offset + 1
        if idx + 1 < len(headings):
            line_end = headings[idx + 1][0] + offset
        else:
            line_end = len(lines) + offset
        body = "\n".join(lines[line_idx + 1: (headings[idx + 1][0] if idx + 1 < len(headings) else len(lines))])
        sections.append(ParsedSection(
            level=level, title=title,
            line_start=line_start, line_end=line_end,
            body=body,
        ))
    return sections


_IMPLICIT_FIELD_RE = re.compile(r"^\*\*([^*:]+):\*\*\s+(.+?)\s*$", re.MULTILINE)


def _extract_implicit_frontmatter(raw: str) -> dict:
    """spec-md style: lines like '**Task ID:** WORKSPACE' become frontmatter.

    Only scans the first 60 lines (header block).
    """
    out: dict = {}
    head = "\n".join(raw.splitlines()[:60])
    for m in _IMPLICIT_FIELD_RE.finditer(head):
        key = m.group(1).strip().lower().replace(" ", "_")
        out[key] = m.group(2).strip()
    return out
