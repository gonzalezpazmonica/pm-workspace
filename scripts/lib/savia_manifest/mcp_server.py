"""mcp_server.py — MCP server ``savia-manifest`` con tools para gestionar manifests.

SPEC-SAVIA-MANIFEST D-7 / Slice 3:
  Expone manifest_verify, manifest_lock, manifest_install como MCP tools
  accesibles desde cualquier frontend MCP-compatible.

Uso:
  python3 -m scripts.lib.savia_manifest.mcp_server   # stdin/stdout (FastMCP)

Dependencia: MCP SDK >= 1.0 (``mcp``). Patrón: scripts/lib/artifacts/mcp_server.py.
Rule #26: lógica Python; bash wrappers invocan este server.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

from .manifest import ManifestError, load_manifest
from .lockfile import (
    LockfileError,
    detect_drift,
    generate_lockfile,
    load_lockfile,
    write_lockfile,
)
from .installer import InstallerError, install
from .pack import PackError
from .resolver import ResolverError, resolve

# ---------------------------------------------------------------------------
# Default paths (overridable via env vars)
# ---------------------------------------------------------------------------

_DEFAULT_MANIFEST = os.environ.get("SAVIA_MANIFEST", "savia.manifest.yaml")
_DEFAULT_LOCK = os.environ.get("SAVIA_LOCK", "savia.lock")
_DEFAULT_WORKSPACE = os.environ.get("SAVIA_WORKSPACE", ".")

# ---------------------------------------------------------------------------
# FastMCP server
# ---------------------------------------------------------------------------

mcp = FastMCP(
    name="savia-manifest",
    instructions=(
        "Savia manifest toolset. "
        "Manages savia.manifest.yaml, savia.lock, and pack installation. "
        "Three canonical tools: manifest_verify, manifest_lock, manifest_install. "
        "SPEC-SAVIA-MANIFEST D-7, Slice 3."
    ),
)


# ---------------------------------------------------------------------------
# Tool 1: manifest_verify
# ---------------------------------------------------------------------------

@mcp.tool(
    name="manifest_verify",
    description=(
        "Validate savia.manifest.yaml and optionally check if savia.lock is up to date. "
        "Returns JSON with valid, workspace_id, component_kinds, pack_count, and "
        "optionally lock_status ('up_to_date'|'stale'|'missing')."
    ),
)
def manifest_verify(
    manifest_path: str = _DEFAULT_MANIFEST,
    check_lock: bool = False,
    lock_path: str = _DEFAULT_LOCK,
) -> dict[str, Any]:
    """Verify a savia.manifest.yaml against its schema.

    Args:
        manifest_path: Path to savia.manifest.yaml.
        check_lock:    If True, also verify the lockfile hash matches.
        lock_path:     Path to savia.lock (used when check_lock=True).

    Returns:
        dict with verification results.
    """
    try:
        data = load_manifest(manifest_path)
    except ManifestError as exc:
        return {"valid": False, "error": str(exc)}

    result: dict[str, Any] = {
        "valid": True,
        "workspace_id": data.get("workspace_id"),
        "manifest_version": data.get("manifest_version"),
        "component_kinds": list(data.get("components", {}).keys()),
        "pack_count": len(data.get("packs", [])),
    }

    if check_lock:
        lp = Path(lock_path)
        if not lp.exists():
            result["lock_status"] = "missing"
        else:
            try:
                from .lockfile import _manifest_hash
                lf = load_lockfile(lp)
                current_hash = _manifest_hash(data)
                result["lock_status"] = (
                    "up_to_date" if lf.manifest_hash == current_hash else "stale"
                )
            except LockfileError as exc:
                result["lock_status"] = f"error: {exc}"

    return result


# ---------------------------------------------------------------------------
# Tool 2: manifest_lock
# ---------------------------------------------------------------------------

@mcp.tool(
    name="manifest_lock",
    description=(
        "Generate or regenerate savia.lock from the current manifest. "
        "Returns JSON with lockfile path, component count, pack count, and manifest_hash. "
        "Idempotent: same manifest + workspace = same lockfile."
    ),
)
def manifest_lock(
    manifest_path: str = _DEFAULT_MANIFEST,
    workspace_path: str = _DEFAULT_WORKSPACE,
    lock_out: str = _DEFAULT_LOCK,
) -> dict[str, Any]:
    """Regenerate savia.lock from the manifest.

    Args:
        manifest_path:  Path to savia.manifest.yaml.
        workspace_path: Workspace root directory.
        lock_out:       Output path for savia.lock.

    Returns:
        dict with lockfile metadata.
    """
    try:
        data = load_manifest(manifest_path)
    except ManifestError as exc:
        return {"success": False, "error": str(exc)}

    try:
        lf = generate_lockfile(data, workspace_path)
        write_lockfile(lock_out, lf)
    except LockfileError as exc:
        return {"success": False, "error": str(exc)}

    return {
        "success": True,
        "lockfile": lock_out,
        "components": len(lf.components),
        "packs": len(lf.packs),
        "manifest_hash": lf.manifest_hash,
    }


# ---------------------------------------------------------------------------
# Tool 3: manifest_install
# ---------------------------------------------------------------------------

@mcp.tool(
    name="manifest_install",
    description=(
        "Resolve a pack source spec and install it into a workspace. "
        "Source formats: 'file:///abs/path' or 'github:user/repo#ref'. "
        "Returns JSON with pack name, version, hash, and installed component paths."
    ),
)
def manifest_install(
    source: str,
    workspace_path: str = _DEFAULT_WORKSPACE,
    expected_hash: str = "",
    confidentiality_max: str = "N2",
) -> dict[str, Any]:
    """Install a pack from a source spec.

    Args:
        source:             Pack source spec.
        workspace_path:     Target workspace root.
        expected_hash:      Optional expected SHA-256 (verified before install).
        confidentiality_max: Maximum allowed confidentiality level.

    Returns:
        dict with installation results.
    """
    try:
        pack_path = resolve(source, Path(workspace_path))
    except ResolverError as exc:
        return {"success": False, "error": f"Cannot resolve {source!r}: {exc}"}

    try:
        result = install(
            pack_dir=pack_path,
            workspace_dir=workspace_path,
            expected_hash=expected_hash or None,
            confidentiality_max=confidentiality_max,
        )
        return {"success": True, **result}
    except (InstallerError, PackError) as exc:
        return {"success": False, "error": str(exc)}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":  # pragma: no cover
    mcp.run()
