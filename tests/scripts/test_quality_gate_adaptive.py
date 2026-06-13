"""Tests for scripts/quality-gate-adaptive.py — SPEC-200."""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "quality-gate-adaptive.py"


def _load_module():
    import sys as _sys
    spec = importlib.util.spec_from_file_location("qga", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    _sys.modules["qga"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def qga():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# stddev
# ─────────────────────────────────────────────────────────────────────────────


def test_stddev_empty(qga):
    assert qga.stddev([]) == 0.0


def test_stddev_single(qga):
    assert qga.stddev([85]) == 0.0


# ─────────────────────────────────────────────────────────────────────────────
# adaptive_threshold strategies
# ─────────────────────────────────────────────────────────────────────────────


def test_high_mean_strict_outlier_set(qga):
    """Scores with high mean (89) + outlier; threshold pulls outlier."""
    r = qga.adaptive_threshold([88, 90, 92, 89, 87, 91, 85, 93, 89, 88])
    assert r["strategy"] == "high_mean_strict"
    assert r["threshold"] == 85  # ~85.6 raw, clamped
    assert r["metrics"]["mean"] > 85


def test_high_mean_strict_outlier_lifts_to_fixed_min(qga):
    """Mean 86.5, stddev 6.5 -> raw 76.7, clamped to fixed_min 80."""
    r = qga.adaptive_threshold([85, 92, 78, 88, 95, 81])
    assert r["strategy"] == "high_mean_strict"
    assert r["threshold"] == 80  # fixed_min wins


def test_low_mean_tolerant(qga):
    """Mean 71.6 (low) -> tolerant strategy."""
    r = qga.adaptive_threshold([72, 68, 75, 70, 73])
    assert r["strategy"] == "low_mean_tolerant"
    # mean=71.6, stddev=2.7, raw=70.25 -> 70 (above floor 60)
    assert 60 <= r["threshold"] <= 75


def test_floor_clamp(qga):
    """Very low scores hit floor 60."""
    r = qga.adaptive_threshold([40, 45, 42, 38])
    assert r["threshold"] == 60
    assert r["strategy"] == "low_mean_tolerant"


def test_ceil_clamp(qga):
    """Very high uniform scores hit ceil 90."""
    r = qga.adaptive_threshold([95, 98, 99, 97, 96])
    assert r["threshold"] == 90
    assert r["strategy"] == "high_mean_strict"


def test_n_eq_1_no_stddev(qga):
    """Single score: stddev=0, threshold = fixed_min (default)."""
    r = qga.adaptive_threshold([90])
    assert r["strategy"] == "high_mean_strict"
    assert r["threshold"] == 90  # mean=90, stddev=0, raw=90, clamped to ceil


def test_empty_scores(qga):
    r = qga.adaptive_threshold([])
    assert r["strategy"] == "empty"
    assert r["threshold"] == 80  # fixed_min default


def test_custom_fixed_min(qga):
    r = qga.adaptive_threshold([86, 88, 90, 87], fixed_min=85)
    assert r["threshold"] >= 85


def test_custom_floor(qga):
    r = qga.adaptive_threshold([40, 42, 38], floor=50)
    assert r["threshold"] == 50


def test_custom_ceil(qga):
    r = qga.adaptive_threshold([99, 99, 99, 99], ceil=95)
    assert r["threshold"] == 95


def test_metrics_complete(qga):
    r = qga.adaptive_threshold([85, 90])
    assert "mean" in r["metrics"]
    assert "stddev" in r["metrics"]
    assert "n_scores" in r["metrics"]
    assert "fixed_min" in r["metrics"]
    assert "floor" in r["metrics"]
    assert "ceil" in r["metrics"]
    assert "raw_pre_clamp" in r["metrics"]


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────


def _cli(*args) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, timeout=10,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_basic_json():
    rc, out, _ = _cli("--scores", "85", "92", "78", "88", "--json")
    assert rc == 0
    d = json.loads(out)
    assert "threshold" in d
    assert "strategy" in d


def test_cli_text_output():
    rc, out, _ = _cli("--scores", "85", "90")
    assert rc == 0
    assert "threshold=" in out
    assert "strategy=" in out


def test_cli_invalid_floor_gt_ceil_exits_2():
    rc, _, err = _cli("--scores", "85", "--floor", "90", "--ceil", "80")
    assert rc == 2


def test_cli_invalid_fixed_min_gt_ceil_exits_2():
    rc, _, err = _cli("--scores", "85", "--fixed-min", "95", "--ceil", "90")
    assert rc == 2


def test_cli_missing_scores_exits_2():
    rc, _, _ = _cli("--fixed-min", "80")
    assert rc == 2


# ─────────────────────────────────────────────────────────────────────────────
# Edge cases
# ─────────────────────────────────────────────────────────────────────────────


def test_boundary_mean_exactly_85_uses_strict(qga):
    """At exactly mean=85, choose high_mean_strict."""
    r = qga.adaptive_threshold([80, 85, 90])  # mean=85
    assert r["strategy"] == "high_mean_strict"


def test_boundary_mean_just_below_85_uses_tolerant(qga):
    r = qga.adaptive_threshold([80, 85, 89])  # mean=84.67
    assert r["strategy"] == "low_mean_tolerant"


def test_threshold_is_int(qga):
    r = qga.adaptive_threshold([85.5, 90.3, 87.1])
    assert isinstance(r["threshold"], int)
