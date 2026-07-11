#!/usr/bin/env python3
"""Managed Artifacts Library — SE-260 S3
Implements the 6 operations of the managed-artifacts contract:
init, install, sync, uninstall, probe, backup.
"""

import os
import sys
import shutil
import hashlib
from datetime import datetime, timezone
from pathlib import Path


MARKER_PREFIX = "# managed-by: savia"


def _marker(artifact_id: str, version: str = "1") -> str:
    ts = datetime.now(timezone.utc).isoformat()
    return f"{MARKER_PREFIX} {artifact_id} v{version} {ts}"


def _has_our_marker(path: Path, artifact_id: str) -> bool:
    """Check if file has our marker for the given artifact."""
    if not path.exists():
        return False
    try:
        content = path.read_text()
        return f"{MARKER_PREFIX} {artifact_id}" in content
    except Exception:
        return False


def _backup_dir(root: Path, artifact_id: str) -> Path:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    d = root / "output" / "artifacts-backup" / artifact_id / ts
    d.mkdir(parents=True, exist_ok=True)
    return d


def init_artifact(root: Path) -> bool:
    """Validate canonical root is a git repo."""
    return (root / ".git").exists()


def install_artifact(
    root: Path, artifact_id: str, target: Path, template: Path, version: str = "1"
) -> bool:
    """Install artifact to target, respecting ownership."""
    # Ownership check
    if target.exists():
        if _has_our_marker(target, artifact_id):
            backup_artifact(root, artifact_id, target)
        else:
            print(f"ABORT: {target} exists without our marker — refusing to overwrite", file=sys.stderr)
            return False

    # Install
    content = template.read_text()
    marker_line = _marker(artifact_id, version)
    if not content.endswith("\n"):
        content += "\n"
    content += marker_line + "\n"

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    target.chmod(template.stat().st_mode if template.exists() else 0o755)
    return True


def sync_artifact(root: Path, artifact_id: str, target: Path, template: Path) -> bool:
    """Sync installed artifact with template. Returns True if reinstall was needed."""
    if not target.exists():
        return install_artifact(root, artifact_id, target, template)

    current = target.read_text()
    expected = template.read_text()
    if not expected.endswith("\n"):
        expected += "\n"
    expected += _marker(artifact_id) + "\n"

    # Strip marker for comparison
    current_clean = "\n".join(
        line for line in current.split("\n") if not line.startswith(MARKER_PREFIX)
    )
    expected_clean = "\n".join(
        line for line in expected.split("\n") if not line.startswith(MARKER_PREFIX)
    )

    if current_clean.strip() != expected_clean.strip():
        backup_artifact(root, artifact_id, target)
        return install_artifact(root, artifact_id, target, template)
    return False


def uninstall_artifact(root: Path, artifact_id: str, target: Path) -> bool:
    """Uninstall artifact and restore backup if available."""
    if not target.exists():
        return True

    if not _has_our_marker(target, artifact_id):
        print(f"ABORT: {target} does not have our marker — refusing to remove", file=sys.stderr)
        return False

    # Check for backup
    backup_base = root / "output" / "artifacts-backup" / artifact_id
    backups = sorted(backup_base.glob("*")) if backup_base.exists() else []

    if backups:
        latest_backup = backups[-1] / target.name
        if latest_backup.exists():
            shutil.copy2(latest_backup, target)
            return True

    target.unlink()
    return True


def probe_artifact(root: Path, artifact_id: str, target: Path, template: Path) -> int:
    """Health probe. Returns: 0=healthy, 1=degraded, 2=missing."""
    if not target.exists():
        return 2

    if not _has_our_marker(target, artifact_id):
        return 1

    if template.exists():
        current = target.read_text()
        expected = template.read_text()
        current_clean = "\n".join(
            line for line in current.split("\n") if not line.startswith(MARKER_PREFIX)
        )
        expected_clean = "\n".join(
            line for line in expected.split("\n") if not line.startswith(MARKER_PREFIX)
        )
        if current_clean.strip() != expected_clean.strip():
            return 1

    return 0


def backup_artifact(root: Path, artifact_id: str, target: Path) -> bool:
    """Create pre-mutation backup."""
    if not target.exists():
        return True
    bd = _backup_dir(root, artifact_id)
    shutil.copy2(target, bd / target.name)
    return True


# CLI
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Managed Artifacts Library")
    sub = parser.add_subparsers(dest="cmd")

    for cmd_name in ["init", "install", "sync", "uninstall", "probe", "backup"]:
        p = sub.add_parser(cmd_name)
        p.add_argument("--root", default=".", help="Project root")
        p.add_argument("--artifact-id", default="unknown", help="Artifact identifier")
        p.add_argument("--target", help="Target path")
        p.add_argument("--template", help="Template path")
        p.add_argument("--version", default="1", help="Artifact version")

    args = parser.parse_args()
    root = Path(args.root).resolve()

    if args.cmd == "init":
        ok = init_artifact(root)
        sys.exit(0 if ok else 1)
    elif args.cmd == "install":
        ok = install_artifact(root, args.artifact_id, Path(args.target), Path(args.template), args.version)
        sys.exit(0 if ok else 1)
    elif args.cmd == "sync":
        needed = sync_artifact(root, args.artifact_id, Path(args.target), Path(args.template))
        sys.exit(0 if not needed else 1)
    elif args.cmd == "uninstall":
        ok = uninstall_artifact(root, args.artifact_id, Path(args.target))
        sys.exit(0 if ok else 1)
    elif args.cmd == "probe":
        code = probe_artifact(root, args.artifact_id, Path(args.target), Path(args.template))
        sys.exit(code)
    elif args.cmd == "backup":
        ok = backup_artifact(root, args.artifact_id, Path(args.target))
        sys.exit(0 if ok else 1)
