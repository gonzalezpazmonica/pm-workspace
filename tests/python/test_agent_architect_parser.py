"""Tests for agent_architect.parser."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "lib"))

from agent_architect.parser import parse_agent, discover_agents

FIX = Path(__file__).parent / "fixtures" / "agents"


def test_parse_clean_agent_extracts_frontmatter():
    ast = parse_agent(FIX / "clean-agent.md")
    assert ast.name == "clean-agent"
    assert ast.frontmatter["model"] == "mid"
    assert "read" in ast.tools
    assert "grep" in ast.tools
    assert ast.parse_errors == []


def test_parse_clean_agent_extracts_headers_with_lines():
    ast = parse_agent(FIX / "clean-agent.md")
    assert any(h.text.startswith("Validate") for h in ast.headers)
    h = next(h for h in ast.headers if h.text.startswith("Validate"))
    assert h.level == 2
    assert h.line_no > 0


def test_parse_monolith_counts_lines_correctly():
    ast = parse_agent(FIX / "mega-monolith.md")
    assert ast.line_count >= 400


def test_parse_monolith_extracts_many_tools():
    ast = parse_agent(FIX / "mega-monolith.md")
    assert len(ast.tools) >= 11
    assert "ppt_create_presentation" in ast.tools


def test_parse_handles_malformed_frontmatter_gracefully():
    ast = parse_agent(FIX / "bad-frontmatter.md")
    assert ast.parse_errors  # error tolerated, not raised
    # Frontmatter dict may be empty but body is still readable
    assert "bad-frontmatter" in ast.body


def test_parse_missing_file_returns_empty_with_error():
    ast = parse_agent(FIX / "does-not-exist.md")
    assert ast.parse_errors
    assert ast.line_count == 0


def test_parse_orchestrator_kind_detected():
    ast = parse_agent(FIX / "big-orchestrator.md")
    assert ast.is_orchestrator is True
    clean = parse_agent(FIX / "clean-agent.md")
    assert clean.is_orchestrator is False


def test_discover_agents_finds_real_repo_agents(tmp_path, monkeypatch):
    # Build a fake .opencode/agents tree
    agents_dir = tmp_path / ".opencode" / "agents"
    agents_dir.mkdir(parents=True)
    (agents_dir / "a.md").write_text("---\nname: a\n---\n# a\n")
    (agents_dir / "b.md").write_text("---\nname: b\n---\n# b\n")
    (agents_dir / "ignore.txt").write_text("not md")
    found = discover_agents(tmp_path)
    names = sorted(p.name for p in found)
    assert names == ["a.md", "b.md"]
