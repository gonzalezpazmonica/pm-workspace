"""Differ contract."""
from __future__ import annotations
from typing import Literal, Any
from pydantic import BaseModel, Field

ChangeKind = Literal[
    "frontmatter-added", "frontmatter-removed", "frontmatter-modified",
    "section-added", "section-removed",
]


class Change(BaseModel):
    kind: ChangeKind
    path: str
    before: Any | None = None
    after: Any | None = None


class DiffResult(BaseModel):
    type_id: str
    file_a: str
    file_b: str
    changes: list[Change] = Field(default_factory=list)
    regression: bool = False
