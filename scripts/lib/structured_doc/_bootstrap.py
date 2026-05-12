"""Register canonical Savia document types.

Imported by cli.py. Tests use a dedicated fixture or call register_type directly.
"""
from pathlib import Path
from .registry import register_type

# Resolve repo root by walking up from this file (scripts/lib/structured_doc/_bootstrap.py)
_REPO_ROOT = Path(__file__).resolve().parents[3]

register_type(
    type_id="spec-md",
    parser="frontmatter-prose",
    schema_path=_REPO_ROOT / "schemas" / "spec-md.schema.json",
    lint_rules_path=_REPO_ROOT / "rules" / "spec-md.lint.yaml",
)
