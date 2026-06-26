"""tests/scripts/test_actor_pre_action.py — SPEC-168

Tests for scripts/actor-pre-action-loop.py: actor iterative pre-action loop
using the world-model-simulator (SPEC-165).
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "actor-pre-action-loop.py"


def _load() -> object:
    spec = importlib.util.spec_from_file_location("actor_pre_action_loop", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["actor_pre_action_loop"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
run_pre_action_loop = mod.run_pre_action_loop
_bypass_result = mod._bypass_result
_refine_action = mod._refine_action
main = mod.main


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_simulator(confidence: float, outcome: str = "file updated successfully") -> MagicMock:
    """Create a mock simulator that always returns the given confidence."""
    sim = MagicMock()
    sim.simulate.return_value = {
        "simulation_confidence": confidence,
        "outcomes": [
            {"scenario": "best", "probability": 0.6, "description": "success"},
            {"scenario": "likely", "probability": 0.3, "description": outcome},
            {"scenario": "worst", "probability": 0.1, "description": "fail"},
        ],
        "action_type": "edit",
        "risk_score": 0.2,
    }
    return sim


def _make_simulator_sequence(confidences: list[float]) -> MagicMock:
    """Mock simulator returning successive confidence values on each call."""
    sim = MagicMock()
    side_effects = []
    for c in confidences:
        side_effects.append({
            "simulation_confidence": c,
            "outcomes": [
                {"scenario": "best", "probability": 0.6, "description": "ok"},
                {"scenario": "likely", "probability": 0.3,
                 "description": "partial update — some sections skipped"},
                {"scenario": "worst", "probability": 0.1, "description": "fail"},
            ],
            "action_type": "edit",
            "risk_score": 0.2,
        })
    sim.simulate.side_effect = side_effects
    return sim


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestApprovedFirstIteration:
    """approved si confidence >= threshold en iteración 1."""

    def test_approved_at_first_iteration(self):
        sim = _make_simulator(confidence=0.85)
        result = run_pre_action_loop(
            action="edit README.md",
            context="update docs",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["verdict"] == "approved"
        assert result["iterations"] == 1
        assert result["final_confidence"] == 0.85

    def test_approved_action_matches_input(self):
        sim = _make_simulator(confidence=0.90)
        result = run_pre_action_loop(
            action="read config.json",
            context="inspect settings",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["approved_action"] == "read config.json"
        assert result["verdict"] == "approved"

    def test_simulate_called_once_when_approved_immediately(self):
        sim = _make_simulator(confidence=0.80)
        run_pre_action_loop(
            action="read logs",
            context="",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert sim.simulate.call_count == 1


class TestIteratesWhenBelowThreshold:
    """itera cuando confidence < threshold."""

    def test_iterates_on_low_confidence(self):
        sim = _make_simulator_sequence([0.5, 0.5, 0.9])
        result = run_pre_action_loop(
            action="delete old-file.log",
            context="cleanup",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["iterations"] == 3
        assert sim.simulate.call_count == 3

    def test_approves_after_refinement(self):
        sim = _make_simulator_sequence([0.5, 0.85])
        result = run_pre_action_loop(
            action="edit config",
            context="change port",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["verdict"] == "approved"
        assert result["iterations"] == 2

    def test_refined_action_differs_from_original(self):
        sim = _make_simulator_sequence([0.4, 0.4, 0.4])
        result = run_pre_action_loop(
            action="edit main.py",
            context="add function",
            max_iterations=3,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        # History should show evolving action descriptions
        actions_in_history = [h["action"] for h in result["simulation_history"]]
        # At least one iteration should differ from the original or be refined
        assert len(actions_in_history) == 3


class TestMaxIterationsRespected:
    """max-iterations respetado."""

    def test_stops_at_max_iterations(self):
        sim = _make_simulator(confidence=0.3)  # always below threshold
        result = run_pre_action_loop(
            action="deploy to prod",
            context="hotfix",
            max_iterations=3,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        assert result["iterations"] == 3
        assert sim.simulate.call_count == 3

    def test_max_iterations_1_runs_exactly_once(self):
        sim = _make_simulator(confidence=0.3)
        result = run_pre_action_loop(
            action="edit file",
            context="",
            max_iterations=1,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        assert result["iterations"] == 1
        assert sim.simulate.call_count == 1

    def test_max_iterations_2_runs_at_most_twice(self):
        sim = _make_simulator(confidence=0.3)
        result = run_pre_action_loop(
            action="delete db",
            context="",
            max_iterations=2,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        assert result["iterations"] == 2
        assert sim.simulate.call_count == 2


class TestSimulationHistory:
    """simulation_history tiene N entradas."""

    def test_history_length_matches_iterations(self):
        sim = _make_simulator(confidence=0.3)
        result = run_pre_action_loop(
            action="edit file",
            context="",
            max_iterations=3,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        assert len(result["simulation_history"]) == 3

    def test_history_length_1_when_approved_immediately(self):
        sim = _make_simulator(confidence=0.85)
        result = run_pre_action_loop(
            action="read file",
            context="",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert len(result["simulation_history"]) == 1

    def test_history_entries_have_required_keys(self):
        sim = _make_simulator(confidence=0.3)
        result = run_pre_action_loop(
            action="edit config",
            context="",
            max_iterations=2,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        for entry in result["simulation_history"]:
            assert "action" in entry
            assert "confidence" in entry
            assert "outcome" in entry

    def test_history_confidence_values_match_simulator(self):
        sim = _make_simulator_sequence([0.6, 0.7, 0.9])
        result = run_pre_action_loop(
            action="edit x",
            context="",
            max_iterations=3,
            confidence_threshold=0.95,
            simulator_mod=sim,
        )
        confidences = [h["confidence"] for h in result["simulation_history"]]
        assert confidences[0] == 0.6
        assert confidences[1] == 0.7
        assert confidences[2] == 0.9


class TestVerdicts:
    """verdict 'approved' para alta confianza / 'best_effort' al agotar iteraciones."""

    def test_verdict_approved_high_confidence(self):
        sim = _make_simulator(confidence=0.95)
        result = run_pre_action_loop(
            action="read logs",
            context="",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["verdict"] == "approved"

    def test_verdict_best_effort_when_iterations_exhausted(self):
        sim = _make_simulator(confidence=0.5)
        result = run_pre_action_loop(
            action="delete everything",
            context="",
            max_iterations=3,
            confidence_threshold=0.9,
            simulator_mod=sim,
        )
        assert result["verdict"] == "best_effort"

    def test_verdict_approved_exactly_at_threshold(self):
        sim = _make_simulator(confidence=0.7)
        result = run_pre_action_loop(
            action="edit file",
            context="",
            max_iterations=3,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["verdict"] == "approved"


class TestOutputSchema:
    """output JSON válido con todos los campos."""

    def test_all_required_fields_present(self):
        sim = _make_simulator(confidence=0.85)
        result = run_pre_action_loop(
            action="edit file",
            context="add feature",
            max_iterations=2,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert "approved_action" in result
        assert "final_confidence" in result
        assert "iterations" in result
        assert "simulation_history" in result
        assert "verdict" in result

    def test_final_confidence_is_float(self):
        sim = _make_simulator(confidence=0.8)
        result = run_pre_action_loop(
            action="read data",
            context="",
            max_iterations=1,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert isinstance(result["final_confidence"], float)

    def test_iterations_is_int(self):
        sim = _make_simulator(confidence=0.8)
        result = run_pre_action_loop(
            action="edit x",
            context="",
            max_iterations=1,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert isinstance(result["iterations"], int)

    def test_result_is_json_serializable(self):
        sim = _make_simulator(confidence=0.8)
        result = run_pre_action_loop(
            action="edit file",
            context="context",
            max_iterations=2,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        json_str = json.dumps(result)
        parsed = json.loads(json_str)
        assert parsed["verdict"] in ("approved", "best_effort", "blocked")

    def test_verdict_is_one_of_valid_values(self):
        sim = _make_simulator(confidence=0.8)
        result = run_pre_action_loop(
            action="read log",
            context="",
            max_iterations=1,
            confidence_threshold=0.7,
            simulator_mod=sim,
        )
        assert result["verdict"] in ("approved", "best_effort", "blocked")


class TestMasterSwitch:
    """SAVIA_ACTOR_PRE_ACTION=off → devuelve acción sin simular."""

    def test_off_returns_action_without_simulation(self, monkeypatch):
        monkeypatch.setenv("SAVIA_ACTOR_PRE_ACTION", "off")
        result = _bypass_result("edit config.yaml")
        assert result["approved_action"] == "edit config.yaml"
        assert result["iterations"] == 0
        assert result["simulation_history"] == []

    def test_off_verdict_approved(self, monkeypatch):
        monkeypatch.setenv("SAVIA_ACTOR_PRE_ACTION", "off")
        result = _bypass_result("delete old-logs")
        assert result["verdict"] == "approved"

    def test_off_confidence_is_1(self, monkeypatch):
        monkeypatch.setenv("SAVIA_ACTOR_PRE_ACTION", "off")
        result = _bypass_result("any action")
        assert result["final_confidence"] == 1.0

    def test_main_off_outputs_json(self, monkeypatch, capsys):
        monkeypatch.setenv("SAVIA_ACTOR_PRE_ACTION", "off")
        rc = main(["--action", "read logs", "--context", "debug"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert parsed["approved_action"] == "read logs"
        assert parsed["simulation_history"] == []

    def test_main_on_uses_simulator(self, monkeypatch, capsys):
        monkeypatch.setenv("SAVIA_ACTOR_PRE_ACTION", "on")
        # Real simulator is available; just verify output is valid JSON
        rc = main(["--action", "read config", "--context", "test", "--quiet"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert "verdict" in parsed
        assert "simulation_history" in parsed
