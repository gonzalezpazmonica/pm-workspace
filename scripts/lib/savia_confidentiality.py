"""
savia_confidentiality.py — Orden total entre niveles de confidencialidad Savia.

Niveles (de menor a mayor restricción): N1 < N2 < N3 < N4 < N4b

Usado por otel_exporter para gate de confidencialidad (D-4 de SPEC-FLOW-OBSERVABILITY).
Reutilizable en cualquier otro módulo que necesite comparar niveles.
"""
from __future__ import annotations

from enum import Enum


class ConfidentialityLevel(str, Enum):
    """Niveles de confidencialidad con orden total.

    Orden ascendente (menor a mayor restricción):
    N1 < N2 < N3 < N4 < N4b
    """

    N1 = "N1"   # Público
    N2 = "N2"   # Empresa
    N3 = "N3"   # Usuario
    N4 = "N4"   # Proyecto
    N4B = "N4b"  # PM-Only

    # Orden total definido explícitamente
    _ORDER: list[str]  # type: ignore[misc]

    @classmethod
    def _all_ordered(cls) -> list["ConfidentialityLevel"]:
        return [cls.N1, cls.N2, cls.N3, cls.N4, cls.N4B]

    def rank(self) -> int:
        """Rango numérico (0-4). Mayor rango = más restrictivo."""
        return self._all_ordered().index(self)

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, ConfidentialityLevel):
            return NotImplemented
        return self.rank() < other.rank()

    def __le__(self, other: object) -> bool:
        if not isinstance(other, ConfidentialityLevel):
            return NotImplemented
        return self.rank() <= other.rank()

    def __gt__(self, other: object) -> bool:
        if not isinstance(other, ConfidentialityLevel):
            return NotImplemented
        return self.rank() > other.rank()

    def __ge__(self, other: object) -> bool:
        if not isinstance(other, ConfidentialityLevel):
            return NotImplemented
        return self.rank() >= other.rank()


def parse_level(value: str) -> ConfidentialityLevel:
    """Parsea un string a ConfidentialityLevel (case-insensitive).

    Args:
        value: String como "N1", "N2", "N3", "N4", "N4b" (o variantes de case).

    Returns:
        ConfidentialityLevel correspondiente.

    Raises:
        ValueError: Si el valor no es reconocido.
    """
    normalized = value.strip().upper()
    # N4B es especial: el enum value es "N4b" pero se puede escribir "N4B"
    mapping: dict[str, ConfidentialityLevel] = {
        "N1": ConfidentialityLevel.N1,
        "N2": ConfidentialityLevel.N2,
        "N3": ConfidentialityLevel.N3,
        "N4": ConfidentialityLevel.N4,
        "N4B": ConfidentialityLevel.N4B,
    }
    if normalized not in mapping:
        raise ValueError(
            f"Nivel de confidencialidad desconocido: {value!r}. "
            f"Valores válidos: N1, N2, N3, N4, N4b"
        )
    return mapping[normalized]


def is_exportable(
    flow_level: ConfidentialityLevel,
    max_allowed: ConfidentialityLevel,
) -> bool:
    """Determina si un flujo puede exportarse a OTel dada la restricción configurada.

    Un flujo es exportable si su nivel de confidencialidad es <= al umbral máximo.

    Args:
        flow_level: Nivel de confidencialidad del flujo.
        max_allowed: Nivel máximo permitido para exportar (SAVIA_OTEL_MAX_CONFIDENTIALITY).

    Returns:
        True si el flujo puede exportarse, False si debe saltarse.
    """
    return flow_level <= max_allowed
