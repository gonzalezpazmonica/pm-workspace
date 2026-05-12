"""Check function registry."""
from __future__ import annotations
from typing import Callable
from ..spec import LintRule
from ...findings import Finding
from ...parser.spec import ParsedDocument

CheckFn = Callable[[ParsedDocument, LintRule], list[Finding]]

_CHECKS: dict[str, CheckFn] = {}


def register_check(name: str, fn: CheckFn) -> None:
    _CHECKS[name] = fn


def get_check(name: str) -> CheckFn | None:
    return _CHECKS.get(name)


def list_checks() -> list[str]:
    return sorted(_CHECKS.keys())


# Auto-register built-in checks
from . import required_field as _rf  # noqa: E402, F401
from . import reference_exists as _re  # noqa: E402, F401
from . import line_count as _lc  # noqa: E402, F401
