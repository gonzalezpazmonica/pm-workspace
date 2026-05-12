"""Helpers for structured_doc tests (imported by each test file)."""
from pathlib import Path
import sys

# Ensure scripts/lib is on sys.path so tests can import structured_doc
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))

from structured_doc.registry import register_type, _reset

FIX = ROOT / "tests" / "python" / "fixtures" / "structured_doc"


def setup_spec_md(rules: str | None = "test-rules.yaml",
                  schema: str | None = "test-schema.json") -> None:
    _reset()
    register_type(
        type_id="spec-md",
        parser="frontmatter-prose",
        schema_path=(FIX / schema) if schema else None,
        lint_rules_path=(FIX / rules) if rules else None,
    )


def setup_yaml_only(type_id: str = "raw-yaml") -> None:
    _reset()
    register_type(type_id=type_id, parser="yaml-only")
