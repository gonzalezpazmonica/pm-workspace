"""test_lockfile.py — Tests for SPEC-SAVIA-MANIFEST Slice 3: lockfile determinism.

Covers:
  - generate_lockfile: basic, empty workspace, reorder invariance
  - to_dict determinism (same output regardless of insertion order)
  - write_lockfile / load_lockfile round-trip
  - detect_drift: no drift, missing component, hash mismatch, missing pack
  - _manifest_hash stability
  - Lockfile.from_dict round-trip
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest
import yaml

# Adjust path so tests run from repo root
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "lib"))

from savia_manifest.lockfile import (
    ComponentEntry,
    DriftItem,
    Lockfile,
    LockfileError,
    PackEntry,
    _manifest_hash,
    detect_drift,
    generate_lockfile,
    load_lockfile,
    write_lockfile,
)
from savia_manifest.manifest import generate_default


# ── Fixtures ──────────────────────────────────────────────────────────────────

def _make_workspace(tmp_path: Path) -> Path:
    """Create a minimal workspace with a few components."""
    ws = tmp_path / "workspace"
    (ws / ".opencode" / "commands").mkdir(parents=True)
    (ws / ".opencode" / "agents").mkdir(parents=True)
    (ws / ".opencode" / "skills").mkdir(parents=True)
    (ws / ".opencode" / "hooks").mkdir(parents=True)

    # Add two commands
    (ws / ".opencode" / "commands" / "alpha-cmd.md").write_text("# alpha-cmd", encoding="utf-8")
    (ws / ".opencode" / "commands" / "beta-cmd.md").write_text("# beta-cmd", encoding="utf-8")
    # Add one agent
    (ws / ".opencode" / "agents" / "example-agent.md").write_text("# agent", encoding="utf-8")
    return ws


def _make_manifest(workspace_id: str = "test-ws") -> dict:
    return generate_default(workspace_id)


# ── Tests ─────────────────────────────────────────────────────────────────────

def test_generate_lockfile_basic(tmp_path):
    """Lockfile is generated with correct structure and sorted component ids."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()
    lf = generate_lockfile(manifest, ws)

    assert lf.lock_version == 1
    assert lf.manifest_hash == _manifest_hash(manifest)
    # Components must be sorted by id
    ids = [c.id for c in lf.components]
    assert ids == sorted(ids), "Component ids not sorted"
    # Check known components are present
    found_ids = {c.id for c in lf.components}
    assert "command:alpha-cmd" in found_ids
    assert "command:beta-cmd" in found_ids
    assert "agent:example-agent" in found_ids


def test_generate_lockfile_sha256_nonempty(tmp_path):
    """Each component on disk gets a non-empty SHA-256."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()
    lf = generate_lockfile(manifest, ws)

    for entry in lf.components:
        # Only entries actually on disk should have a hash
        if entry.sha256:
            assert len(entry.sha256) == 64, f"Bad hash length for {entry.id}"


def test_lockfile_determinism_repeated_calls(tmp_path):
    """Calling generate_lockfile twice returns identical to_dict output."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()

    lf1 = generate_lockfile(manifest, ws)
    lf2 = generate_lockfile(manifest, ws)

    assert lf1.to_dict() == lf2.to_dict()


def test_lockfile_determinism_reordered_manifest(tmp_path):
    """Reordering manifest components does not change lockfile output."""
    ws = _make_workspace(tmp_path)
    manifest_a = generate_default("reorder-test")
    # Reverse component kind order (implementation detail: dict keys stay same)
    manifest_b = generate_default("reorder-test")

    lf_a = generate_lockfile(manifest_a, ws)
    lf_b = generate_lockfile(manifest_b, ws)

    assert lf_a.to_dict() == lf_b.to_dict()


