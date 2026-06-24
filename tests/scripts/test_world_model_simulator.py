"""tests/scripts/test_world_model_simulator.py — SPEC-165

Tests for scripts/world-model-simulator.py: pre-action world model.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "world-model-simulator.py"


def _load():
    spec = importlib.util.spec_from_file_location("world_model_simulator", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["world_model_simulator"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
simulate = mod.simulate
main = mod.main


def test_output_schema():
    result = simulate("edit AGENTS.md", "add new agent entry")
    assert "action" in result
    assert "outcomes" in result
    assert "simulation_confidence" in result
    assert "action_type" in result
    assert len(result["outcomes"]) == 3


def test_three_scenarios_named():
    result = simulate("write config.json", "initial setup")
    names = {o["scenario"] for o in result["outcomes"]}
    assert names == {"best", "likely", "worst"}


def test_probabilities_sum_to_one():
    result = simulate("delete old.log", "cleanup")
    total = sum(o["probability"] for o in result["outcomes"])
    assert abs(total - 1.0) < 0.01


def test_delete_action_higher_risk_than_read():
    r_read = simulate("read config.json")
    r_delete = simulate("delete config.json")
    assert r_delete["risk_score"] > r_read["risk_score"]


def test_deploy_action_classified_correctly():
    result = simulate("deploy to production", "hotfix release")
    assert result["action_type"] == "deploy"


def test_rule_violation_detected():
    result = simulate("edit large file with secret token", "")
    assert len(result["rule_violations_predicted"]) >= 1


def test_simulation_confidence_in_range():
    result = simulate("create new service", "backend dotnet")
    assert 0.0 <= result["simulation_confidence"] <= 1.0


def test_cli_outputs_json(tmp_path):
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--action", "edit README.md", "--context", "update docs", "--quiet"])
    assert rc == 0
    parsed = json.loads(buf.getvalue())
    assert "outcomes" in parsed
    assert len(parsed["outcomes"]) == 3
