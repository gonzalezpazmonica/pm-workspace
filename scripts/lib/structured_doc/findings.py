"""Canonical Finding type — §2.2 of SPEC-STRUCTURED-DOC-TOOLING."""
from __future__ import annotations
from typing import Literal, Optional
from pydantic import BaseModel, Field

Severity = Literal["error", "warning", "info"]


class Finding(BaseModel):
    """A single linting finding emitted by a check function.

    Attributes:
        severity: ``"error"`` (blocks), ``"warning"`` (advisory), or ``"info"``.
        rule_id: ID of the lint rule that produced this finding (e.g. ``"missing-required-field"``).
        path: Dot-notation path within the document (e.g. ``"frontmatter.task_id"``).
        message: Human-readable description of the problem.
        evidence: Optional excerpt from the document that triggered the finding.
        suggestion: Optional fix hint shown in ``--human`` output.
    """
    severity: Severity
    rule_id: str
    path: str
    message: str
    evidence: Optional[str] = None
    suggestion: Optional[str] = None


class Summary(BaseModel):
    """Aggregated counts of findings by severity."""
    errors: int = 0
    warnings: int = 0
    info: int = 0


class FindingsReport(BaseModel):
    """Collection of ``Finding`` objects with a pre-computed ``Summary``.

    Build with ``FindingsReport.from_findings(findings)`` rather than constructing directly.
    """
    findings: list[Finding] = Field(default_factory=list)
    summary: Summary = Field(default_factory=Summary)

    @classmethod
    def from_findings(cls, findings: list[Finding]) -> "FindingsReport":
        """Construct a ``FindingsReport`` and compute severity counts."""
        s = Summary()
        for f in findings:
            if f.severity == "error":
                s.errors += 1
            elif f.severity == "warning":
                s.warnings += 1
            else:
                s.info += 1
        return cls(findings=findings, summary=s)
