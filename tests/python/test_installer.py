"""test_installer.py — Unit tests for savia_manifest.installer (Slice 2).

SPEC-SAVIA-MANIFEST §4 Slice 2: 15 test cases minimum.
Uses tmp_path; NEVER writes to output/ or ~/.savia/.
"""
from __future__ import annotations

import sys
import shutil
from pathlib import Path
from typing import Any

import pytest
import yaml

_LIB = Path(__file__).resolve().parents[2] / "scripts" / "lib"
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

from savia_manifest.installer import InstallerError, install
from savia_manifest.pack import compute_dir_hash

_FIXTURES = Path(__file__).parent / "fixtures" / "packs"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _build_pack(tmp: Path, **overrides: Any) -> Path:
    """Build a minimal installable pack directory in tmp."""
    pack_dir = tmp / "my-pack"
    pack_dir.mkdir(parents=True)

    data: dict[str, Any] = {
        "pack_version": 1,
        "name": "test-pack",
        "version": "1.0.0",
        "confidentiality_declared": "N1",
        "requires_savia": ">=4.0.0",
        "components": {
            "skills": ["my-skill"],
            "commands": ["my-command"],
        },
        **overrides,
    }
    (pack_dir / "pack.yaml").write_text(
        yaml.dump(data, default_flow_style=False), encoding="utf-8"
    )

    # Create component files
    (pack_dir / "skills").mkdir()
    (pack_dir / "skills" / "my-skill.md").write_text("# my-skill\n", encoding="utf-8")
    (pack_dir / "commands").mkdir()
    (pack_dir / "commands" / "my-command.md").write_text("# my-command\n", encoding="utf-8")

    return pack_dir


def _build_workspace(tmp: Path) -> Path:
    """Create a minimal workspace directory structure."""
    ws = tmp / "workspace"
    for sub in (".opencode/skills", ".opencode/commands", ".opencode/agents", ".opencode/hooks"):
        (ws / sub).mkdir(parents=True)
    return ws


# ── TC-I01..I04: successful installation ─────────────────────────────────────

class TestInstallSuccess:
    def test_basic_install_returns_result(self, tmp_path: Path) -> None:
        """TC-I01: successful install returns dict with name, version, hash."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        result = install(pack, ws)
        assert result["name"] == "test-pack"
        assert result["version"] == "1.0.0"
        assert len(result["hash"]) == 64  # SHA-256 hex

    def test_skill_copied_to_workspace(self, tmp_path: Path) -> None:
        """TC-I02: skill component appears in .opencode/skills/ after install."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        install(pack, ws)
        assert (ws / ".opencode" / "skills" / "my-skill.md").exists()

    def test_command_copied_to_workspace(self, tmp_path: Path) -> None:
        """TC-I03: command component appears in .opencode/commands/ after install."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        install(pack, ws)
        assert (ws / ".opencode" / "commands" / "my-command.md").exists()

    def test_install_is_idempotent(self, tmp_path: Path) -> None:
        """TC-I04: installing the same pack twice does not raise."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        install(pack, ws)
        install(pack, ws)  # second call must not raise
        assert (ws / ".opencode" / "skills" / "my-skill.md").exists()


# ── TC-I05..I07: hash verification ───────────────────────────────────────────

class TestHashVerification:
    def test_correct_hash_accepted(self, tmp_path: Path) -> None:
        """TC-I05: providing correct expected_hash succeeds."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        actual = compute_dir_hash(pack)
        result = install(pack, ws, expected_hash=actual)
        assert result["hash"] == actual

    def test_wrong_hash_raises(self, tmp_path: Path) -> None:
        """TC-I06: wrong expected_hash raises InstallerError."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        with pytest.raises(InstallerError, match="Hash mismatch"):
            install(pack, ws, expected_hash="a" * 64)

    def test_no_hash_skips_check(self, tmp_path: Path) -> None:
        """TC-I07: omitting expected_hash skips verification (no error)."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        result = install(pack, ws, expected_hash=None)
        assert "hash" in result


# ── TC-I08..I10: confidentiality ─────────────────────────────────────────────

class TestConfidentiality:
    def test_n1_pack_allowed_under_n2(self, tmp_path: Path) -> None:
        """TC-I08: N1 pack installs when conf_max=N2."""
        pack = _build_pack(tmp_path, confidentiality_declared="N1")
        ws = _build_workspace(tmp_path)
        result = install(pack, ws, confidentiality_max="N2")
        assert result["name"] == "test-pack"

    def test_n3_pack_rejected_under_n2(self, tmp_path: Path) -> None:
        """TC-I09: N3 pack raises InstallerError when conf_max=N2."""
        pack = _build_pack(tmp_path, confidentiality_declared="N3")
        ws = _build_workspace(tmp_path)
        with pytest.raises(InstallerError, match="exceeds"):
            install(pack, ws, confidentiality_max="N2")

    def test_n2_pack_allowed_under_n2(self, tmp_path: Path) -> None:
        """TC-I10: N2 pack allowed at exact max level."""
        pack = _build_pack(tmp_path, confidentiality_declared="N2")
        ws = _build_workspace(tmp_path)
        result = install(pack, ws, confidentiality_max="N2")
        assert result["name"] == "test-pack"


# ── TC-I11..I12: version requirement ─────────────────────────────────────────

class TestVersionRequirement:
    def test_satisfied_requirement_ok(self, tmp_path: Path) -> None:
        """TC-I11: pack with requires_savia>=4.0.0 installs (installer at 4.0.0)."""
        pack = _build_pack(tmp_path, requires_savia=">=4.0.0")
        ws = _build_workspace(tmp_path)
        result = install(pack, ws)
        assert result["name"] == "test-pack"

    def test_unsatisfied_requirement_raises(self, tmp_path: Path) -> None:
        """TC-I12: pack requiring savia>=99.0.0 raises InstallerError."""
        pack = _build_pack(tmp_path, requires_savia=">=99.0.0")
        ws = _build_workspace(tmp_path)
        with pytest.raises(InstallerError, match="requires savia"):
            install(pack, ws)


# ── TC-I13..I15: edge cases ───────────────────────────────────────────────────

class TestEdgeCases:
    def test_install_fixture_pack(self, tmp_path: Path) -> None:
        """TC-I13: installing from the tests/fixtures valid_pack fixture works."""
        fixture = _FIXTURES / "valid_pack"
        ws = _build_workspace(tmp_path)
        result = install(fixture, ws)
        assert result["name"] == "test-pack"
        assert (ws / ".opencode" / "skills" / "test-skill.md").exists()
        assert (ws / ".opencode" / "commands" / "test-command.md").exists()

    def test_install_example_pack(self, tmp_path: Path) -> None:
        """TC-I14: installing examples/savia-pack-example works end-to-end."""
        example = Path(__file__).resolve().parents[2] / "examples" / "savia-pack-example"
        ws = _build_workspace(tmp_path)
        result = install(example, ws)
        assert result["name"] == "savia-pack-example"
        assert (ws / ".opencode" / "skills" / "example-skill.md").exists()
        assert (ws / ".opencode" / "commands" / "example-command.md").exists()

    def test_components_installed_list_populated(self, tmp_path: Path) -> None:
        """TC-I15: result contains non-empty components_installed list."""
        pack = _build_pack(tmp_path)
        ws = _build_workspace(tmp_path)
        result = install(pack, ws)
        assert len(result["components_installed"]) >= 2
