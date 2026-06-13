"""Tests for scripts/annealing-schedule.py — SPEC-197."""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "annealing-schedule.py"


def _load_module():
    import sys as _sys
    spec = importlib.util.spec_from_file_location("annealing_schedule", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    _sys.modules["annealing_schedule"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def asched():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# Formula boundaries
# ─────────────────────────────────────────────────────────────────────────────


def test_schedule_at_index_zero_returns_max(asched):
    assert asched.schedule(0, 4) == 0.8


def test_schedule_at_last_index_returns_min(asched):
    assert asched.schedule(3, 4) == 0.4


def test_schedule_total_one_returns_min(asched):
    """Degenerate case: single phase = decision."""
    assert asched.schedule(0, 1) == 0.4


def test_schedule_total_zero_returns_min(asched):
    assert asched.schedule(0, 0) == 0.4


def test_schedule_monotonic_decreasing(asched):
    """For exponent=1, sequence should be monotonically decreasing."""
    values = [asched.schedule(i, 5) for i in range(5)]
    for a, b in zip(values, values[1:]):
        assert a >= b, f"Not monotonic: {values}"


def test_schedule_custom_max_min(asched):
    assert asched.schedule(0, 4, max_t=1.0, min_t=0.0) == 1.0
    assert asched.schedule(3, 4, max_t=1.0, min_t=0.0) == 0.0


def test_schedule_exponent_changes_curve(asched):
    """exponent>1 -> faster decay early. exponent<1 -> slower decay early."""
    linear = asched.schedule(1, 4, exponent=1.0)
    fast_decay = asched.schedule(1, 4, exponent=2.0)
    slow_decay = asched.schedule(1, 4, exponent=0.5)
    # exp>1 at index 1: T drops faster than linear
    assert fast_decay < linear
    # exp<1 at index 1: T stays higher than linear
    assert slow_decay > linear


def test_schedule_negative_index_clamps_to_zero(asched):
    assert asched.schedule(-1, 4) == 0.8


def test_schedule_index_above_total_clamps_to_last(asched):
    assert asched.schedule(10, 4) == 0.4


# ─────────────────────────────────────────────────────────────────────────────
# Numerical accuracy
# ─────────────────────────────────────────────────────────────────────────────


def test_schedule_linear_midpoint(asched):
    # 4 phases linear: index 1 should be ~ 0.6667
    t = asched.schedule(1, 4, max_t=0.8, min_t=0.4, exponent=1.0)
    assert abs(t - 0.6667) < 0.01


def test_schedule_3_phases_midpoint(asched):
    # 3 phases linear: index 1 should be 0.6 (midpoint of 0.8 and 0.4)
    t = asched.schedule(1, 3, max_t=0.8, min_t=0.4, exponent=1.0)
    assert abs(t - 0.6) < 0.001


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────


def _cli(*args) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, timeout=10,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_json_output():
    rc, out, _ = _cli("--index", "0", "--total", "4", "--json")
    assert rc == 0
    d = json.loads(out)
    assert d["temperature"] == 0.8


def test_cli_text_output():
    rc, out, _ = _cli("--index", "0", "--total", "4")
    assert rc == 0
    assert "0.8000" in out


def test_cli_invalid_total_exits_2():
    rc, _, err = _cli("--index", "0", "--total", "0")
    assert rc == 2
    assert "total" in err.lower()


def test_cli_max_lower_than_min_exits_2():
    rc, _, err = _cli("--index", "0", "--total", "4", "--max-t", "0.2", "--min-t", "0.8")
    assert rc == 2
    assert "max-t" in err.lower() or "min-t" in err.lower()


def test_cli_custom_exponent():
    rc, out, _ = _cli("--index", "1", "--total", "4", "--exponent", "2.0", "--json")
    assert rc == 0
    d = json.loads(out)
    # exponent=2 (fast decay): T at index 1 lower than linear (0.6667)
    assert d["temperature"] < 0.6667


def test_cli_missing_required_exits_2():
    rc, _, _ = _cli("--total", "4")
    assert rc == 2
