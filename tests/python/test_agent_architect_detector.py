"""Tests for agent_architect.detector and CLI integration."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "lib"))

from agent_architect.detector import aggregate, analyze_path, load_thresholds

FIX = Path(__file__).parent / "fixtures" / "agents"
REPO_ROOT = Path(__file__).resolve().parents[2]


def test_monolith_is_candidate():
    r = analyze_path(FIX / "mega-monolith.md")
    assert r.alerts >= 2
    assert r.is_candidate is True


def test_clean_agent_is_not_candidate():
    r = analyze_path(FIX / "clean-agent.md")
    assert r.is_candidate is False
    assert r.alerts == 0


def test_aggregate_sorts_candidates_first():
    results = [analyze_path(p) for p in FIX.glob("*.md")]
    ranked = aggregate(results)
    # mega-monolith should be first (most alerts)
    assert ranked[0].agent_id == "mega-monolith"


def test_orchestrator_whitelist_relaxes_thresholds(tmp_path):
    cfg = load_thresholds()
    cfg["orchestrator_whitelist"] = ["clean-agent"]
    r_normal = analyze_path(FIX / "clean-agent.md")
    r_whitelisted = analyze_path(FIX / "clean-agent.md", cfg)
    # both info, but the whitelisted one has doubled thresholds
    length_normal = next(s for s in r_normal.signals if s.name == "length")
    length_white = next(s for s in r_whitelisted.signals if s.name == "length")
    assert length_white.threshold_warn == length_normal.threshold_warn * 2


def test_load_thresholds_yaml_override(tmp_path):
    yml = tmp_path / "t.yaml"
    yml.write_text("length:\n  warn: 50\n  alert: 100\n")
    cfg = load_thresholds(yml)
    assert cfg["length"]["warn"] == 50
    assert cfg["length"]["alert"] == 100
    # other heuristics retain defaults
    assert cfg["tools"]["warn"] == 6


def test_load_thresholds_missing_file_falls_back_to_defaults(tmp_path):
    cfg = load_thresholds(tmp_path / "nonexistent.yaml")
    assert cfg["length"]["warn"] == 200


def test_cli_single_agent_json_emits_signals():
    proc = subprocess.run(
        [sys.executable, "-m", "agent_architect.cli", "--agent", str(FIX / "mega-monolith.md"), "--json"],
        cwd=str(REPO_ROOT),
        env={"PYTHONPATH": "scripts/lib", "PATH": "/usr/bin:/bin"},
        capture_output=True, text=True,
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["agent_id"] == "mega-monolith"
    assert data["is_candidate"] is True
    assert any(s["name"] == "tools" for s in data["signals"])


def test_cli_all_threshold_alert_filters(tmp_path):
    # Build a tiny fake repo with one monolith and one clean agent
    fake = tmp_path / "fakerepo"
    agents = fake / ".opencode" / "agents"
    agents.mkdir(parents=True)
    (agents / "mega.md").write_text((FIX / "mega-monolith.md").read_text())
    (agents / "clean.md").write_text((FIX / "clean-agent.md").read_text())
    proc = subprocess.run(
        [sys.executable, "-m", "agent_architect.cli", "--all", "--json", "--threshold", "alert", "--root", str(fake)],
        cwd=str(REPO_ROOT),
        env={"PYTHONPATH": "scripts/lib", "PATH": "/usr/bin:/bin"},
        capture_output=True, text=True,
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    ids = [r["agent_id"] for r in data]
    assert "mega-monolith" in ids
    assert "clean-agent" not in ids
