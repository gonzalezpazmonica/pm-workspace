"""Document type registry — §2.6 of spec."""
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

ParserStrategy = Literal["frontmatter-prose", "yaml-only"]

_REGISTRY: dict[str, "DocType"] = {}


@dataclass(frozen=True)
class DocType:
    type_id: str
    parser: ParserStrategy
    schema_path: Path | None = None
    lint_rules_path: Path | None = None
    required_frontmatter_fields: tuple[str, ...] = field(default_factory=tuple)


def register_type(
    type_id: str,
    parser: ParserStrategy,
    schema_path: str | Path | None = None,
    lint_rules_path: str | Path | None = None,
    required_frontmatter_fields: tuple[str, ...] = (),
) -> DocType:
    """Register a document type in the global registry.

    Idempotent: re-registering with the same ``type_id`` replaces the previous entry.

    Args:
        type_id: Unique identifier used in CLI and API calls (e.g. ``"spec-md"``).
        parser: Parsing strategy — ``"frontmatter-prose"`` or ``"yaml-only"``.
        schema_path: Path to a JSON Schema file for frontmatter validation.
            ``None`` disables schema validation for this type.
        lint_rules_path: Path to a YAML lint-ruleset file.
            ``None`` means lint returns an empty ``FindingsReport``.
        required_frontmatter_fields: Tuple of field names that must be present.
            Checked at parse time independently of the lint rules.

    Returns:
        The registered ``DocType`` dataclass instance.
    """
    dt = DocType(
        type_id=type_id,
        parser=parser,
        schema_path=Path(schema_path) if schema_path else None,
        lint_rules_path=Path(lint_rules_path) if lint_rules_path else None,
        required_frontmatter_fields=tuple(required_frontmatter_fields),
    )
    _REGISTRY[type_id] = dt
    return dt


def get_type(type_id: str) -> DocType | None:
    """Return the ``DocType`` registered under ``type_id``, or ``None`` if unknown."""
    return _REGISTRY.get(type_id)


def list_types() -> list[str]:
    """Return a sorted list of all registered ``type_id`` strings."""
    return sorted(_REGISTRY.keys())


def _reset() -> None:
    """Clear the registry. For use in tests only."""
    _REGISTRY.clear()
