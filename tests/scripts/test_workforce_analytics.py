"""tests/scripts/test_workforce_analytics.py — SPEC-SE-025

pytest >= 8 tests for scripts/workforce-analytics.py
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "workforce-analytics.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("workforce_analytics", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["workforce_analytics"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load_module()
compute_metrics = mod.compute_metrics


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture()
def empty_dirs(tmp_path: Path):
    """Empty data_dir and repo_root with no agent data."""
    data_dir = tmp_path / "output"
    data_dir.mkdir()
    (data_dir / "agent-trace").mkdir()
    return data_dir, tmp_path


@pytest.fixture()
def synthetic_data(tmp_path: Path):
    """Minimal synthetic data: 3 agents, 5 runs, some failures."""
    data_dir = tmp_path / "output"
    data_dir.mkdir()
    trace_dir = data_dir / "agent-trace"
    trace_dir.mkdir()

    # data/agent-actuals.jsonl
    data_d = tmp_path / "data"
    data_d.mkdir()
    actuals_path = data_d / "agent-actuals.jsonl"

    runs = [
        {
            "schema_version": "2",
            "agent": "dotnet-developer",
            "task": "task-1",
            "started_at": "2026-06-01T08:00:00Z",
            "finished_at": "2026-06-01T08:03:45Z",
            "duration_s": 225,
            "run_status": "completed",
        },
        {
            "schema_version": "2",
            "agent": "dotnet-developer",
            "task": "task-2",
            "started_at": "2026-06-01T09:00:00Z",
            "finished_at": "2026-06-01T09:01:30Z",
            "duration_s": 90,
            "run_status": "failed",
        },
        {
            "schema_version": "2",
            "agent": "test-engineer",
            "task": "task-3",
            "started_at": "2026-06-01T10:00:00Z",
            "finished_at": "2026-06-01T10:05:00Z",
            "duration_s": 300,
            "run_status": "completed",
        },
        {
            "schema_version": "2",
            "agent": "test-engineer",
            "task": "task-4",
            "started_at": "2026-06-02T14:00:00Z",
            "finished_at": "2026-06-02T14:02:00Z",
            "duration_s": 120,
            "run_status": "completed",
        },
        {
            "schema_version": "2",
            "agent": "architect",
            "task": "task-5",
            "started_at": "2026-06-03T16:00:00Z",
            "finished_at": "2026-06-03T16:10:00Z",
            "duration_s": 600,
            "run_status": "completed",
        },
    ]
    with actuals_path.open("w") as fh:
        for r in runs:
            fh.write(json.dumps(r) + "\n")

    return data_dir, tmp_path


# ── Tests — no data (graceful) ────────────────────────────────────────────────

def test_no_data_returns_dict(empty_dirs):
    data_dir, repo_root = empty_dirs
    result = compute_metrics(data_dir, repo_root)
    assert isinstance(result, dict), "compute_metrics must return a dict"


def test_no_data_agent_invocations_is_dict(empty_dirs):
    data_dir, repo_root = empty_dirs
    result = compute_metrics(data_dir, repo_root)
    assert isinstance(result["agent_invocations"], dict)


def test_no_data_top_agents_is_list(empty_dirs):
    data_dir, repo_root = empty_dirs
    result = compute_metrics(data_dir, repo_root)
    assert isinstance(result["top_agents"], list)


def test_no_data_does_not_crash(empty_dirs):
    """No exception raised when there is zero data."""
    data_dir, repo_root = empty_dirs
    try:
        compute_metrics(data_dir, repo_root)
    except Exception as exc:
        pytest.fail(f"compute_metrics raised unexpectedly: {exc}")


# ── Tests — with synthetic data ───────────────────────────────────────────────

def test_agent_invocations_counts(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    inv = result["agent_invocations"]
    assert inv.get("dotnet-developer") == 2
    assert inv.get("test-engineer") == 2
    assert inv.get("architect") == 1


def test_agent_invocations_is_dict_with_data(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert isinstance(result["agent_invocations"], dict)


def test_avg_duration_min_non_negative(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    for agent, avg in result["avg_durations"].items():
        assert avg >= 0, f"avg_duration_min for {agent} is negative: {avg}"


def test_avg_duration_min_dotnet_developer(synthetic_data):
    """(225+90)/2 s = 157.5 s = 2.625 min"""
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    dur = result["avg_durations"].get("dotnet-developer", -1)
    assert abs(dur - 2.625) < 0.01, f"Expected 2.625 min, got {dur}"


def test_success_rate_in_range(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    for agent, rate in result["success_rates"].items():
        assert 0.0 <= rate <= 1.0, f"success_rate for {agent} out of range: {rate}"


def test_success_rate_dotnet_developer_half(synthetic_data):
    """1 of 2 runs completed => 0.5"""
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert result["success_rates"].get("dotnet-developer") == pytest.approx(0.5)


def test_top_agents_max_five(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert len(result["top_agents"]) <= 5


def test_top_agents_is_list(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert isinstance(result["top_agents"], list)


def test_top_agents_sorted_by_invocations(synthetic_data):
    """First entry should have the most or equal invocations."""
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    top = result["top_agents"]
    inv = result["agent_invocations"]
    if len(top) >= 2:
        assert inv.get(top[0], 0) >= inv.get(top[1], 0)


def test_json_serializable(synthetic_data):
    """Result must be JSON-serializable (no sets, datetimes, etc.)."""
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    try:
        json.dumps(result)
    except TypeError as exc:
        pytest.fail(f"Result is not JSON-serializable: {exc}")


def test_summary_total_invocations(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert result["summary"]["total_invocations"] == 5


def test_since_filter_excludes_old(synthetic_data):
    data_dir, repo_root = synthetic_data
    # Filter to after 2026-06-02 excludes 3 runs from 2026-06-01
    result = compute_metrics(data_dir, repo_root, since="2026-06-02")
    assert result["summary"]["total_invocations"] <= 2


def test_review_court_key_present(synthetic_data):
    data_dir, repo_root = synthetic_data
    result = compute_metrics(data_dir, repo_root)
    assert "review_court" in result
    assert "total_prs" in result["review_court"]
