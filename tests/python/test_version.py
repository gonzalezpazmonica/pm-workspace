"""test_version.py — Unit tests for savia_manifest.version (Slice 1).

SPEC-SAVIA-MANIFEST §2.7: version comparison via packaging.version.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

_LIB = Path(__file__).resolve().parents[2] / "scripts" / "lib"
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

from savia_manifest.version import VersionError, compare_versions, satisfies_requirement


class TestCompareVersions:
    def test_gte_true(self) -> None:
        assert compare_versions("4.2.0", ">=", "4.0.0") is True

    def test_gte_false(self) -> None:
        assert compare_versions("3.9.0", ">=", "4.0.0") is False

    def test_lte_true(self) -> None:
        assert compare_versions("1.0.0", "<=", "2.0.0") is True

    def test_eq_true(self) -> None:
        assert compare_versions("1.2.3", "==", "1.2.3") is True

    def test_eq_false(self) -> None:
        assert compare_versions("1.2.3", "==", "1.2.4") is False

    def test_neq_true(self) -> None:
        assert compare_versions("1.0.0", "!=", "2.0.0") is True

    def test_gt_true(self) -> None:
        assert compare_versions("5.0.0", ">", "4.9.9") is True

    def test_lt_true(self) -> None:
        assert compare_versions("0.1.0", "<", "1.0.0") is True

    def test_tilde_eq(self) -> None:
        # ~=4.0.0 means >=4.0.0, <4.1
        assert compare_versions("4.0.5", "~=", "4.0.0") is True

    def test_invalid_version_raises(self) -> None:
        with pytest.raises(VersionError):
            compare_versions("not-a-version", ">=", "1.0.0")

    def test_unknown_operator_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown operator"):
            compare_versions("1.0.0", "??", "1.0.0")


class TestSatisfiesRequirement:
    def test_gte_satisfies(self) -> None:
        assert satisfies_requirement("4.1.0", ">=4.0.0") is True

    def test_gte_not_satisfies(self) -> None:
        assert satisfies_requirement("3.9.0", ">=4.0.0") is False

    def test_range_satisfies(self) -> None:
        assert satisfies_requirement("4.2.1", ">=4.0.0,<5.0.0") is True

    def test_range_not_satisfies_upper(self) -> None:
        assert satisfies_requirement("5.0.0", ">=4.0.0,<5.0.0") is False

    def test_exact_satisfies(self) -> None:
        assert satisfies_requirement("1.2.0", "==1.2.0") is True

    def test_invalid_version_raises(self) -> None:
        with pytest.raises(VersionError):
            satisfies_requirement("bad", ">=1.0.0")

    def test_invalid_specifier_raises(self) -> None:
        with pytest.raises(ValueError):
            satisfies_requirement("1.0.0", ">>1.0.0")
