"""Linter handler — applies declarative YAML rules to a parsed document."""
from __future__ import annotations
from pathlib import Path
import yaml

from ..registry import get_type
from ..result import Result, Success, Failure
from ..findings import Finding, FindingsReport
from ..parser.handler import parse_document
from ..parser.spec import ParsedDocument
from .spec import LintRule, LintRuleset
from .rules.registry import get_check


def lint_document(
    type_id: str,
    file_path: str | Path,
    rules_path: str | Path | None = None,
) -> Result[FindingsReport]:
    """Lint file against the rules YAML for its doc type."""
    parsed_result = parse_document(type_id, file_path)
    if not parsed_result.ok:
        return parsed_result  # type: ignore[return-value]
    parsed: ParsedDocument = parsed_result.value

    dt = get_type(type_id)
    rules_resolved = Path(rules_path) if rules_path else dt.lint_rules_path
    if rules_resolved is None:
        return Success(FindingsReport.from_findings([]))
    if not rules_resolved.exists():
        return Failure("rules-file-not-found",
                       f"Rules file not found: {rules_resolved}")

    try:
        raw = yaml.safe_load(rules_resolved.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        return Failure("invalid-rules-yaml", f"YAML error in rules: {e}")
    if not isinstance(raw, dict) or "rules" not in raw:
        return Failure("invalid-rules-yaml", "Rules YAML must have top-level 'rules:' list")

    try:
        ruleset = LintRuleset(**raw)
    except Exception as e:
        return Failure("invalid-rules-yaml", f"Rules schema error: {e}")

    findings: list[Finding] = []
    for rule in ruleset.rules:
        if rule.applies_to != type_id:
            continue
        check_fn = get_check(rule.check)
        if check_fn is None:
            return Failure("unknown-check",
                           f"Check {rule.check!r} not registered (rule {rule.id!r})")
        findings.extend(check_fn(parsed, rule))

    return Success(FindingsReport.from_findings(findings))
