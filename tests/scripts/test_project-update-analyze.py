"""Tests for scripts/project-update-analyze.py — F3 deterministic consolidator.

F3 reads F1+F2 outputs and produces a single radar.md. Pure deterministic
(no LLM); tests cover schema parsing, idempotence, and graceful behavior
when sources are missing.
"""
import importlib.util
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "project-update-analyze.py"


def _load():
    spec = importlib.util.spec_from_file_location("project_update_analyze", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_load_json_returns_default_on_missing(tmp_path):
    mod = _load()
    assert mod.load_json(tmp_path / "missing.json", default={}) == {}
    assert mod.load_json(tmp_path / "missing.json", default=[]) == []


def test_load_json_returns_default_on_invalid(tmp_path):
    mod = _load()
    bad = tmp_path / "bad.json"
    bad.write_text("not json", encoding="utf-8")
    assert mod.load_json(bad, default={"x": 1}) == {"x": 1}


def test_summarize_mail_counts_inbox_and_sent():
    mod = _load()
    payload = [
        {"account": "a1", "count": 5, "sent_count": 3, "emails": ["e1"], "sent": ["s1"]},
        {"account": "a2", "count": 0, "sent_count": 0, "emails": [], "sent": []},
    ]
    s = mod.summarize_mail(payload)
    assert s["accounts"] == 2
    assert s["total_inbox"] == 5
    assert s["total_sent"] == 3
    # account-level breakdown
    assert s["per_account"]["a1"]["inbox"] == 5
    assert s["per_account"]["a2"]["inbox"] == 0


def test_summarize_calendar_groups_by_day():
    mod = _load()
    payload = [
        {"account": "a1", "events": [
            {"event": "Daily 9-10", "day_offset": 0, "day_date": "2026-04-30"},
            {"event": "Sprint review 14-15", "day_offset": 1, "day_date": "2026-05-01"},
            {"event": "Lunch 13-14", "day_offset": 0, "day_date": "2026-04-30"},
        ]}
    ]
    s = mod.summarize_calendar(payload)
    assert s["total_events"] == 3
    assert "2026-04-30" in s["per_day"]
    assert s["per_day"]["2026-04-30"] == 2


def test_extract_action_items_from_digest_finds_checkboxes(tmp_path):
    mod = _load()
    md = tmp_path / "20260430-test.md"
    md.write_text(
        "# Meeting digest\n\n"
        "## Action items\n"
        "- [ ] @monica revisar PBI deadline lunes\n"
        "- [ ] @ana cerrar sprint el viernes\n"
        "- [x] hecho\n",
        encoding="utf-8",
    )
    items = mod.extract_action_items(md)
    assert len(items) == 2
    assert "@monica" in items[0]


def test_extract_action_items_returns_empty_for_stub_digest(tmp_path):
    mod = _load()
    md = tmp_path / "stub.md"
    md.write_text(
        "# Meeting digest\n\n"
        "**Líneas totales**: 100\n"
        "## Inicio\n"
        "alguna linea\n",
        encoding="utf-8",
    )
    assert mod.extract_action_items(md) == []


def test_render_radar_is_idempotent(tmp_path):
    """Same inputs → same output (modulo timestamp)."""
    mod = _load()
    inputs = {
        "mail_summary": {"accounts": 2, "total_inbox": 10, "total_sent": 5,
                         "per_account": {"a1": {"inbox": 10, "sent": 5}}},
        "calendar_summary": {"total_events": 0, "per_day": {}},
        "devops_md": "Total: **0**",
        "auth_status": {"a1": "running", "a2": "error"},
        "digests": [],
    }
    out_a = mod.render_radar("Project X", inputs, fixed_ts="2026-04-30 10:00")
    out_b = mod.render_radar("Project X", inputs, fixed_ts="2026-04-30 10:00")
    assert out_a == out_b
    assert "Project X" in out_a
    assert "Sources status" in out_a


def test_render_radar_marks_failed_auth():
    mod = _load()
    inputs = {
        "mail_summary": {"accounts": 0, "total_inbox": 0, "total_sent": 0, "per_account": {}},
        "calendar_summary": {"total_events": 0, "per_day": {}},
        "devops_md": "",
        "auth_status": {"a1": "error", "a2": "running"},
        "digests": [],
    }
    out = mod.render_radar("X", inputs, fixed_ts="t")
    # both accounts must be present in status table (running and error)
    assert "a1" in out
    assert "a2" in out


def test_main_creates_radar_file(tmp_path, monkeypatch):
    mod = _load()
    # Build minimal F1 layout
    tmp = tmp_path / "tmp"
    tmp.mkdir()
    (tmp / "mail.json").write_text(json.dumps([
        {"account": "a1", "count": 3, "sent_count": 1, "emails": [], "sent": []}
    ]), encoding="utf-8")
    (tmp / "calendar.json").write_text("[]", encoding="utf-8")
    (tmp / "devops-summary.md").write_text("# devops\nTotal: 0", encoding="utf-8")

    target = tmp_path / "radar"
    out = mod.run_analyze(slug="ProjectX", tmp_dir=tmp, meetings_dir=tmp_path / "missing", target_dir=target)
    assert out.exists()
    body = out.read_text(encoding="utf-8")
    assert "ProjectX" in body
    assert "Sources status" in body


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
