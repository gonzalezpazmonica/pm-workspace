"""tests/scripts/test_critic_rag.py — SPEC-167

Tests for scripts/critic-rag.py: critic with RAG over external memory.
"""
from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "critic-rag.py"


def _load():
    spec = importlib.util.spec_from_file_location("critic_rag", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["critic_rag"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
critique = mod.critique
retrieve_precedents = mod.retrieve_precedents
bm25_score = mod.bm25_score
main = mod.main


def _make_kg(tmp_path, rows):
    """Create a minimal knowledge-graph.db with entities table."""
    db = tmp_path / "knowledge-graph.db"
    conn = sqlite3.connect(str(db))
    conn.execute(
        "CREATE TABLE entities "
        "(id TEXT PRIMARY KEY, name TEXT, entity_type TEXT, description TEXT, created_at TEXT)"
    )
    for row in rows:
        conn.execute(
            "INSERT INTO entities VALUES (?,?,?,?,?)",
            (row["id"], row["name"], row.get("type", "decision"),
             row.get("desc", ""), row.get("ts", "2026-01-01")),
        )
    conn.commit()
    conn.close()
    return db


def test_output_schema():
    """critique() returns required JSON keys."""
    result = critique("Some draft text about architecture", kg_path=Path("/nonexistent"))
    assert "verdict" in result
    assert "score" in result
    assert "rag_context_used" in result
    assert "precedents" in result


def test_fallback_when_no_kg():
    """critic works gracefully without a KG (rag_available=False)."""
    result = critique("draft without memory", kg_path=Path("/nonexistent/missing.db"))
    assert result["rag_context_used"] is False
    assert isinstance(result["score"], float)
    assert result["verdict"]


def test_retrieves_relevant_precedents(tmp_path):
    """With matching content in KG, rag_context_used=True and precedents returned."""
    db = _make_kg(tmp_path, [
        {"id": "e1", "name": "architecture decision", "desc": "use microservices for scalability"},
        {"id": "e2", "name": "test failure", "desc": "integration test broken after refactor"},
    ])
    result = critique("microservices architecture scalability decision", kg_path=db, top_k=5)
    assert result["rag_available"] is True
    assert result["rag_context_used"] is True
    assert len(result["precedents"]) >= 1


def test_bm25_score_positive_for_matching_text():
    """BM25 returns positive score for query that overlaps with doc."""
    import math
    idf_map = {"architecture": math.log(2.0), "service": math.log(2.0)}
    score = bm25_score(["architecture", "service"], "service architecture design pattern", idf_map)
    assert score > 0.0


def test_score_range():
    """Score is always in [0, 1]."""
    result = critique("x" * 1000, kg_path=Path("/nonexistent"))
    assert 0.0 <= result["score"] <= 1.0


def test_low_score_for_negative_signals():
    """Draft with known negative signals scores lower than clean draft."""
    clean = critique("The system works as expected and is well-tested.", kg_path=Path("/nonexistent"))
    flagged = critique("This is broken deprecated without replacement undefined never works always fails.", kg_path=Path("/nonexistent"))
    assert flagged["score"] <= clean["score"]


def test_cli_outputs_json(tmp_path, capsys):
    """CLI outputs valid JSON to stdout."""
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--draft", "test critique text", "--kg-path", str(tmp_path / "missing.db"), "--quiet"])
    assert rc == 0
    parsed = json.loads(buf.getvalue())
    assert "verdict" in parsed
