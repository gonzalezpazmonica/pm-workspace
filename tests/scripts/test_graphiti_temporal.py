"""tests/scripts/test_graphiti_temporal.py — SPEC-123

Tests for scripts/knowledge-graph-temporal.py: Temporal Pattern.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "knowledge-graph-temporal.py"


def _load():
    spec = importlib.util.spec_from_file_location("kg_temporal", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["kg_temporal"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()


def fresh_db(tmp_path: Path) -> Path:
    db = tmp_path / "test-kg.db"
    conn = mod.open_db(db)
    conn.close()
    return db


# ── test 1: add-temporal sets valid_at ───────────────────────────────────────
def test_add_temporal_valid_at(tmp_path):
    db = fresh_db(tmp_path)
    conn = mod.open_db(db)
    mod.upsert_entity(conn, "pbi:PBI-001", "spec")
    conn.close()

    output_lines: list[str] = []
    import builtins
    orig_print = builtins.print
    builtins.print = lambda *a, **kw: output_lines.append(" ".join(str(x) for x in a))
    try:
        rc = mod.main(["--db", str(db), "add-temporal",
                       "--entity", "pbi:PBI-001",
                       "--valid-at", "2026-03-15T09:00:00Z"])
    finally:
        builtins.print = orig_print

    assert rc == 0
    parsed = json.loads("\n".join(output_lines))
    assert parsed["valid_at"] == "2026-03-15T09:00:00Z"
    assert parsed["action"] == "add_temporal"


# ── test 2: invalidate sets expired_at ───────────────────────────────────────
def test_invalidate_sets_expired_at(tmp_path):
    db = fresh_db(tmp_path)
    conn = mod.open_db(db)
    eid = mod.upsert_entity(conn, "person:laura", "person")
    conn.execute("UPDATE entities SET valid_at='2026-01-01T00:00:00Z' WHERE id=?", (eid,))
    conn.commit()
    conn.close()

    output_lines: list[str] = []
    import builtins
    orig_print = builtins.print
    builtins.print = lambda *a, **kw: output_lines.append(" ".join(str(x) for x in a))
    try:
        rc = mod.main(["--db", str(db), "invalidate",
                       "--entity", "person:laura",
                       "--expired-at", "2026-06-01T00:00:00Z"])
    finally:
        builtins.print = orig_print

    assert rc == 0
    parsed = json.loads("\n".join(output_lines))
    assert parsed["expired_at"] == "2026-06-01T00:00:00Z"
    assert parsed["records_updated"] >= 1


# ── test 3: query-at returns only entities valid at given time ────────────────
def test_query_at_filters_correctly(tmp_path):
    db = fresh_db(tmp_path)
    conn = mod.open_db(db)
    eid1 = mod.upsert_entity(conn, "entity:active", "concept")
    eid2 = mod.upsert_entity(conn, "entity:future", "concept")
    eid3 = mod.upsert_entity(conn, "entity:expired", "concept")
    conn.execute("UPDATE entities SET valid_at='2026-01-01T00:00:00Z', expired_at=NULL WHERE id=?", (eid1,))
    conn.execute("UPDATE entities SET valid_at='2026-12-01T00:00:00Z' WHERE id=?", (eid2,))
    conn.execute("UPDATE entities SET valid_at='2026-01-01T00:00:00Z', expired_at='2026-03-01T00:00:00Z' WHERE id=?", (eid3,))
    conn.commit()
    conn.close()

    output_lines: list[str] = []
    import builtins
    orig_print = builtins.print
    builtins.print = lambda *a, **kw: output_lines.append(" ".join(str(x) for x in a))
    try:
        rc = mod.main(["--db", str(db), "query-at", "--when", "2026-06-01T00:00:00Z"])
    finally:
        builtins.print = orig_print

    assert rc == 0
    parsed = json.loads("\n".join(output_lines))
    names = [r["entity"] for r in parsed["results"]]
    assert "entity:active" in names
    assert "entity:future" not in names   # not yet valid
    assert "entity:expired" not in names  # already expired


# ── test 4: retro-compat backfill from first_seen ────────────────────────────
def test_backfill_from_first_seen(tmp_path):
    db = fresh_db(tmp_path)
    conn = mod.open_db(db)
    eid = mod.upsert_entity(conn, "legacy:entity", "spec")
    # Manually set first_seen, leave valid_at NULL
    conn.execute("UPDATE entities SET first_seen='2025-11-01 10:00:00', valid_at=NULL WHERE id=?", (eid,))
    conn.commit()
    conn.close()

    # Run backfill — capture only stdout (not stderr warning)
    import io
    stdout_capture = io.StringIO()
    import builtins
    orig_print = builtins.print

    def capture_print(*a, file=None, **kw):
        if file is None or file is sys.stdout:
            stdout_capture.write(" ".join(str(x) for x in a) + "\n")
        # Allow stderr messages through (they go to real stderr, not captured)

    builtins.print = capture_print
    try:
        rc = mod.main(["--db", str(db), "backfill"])
    finally:
        builtins.print = orig_print

    assert rc == 0
    parsed = json.loads(stdout_capture.getvalue().strip())
    assert parsed["records_updated"] >= 1

    # Verify entity now has valid_at
    conn2 = mod.open_db(db)
    row = conn2.execute("SELECT valid_at FROM entities WHERE id=?", (eid,)).fetchone()
    assert row[0] == "2025-11-01 10:00:00"
    conn2.close()


# ── test 5: entity without temporal fields still appears in null-safe query ───
def test_entity_without_temporal_appears_in_query(tmp_path):
    db = fresh_db(tmp_path)
    conn = mod.open_db(db)
    mod.upsert_entity(conn, "entity:no-temporal", "concept")
    conn.commit()
    conn.close()

    output_lines: list[str] = []
    import builtins
    orig_print = builtins.print
    builtins.print = lambda *a, **kw: output_lines.append(" ".join(str(x) for x in a))
    try:
        rc = mod.main(["--db", str(db), "query-at", "--when", "2026-06-01T00:00:00Z"])
    finally:
        builtins.print = orig_print

    parsed = json.loads("\n".join(output_lines))
    names = [r["entity"] for r in parsed["results"]]
    assert "entity:no-temporal" in names


# ── test 6: invalid ISO date rejected ────────────────────────────────────────
def test_invalid_iso_date_rejected(tmp_path):
    db = fresh_db(tmp_path)
    with pytest.raises(SystemExit):
        mod.main(["--db", str(db), "add-temporal",
                  "--entity", "test", "--valid-at", "not-a-date"])


# ── test 7: expired_at before valid_at is rejected ───────────────────────────
def test_expired_before_valid_rejected(tmp_path):
    db = fresh_db(tmp_path)
    with pytest.raises(SystemExit):
        mod.main(["--db", str(db), "add-temporal",
                  "--entity", "test",
                  "--valid-at", "2026-06-01",
                  "--expired-at", "2026-01-01"])


# ── test 8: add-temporal with both valid_at and expired_at ───────────────────
def test_add_temporal_with_expiry(tmp_path):
    db = fresh_db(tmp_path)

    output_lines: list[str] = []
    import builtins
    orig_print = builtins.print
    builtins.print = lambda *a, **kw: output_lines.append(" ".join(str(x) for x in a))
    try:
        rc = mod.main(["--db", str(db), "add-temporal",
                       "--entity", "temp:sprint-01",
                       "--valid-at", "2026-01-01",
                       "--expired-at", "2026-01-14"])
    finally:
        builtins.print = orig_print

    assert rc == 0
    parsed = json.loads("\n".join(output_lines))
    assert parsed["valid_at"] == "2026-01-01"
    assert parsed["expired_at"] == "2026-01-14"
