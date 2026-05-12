"""
test_savia_confidentiality.py — Tests unitarios para savia_confidentiality.py

Cubre orden total N1<N2<N3<N4<N4b, parse, y gate de exportación.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Asegurar que scripts/lib está en el path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

from savia_confidentiality import ConfidentialityLevel, is_exportable, parse_level


class TestConfidentialityLevelOrder:
    """Verificar orden total entre niveles."""

    def test_n1_less_than_n2(self) -> None:
        assert ConfidentialityLevel.N1 < ConfidentialityLevel.N2

    def test_n2_less_than_n3(self) -> None:
        assert ConfidentialityLevel.N2 < ConfidentialityLevel.N3

    def test_n3_less_than_n4(self) -> None:
        assert ConfidentialityLevel.N3 < ConfidentialityLevel.N4

    def test_n4_less_than_n4b(self) -> None:
        assert ConfidentialityLevel.N4 < ConfidentialityLevel.N4B

    def test_full_order_ascending(self) -> None:
        levels = ConfidentialityLevel._all_ordered()
        for i in range(len(levels) - 1):
            assert levels[i] < levels[i + 1], f"{levels[i]} < {levels[i + 1]} failed"

    def test_equality_same_level(self) -> None:
        assert ConfidentialityLevel.N2 == ConfidentialityLevel.N2

    def test_n4b_is_most_restrictive(self) -> None:
        for level in ConfidentialityLevel._all_ordered()[:-1]:
            assert level < ConfidentialityLevel.N4B

    def test_n1_is_least_restrictive(self) -> None:
        for level in ConfidentialityLevel._all_ordered()[1:]:
            assert ConfidentialityLevel.N1 < level


class TestParseLevel:
    """Verificar parseo de strings a ConfidentialityLevel."""

    def test_parse_n1(self) -> None:
        assert parse_level("N1") == ConfidentialityLevel.N1

    def test_parse_n4b_lowercase(self) -> None:
        assert parse_level("N4b") == ConfidentialityLevel.N4B

    def test_parse_n4b_uppercase(self) -> None:
        assert parse_level("N4B") == ConfidentialityLevel.N4B

    def test_parse_with_whitespace(self) -> None:
        assert parse_level("  N2  ") == ConfidentialityLevel.N2

    def test_parse_unknown_raises(self) -> None:
        with pytest.raises(ValueError, match="desconocido"):
            parse_level("N5")

    def test_parse_empty_raises(self) -> None:
        with pytest.raises(ValueError):
            parse_level("")


class TestIsExportable:
    """Verificar gate de confidencialidad."""

    def test_n1_exportable_with_n2_threshold(self) -> None:
        assert is_exportable(ConfidentialityLevel.N1, ConfidentialityLevel.N2) is True

    def test_n2_exportable_with_n2_threshold(self) -> None:
        assert is_exportable(ConfidentialityLevel.N2, ConfidentialityLevel.N2) is True

    def test_n3_not_exportable_with_n2_threshold(self) -> None:
        """Escenario clave de la spec: flujo N3 con umbral N2 → NO exporta."""
        assert is_exportable(ConfidentialityLevel.N3, ConfidentialityLevel.N2) is False

    def test_n4_not_exportable_with_n2_threshold(self) -> None:
        assert is_exportable(ConfidentialityLevel.N4, ConfidentialityLevel.N2) is False

    def test_n4b_not_exportable_with_n4_threshold(self) -> None:
        assert is_exportable(ConfidentialityLevel.N4B, ConfidentialityLevel.N4) is False

    def test_n4b_exportable_with_n4b_threshold(self) -> None:
        """Si el umbral es N4b, todos son exportables."""
        for level in ConfidentialityLevel._all_ordered():
            assert is_exportable(level, ConfidentialityLevel.N4B) is True
