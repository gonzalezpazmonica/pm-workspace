"""resolver.py — Resolve pack source specs to local directories.

SPEC-SAVIA-MANIFEST Slice 2 §2.4, §2.7.

Supported source schemes (Slice 2):
    file://path      — local filesystem, absolute or relative to cwd
    github:user/repo#ref  — stub: clones via HTTPS if git is available,
                            otherwise raises ResolverError with guidance

Public API:
    resolve(source, work_dir)  — resolve source spec to a local Path
    ResolverError              — raised when resolution fails
"""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse


class ResolverError(ValueError):
    """Raised when a pack source cannot be resolved to a local directory."""


def _resolve_file(spec: str, cwd: Path) -> Path:
    """Resolve a file:// source spec to a local Path.

    Args:
        spec: Source string, e.g. "file:///abs/path" or "file://./rel/path".
        cwd:  Base directory for relative paths.

    Returns:
        Absolute Path to the pack directory.

    Raises:
        ResolverError: if path does not exist.
    """
    # Strip scheme: file:// or file:///
    raw = spec[len("file://"):]
    # Handle relative paths starting with . or without leading /
    if raw.startswith("/"):
        p = Path(raw)
    else:
        # e.g. file://./examples/savia-pack-example
        p = cwd / raw.lstrip("./")
        if raw.startswith("."):
            p = cwd / raw[1:].lstrip("/")
            # simpler: resolve from cwd
            p = (cwd / raw).resolve()

    if not p.exists():
        # Last attempt: try as relative to cwd without prefix mangling
        alt = (cwd / raw).resolve()
        if alt.exists():
            return alt
        raise ResolverError(
            f"file:// source does not exist: {p}\n"
            f"  (resolved from spec={spec!r}, cwd={cwd})"
        )
    return p.resolve()


def _resolve_github(spec: str, work_dir: Path) -> Path:
    """Resolve a github:user/repo#ref spec by cloning with git.

    Args:
        spec:     e.g. "github:test-user/my-pack#v1.0.0"
        work_dir: Directory where the clone will be placed.

    Returns:
        Path to the cloned directory.

    Raises:
        ResolverError: if git is unavailable or clone fails.
    """
    # Strip "github:" prefix
    rest = spec[len("github:"):]

    ref: str | None = None
    if "#" in rest:
        repo_path, ref = rest.split("#", 1)
    else:
        repo_path = rest

    url = f"https://github.com/{repo_path}.git"
    clone_dir = work_dir / repo_path.replace("/", "_")

    # Ensure git is available
    try:
        subprocess.run(
            ["git", "--version"],
            check=True,
            capture_output=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        raise ResolverError(
            "git is not available. Cannot resolve github: source.\n"
            "  Install git or use a local file:// path instead."
        ) from exc

    cmd = ["git", "clone", "--depth", "1"]
    if ref:
        cmd += ["--branch", ref]
    cmd += [url, str(clone_dir)]

    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        raise ResolverError(
            f"git clone failed for {url!r} (ref={ref!r}):\n"
            f"  {exc.stderr.strip()}"
        ) from exc

    return clone_dir


def resolve(source: str, work_dir: Path | None = None) -> Path:
    """Resolve a pack source specification to a local directory.

    Args:
        source:   Source spec string, e.g. "file://./my-pack" or
                  "github:user/repo#v1.0.0".
        work_dir: Working directory used as base for relative paths and
                  temporary clone targets.  Defaults to ``Path.cwd()``.

    Returns:
        Absolute Path to a local directory containing the pack.

    Raises:
        ResolverError: if the source cannot be resolved.
    """
    if work_dir is None:
        work_dir = Path.cwd()

    if source.startswith("file://"):
        return _resolve_file(source, work_dir)

    if source.startswith("github:"):
        return _resolve_github(source, work_dir)

    raise ResolverError(
        f"Unsupported source scheme: {source!r}\n"
        f"  Supported: file://, github:"
    )
