"""pack.py — Load and validate Savia packs.

SPEC-SAVIA-MANIFEST Slice 2 §2.3, §2.7.

Public API:
    load_pack(path)          — load + validate pack.yaml from a directory
    compute_dir_hash(path)   — SHA-256 hash of a directory tree (canonical order)
    PackError                — raised on any pack-level failure
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import yaml
import jsonschema

# parents: [0]=savia_manifest, [1]=lib, [2]=scripts, [3]=repo-root
_SCHEMAS_DIR = Path(__file__).resolve().parents[3] / "schemas"
_PACK_SCHEMA_PATH = _SCHEMAS_DIR / "pack.schema.json"

# Confidentiality level ordering (lower index = less restricted)
_CONF_LEVELS: list[str] = ["N1", "N2", "N3", "N4", "N4b"]


class PackError(ValueError):
    """Raised when a pack cannot be loaded, validated, or verified."""


def _load_pack_schema() -> dict[str, Any]:
    try:
        return json.loads(_PACK_SCHEMA_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PackError(
            f"Pack schema not found at {_PACK_SCHEMA_PATH}"
        ) from exc


def validate_pack(data: dict[str, Any]) -> None:
    """Validate *data* against pack.schema.json.

    Raises:
        PackError: on any validation failure.
    """
    schema = _load_pack_schema()
    try:
        jsonschema.validate(instance=data, schema=schema)
    except jsonschema.ValidationError as exc:
        raise PackError(f"Pack validation failed: {exc.message}") from exc


def load_pack(directory: str | Path) -> dict[str, Any]:
    """Load and validate a pack from a directory containing pack.yaml.

    Args:
        directory: Path to the pack root directory.

    Returns:
        Normalised pack dict.

    Raises:
        PackError: on IO, YAML parse, or validation failure.
    """
    d = Path(directory)
    if not d.is_dir():
        raise PackError(f"Pack directory not found: {d}")

    pack_yaml = d / "pack.yaml"
    if not pack_yaml.exists():
        raise PackError(f"pack.yaml not found in {d}")

    try:
        raw = yaml.safe_load(pack_yaml.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise PackError(f"YAML parse error in {pack_yaml}: {exc}") from exc

    if not isinstance(raw, dict):
        raise PackError(
            f"pack.yaml must be a YAML mapping, got {type(raw).__name__}"
        )

    validate_pack(raw)

    # Normalise optional fields
    raw.setdefault("description", "")
    raw.setdefault("license", "")
    raw.setdefault("confidentiality_declared", "N1")
    raw.setdefault("requires_savia", "")
    raw.setdefault("components", {})
    for kind in ("agents", "commands", "skills", "hooks"):
        raw["components"].setdefault(kind, [])

    return raw


def compute_dir_hash(directory: str | Path) -> str:
    """Compute a deterministic SHA-256 digest of a directory tree.

    Algorithm: iterate all files in canonical sorted order (relative path),
    hash each file's relative path + contents; feed all into a single SHA-256.
    Deterministic for same content regardless of filesystem metadata.

    Args:
        directory: Root directory to hash.

    Returns:
        Hex-encoded SHA-256 digest string.

    Raises:
        PackError: if directory does not exist.
    """
    d = Path(directory)
    if not d.is_dir():
        raise PackError(f"Cannot hash non-existent directory: {d}")

    h = hashlib.sha256()
    # Collect all files, sorted by relative path for determinism
    files = sorted(
        p for p in d.rglob("*") if p.is_file()
    )
    for fp in files:
        rel = fp.relative_to(d).as_posix()
        # Hash relative path then content
        h.update(rel.encode("utf-8"))
        h.update(fp.read_bytes())
    return h.hexdigest()


def check_confidentiality(
    pack: dict[str, Any],
    max_level: str,
) -> None:
    """Verify the pack's declared confidentiality does not exceed *max_level*.

    Args:
        pack:      Loaded pack dict (from load_pack).
        max_level: Maximum allowed level, e.g. "N2".

    Raises:
        PackError: if pack exceeds the allowed confidentiality level.
    """
    declared = pack.get("confidentiality_declared", "N1")
    try:
        declared_idx = _CONF_LEVELS.index(declared)
        max_idx = _CONF_LEVELS.index(max_level)
    except ValueError as exc:
        raise PackError(f"Unknown confidentiality level: {exc}") from exc

    if declared_idx > max_idx:
        raise PackError(
            f"Pack declares confidentiality {declared!r} which exceeds "
            f"allowed maximum {max_level!r}"
        )
