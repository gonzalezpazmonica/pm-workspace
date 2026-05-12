"""Linter contract."""
from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Literal, Any
from ..findings import Severity


class LintRule(BaseModel):
    id: str
    severity: Severity
    applies_to: str
    check: str                # name of registered check function
    config: dict[str, Any] = Field(default_factory=dict)


class LintRuleset(BaseModel):
    rules: list[LintRule] = Field(default_factory=list)


# Errors:
#   "rules-file-not-found"
#   "invalid-rules-yaml"
#   "unknown-check"
