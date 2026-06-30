"""tests/scripts/test_memory_bitemporal.py — SPEC-153

Tests for scripts/memory-bitemporal.py: bi-temporal memory extension.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "memory-bitemporal.py"


def _load():
    spec = importlib.util.spec_from_file_location("memory_bitemporal", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["memory_bitemporal"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
add_entry = mod.add_entry
query_at = mod.query_at
list_all = mod.list_all
invalidate = mod.invalidate
main = mod.main


def test_add_returns_required_fields(tmp_path):
    db = tmp_path / "test.db"
    result = add_entry("Use Redis for caching", "2026-01-15", "2026-06-01", db_path=db)
    assert "id" in result
    assert result["occurred"] == "2026-01-15"
    assert result["learned"] == "2026-06-01"
    assert result["entry"] == "Use Redis for caching"


def test_query_at_returns_entries_known_by_that_date(tmp_path):
    db = tmp_path / "test.db"
    add_entry("Fact A", "2025-12-01", "2026-01-01", db_path=db)
    add_entry("Fact B", "2026-05-01", "2026-06-15", db_path=db)
    # Query at 2026-03-01 — only Fact A should appear (learned 2026-01-01 <= 2026-03-01)
    results = query_at("2026-03-01", db_path=db)
    texts = [r["entry"] for r in results]
    assert "Fact A" in texts
    assert "Fact B" not in texts


def test_query_at_excludes_future_learned(tmp_path):
    db = tmp_path / "test.db"
    add_entry("Future fact", "2026-10-01", "2026-11-01", db_path=db)
    results = query_at("2026-06-01", db_path=db)
    assert all(r["entry"] != "Future fact" for r in results)


def test_invalidate_excludes_entry_from_later_queries(tmp_path):
    db = tmp_path / "test.db"
    e = add_entry("Old decision", "2026-01-01", "2026-02-01", db_path=db)
    invalidate(e["id"], "2026-04-01", db_path=db)
    # Should appear at 2026-03-01 (before invalidation)
    before = query_at("2026-03-01", db_path=db)
    assert any(r["entry"] == "Old decision" for r in before)
    # Should NOT appear at 2026-05-01 (after invalidation)
    after = query_at("2026-05-01", db_path=db)
    assert all(r["entry"] != "Old decision" for r in after)


def test_invalid_date_raises(tmp_path):
    db = tmp_path / "test.db"
    with pytest.raises(ValueError):
        add_entry("Bad date entry", "not-a-date", "2026-06-01", db_path=db)


def test_list_all_includes_all_entries(tmp_path):
    db = tmp_path / "test.db"
    add_entry("Entry 1", "2026-01-01", "2026-01-15", db_path=db)
    add_entry("Entry 2", "2026-03-01", "2026-03-10", db_path=db)
    rows = list_all(db_path=db)
    assert len(rows) == 2


def test_cli_add_and_query(tmp_path):
    db = tmp_path / "mem.db"
    import io, contextlib
    # add
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--db-path", str(db), "add",
                   "--entry", "Test memory entry",
                   "--occurred", "2026-05-01",
                   "--learned", "2026-06-01"])
    assert rc == 0
    # query
    buf2 = io.StringIO()
    with contextlib.redirect_stdout(buf2):
        rc2 = main(["--db-path", str(db), "--quiet", "query", "--at", "2026-06-15"])
    assert rc2 == 0
    rows = json.loads(buf2.getvalue())
    assert any(r["entry"] == "Test memory entry" for r in rows)
