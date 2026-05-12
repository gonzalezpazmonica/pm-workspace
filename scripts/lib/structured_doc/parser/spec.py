"""Parser contract — Spec & Handler Pattern (D-3).

Input: file path + parser strategy.
Output: ParsedDocument (frontmatter dict + prose text + sections + line map).
Errors as discriminated union: file-not-found | invalid-yaml | empty-document.
"""
from __future__ import annotations
from pathlib import Path
from pydantic import BaseModel, Field


class ParsedSection(BaseModel):
    """A markdown section (heading + body)."""
    level: int            # 1=#, 2=##, ...
    title: str
    line_start: int       # 1-indexed
    line_end: int
    body: str


class ParsedDocument(BaseModel):
    """AST of a structured document."""
    type_id: str
    file_path: str
    frontmatter: dict = Field(default_factory=dict)
    prose: str = ""
    sections: list[ParsedSection] = Field(default_factory=list)
    total_lines: int = 0
    raw_text: str = ""


# Discriminated union of parser errors (string tags used in Failure.error_kind):
#   "file-not-found"
#   "invalid-yaml"
#   "unknown-type"
#   "empty-document"
