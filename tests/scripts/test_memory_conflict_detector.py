"""tests/scripts/test_memory_conflict_detector.py — SE-214

Tests for scripts/memory-conflict-detector.py: semantic conflict detection.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "memory-conflict-detector.py"


def _load():
    spec = importlib.util.spec_from_file_location("memory_conflict_detector", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["memory_conflict_detector"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
detect_conflicts = mod.detect_conflicts
_parse_memory_md = mod._parse_memory_md
main = mod.main


def _entries(*texts):
    return [{"id": f"e{i}", "text": t, "type": "decision"} for i, t in enumerate(texts)]


def test_direct_contradiction_detected():
    entries = _entries(
        "Always require human approval for deployments",
        "Never require approval for low-risk automated deployments",
    )
    conflicts = detect_conflicts(entries)
    types = [c["conflict_type"] for c in conflicts]
    assert "direct_contradiction" in types


def test_value_disagreement_detected():
    entries = _entries(
        "Workspace has 70 agents available for use",
        "Workspace has 90 agents available for use",
    )
    conflicts = detect_conflicts(entries)
    types = [c["conflict_type"] for c in conflicts]
    assert "value_disagreement" in types


def test_no_conflict_for_unrelated_entries():
    entries = _entries(
        "Use Redis for session caching",
        "Deploy every Friday after QA approval",
    )
    conflicts = detect_conflicts(entries)
    assert len(conflicts) == 0


def test_conflict_output_schema():
    entries = _entries(
        "Use PostgreSQL always for primary storage",
        "Never use PostgreSQL — migrate to MongoDB",
    )
    conflicts = detect_conflicts(entries)
    if conflicts:
        c = conflicts[0]
        assert "entry_a" in c
        assert "entry_b" in c
        assert "conflict_type" in c
        assert "description" in c
        assert c["conflict_type"] in ("direct_contradiction", "temporal_overlap", "value_disagreement")


def test_parse_memory_md_entries(tmp_path):
    md = tmp_path / "MEMORY.md"
    md.write_text(
        "- decision: Use GraphQL for frontend [dec-1]\n"
        "- pattern: Circuit breaker on all external calls [pat-1]\n"
    )
    entries = _parse_memory_md(md)
    assert len(entries) == 2
    assert entries[0]["type"] == "decision"
    assert "GraphQL" in entries[0]["text"]


def test_empty_memory_no_conflicts():
    conflicts = detect_conflicts([])
    assert conflicts == []


def test_cli_outputs_json(tmp_path):
    md = tmp_path / "MEMORY.md"
    md.write_text(
        "- decision: Always require approval [d1]\n"
        "- decision: Never require approval for deployments [d2]\n"
    )
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--memory-file", str(md), "--quiet"])
    assert rc == 0
    parsed = json.loads(buf.getvalue())
    assert "conflicts" in parsed
    assert "total" in parsed
