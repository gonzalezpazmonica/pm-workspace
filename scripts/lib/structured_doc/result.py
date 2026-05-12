"""Result[Success, Failure] type — D-3 Spec & Handler Pattern.

Handlers MUST NOT raise. They return Result[T] = Success[T] | Failure.
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Generic, TypeVar, Union

T = TypeVar("T")


@dataclass(frozen=True)
class Success(Generic[T]):
    value: T

    @property
    def ok(self) -> bool:
        return True


@dataclass(frozen=True)
class Failure:
    error_kind: str          # discriminated union tag (e.g. "file-not-found")
    message: str
    detail: dict | None = None

    @property
    def ok(self) -> bool:
        return False


Result = Union[Success[T], Failure]
