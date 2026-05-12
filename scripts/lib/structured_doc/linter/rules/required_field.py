"""Check: every named frontmatter field is present and non-empty."""
from __future__ import annotations
from ..spec import LintRule
from ...findings import Finding
from ...parser.spec import ParsedDocument
from .registry import register_check


def _check(parsed: ParsedDocument, rule: LintRule) -> list[Finding]:
    fields = rule.config.get("fields", [])
    out: list[Finding] = []
    for field in fields:
        value = parsed.frontmatter.get(field)
        if value is None or (isinstance(value, str) and not value.strip()):
            out.append(Finding(
                severity=rule.severity,
                rule_id=rule.id,
                path=f"frontmatter.{field}",
                message=f"Missing required field: {field}",
                evidence=None,
                suggestion=f"Add `{field}:` to the frontmatter",
            ))
    return out


register_check("required_field", _check)
