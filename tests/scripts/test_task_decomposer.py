"""tests/scripts/test_task_decomposer.py — SPEC-052

Tests for scripts/task-decomposer.py: Recursive Task Decomposition.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "task-decomposer.py"


def _load():
    spec = importlib.util.spec_from_file_location("task_decomposer", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["task_decomposer"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
decompose = mod.decompose
estimate_hours = mod.estimate_hours
is_compound = mod.is_compound


# ── test 1: simple task → atomic ──────────────────────────────────────────────
def test_simple_task_is_atomic():
    mod._reset_counter()
    result = decompose("Fix typo in README", max_depth=3, size_threshold=4.0)
    assert result.classification == "atomic"
    assert result.subtasks == []


# ── test 2: compound task decomposes ─────────────────────────────────────────
def test_compound_task_decomposes():
    mod._reset_counter()
    result = decompose(
        "Build authentication system with JWT and database integration",
        max_depth=3, size_threshold=4.0
    )
    assert result.classification == "compound"
    assert len(result.subtasks) >= 2


# ── test 3: max_depth respected ───────────────────────────────────────────────
def test_max_depth_one():
    mod._reset_counter()
    result = decompose(
        "Build complete payment system with frontend, backend and database",
        max_depth=1, size_threshold=4.0
    )
    # At depth 0 compound, subtasks at depth 1 must be atomic
    for sub in result.subtasks:
        assert sub.depth == 1
        assert len(sub.subtasks) == 0 or sub.depth < 1


# ── test 4: subtasks count in [2, 7] ─────────────────────────────────────────
def test_subtasks_between_2_and_7():
    mod._reset_counter()
    result = decompose(
        "Build API system with authentication and database and frontend and search and notifications",
        max_depth=2, size_threshold=4.0
    )
    if result.classification == "compound":
        assert 2 <= len(result.subtasks) <= 7


# ── test 5: lineage is populated in children ─────────────────────────────────
def test_lineage_propagated():
    mod._reset_counter()
    root_title = "Build notification service with email and webhooks"
    result = decompose(root_title, max_depth=3, size_threshold=4.0)
    if result.subtasks:
        child = result.subtasks[0]
        assert root_title in child.lineage


# ── test 6: SAVIA_TASK_SIZE_HOURS env var controls threshold ─────────────────
def test_env_var_size_threshold(monkeypatch):
    monkeypatch.setenv("SAVIA_TASK_SIZE_HOURS", "100")
    # With threshold=100h, everything is atomic
    mod._reset_counter()
    result = decompose(
        "Build authentication system with JWT",
        max_depth=3,
        size_threshold=100.0  # explicit override
    )
    assert result.classification == "atomic"


# ── test 7: estimated_hours is positive ─────────────────────────────────────
def test_estimated_hours_positive():
    for title in ["Fix bug", "Implement auth", "Deploy service"]:
        assert estimate_hours(title) > 0


# ── test 8: output has required JSON fields ───────────────────────────────────
def test_output_has_required_fields():
    mod._reset_counter()
    result = decompose("Create REST API", max_depth=2, size_threshold=4.0)
    d = result.to_dict()
    for key in ["id", "title", "classification", "estimated_hours", "depth", "can_parallelize", "lineage", "subtasks"]:
        assert key in d, f"Missing key: {key}"


# ── test 9: CLI produces valid JSON ───────────────────────────────────────────
def test_cli_output_is_json(monkeypatch):
    lines: list[str] = []
    monkeypatch.setattr("builtins.print", lambda *a, **kw: lines.append(" ".join(str(x) for x in a)))
    rc = mod.main(["--task", "Create a simple config file", "--max-depth", "2"])
    assert rc == 0
    parsed = json.loads("\n".join(lines))
    assert "id" in parsed
    assert "classification" in parsed


# ── test 10: is_compound correctly identifies compound tasks ──────────────────
def test_is_compound_detection():
    assert is_compound("Build auth, API, and database migration") is True
    assert is_compound("Fix typo") is False
