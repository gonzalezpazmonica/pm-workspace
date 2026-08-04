"""Monotonic-clock seam.

Production code uses `RealClock`; tests pass a `FakeClock` so pause-duration
math is deterministic regardless of wall-clock jitter.
"""

from __future__ import annotations

import time
from typing import Protocol


class Clock(Protocol):
    def monotonic(self) -> float: ...


class RealClock:
    def monotonic(self) -> float:
        return time.monotonic()


class FakeClock:
    """Test double. `advance(seconds)` moves time forward; `monotonic()` reads it."""

    def __init__(self, start: float = 0.0) -> None:
        self._t = float(start)

    def monotonic(self) -> float:
        return self._t

    def advance(self, seconds: float) -> None:
        self._t += float(seconds)
