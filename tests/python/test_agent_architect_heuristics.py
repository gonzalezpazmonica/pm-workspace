"""Tests for agent_architect.heuristics."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "lib"))

from agent_architect.detector import DEFAULT_THRESHOLDS
from agent_architect.heuristics import (
    heuristic_age,
    heuristic_contradictions,
    heuristic_length,
    heuristic_responsibilities,
    heuristic_roleplay_nesting,
    heuristic_tools,
)
from agent_architect.parser import parse_agent

FIX = Path(__file__).parent / "fixtures" / "agents"


def test_length_alert_on_monolith():
    ast = parse_agent(FIX / "mega-monolith.md")
    sig = heuristic_length(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "alert"
    assert sig.value >= 400


def test_length_info_on_clean():
    ast = parse_agent(FIX / "clean-agent.md")
    sig = heuristic_length(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"


def test_length_orchestrator_doubles_thresholds():
    ast = parse_agent(FIX / "big-orchestrator.md")
    sig = heuristic_length(ast, DEFAULT_THRESHOLDS)
    # ~270 lines: would be warn for normal (>200), but info for orchestrator (warn=400)
    assert sig.level == "info"


def test_responsibilities_alert_on_monolith():
    ast = parse_agent(FIX / "mega-monolith.md")
    sig = heuristic_responsibilities(ast, DEFAULT_THRESHOLDS)
    # review, fix, test, document, deploy, audit, refactor -> >=5 distinct verbs
    assert sig.level == "alert"
    assert sig.value >= 5


def test_responsibilities_info_on_clean():
    ast = parse_agent(FIX / "clean-agent.md")
    sig = heuristic_responsibilities(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"


def test_tools_alert_on_monolith():
    ast = parse_agent(FIX / "mega-monolith.md")
    sig = heuristic_tools(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "alert"
    assert sig.value >= 11


def test_tools_info_on_clean():
    ast = parse_agent(FIX / "clean-agent.md")
    sig = heuristic_tools(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"


def test_contradictions_detects_always_never_pair():
    ast = parse_agent(FIX / "mega-monolith.md")
    sig = heuristic_contradictions(ast, DEFAULT_THRESHOLDS)
    # "You always do everything." vs "You never skip." -> at least 1 pair
    assert sig.value >= 1
    assert sig.level in ("warn", "alert")


def test_contradictions_zero_on_clean():
    ast = parse_agent(FIX / "clean-agent.md")
    sig = heuristic_contradictions(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"
    assert sig.value == 0


def test_roleplay_nesting_alert_on_monolith():
    ast = parse_agent(FIX / "mega-monolith.md")
    sig = heuristic_roleplay_nesting(ast, DEFAULT_THRESHOLDS)
    # "Imagine you are an expert reviewer" + "Imagine you are also a tester" + "Act as a documenter" => 3 markers, depth=2
    assert sig.level == "alert"


def test_roleplay_nesting_info_on_clean():
    ast = parse_agent(FIX / "clean-agent.md")
    sig = heuristic_roleplay_nesting(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"


def test_age_returns_signal_with_value(tmp_path):
    f = tmp_path / "fresh.md"
    f.write_text("---\nname: fresh\n---\n# fresh\n")
    ast = parse_agent(f)
    sig = heuristic_age(ast, DEFAULT_THRESHOLDS)
    assert sig.level == "info"
    assert sig.value >= 0
