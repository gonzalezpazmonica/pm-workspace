"""test_manifest.py — Unit tests for savia_manifest.manifest (Slice 1).

SPEC-SAVIA-MANIFEST §4, Slice 1: >= 20 test cases.
Uses tmp_path (pytest) and fixtures in tests/python/fixtures/manifests/.
Rule #26: Python for data logic; no subprocess in unit tests.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import pytest
import yaml

# Ensure savia_manifest is importable regardless of working directory.
_LIB = Path(__file__).resolve().parents[2] / "scripts" / "lib"
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

from savia_manifest.manifest import (
    ManifestError,
    generate_default,
    load_manifest,
    validate_manifest,
    write_manifest,
)

_FIXTURES = Path(__file__).parent / "fixtures" / "manifests"


# ── helpers ───────────────────────────────────────────────────────────────────

def _make_manifest(tmp_path: Path, data: dict[str, Any]) -> Path:
    p = tmp_path / "savia.manifest.yaml"
    p.write_text(yaml.dump(data, default_flow_style=False), encoding="utf-8")
    return p


# ── TC-01 … TC-06: load valid fixtures ───────────────────────────────────────

class TestLoadValidManifests:
    """TC-01..06: loading valid manifests from disk."""

    def test_load_minimal_fixture(self) -> None:
        """TC-01: minimal manifest with only required fields loads."""
        data = load_manifest(_FIXTURES / "valid_minimal.yaml")
        assert data["manifest_version"] == 1
        assert data["workspace_id"] == "test-ws"

    def test_load_full_fixture(self) -> None:
        """TC-02: full manifest with all fields loads and retains structure."""
        data = load_manifest(_FIXTURES / "valid_full.yaml")
        assert data["workspace_id"] == "test-ws-full"
        assert data["components"]["commands"]["enabled"] == "listed"
        assert "sprint-status" in data["components"]["commands"]["list"]
        assert len(data["packs"]) == 2

    def test_load_normalises_missing_description(self) -> None:
        """TC-03: missing description is normalised to empty string."""
        data = load_manifest(_FIXTURES / "valid_minimal.yaml")
        assert data["description"] == ""

    def test_load_normalises_missing_packs(self) -> None:
        """TC-04: missing packs list is normalised to []."""
        data = load_manifest(_FIXTURES / "valid_minimal.yaml")
        assert data["packs"] == []

    def test_load_normalises_component_selectors(self) -> None:
        """TC-05: missing component selectors are defaulted to enabled:all."""
        data = load_manifest(_FIXTURES / "valid_minimal.yaml")
        for kind in ("agents", "commands", "skills", "hooks"):
            sel = data["components"][kind]
            assert sel["enabled"] == "all"
            assert sel["list"] == []
            assert sel["exclude"] == []

    def test_load_full_fixture_packs(self) -> None:
        """TC-06: pack entries contain name and source."""
        data = load_manifest(_FIXTURES / "valid_full.yaml")
        pack = data["packs"][0]
        assert pack["name"] == "savia-core"
        assert pack["source"] == "builtin"


# ── TC-07 … TC-12: load invalid fixtures ─────────────────────────────────────

class TestLoadInvalidManifests:
    """TC-07..12: loading invalid manifests raises ManifestError."""

    def test_missing_workspace_id(self) -> None:
        """TC-07: manifest without workspace_id raises ManifestError."""
        with pytest.raises(ManifestError, match="workspace_id"):
            load_manifest(_FIXTURES / "invalid_missing_workspace_id.yaml")

    def test_bad_manifest_version(self) -> None:
        """TC-08: manifest_version != 1 raises ManifestError."""
        with pytest.raises(ManifestError):
            load_manifest(_FIXTURES / "invalid_bad_version.yaml")

    def test_workspace_id_invalid_chars(self) -> None:
        """TC-09: workspace_id with spaces fails pattern validation."""
        with pytest.raises(ManifestError):
            load_manifest(_FIXTURES / "invalid_workspace_id_chars.yaml")

    def test_not_a_mapping(self) -> None:
        """TC-10: YAML list instead of mapping raises ManifestError."""
        with pytest.raises(ManifestError):
            load_manifest(_FIXTURES / "invalid_not_yaml.yaml")

    def test_nonexistent_file(self, tmp_path: Path) -> None:
        """TC-11: nonexistent file raises ManifestError."""
        with pytest.raises(ManifestError, match="not found"):
            load_manifest(tmp_path / "does_not_exist.yaml")

    def test_broken_yaml(self, tmp_path: Path) -> None:
        """TC-12: broken YAML content raises ManifestError."""
        bad = tmp_path / "broken.yaml"
        bad.write_text("manifest_version: 1\nworkspace_id: [unclosed", encoding="utf-8")
        with pytest.raises(ManifestError, match="YAML"):
            load_manifest(bad)


# ── TC-13 … TC-15: generate_default ──────────────────────────────────────────

class TestGenerateDefault:
    """TC-13..15: generate_default returns valid structures."""

    def test_generates_valid_manifest(self) -> None:
        """TC-13: generated default passes schema validation."""
        data = generate_default("my-ws")
        validate_manifest(data)  # must not raise

    def test_generates_all_component_kinds(self) -> None:
        """TC-14: all four component kinds present in generated manifest."""
        data = generate_default("my-ws")
        for kind in ("agents", "commands", "skills", "hooks"):
            assert kind in data["components"]
            assert data["components"][kind]["enabled"] == "all"

    def test_empty_workspace_id_raises(self) -> None:
        """TC-15: empty workspace_id raises ManifestError."""
        with pytest.raises(ManifestError):
            generate_default("")


# ── TC-16 … TC-18: write_manifest ────────────────────────────────────────────

class TestWriteManifest:
    """TC-16..18: write_manifest writes valid YAML to disk."""

    def test_write_and_reload(self, tmp_path: Path) -> None:
        """TC-16: written manifest can be reloaded and matches original."""
        data = generate_default("round-trip-ws", "test round-trip")
        p = tmp_path / "savia.manifest.yaml"
        write_manifest(p, data)
        reloaded = load_manifest(p)
        assert reloaded["workspace_id"] == "round-trip-ws"

    def test_write_invalid_raises(self, tmp_path: Path) -> None:
        """TC-17: writing invalid data raises ManifestError."""
        p = tmp_path / "savia.manifest.yaml"
        with pytest.raises(ManifestError):
            write_manifest(p, {"manifest_version": 99, "workspace_id": "ws"})

    def test_write_creates_yaml_file(self, tmp_path: Path) -> None:
        """TC-18: written file is valid YAML parseable by PyYAML."""
        data = generate_default("yaml-check-ws")
        p = tmp_path / "savia.manifest.yaml"
        write_manifest(p, data)
        loaded = yaml.safe_load(p.read_text(encoding="utf-8"))
        assert loaded["manifest_version"] == 1


# ── TC-19 … TC-21: validate_manifest direct ──────────────────────────────────

class TestValidateManifest:
    """TC-19..21: validate_manifest on raw dicts."""

    def test_valid_minimal_dict(self) -> None:
        """TC-19: minimal valid dict passes."""
        validate_manifest({"manifest_version": 1, "workspace_id": "ws-ok"})

    def test_invalid_enabled_value(self) -> None:
        """TC-20: unknown enabled value fails schema."""
        data = {
            "manifest_version": 1,
            "workspace_id": "ws",
            "components": {
                "agents": {"enabled": "unknown-value"}
            },
        }
        with pytest.raises(ManifestError):
            validate_manifest(data)

    def test_invalid_confidentiality_max(self) -> None:
        """TC-21: confidentiality_max outside enum fails schema."""
        data = {
            "manifest_version": 1,
            "workspace_id": "ws",
            "packs": [{"name": "p", "source": "builtin", "confidentiality_max": "N9"}],
        }
        with pytest.raises(ManifestError):
            validate_manifest(data)


# ── TC-22 … TC-23: full round-trip with listed selectors ─────────────────────

class TestRoundTrip:
    """TC-22..23: end-to-end round-trips with complex selectors."""

    def test_listed_commands_survive_roundtrip(self, tmp_path: Path) -> None:
        """TC-22: listed commands preserved after write+reload."""
        data = generate_default("rt-ws")
        data["components"]["commands"] = {
            "enabled": "listed",
            "list": ["cmd-a", "cmd-b"],
            "exclude": [],
        }
        p = tmp_path / "savia.manifest.yaml"
        write_manifest(p, data)
        reloaded = load_manifest(p)
        assert reloaded["components"]["commands"]["list"] == ["cmd-a", "cmd-b"]

    def test_packs_survive_roundtrip(self, tmp_path: Path) -> None:
        """TC-23: pack entries preserved after write+reload."""
        data = generate_default("packs-ws")
        data["packs"] = [
            {"name": "core", "source": "builtin", "version": ">=4.0.0"}
        ]
        p = tmp_path / "savia.manifest.yaml"
        write_manifest(p, data)
        reloaded = load_manifest(p)
        assert reloaded["packs"][0]["name"] == "core"