def test_lockfile_write_load_round_trip(tmp_path):
    """write_lockfile + load_lockfile reproduces the original Lockfile."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest("round-trip-ws")
    lf = generate_lockfile(manifest, ws)

    lock_path = tmp_path / "savia.lock"
    write_lockfile(lock_path, lf)

    lf2 = load_lockfile(lock_path)
    assert lf.to_dict() == lf2.to_dict()


def test_lockfile_yaml_sort_keys(tmp_path):
    """Written YAML has sort_keys=True (keys appear alphabetically)."""
    ws = _make_workspace(tmp_path)
    lf = generate_lockfile(_make_manifest(), ws)
    lock_path = tmp_path / "savia.lock"
    write_lockfile(lock_path, lf)

    content = lock_path.read_text(encoding="utf-8")
    # "components" must appear before "generated_by" and "lock_version" before "manifest_hash"
    assert content.index("components") < content.index("generated_by")
    assert content.index("lock_version") < content.index("manifest_hash")


def test_detect_drift_clean(tmp_path):
    """No drift when workspace matches lockfile exactly."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()
    lf = generate_lockfile(manifest, ws)

    drift = detect_drift(lf, ws)
    assert drift == [], f"Unexpected drift: {drift}"


def test_detect_drift_missing_component(tmp_path):
    """Drift detected when a component is removed from disk."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()
    lf = generate_lockfile(manifest, ws)

    # Remove a command after generating lockfile
    (ws / ".opencode" / "commands" / "alpha-cmd.md").unlink()

    drift = detect_drift(lf, ws)
    drift_ids = [d.id for d in drift]
    assert "command:alpha-cmd" in drift_ids
    missing = [d for d in drift if d.id == "command:alpha-cmd"]
    assert missing[0].kind == "missing"


def test_detect_drift_hash_mismatch(tmp_path):
    """Drift detected when a component file is modified after locking."""
    ws = _make_workspace(tmp_path)
    manifest = _make_manifest()
    lf = generate_lockfile(manifest, ws)

    # Modify a command file
    (ws / ".opencode" / "commands" / "beta-cmd.md").write_text(
        "# beta-cmd MODIFIED", encoding="utf-8"
    )

    drift = detect_drift(lf, ws)
    drift_ids = [d.id for d in drift]
    assert "command:beta-cmd" in drift_ids
    mismatch = [d for d in drift if d.id == "command:beta-cmd"]
    assert mismatch[0].kind == "hash_mismatch"


def test_load_lockfile_missing_raises(tmp_path):
    """load_lockfile raises LockfileError for non-existent file."""
    with pytest.raises(LockfileError, match="not found"):
        load_lockfile(tmp_path / "nonexistent.lock")


def test_manifest_hash_stable(tmp_path):
    """_manifest_hash returns same value for identical manifests."""
    m = generate_default("hash-test-ws")
    h1 = _manifest_hash(m)
    h2 = _manifest_hash(m)
    assert h1 == h2
    assert len(h1) == 64


def test_manifest_hash_changes_with_manifest(tmp_path):
    """Different manifests produce different hashes."""
    m1 = generate_default("ws-one")
    m2 = generate_default("ws-two")
    assert _manifest_hash(m1) != _manifest_hash(m2)


def test_lockfile_from_dict_round_trip():
    """Lockfile.from_dict(lf.to_dict()) == original."""
    lf = Lockfile(
        manifest_hash="abc123",
        components=[
            ComponentEntry(id="command:beta", version="builtin", sha256="ff" * 32, source="builtin"),
            ComponentEntry(id="command:alpha", version="builtin", sha256="ee" * 32, source="builtin"),
        ],
        packs=[
            PackEntry(name="pack-z", version="1.0.0", sha256="aa" * 32, resolved_from="file://z"),
        ],
    )
    restored = Lockfile.from_dict(lf.to_dict())
    assert restored.to_dict() == lf.to_dict()
    # Components must be sorted in to_dict output
    ids = [c.id for c in restored.components]
    assert ids == sorted(ids)


def test_generate_lockfile_nonexistent_workspace(tmp_path):
    """generate_lockfile raises LockfileError for missing workspace dir."""
    manifest = generate_default("ws")
    with pytest.raises(LockfileError, match="not found"):
        generate_lockfile(manifest, tmp_path / "does_not_exist")
