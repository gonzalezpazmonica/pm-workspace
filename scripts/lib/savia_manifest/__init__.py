"""savia_manifest — Skill Registry Manifest for Savia workspaces.

SPEC-SAVIA-MANIFEST Slices 1+2+3: schema validation, normalization, semver,
lockfile, packs, installer, MCP server.

Public API:
    load_manifest(path)        — load + validate + normalize a savia.manifest.yaml
    validate_manifest(data)    — validate raw dict against manifest.schema.json
    compare_versions(a, op, b) — semver comparison via packaging.version
    generate_lockfile(...)     — generate deterministic Lockfile
    detect_drift(...)          — detect workspace vs lockfile discrepancies
"""
from __future__ import annotations

from .manifest import load_manifest, validate_manifest, ManifestError
from .version import compare_versions, satisfies_requirement, VersionError
from .lockfile import (
    Lockfile,
    LockfileError,
    DriftItem,
    generate_lockfile,
    load_lockfile,
    write_lockfile,
    detect_drift,
)

__version__ = "0.1.0"

__all__ = [
    "load_manifest",
    "validate_manifest",
    "ManifestError",
    "compare_versions",
    "satisfies_requirement",
    "VersionError",
    "Lockfile",
    "LockfileError",
    "DriftItem",
    "generate_lockfile",
    "load_lockfile",
    "write_lockfile",
    "detect_drift",
]
