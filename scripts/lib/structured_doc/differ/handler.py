"""Differ handler — structural diff between two parsed documents."""
from __future__ import annotations
from pathlib import Path

from ..parser.handler import parse_document
from ..parser.spec import ParsedDocument
from ..result import Result, Success, Failure
from .spec import Change, DiffResult


def diff_documents(
    type_id: str,
    file_a: str | Path,
    file_b: str | Path,
) -> Result[DiffResult]:
    """Compute a structural diff between two documents of the same type.

    Compares frontmatter keys/values and section headings (by level+title).
    Does **not** diff prose body text.

    Args:
        type_id: Registered document type (e.g. ``"spec-md"``).
        file_a: Path to the baseline (older) document.
        file_b: Path to the updated document.

    Returns:
        ``Success(DiffResult)`` with a list of ``Change`` objects and a
        ``regression`` flag (``True`` when frontmatter fields were removed or
        modified, or sections were removed).
        ``Failure`` if either file cannot be parsed.
    """
    pa = parse_document(type_id, file_a)
    if not pa.ok:
        return pa  # type: ignore[return-value]
    pb = parse_document(type_id, file_b)
    if not pb.ok:
        return pb  # type: ignore[return-value]
    a: ParsedDocument = pa.value
    b: ParsedDocument = pb.value

    changes: list[Change] = []

    # Frontmatter diff
    a_fm, b_fm = a.frontmatter, b.frontmatter
    a_keys, b_keys = set(a_fm.keys()), set(b_fm.keys())
    for k in sorted(a_keys - b_keys):
        changes.append(Change(kind="frontmatter-removed", path=f"frontmatter.{k}",
                              before=a_fm[k]))
    for k in sorted(b_keys - a_keys):
        changes.append(Change(kind="frontmatter-added", path=f"frontmatter.{k}",
                              after=b_fm[k]))
    for k in sorted(a_keys & b_keys):
        if a_fm[k] != b_fm[k]:
            changes.append(Change(kind="frontmatter-modified", path=f"frontmatter.{k}",
                                  before=a_fm[k], after=b_fm[k]))

    # Section diff (by title at level)
    a_sections = {(s.level, s.title) for s in a.sections}
    b_sections = {(s.level, s.title) for s in b.sections}
    for level, title in sorted(a_sections - b_sections):
        changes.append(Change(kind="section-removed", path=f"section.{level}.{title}",
                              before=title))
    for level, title in sorted(b_sections - a_sections):
        changes.append(Change(kind="section-added", path=f"section.{level}.{title}",
                              after=title))

    regression = any(c.kind in ("frontmatter-removed", "section-removed",
                                 "frontmatter-modified") for c in changes)

    return Success(DiffResult(
        type_id=type_id,
        file_a=str(file_a),
        file_b=str(file_b),
        changes=changes,
        regression=regression,
    ))
