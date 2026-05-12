"""Check: total document line count under threshold."""
from __future__ import annotations
from ..spec import LintRule
from ...findings import Finding
from ...parser.spec import ParsedDocument
from .registry import register_check


def _check(parsed: ParsedDocument, rule: LintRule) -> list[Finding]:
    max_lines = rule.config.get("max_lines")
    if not isinstance(max_lines, int):
        return []
    if parsed.total_lines <= max_lines:
        return []
    return [Finding(
        severity=rule.severity,
        rule_id=rule.id,
        path="document",
        message=f"Document has {parsed.total_lines} lines, exceeds limit of {max_lines}",
        evidence=None,
        suggestion="Split the document or move sections to separate files",
    )]


register_check("line_count", _check)
