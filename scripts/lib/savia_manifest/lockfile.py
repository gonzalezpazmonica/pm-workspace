"""lockfile.py — Deterministic lockfile for SPEC-SAVIA-MANIFEST Slice 3.

Public API:
    Lockfile            — dataclass representing a savia.lock
    generate_lockfile(manifest, workspace_dir) -> Lockfile
    load_lockfile(path) -> Lockfile
    write_lockfile(path, lockfile)
    detect_drift(lockfile, workspace_dir) -> list[DriftItem]
    LockfileError       — raised on any lockfile failure
    DriftItem           — named tuple describing a drift between lock and disk

Determinism guarantees:
  - Component list sorted by id (alphabetical).
  - Pack list sorted by name.
  - YAML serialised with sort_keys=True.
  - SHA-256 computed via pack.compute_dir_hash (canonical sorted file order).
  - generated_at omitted from the structural hash; present only as metadata.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, NamedTuple

import yaml

from .pack import PackError, compute_dir_hash, load_pack
from .manifest import ManifestError, load_manifest

# Locate schemas relative to this file
_SCHEMAS_DIR = Path(__file__).resolve().parents[3] / "schemas"
_LOCK_SCHEMA_PATH = _SCHEMAS_DIR / "lock.schema.json"

# Mapping of component kind → workspace sub-directory
_CATEGORY_DIRS: dict[str, str] = {
    "agents": ".opencode/agents",
    "commands": ".opencode/commands",
    "skills": ".opencode/skills",
    "hooks": ".opencode/hooks",
}


class LockfileError(ValueError):
    """Raised when a lockfile cannot be created, loaded, or verified."""


class DriftItem(NamedTuple):
    """Describes a discrepancy between lockfile and actual workspace state."""

    kind: str   # "missing" | "hash_mismatch" | "version_mismatch"
    id: str     # component id, e.g. "command:sprint-status"
    detail: str # human-readable explanation


# ── Internal helpers ──────────────────────────────────────────────────────────

def _component_id(kind: str, name: str) -> str:
    """Return canonical id string for a component, e.g. 'command:sprint-status'."""
    return f"{kind.rstrip('s')}:{name}"


def _hash_component_file(workspace_dir: Path, kind: str, name: str) -> str | None:
    """Compute SHA-256 of a component file or directory inside workspace_dir.

    Returns hex digest or None if component is not found on disk.
    """
    base = workspace_dir / _CATEGORY_DIRS.get(kind, kind)

    # Try markdown file first, then directory
    candidates = [
        base / f"{name}.md",
        base / name,
    ]
    for c in candidates:
        if c.is_file():
            h = hashlib.sha256()
            h.update(c.read_bytes())
            return h.hexdigest()
        if c.is_dir():
            # Reuse pack hash algorithm (canonical sorted order)
            h = hashlib.sha256()
            files = sorted(p for p in c.rglob("*") if p.is_file())
            for fp in files:
                rel = fp.relative_to(c).as_posix()
                h.update(rel.encode("utf-8"))
                h.update(fp.read_bytes())
            return h.hexdigest()

    return None


def _manifest_hash(manifest_data: dict[str, Any]) -> str:
    """Compute a stable hash of the manifest dict (canonical JSON)."""
    canonical = json.dumps(manifest_data, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


# ── Dataclasses ───────────────────────────────────────────────────────────────

@dataclass
class ComponentEntry:
    id: str       # e.g. "command:sprint-status"
    version: str  # workspace version tag, e.g. "4.0.0" or "builtin"
    sha256: str   # SHA-256 of the component on disk
    source: str   # "builtin" | pack name | path

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "version": self.version,
            "sha256": self.sha256,
            "source": self.source,
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "ComponentEntry":
        return cls(
            id=d["id"],
            version=d.get("version", "builtin"),
            sha256=d["sha256"],
            source=d.get("source", "builtin"),
        )


@dataclass
class PackEntry:
    name: str
    version: str
    sha256: str
    resolved_from: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "sha256": self.sha256,
            "resolved_from": self.resolved_from,
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "PackEntry":
        return cls(
            name=d["name"],
            version=d.get("version", ""),
            sha256=d["sha256"],
            resolved_from=d.get("resolved_from", ""),
        )


@dataclass
class Lockfile:
    lock_version: int = 1
    generated_by: str = "savia-manifest@0.1.0"
    manifest_hash: str = ""  # SHA-256 of the manifest that generated this lock
    components: list[ComponentEntry] = field(default_factory=list)
    packs: list[PackEntry] = field(default_factory=list)

    # ── Serialisation ────────────────────────────────────────────────────────

    def to_dict(self) -> dict[str, Any]:
        """Return a deterministic dict representation (no timestamp)."""
        return {
            "lock_version": self.lock_version,
            "generated_by": self.generated_by,
            "manifest_hash": self.manifest_hash,
            "components": [c.to_dict() for c in
                           sorted(self.components, key=lambda c: c.id)],
            "packs": [p.to_dict() for p in
                      sorted(self.packs, key=lambda p: p.name)],
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Lockfile":
        return cls(
            lock_version=d.get("lock_version", 1),
            generated_by=d.get("generated_by", ""),
            manifest_hash=d.get("manifest_hash", ""),
            components=[ComponentEntry.from_dict(c) for c in d.get("components", [])],
            packs=[PackEntry.from_dict(p) for p in d.get("packs", [])],
        )


# ── Public API ────────────────────────────────────────────────────────────────

def generate_lockfile(
    manifest: dict[str, Any],
    workspace_dir: str | Path,
) -> Lockfile:
    """Generate a deterministic Lockfile from a loaded manifest.

    Scans the workspace_dir for declared components, computes their SHA-256,
    and records installed packs referenced in the manifest.

    Args:
        manifest:      Loaded (normalised) manifest dict.
        workspace_dir: Root of the Savia workspace.

    Returns:
        A new Lockfile instance.

    Raises:
        LockfileError: if workspace_dir does not exist.
    """
    ws = Path(workspace_dir)
    if not ws.is_dir():
        raise LockfileError(f"Workspace directory not found: {ws}")

    lf = Lockfile(manifest_hash=_manifest_hash(manifest))
    components_cfg = manifest.get("components", {})

    for kind, cfg in components_cfg.items():
        mode = cfg.get("enabled", "all")
        exclude = set(cfg.get("exclude", []))
        listed = cfg.get("list", [])
        kind_dir = ws / _CATEGORY_DIRS.get(kind, kind)

        if mode == "all":
            # Discover all components present on disk for this kind
            names = _discover_components(kind_dir)
        elif mode == "listed":
            names = listed
        else:
            # mode == "none" or unknown → skip
            continue

        for name in sorted(n for n in names if n not in exclude):
            sha = _hash_component_file(ws, kind, name)
            if sha is None:
                # Component declared but not found — record with empty hash
                sha = ""
            lf.components.append(ComponentEntry(
                id=_component_id(kind, name),
                version="builtin",
                sha256=sha,
                source="builtin",
            ))

    # Record packs
    for pack_spec in manifest.get("packs", []):
        pack_name = pack_spec.get("name", "")
        pack_version = pack_spec.get("version", "")
        source = pack_spec.get("source", "")
        # Hash the pack install dir if it exists under workspace
        pack_dir = ws / "savia.packs" / pack_name
        if pack_dir.is_dir():
            try:
                pack_sha = compute_dir_hash(pack_dir)
            except PackError:
                pack_sha = ""
        else:
            pack_sha = ""
        lf.packs.append(PackEntry(
            name=pack_name,
            version=str(pack_version),
            sha256=pack_sha,
            resolved_from=source,
        ))

    # Sort for determinism
    lf.components.sort(key=lambda c: c.id)
    lf.packs.sort(key=lambda p: p.name)
    return lf


def _discover_components(kind_dir: Path) -> list[str]:
    """Return names of components present in kind_dir."""
    if not kind_dir.is_dir():
        return []
    names: list[str] = []
    for item in kind_dir.iterdir():
        if item.is_file() and item.suffix == ".md":
            names.append(item.stem)
        elif item.is_dir():
            names.append(item.name)
    return names


def load_lockfile(path: str | Path) -> Lockfile:
    """Load a savia.lock (YAML or JSON) from disk.

    Raises:
        LockfileError: on IO or parse failure.
    """
    p = Path(path)
    if not p.exists():
        raise LockfileError(f"Lockfile not found: {p}")
    try:
        raw = yaml.safe_load(p.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise LockfileError(f"YAML parse error in {p}: {exc}") from exc

    if not isinstance(raw, dict):
        raise LockfileError(f"Lockfile must be a YAML mapping, got {type(raw).__name__}")
    return Lockfile.from_dict(raw)


def write_lockfile(path: str | Path, lockfile: Lockfile) -> None:
    """Write a Lockfile to disk as deterministic YAML.

    Raises:
        LockfileError: on IO failure.
    """
    p = Path(path)
    data = lockfile.to_dict()
    try:
        p.write_text(
            yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=True),
            encoding="utf-8",
        )
    except OSError as exc:
        raise LockfileError(f"Cannot write lockfile to {p}: {exc}") from exc


def detect_drift(
    lockfile: Lockfile,
    workspace_dir: str | Path,
) -> list[DriftItem]:
    """Compare a Lockfile against the actual workspace state.

    Returns a list of DriftItem describing discrepancies.
    Empty list means workspace exactly matches the lockfile.

    Args:
        lockfile:      Lockfile to check against.
        workspace_dir: Root of the Savia workspace.
    """
    ws = Path(workspace_dir)
    drift: list[DriftItem] = []

    for entry in lockfile.components:
        # Parse kind and name from id, e.g. "command:sprint-status"
        if ":" not in entry.id:
            continue
        kind_singular, name = entry.id.split(":", 1)
        # Reconstruct plural kind
        kind = kind_singular + "s"

        actual_sha = _hash_component_file(ws, kind, name)
        if actual_sha is None:
            drift.append(DriftItem(
                kind="missing",
                id=entry.id,
                detail=f"Component not found in workspace at {ws / _CATEGORY_DIRS.get(kind, kind)}",
            ))
        elif entry.sha256 and actual_sha != entry.sha256:
            drift.append(DriftItem(
                kind="hash_mismatch",
                id=entry.id,
                detail=(
                    f"SHA-256 mismatch: lock={entry.sha256[:12]}… "
                    f"actual={actual_sha[:12]}…"
                ),
            ))

    for pack_entry in lockfile.packs:
        pack_dir = ws / "savia.packs" / pack_entry.name
        if pack_entry.sha256 and not pack_dir.is_dir():
            drift.append(DriftItem(
                kind="missing",
                id=f"pack:{pack_entry.name}",
                detail=f"Pack directory not found: {pack_dir}",
            ))
        elif pack_entry.sha256 and pack_dir.is_dir():
            try:
                actual_sha = compute_dir_hash(pack_dir)
            except PackError:
                actual_sha = ""
            if actual_sha != pack_entry.sha256:
                drift.append(DriftItem(
                    kind="hash_mismatch",
                    id=f"pack:{pack_entry.name}",
                    detail=(
                        f"Pack SHA-256 mismatch: lock={pack_entry.sha256[:12]}… "
                        f"actual={actual_sha[:12]}…"
                    ),
                ))

    return drift
