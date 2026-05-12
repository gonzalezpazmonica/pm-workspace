"""installer.py — Install a Savia pack into a workspace.

SPEC-SAVIA-MANIFEST Slice 2 §2.7.

Responsibilities:
  1. Verify SHA-256 hash of the pack directory (optional but checked if supplied).
  2. Copy component files to the correct workspace sub-paths.
  3. Idempotent: re-installing same pack is safe (files overwritten).

Component category → workspace target mapping:
    agents   → .opencode/agents/
    commands → .opencode/commands/
    skills   → .opencode/skills/
    hooks    → .opencode/hooks/

Public API:
    install(pack_dir, workspace_dir, expected_hash=None, confidentiality_max="N2")
    InstallerError — raised on hash mismatch or copy failure
"""
from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any

from .pack import PackError, check_confidentiality, compute_dir_hash, load_pack
from .version import VersionError, satisfies_requirement

# Minimum Savia version this installer reports itself as
_SAVIA_VERSION = "4.0.0"

# Mapping of component kind → relative sub-directory inside workspace
_CATEGORY_TARGETS: dict[str, str] = {
    "agents": ".opencode/agents",
    "commands": ".opencode/commands",
    "skills": ".opencode/skills",
    "hooks": ".opencode/hooks",
}


class InstallerError(ValueError):
    """Raised when pack installation fails."""


def _check_hash(pack_dir: Path, expected: str) -> None:
    """Compute actual hash and compare against *expected*.

    Raises:
        InstallerError: on mismatch.
    """
    actual = compute_dir_hash(pack_dir)
    if actual != expected:
        raise InstallerError(
            f"Hash mismatch for pack at {pack_dir}.\n"
            f"  expected: {expected}\n"
            f"  actual:   {actual}"
        )


def _copy_component(
    src_dir: Path,
    name: str,
    target_dir: Path,
) -> list[Path]:
    """Copy a named component from *src_dir* into *target_dir*.

    A component may be a single file (``{name}.md``) or a directory (``{name}/``).
    Both cases are handled.  Returns list of destination paths written.

    Args:
        src_dir:    Directory containing the component (e.g. pack/commands/).
        name:       Component identifier (e.g. "my-command").
        target_dir: Workspace destination directory.

    Returns:
        List of Path objects created/overwritten.

    Raises:
        InstallerError: if the component cannot be found in src_dir.
    """
    target_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    # Try {name}.md first (markdown commands/agents/skills)
    md_file = src_dir / f"{name}.md"
    if md_file.exists():
        dst = target_dir / f"{name}.md"
        shutil.copy2(md_file, dst)
        written.append(dst)
        return written

    # Try directory component
    comp_dir = src_dir / name
    if comp_dir.is_dir():
        dst_dir = target_dir / name
        if dst_dir.exists():
            shutil.rmtree(dst_dir)
        shutil.copytree(comp_dir, dst_dir)
        written.append(dst_dir)
        return written

    # Try any file with the name as stem
    matches = list(src_dir.glob(f"{name}*"))
    if matches:
        for src_file in matches:
            dst = target_dir / src_file.name
            shutil.copy2(src_file, dst)
            written.append(dst)
        return written

    raise InstallerError(
        f"Component {name!r} not found in {src_dir} "
        f"(tried {name}.md, {name}/, {name}*)"
    )


def install(
    pack_dir: str | Path,
    workspace_dir: str | Path,
    expected_hash: str | None = None,
    confidentiality_max: str = "N2",
) -> dict[str, Any]:
    """Install a pack into a Savia workspace.

    Steps:
      1. Validate pack.yaml.
      2. Verify SHA-256 hash if *expected_hash* provided.
      3. Check confidentiality constraints.
      4. Check requires_savia version constraint.
      5. Copy each declared component to the appropriate workspace directory.

    Args:
        pack_dir:           Path to the local pack directory.
        workspace_dir:      Root of the target Savia workspace.
        expected_hash:      Optional expected SHA-256 hex digest of the pack
                            directory.  Verified before any files are copied.
        confidentiality_max: Maximum allowed confidentiality level (default N2).

    Returns:
        dict with keys: name, version, hash, components_installed (list of paths).

    Raises:
        InstallerError: on hash mismatch, confidentiality violation, version
                        incompatibility, or copy failure.
        PackError:      if pack.yaml is missing or invalid.
    """
    pack_path = Path(pack_dir)
    ws = Path(workspace_dir)

    # 1. Load and validate pack metadata
    try:
        pack = load_pack(pack_path)
    except PackError as exc:
        raise InstallerError(f"Invalid pack: {exc}") from exc

    # 2. Hash verification (before modifying workspace)
    actual_hash = compute_dir_hash(pack_path)
    if expected_hash is not None:
        if actual_hash != expected_hash:
            raise InstallerError(
                f"Hash mismatch for pack {pack['name']!r}.\n"
                f"  expected: {expected_hash}\n"
                f"  actual:   {actual_hash}"
            )

    # 3. Confidentiality check
    try:
        check_confidentiality(pack, confidentiality_max)
    except PackError as exc:
        raise InstallerError(str(exc)) from exc

    # 4. Savia version requirement
    req = pack.get("requires_savia", "")
    if req:
        try:
            if not satisfies_requirement(_SAVIA_VERSION, req):
                raise InstallerError(
                    f"Pack {pack['name']!r} requires savia {req!r}, "
                    f"but installer reports version {_SAVIA_VERSION!r}"
                )
        except (VersionError, ValueError) as exc:
            raise InstallerError(
                f"Invalid requires_savia specifier {req!r}: {exc}"
            ) from exc

    # 5. Copy components
    components_installed: list[str] = []
    components = pack.get("components", {})

    for kind, target_sub in _CATEGORY_TARGETS.items():
        names: list[str] = components.get(kind, [])
        if not names:
            continue
        src_kind_dir = pack_path / kind
        target_dir = ws / target_sub

        for name in names:
            try:
                written = _copy_component(src_kind_dir, name, target_dir)
                components_installed.extend(str(p) for p in written)
            except InstallerError:
                # If the kind directory exists but component is missing, re-raise
                if src_kind_dir.exists():
                    raise
                # Category directory absent — skip gracefully (empty declared list)
                break

    return {
        "name": pack["name"],
        "version": pack["version"],
        "hash": actual_hash,
        "components_installed": components_installed,
    }
