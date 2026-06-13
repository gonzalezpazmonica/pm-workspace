"""Tests for scripts/recommendation-tribunal/early_stop.py — SPEC-195."""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "recommendation-tribunal" / "early_stop.py"


def _load_module():
    import sys as _sys
    spec = importlib.util.spec_from_file_location("early_stop", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    _sys.modules["early_stop"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def es():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# stddev
# ─────────────────────────────────────────────────────────────────────────────


def test_stddev_empty(es):
    assert es.stddev([]) == 0.0


def test_stddev_single(es):
    assert es.stddev([42]) == 0.0


def test_stddev_uniform(es):
    assert es.stddev([5, 5, 5, 5]) == 0.0


def test_stddev_known(es):
    # stddev of [1,2,3,4,5] = sqrt(2.5) ~= 1.581
    assert abs(es.stddev([1, 2, 3, 4, 5]) - 1.581) < 0.01


# ─────────────────────────────────────────────────────────────────────────────
# Token stability
# ─────────────────────────────────────────────────────────────────────────────


def test_stability_first_iteration_no_previous(es):
    assert es.token_stability_stop("abc", "") is False


def test_stability_same_hash_stops(es):
    assert es.token_stability_stop("abc", "abc") is True


def test_stability_different_hashes(es):
    assert es.token_stability_stop("abc", "def") is False


# ─────────────────────────────────────────────────────────────────────────────
# Entropy
# ─────────────────────────────────────────────────────────────────────────────


def test_entropy_low_stddev_stops(es):
    assert es.entropy_stop([85, 86, 87, 84, 85], 5.0) is True


def test_entropy_high_stddev_continues(es):
    assert es.entropy_stop([20, 90, 50, 80, 10], 5.0) is False


def test_entropy_zero_threshold(es):
    # Even perfect consensus needs stddev > 0 to NOT stop with threshold 0
    assert es.entropy_stop([85, 85, 85], 0.0) is False  # stddev=0 is NOT < 0


def test_entropy_empty_scores(es):
    assert es.entropy_stop([], 5.0) is True  # stddev of [] = 0


# ─────────────────────────────────────────────────────────────────────────────
# Max iter
# ─────────────────────────────────────────────────────────────────────────────


def test_max_iter_under_cap(es):
    assert es.max_iter_stop(1, 3) is False


def test_max_iter_at_cap(es):
    assert es.max_iter_stop(3, 3) is True


def test_max_iter_over_cap(es):
    assert es.max_iter_stop(5, 3) is True


# ─────────────────────────────────────────────────────────────────────────────
# should_stop (full evaluator)
# ─────────────────────────────────────────────────────────────────────────────


def test_should_stop_no_criteria_met(es):
    result = es.should_stop(
        iteration=0, max_iter=3, draft_hash="abc", previous_draft_hash="",
        judge_scores=[20, 90, 50, 80, 10], entropy_threshold=5.0,
    )
    assert result["should_stop"] is False
    assert result["stop_reason"] == "none"


def test_should_stop_stability_wins_priority(es):
    # All 3 trigger; stability priority
    result = es.should_stop(
        iteration=3, max_iter=3, draft_hash="abc", previous_draft_hash="abc",
        judge_scores=[85, 85, 85], entropy_threshold=5.0,
    )
    assert result["should_stop"] is True
    assert result["stop_reason"] == "stability"


def test_should_stop_entropy_when_no_stability(es):
    result = es.should_stop(
        iteration=1, max_iter=3, draft_hash="abc", previous_draft_hash="def",
        judge_scores=[85, 86, 87], entropy_threshold=5.0,
    )
    assert result["should_stop"] is True
    assert result["stop_reason"] == "entropy"


def test_should_stop_max_iter_last_resort(es):
    result = es.should_stop(
        iteration=3, max_iter=3, draft_hash="abc", previous_draft_hash="def",
        judge_scores=[20, 90, 50], entropy_threshold=5.0,
    )
    assert result["should_stop"] is True
    assert result["stop_reason"] == "max_iter"


def test_should_stop_metrics_present(es):
    result = es.should_stop(
        iteration=1, max_iter=3, draft_hash="x", previous_draft_hash="y",
        judge_scores=[1, 2, 3, 4, 5], entropy_threshold=5.0,
    )
    assert "score_stddev" in result["metrics"]
    assert result["metrics"]["judges_count"] == 5
    assert result["metrics"]["iteration"] == 1
    assert result["metrics"]["max_iter"] == 3


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
    rc, out, _ = _cli(
        "--iteration", "0", "--max-iter", "3",
        "--draft-hash", "abc", "--previous-draft-hash", "",
        "--judge-scores", "85,90,88,92,87,89,91",
        "--entropy-threshold", "5.0", "--json",
    )
    assert rc == 0
    d = json.loads(out)
    assert "should_stop" in d
    assert d["stop_reason"] == "entropy"  # tight scores


def test_cli_text_output():
    rc, out, _ = _cli(
        "--iteration", "3", "--max-iter", "3",
        "--draft-hash", "abc", "--previous-draft-hash", "abc",
        "--judge-scores", "85",
    )
    assert rc == 0
    assert "should_stop=True" in out
    assert "stability" in out


def test_cli_invalid_scores_exits_2():
    rc, _, err = _cli(
        "--iteration", "0", "--max-iter", "3",
        "--draft-hash", "abc", "--previous-draft-hash", "",
        "--judge-scores", "not,numbers",
    )
    assert rc == 2
    assert "invalid" in err.lower()


def test_cli_missing_required_exits_2():
    rc, _, _ = _cli("--iteration", "0")
    assert rc == 2
