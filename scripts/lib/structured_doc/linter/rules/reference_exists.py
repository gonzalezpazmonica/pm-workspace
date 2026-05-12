"""Check: a frontmatter field matches a regex AND target exists in registry dir."""
from __future__ import annotations
import re
from pathlib import Path
from ..spec import LintRule
from ...findings import Finding
from ...parser.spec import ParsedDocument
from .registry import register_check


def _check(parsed: ParsedDocument, rule: LintRule) -> list[Finding]:
    pattern = rule.config.get("pattern")
    field_name = rule.config.get("field", "depends_on")
    registry_dir = rule.config.get("registry")
    suffix = rule.config.get("suffix", ".spec.md")
    if not pattern or not registry_dir:
        return []

    rx = re.compile(pattern)
    raw_value = parsed.frontmatter.get(field_name)
    if raw_value is None:
        return []
    values = raw_value if isinstance(raw_value, list) else [raw_value]

    out: list[Finding] = []
    reg_path = Path(registry_dir)
    for v in values:
        if not isinstance(v, str):
            continue
        # Strip "-" or " " padding, then walk every token matching the pattern
        for token in re.split(r"[,\s]+", v.strip()):
            if not token or not rx.match(token):
                continue
            target = reg_path / f"{token}{suffix}"
            if not target.exists():
                out.append(Finding(
                    severity=rule.severity,
                    rule_id=rule.id,
                    path=f"frontmatter.{field_name}",
                    message=f"Reference {token!r} does not exist",
                    evidence=f"{field_name}: {v}",
                    suggestion=None,
                ))
    return out


register_check("reference_exists", _check)
