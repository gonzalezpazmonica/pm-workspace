"""discovery.py — F0: scan workspace and build list of markdown roots to audit.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F0 — Discovery (gate).
Rule #26: Python para lógica, bash solo wrapper.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Scopes
# ---------------------------------------------------------------------------
SCOPE_OPENCODE = "opencode"
SCOPE_CONTENT = "content"
SCOPE_VAULT = "vault"
SCOPE_RAW = "raw"
SCOPE_ALL = "all"

ALL_SCOPES = {SCOPE_OPENCODE, SCOPE_CONTENT, SCOPE_VAULT, SCOPE_RAW, SCOPE_ALL}

# Confidentiality levels (ordered)
CONF_LEVELS = {"N1": 1, "N2": 2, "N3": 3, "N4": 4, "N4b": 5}


def workspace_root() -> Path:
    """Resolve workspace root using provider-agnostic fallback chain (SPEC-127)."""
    for var in ("SAVIA_WORKSPACE_DIR", "CLAUDE_PROJECT_DIR", "OPENCODE_PROJECT_DIR"):
        val = os.environ.get(var)
        if val:
            return Path(val)
    # git rev-parse fallback
    try:
        import subprocess
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        if out:
            return Path(out)
    except Exception:
        pass
    return Path.cwd()


def _projects_dir(ws: Path) -> list[Path]:
    """Return list of project directories under ws/projects/."""
    projects = ws / "projects"
    if not projects.exists():
        return []
    return [p for p in projects.iterdir() if p.is_dir() and not p.name.startswith(".")]


def discover(
    scope: str = SCOPE_ALL,
    slug: Optional[str] = None,
    max_conf_level: str = "N4b",
    workspace: Optional[Path] = None,
) -> dict:
    """Return discovery manifest: roots, file list, metadata.

    Args:
        scope: One of 'all', 'opencode', 'content', 'vault', 'raw'.
        slug: If set, restrict vault/raw to that project slug.
        max_conf_level: Max confidentiality level to include (N1=public ... N4b=pm-only).
        workspace: Workspace root override (defaults to auto-detect).

    Returns:
        dict with keys:
            workspace_root: str
            scope: str
            slug: str | None
            roots: list[str]  # directories scanned
            files: list[dict]  # {path, rel_path, size_bytes, mtime_iso, scope_tag}
            total_files: int
            errors: list[str]
    """
    ws = workspace or workspace_root()
    scope = scope.lower().strip()
    if scope not in ALL_SCOPES:
        scope = SCOPE_ALL

    roots: list[Path] = []
    errors: list[str] = []

    # --- opencode scope ---
    if scope in (SCOPE_ALL, SCOPE_OPENCODE):
        for sub in ("commands", "agents", "skills"):
            p = ws / ".opencode" / sub
            if p.exists():
                roots.append(p)
            # also check .claude/ mirror
            p2 = ws / ".claude" / sub
            if p2.exists():
                roots.append(p2)

    # --- content scope: docs/specs, docs/rules, docs/decisions, docs/propuestas ---
    if scope in (SCOPE_ALL, SCOPE_CONTENT):
        for sub in ("specs", "rules", "decisions", "propuestas", "rules/domain"):
            p = ws / "docs" / sub
            if p.exists():
                roots.append(p)
        # auto-generated insight files at workspace root
        for fname in ("_INSIGHTS.md", "_AUDIT.md"):
            p = ws / fname
            if p.exists():
                roots.append(p)

    # --- vault / raw scopes ---
    if scope in (SCOPE_ALL, SCOPE_VAULT, SCOPE_RAW):
        projects = _projects_dir(ws)
        for proj in projects:
            # filter by slug if provided
            if slug and slug.lower() not in proj.name.lower():
                continue
            if scope in (SCOPE_ALL, SCOPE_VAULT):
                vault = proj / "vault"
                if vault.exists():
                    roots.append(vault)
                # also trazabios-monica style subdirs
                for sub in proj.iterdir():
                    if sub.is_dir() and "vault" in sub.name.lower():
                        roots.append(sub)
            if scope in (SCOPE_ALL, SCOPE_RAW):
                raw = proj / "raw"
                if raw.exists():
                    roots.append(raw)

    # Deduplicate roots preserving order
    seen: set[Path] = set()
    unique_roots: list[Path] = []
    for r in roots:
        rr = r.resolve()
        if rr not in seen:
            seen.add(rr)
            unique_roots.append(r)

    # --- collect markdown files ---
    files: list[dict] = []
    max_level = CONF_LEVELS.get(max_conf_level, 5)

    for root in unique_roots:
        if root.is_file():
            # single file (e.g. _INSIGHTS.md)
            _add_file(root, ws, scope, files, max_level, errors)
        elif root.is_dir():
            for md in root.rglob("*.md"):
                _add_file(md, ws, scope, files, max_level, errors)

    # deduplicate files by resolved path
    seen_files: set[Path] = set()
    unique_files: list[dict] = []
    for f in files:
        rp = Path(f["path"]).resolve()
        if rp not in seen_files:
            seen_files.add(rp)
            unique_files.append(f)

    return {
        "workspace_root": str(ws),
        "scope": scope,
        "slug": slug,
        "roots": [str(r) for r in unique_roots],
        "files": unique_files,
        "total_files": len(unique_files),
        "errors": errors,
    }


def _add_file(
    path: Path,
    ws: Path,
    scope: str,
    files: list,
    max_level: int,
    errors: list,
) -> None:
    """Append file entry if it passes confidentiality gate."""
    try:
        stat = path.stat()
        # Quick frontmatter conf check (first 20 lines only, fast)
        conf = _quick_conf_from_frontmatter(path)
        file_level = CONF_LEVELS.get(conf, 1)
        if file_level > max_level:
            return
        import datetime
        mtime = datetime.datetime.fromtimestamp(stat.st_mtime, tz=datetime.timezone.utc)
        try:
            rel = str(path.relative_to(ws))
        except ValueError:
            rel = str(path)
        files.append({
            "path": str(path),
            "rel_path": rel,
            "size_bytes": stat.st_size,
            "mtime_iso": mtime.isoformat(),
            "scope_tag": scope,
            "conf_level": conf,
        })
    except Exception as exc:
        errors.append(f"{path}: {exc}")


def _quick_conf_from_frontmatter(path: Path) -> str:
    """Extract confidentiality from frontmatter (first 25 lines). Returns 'N1' if absent."""
    try:
        lines = []
        with path.open(encoding="utf-8", errors="ignore") as fh:
            for i, line in enumerate(fh):
                if i >= 25:
                    break
                lines.append(line)
        text = "".join(lines)
        if not text.startswith("---"):
            return "N1"
        for line in lines[1:]:
            if line.startswith("---"):
                break
            if "confidentiality" in line.lower():
                # extract value
                parts = line.split(":", 1)
                if len(parts) == 2:
                    val = parts[1].strip().strip('"').strip("'").upper()
                    if val in CONF_LEVELS:
                        return val
    except Exception:
        pass
    return "N1"


if __name__ == "__main__":
    import json
    result = discover()
    print(json.dumps(result, indent=2, default=str))
