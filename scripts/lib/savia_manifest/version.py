"""version.py — Semver comparison using packaging.version.

SPEC-SAVIA-MANIFEST §2.7: version requirements resolved via packaging.version.
Supports PEP 440 specifiers: >=, <=, ==, !=, ~=, >, <.
"""
from __future__ import annotations

from packaging.version import Version, InvalidVersion
from packaging.specifiers import SpecifierSet, InvalidSpecifier


class VersionError(ValueError):
    """Raised when a version string or specifier is invalid."""


def _parse(v: str) -> Version:
    try:
        return Version(v)
    except InvalidVersion as exc:
        raise VersionError(f"Invalid version: {v!r}") from exc


def compare_versions(a: str, op: str, b: str) -> bool:
    """Compare version strings with operator.

    Args:
        a:  Left-hand version string, e.g. "1.2.3".
        op: Operator string: ">=", "<=", "==", "!=", ">", "<", "~=".
        b:  Right-hand version string.

    Returns:
        True if the comparison holds.

    Raises:
        VersionError: If either version string is invalid.
        ValueError:   If the operator is not recognised.
    """
    va = _parse(a)
    vb = _parse(b)
    ops: dict[str, object] = {
        ">=": va >= vb,
        "<=": va <= vb,
        "==": va == vb,
        "!=": va != vb,
        ">":  va >  vb,
        "<":  va <  vb,
    }
    if op == "~=":
        # Compatible release: >=b, <next-major
        return satisfies_requirement(a, f"~={b}")
    if op not in ops:
        raise ValueError(f"Unknown operator: {op!r}")
    return bool(ops[op])


def satisfies_requirement(version: str, requirement: str) -> bool:
    """Return True if *version* satisfies the PEP 440 *requirement* specifier.

    Args:
        version:     e.g. "4.2.1"
        requirement: e.g. ">=4.0.0" or ">=4.0.0,<5.0.0"

    Raises:
        VersionError: If the version string is invalid.
        ValueError:   If the specifier is invalid.
    """
    try:
        spec = SpecifierSet(requirement)
    except InvalidSpecifier as exc:
        raise ValueError(f"Invalid specifier: {requirement!r}") from exc
    return _parse(version) in spec
