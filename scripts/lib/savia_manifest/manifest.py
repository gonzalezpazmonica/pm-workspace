"""manifest.py — Load, validate, and normalize savia.manifest.yaml.

SPEC-SAVIA-MANIFEST Slice 1.

Public API:
    load_manifest(path)   — load YAML file, validate, return normalized dict
    validate_manifest(d)  — validate raw dict against manifest.schema.json
    generate_default(workspace_id, description) — return default manifest dict
    write_manifest(path, data) — write normalized manifest to YAML file

Raises:
    ManifestError — any validation or IO failure
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml
import jsonschema

# Locate schemas relative to this file — repo-root/schemas/
# parents: [0]=savia_manifest, [1]=lib, [2]=scripts, [3]=repo-root
_SCHEMAS_DIR = Path(__file__).resolve().parents[3] / "schemas"
_MANIFEST_SCHEMA_PATH = _SCHEMAS_DIR / "manifest.schema.json"


class ManifestError(ValueError):
    """Raised when a manifest cannot be loaded, validated, or normalised."""


def _load_schema() -> dict[str, Any]:
    try:
        return json.loads(_MANIFEST_SCHEMA_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(
            f"Manifest schema not found at {_MANIFEST_SCHEMA_PATH}"
        ) from exc


def validate_manifest(data: dict[str, Any]) -> None:
    """Validate *data* against manifest.schema.json.

    Raises:
        ManifestError: on any validation failure.
    """
    schema = _load_schema()
    try:
        jsonschema.validate(instance=data, schema=schema)
    except jsonschema.ValidationError as exc:
        raise ManifestError(f"Manifest validation failed: {exc.message}") from exc


def _normalize(data: dict[str, Any]) -> dict[str, Any]:
    """Apply defaults and normalise mutable fields."""
    data.setdefault("description", "")
    data.setdefault("packs", [])

    # Normalise component selectors
    components = data.setdefault("components", {})
    for kind in ("agents", "commands", "skills", "hooks"):
        sel = components.setdefault(kind, {"enabled": "all"})
        sel.setdefault("list", [])
        sel.setdefault("exclude", [])

    return data


def load_manifest(path: str | Path) -> dict[str, Any]:
    """Load, validate, and normalise a savia.manifest.yaml file.

    Args:
        path: Path to the manifest file.

    Returns:
        Normalised manifest dict.

    Raises:
        ManifestError: on IO, YAML parse, or validation failure.
    """
    p = Path(path)
    if not p.exists():
        raise ManifestError(f"Manifest file not found: {p}")
    try:
        raw = yaml.safe_load(p.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ManifestError(f"YAML parse error in {p}: {exc}") from exc

    if not isinstance(raw, dict):
        raise ManifestError(f"Manifest must be a YAML mapping, got {type(raw).__name__}")

    validate_manifest(raw)
    return _normalize(raw)


def generate_default(
    workspace_id: str,
    description: str = "My Savia workspace configuration.",
) -> dict[str, Any]:
    """Return a default manifest structure for a new workspace.

    All component kinds default to ``enabled: all``.
    """
    if not workspace_id:
        raise ManifestError("workspace_id must be non-empty")

    return {
        "manifest_version": 1,
        "workspace_id": workspace_id,
        "description": description,
        "components": {
            kind: {"enabled": "all", "list": [], "exclude": []}
            for kind in ("agents", "commands", "skills", "hooks")
        },
        "packs": [],
    }


def write_manifest(path: str | Path, data: dict[str, Any]) -> None:
    """Validate *data* and write it as YAML to *path*.

    Raises:
        ManifestError: on validation or IO failure.
    """
    validate_manifest(data)
    p = Path(path)
    try:
        p.write_text(
            yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=True),
            encoding="utf-8",
        )
    except OSError as exc:
        raise ManifestError(f"Cannot write manifest to {p}: {exc}") from exc
