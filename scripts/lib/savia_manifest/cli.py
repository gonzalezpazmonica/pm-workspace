"""cli.py — argparse CLI for savia_manifest.

Usage (via wrapper scripts or directly):
    python3 -m savia_manifest.cli init    [--workspace-id ID] [--out PATH]
    python3 -m savia_manifest.cli verify  [--manifest PATH] [--strict] [--check-lock]
    python3 -m savia_manifest.cli install <source> [--workspace PATH]
                                           [--hash SHA256] [--conf-max LEVEL]
    python3 -m savia_manifest.cli lock    [--manifest PATH] [--workspace PATH]
                                           [--out PATH]
    python3 -m savia_manifest.cli sync    [--lock PATH] [--workspace PATH]

Exit codes:
    0 — success
    1 — validation / drift / hash mismatch
    2 — usage error
    3 — internal / IO error
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Sequence

from .manifest import ManifestError, generate_default, load_manifest, write_manifest
from .installer import InstallerError, install
from .pack import PackError
from .resolver import ResolverError, resolve
from .lockfile import (
    LockfileError,
    detect_drift,
    generate_lockfile,
    load_lockfile,
    write_lockfile,
)


def _fail(msg: str, code: int = 3) -> int:
    sys.stderr.write(f"error: {msg}\n")
    return code


# ── sub-commands ──────────────────────────────────────────────────────────────

def cmd_init(args: argparse.Namespace) -> int:
    """Generate a default savia.manifest.yaml."""
    out = Path(args.out)
    if out.exists() and not args.force:
        sys.stderr.write(
            f"error: {out} already exists. Use --force to overwrite.\n"
        )
        return 2

    workspace_id = args.workspace_id or out.parent.name or "my-workspace"
    try:
        data = generate_default(workspace_id, description=args.description)
        write_manifest(out, data)
    except ManifestError as exc:
        return _fail(str(exc))

    sys.stdout.write(f"Created {out}\n")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    """Verify manifest schema; optionally check lockfile freshness."""
    manifest_path = Path(args.manifest)
    try:
        data = load_manifest(manifest_path)
    except ManifestError as exc:
        return _fail(str(exc), code=1)

    result: dict = {
        "valid": True,
        "workspace_id": data.get("workspace_id"),
        "manifest_version": data.get("manifest_version"),
        "component_kinds": list(data.get("components", {}).keys()),
        "pack_count": len(data.get("packs", [])),
    }

    # --check-lock: verify lockfile exists and matches manifest hash
    if getattr(args, "check_lock", False):
        lock_path = Path(getattr(args, "lock", "savia.lock"))
        if not lock_path.exists():
            if getattr(args, "strict", False):
                sys.stderr.write(f"error: lockfile not found: {lock_path}\n")
                return 1
            result["lock_status"] = "missing"
        else:
            try:
                from .lockfile import load_lockfile, _manifest_hash
                lf = load_lockfile(lock_path)
                current_hash = _manifest_hash(data)
                if lf.manifest_hash != current_hash:
                    result["lock_status"] = "stale"
                    if getattr(args, "strict", False):
                        sys.stderr.write(
                            "error: lockfile is stale. Run `savia-lock` to regenerate.\n"
                        )
                        sys.stdout.write(json.dumps(result, indent=2) + "\n")
                        return 1
                else:
                    result["lock_status"] = "up_to_date"
            except LockfileError as exc:
                result["lock_status"] = f"error: {exc}"
                if getattr(args, "strict", False):
                    sys.stdout.write(json.dumps(result, indent=2) + "\n")
                    return 1

    sys.stdout.write(json.dumps(result, indent=2) + "\n")
    return 0


def cmd_lock(args: argparse.Namespace) -> int:
    """Generate or regenerate savia.lock from the manifest."""
    manifest_path = Path(args.manifest)
    workspace = Path(args.workspace)
    out_path = Path(args.out)

    try:
        data = load_manifest(manifest_path)
    except ManifestError as exc:
        return _fail(str(exc), code=1)

    try:
        lf = generate_lockfile(data, workspace)
        write_lockfile(out_path, lf)
    except LockfileError as exc:
        return _fail(str(exc), code=3)

    result = {
        "lockfile": str(out_path),
        "components": len(lf.components),
        "packs": len(lf.packs),
        "manifest_hash": lf.manifest_hash,
    }
    sys.stdout.write(json.dumps(result, indent=2) + "\n")
    return 0


def cmd_sync(args: argparse.Namespace) -> int:
    """Verify workspace matches lockfile; apply declared packs if needed."""
    lock_path = Path(args.lock)
    workspace = Path(args.workspace)

    try:
        lf = load_lockfile(lock_path)
    except LockfileError as exc:
        return _fail(str(exc), code=3)

    drift = detect_drift(lf, workspace)

    if drift and not getattr(args, "force", False):
        result = {
            "synced": False,
            "drift_count": len(drift),
            "drift": [{"kind": d.kind, "id": d.id, "detail": d.detail} for d in drift],
        }
        sys.stdout.write(json.dumps(result, indent=2) + "\n")
        sys.stderr.write(
            f"error: workspace has {len(drift)} drift item(s). "
            "Use --force to sync anyway.\n"
        )
        return 1

    # Apply packs declared in lockfile that are missing
    applied_packs: list[str] = []
    for pack_entry in lf.packs:
        pack_dir = workspace / "savia.packs" / pack_entry.name
        if pack_dir.is_dir():
            try:
                install(
                    pack_dir=pack_dir,
                    workspace_dir=workspace,
                    expected_hash=pack_entry.sha256 or None,
                )
                applied_packs.append(pack_entry.name)
            except (InstallerError, PackError) as exc:
                return _fail(str(exc), code=1)

    result = {
        "synced": True,
        "drift_count": len(drift),
        "packs_applied": applied_packs,
    }
    sys.stdout.write(json.dumps(result, indent=2) + "\n")
    return 0


def cmd_install(args: argparse.Namespace) -> int:
    """Resolve a pack source and install it into a workspace."""
    source: str = args.source
    ws = Path(args.workspace)
    expected_hash: str | None = args.hash or None
    conf_max: str = args.conf_max

    # Resolve source to local directory
    # For github: sources we need a temp dir for cloning
    work_dir = Path(args.work_dir) if args.work_dir else Path.cwd()

    try:
        pack_path = resolve(source, work_dir)
    except ResolverError as exc:
        return _fail(f"Cannot resolve source {source!r}: {exc}", code=3)

    # Install
    try:
        result = install(
            pack_dir=pack_path,
            workspace_dir=ws,
            expected_hash=expected_hash,
            confidentiality_max=conf_max,
        )
    except (InstallerError, PackError) as exc:
        return _fail(str(exc), code=1)

    sys.stdout.write(json.dumps(result, indent=2) + "\n")
    return 0


# ── main ──────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="savia_manifest",
        description="Savia manifest CLI — manage savia.manifest.yaml.",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    # init
    pi = sub.add_parser("init", help="Generate a default savia.manifest.yaml")
    pi.add_argument(
        "--out",
        default="savia.manifest.yaml",
        help="Output path (default: ./savia.manifest.yaml)",
    )
    pi.add_argument(
        "--workspace-id",
        default="",
        help="workspace_id to embed (default: parent directory name)",
    )
    pi.add_argument(
        "--description",
        default="My Savia workspace configuration.",
        help="Human-readable description",
    )
    pi.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing manifest",
    )
    pi.set_defaults(func=cmd_init)

    # verify
    pv = sub.add_parser("verify", help="Validate an existing savia.manifest.yaml")
    pv.add_argument(
        "--manifest",
        default="savia.manifest.yaml",
        help="Path to manifest file (default: ./savia.manifest.yaml)",
    )
    pv.add_argument(
        "--strict",
        action="store_true",
        help="Return exit 1 on any warning (e.g. stale lockfile)",
    )
    pv.add_argument(
        "--check-lock",
        dest="check_lock",
        action="store_true",
        help="Also verify savia.lock matches current manifest",
    )
    pv.add_argument(
        "--lock",
        default="savia.lock",
        help="Path to lockfile when using --check-lock (default: ./savia.lock)",
    )
    pv.set_defaults(func=cmd_verify)

    # lock
    pl = sub.add_parser("lock", help="Generate or regenerate savia.lock")
    pl.add_argument(
        "--manifest",
        default="savia.manifest.yaml",
        help="Path to manifest file (default: ./savia.manifest.yaml)",
    )
    pl.add_argument(
        "--workspace",
        default=".",
        help="Workspace root directory (default: .)",
    )
    pl.add_argument(
        "--out",
        default="savia.lock",
        help="Output lockfile path (default: ./savia.lock)",
    )
    pl.set_defaults(func=cmd_lock)

    # sync
    ps = sub.add_parser("sync", help="Verify and sync workspace against lockfile")
    ps.add_argument(
        "--lock",
        default="savia.lock",
        help="Path to lockfile (default: ./savia.lock)",
    )
    ps.add_argument(
        "--workspace",
        default=".",
        help="Target workspace root directory (default: .)",
    )
    ps.add_argument(
        "--force",
        action="store_true",
        help="Sync even if drift is detected",
    )
    ps.set_defaults(func=cmd_sync)

    # install
    pi2 = sub.add_parser("install", help="Resolve and install a pack into a workspace")
    pi2.add_argument("source", help="Pack source spec: file://path or github:user/repo#ref")
    pi2.add_argument(
        "--workspace",
        default=".",
        help="Target workspace root directory (default: .)",
    )
    pi2.add_argument(
        "--hash",
        default="",
        help="Expected SHA-256 of the pack directory (optional; verified if provided)",
    )
    pi2.add_argument(
        "--conf-max",
        default="N2",
        choices=["N1", "N2", "N3", "N4", "N4b"],
        help="Maximum allowed confidentiality level (default: N2)",
    )
    pi2.add_argument(
        "--work-dir",
        default="",
        help="Working directory for resolving relative paths (default: cwd)",
    )
    pi2.set_defaults(func=cmd_install)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
