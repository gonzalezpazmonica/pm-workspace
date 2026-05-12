"""test_pack.py — Unit tests for savia_manifest.pack (Slice 2).

SPEC-SAVIA-MANIFEST §4 Slice 2: 15 test cases minimum.
Uses tmp_path; NEVER writes to output/ or ~/.savia/.
Rule #26: Python only, no subprocess in unit tests.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path
from typing import Any

import pytest
import yaml

_LIB = Path(__file__).resolve().parents[2] / "scripts" / "lib"
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

from savia_manifest.pack import (
    PackError,
    check_confidentiality,
    compute_dir_hash,
    load_pack,
    validate_pack,
)

_FIXTURES = Path(__file__).parent / "fixtures" / "packs"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_pack_dir(tmp: Path, data: dict[str, Any]) -> Path:
    """Create a minimal pack directory with pack.yaml in tmp."""
    d = tmp / "pack"
    d.mkdir()
    (d / "pack.yaml").write_text(
        yaml.dump(data, default_flow_style=False), encoding="utf-8"
    )
    return d


def _minimal_pack_data() -> dict[str, Any]:
    return {"pack_version": 1, "name": "test-pack", "version": "1.0.0"}


# ── TC-P01..P04: validate_pack ────────────────────────────────────────────────

class TestValidatePack:
    def test_minimal_valid(self) -> None:
        """TC-P01: minimal required fields pass validation."""
        validate_pack(_minimal_pack_data())

    def test_full_valid(self) -> None:
        """TC-P02: full pack dict passes validation."""
        data = {
            "pack_version": 1,
            "name": "my-pack",
            "version": "1.2.3",
            "description": "desc",
            "license": "MIT",
            "confidentiality_declared": "N1",
            "requires_savia": ">=4.0.0",
            "components": {
                "agents": ["agent-a"],
                "commands": ["cmd-b"],
            },
        }
        validate_pack(data)  # must not raise

    def test_missing_name_raises(self) -> None:
        """TC-P03: missing name raises PackError."""
        with pytest.raises(PackError, match="validation failed"):
            validate_pack({"pack_version": 1, "version": "1.0.0"})

    def test_bad_pack_version_raises(self) -> None:
        """TC-P04: pack_version != 1 raises PackError."""
        with pytest.raises(PackError):
            validate_pack({"pack_version": 2, "name": "p", "version": "1.0.0"})


# ── TC-P05..P09: load_pack ────────────────────────────────────────────────────

class TestLoadPack:
    def test_load_valid_fixture(self) -> None:
        """TC-P05: load valid pack fixture returns correct metadata."""
        pack = load_pack(_FIXTURES / "valid_pack")
        assert pack["name"] == "test-pack"
        assert pack["version"] == "2.0.0"

    def test_load_normalises_components(self) -> None:
        """TC-P06: missing component kinds are normalised to empty lists."""
        pack = load_pack(_FIXTURES / "valid_pack")
        for kind in ("agents", "commands", "skills", "hooks"):
            assert isinstance(pack["components"][kind], list)

    def test_missing_directory_raises(self, tmp_path: Path) -> None:
        """TC-P07: non-existent directory raises PackError."""
        with pytest.raises(PackError, match="not found"):
            load_pack(tmp_path / "ghost")

    def test_missing_pack_yaml_raises(self, tmp_path: Path) -> None:
        """TC-P08: directory without pack.yaml raises PackError."""
        d = tmp_path / "empty-pack"
        d.mkdir()
        with pytest.raises(PackError, match="pack.yaml not found"):
            load_pack(d)

    def test_broken_yaml_raises(self, tmp_path: Path) -> None:
        """TC-P09: malformed YAML in pack.yaml raises PackError."""
        d = tmp_path / "bad-pack"
        d.mkdir()
        (d / "pack.yaml").write_text(
            "pack_version: 1\nname: [unclosed", encoding="utf-8"
        )
        with pytest.raises(PackError, match="YAML"):
            load_pack(d)


# ── TC-P10..P12: compute_dir_hash ────────────────────────────────────────────

class TestComputeDirHash:
    def test_hash_deterministic(self, tmp_path: Path) -> None:
        """TC-P10: same content gives same hash on repeated calls."""
        d = tmp_path / "pack"
        d.mkdir()
        (d / "file.txt").write_bytes(b"hello")
        h1 = compute_dir_hash(d)
        h2 = compute_dir_hash(d)
        assert h1 == h2

    def test_hash_changes_on_content_change(self, tmp_path: Path) -> None:
        """TC-P11: modifying a file changes the hash."""
        d = tmp_path / "pack"
        d.mkdir()
        f = d / "file.txt"
        f.write_bytes(b"hello")
        h1 = compute_dir_hash(d)
        f.write_bytes(b"world")
        h2 = compute_dir_hash(d)
        assert h1 != h2

    def test_hash_nonexistent_raises(self, tmp_path: Path) -> None:
        """TC-P12: hashing non-existent directory raises PackError."""
        with pytest.raises(PackError, match="Cannot hash"):
            compute_dir_hash(tmp_path / "ghost")


# ── TC-P13..P15: check_confidentiality ───────────────────────────────────────

class TestCheckConfidentiality:
    def test_n1_allowed_under_n2(self) -> None:
        """TC-P13: N1 pack is allowed when max is N2."""
        pack = {**_minimal_pack_data(), "confidentiality_declared": "N1"}
        check_confidentiality(pack, "N2")  # must not raise

    def test_n3_rejected_under_n2(self) -> None:
        """TC-P14: N3 pack is rejected when max is N2."""
        pack = {**_minimal_pack_data(), "confidentiality_declared": "N3"}
        with pytest.raises(PackError, match="exceeds"):
            check_confidentiality(pack, "N2")

    def test_same_level_allowed(self) -> None:
        """TC-P15: pack at exactly max level is allowed."""
        pack = {**_minimal_pack_data(), "confidentiality_declared": "N2"}
        check_confidentiality(pack, "N2")  # must not raise
