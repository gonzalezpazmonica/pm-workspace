"""Validator handler — JSON Schema validation against frontmatter."""
from __future__ import annotations
import json
from pathlib import Path
from jsonschema import Draft202012Validator

from ..registry import get_type
from ..result import Result, Success, Failure
from ..parser.handler import parse_document
from .spec import ValidationResult, ValidationError as VErr


def validate_document(
    type_id: str,
    file_path: str | Path,
    schema_path: str | Path | None = None,
) -> Result[ValidationResult]:
    """Validate a document's frontmatter against its registered JSON Schema.

    Uses JSON Schema Draft 2020-12 via ``jsonschema``.

    Args:
        type_id: Registered document type (e.g. ``"spec-md"``).
        file_path: Path to the document to validate.
        schema_path: Override the schema registered for this type.
            ``None`` uses the schema from ``DocType.schema_path``; if that is
            also ``None``, validation is skipped and ``valid=True`` is returned.

    Returns:
        ``Success(ValidationResult)`` — ``valid=True`` when there are no
        schema errors, ``valid=False`` with a list of ``ValidationError``
        objects otherwise.
        ``Failure`` if the file cannot be parsed or the schema file is missing/invalid.
    """
    parsed = parse_document(type_id, file_path)
    if not parsed.ok:
        return parsed  # type: ignore[return-value]

    dt = get_type(type_id)
    schema_resolved = Path(schema_path) if schema_path else dt.schema_path
    if schema_resolved is None:
        return Success(ValidationResult(valid=True, errors=[]))
    if not schema_resolved.exists():
        return Failure("schema-not-found",
                       f"Schema not found: {schema_resolved}")

    try:
        schema = json.loads(schema_resolved.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return Failure("invalid-schema", f"JSON error in schema: {e}")

    target = parsed.value.frontmatter
    validator = Draft202012Validator(schema)
    errors = []
    for err in validator.iter_errors(target):
        path = ".".join(str(p) for p in err.absolute_path) or "(root)"
        errors.append(VErr(path=f"frontmatter.{path}" if path != "(root)" else "frontmatter",
                           message=err.message))

    return Success(ValidationResult(valid=len(errors) == 0, errors=errors))
