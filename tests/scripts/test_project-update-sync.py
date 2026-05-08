"""Tests for scripts/project-update-sync.py — F4 deterministic PENDING updater.

F4 reads the latest radar.md, extracts action items, and appends new ones
to PENDING.md. Idempotent: re-running with same input produces same file.
Dedup is by case-folded action text (with source label stripped).
"""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "project-update-sync.py"


def _load():
    spec = importlib.util.spec_from_file_location("project_update_sync", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_extract_radar_items_finds_consolidated_list(tmp_path):
    mod = _load()
    radar = tmp_path / "20260430-1052-radar.md"
    radar.write_text(
        "# Radar — X — date\n\n"
        "## Action items abiertos (consolidado)\n\n"
        "- [ ] @monica revisar PBI 1 _[meeting-A]_\n"
        "- [ ] @ana cerrar sprint _[meeting-B]_\n"
        "- [x] hecho _[meeting-A]_\n\n"
        "---\n",
        encoding="utf-8",
    )
    items = mod.extract_radar_items(radar)
    assert len(items) == 2
    assert "@monica revisar PBI 1" in items[0]["text"]
    assert items[0]["source"] == "meeting-A"


def test_extract_radar_items_returns_empty_when_section_missing(tmp_path):
    mod = _load()
    radar = tmp_path / "r.md"
    radar.write_text("# Radar\n\n## Otra cosa\n- something\n", encoding="utf-8")
    assert mod.extract_radar_items(radar) == []


def test_dedup_key_normalizes_whitespace_and_case():
    mod = _load()
    a = mod.dedup_key("@MONICA  revisar  algo")
    b = mod.dedup_key("@monica revisar algo")
    assert a == b


def test_existing_item_keys_extracts_from_pending(tmp_path):
    mod = _load()
    pending = tmp_path / "PENDING.md"
    pending.write_text(
        "# PENDING\n\n"
        "## Acciones esta semana\n"
        "- [ ] @ana revisar X _[m1]_\n"
        "- [ ] @bob cerrar Y\n"
        "## Cerradas hoy\n"
        "(ninguno)\n",
        encoding="utf-8",
    )
    keys = mod.existing_item_keys(pending)
    assert mod.dedup_key("@ana revisar X") in keys
    assert mod.dedup_key("@bob cerrar Y") in keys


def test_find_latest_radar_returns_newest(tmp_path):
    mod = _load()
    d = tmp_path / "radar"
    d.mkdir()
    (d / "20260429-0900-radar.md").write_text("old", encoding="utf-8")
    (d / "20260430-1052-radar.md").write_text("new", encoding="utf-8")
    (d / "20260430-0800-radar.md").write_text("middle", encoding="utf-8")
    latest = mod.find_latest_radar(d)
    assert latest.name == "20260430-1052-radar.md"


def test_find_latest_radar_returns_none_when_empty(tmp_path):
    mod = _load()
    (tmp_path / "radar").mkdir()
    assert mod.find_latest_radar(tmp_path / "radar") is None


def test_update_pending_appends_only_new_items(tmp_path):
    mod = _load()
    pending = tmp_path / "PENDING.md"
    pending.write_text(
        "# PENDING — Mónica · X\n\n"
        "**Última actualización**: 2026-04-29\n\n"
        "## Acciones esta semana\n"
        "- [ ] @ana already-here\n\n"
        "## Cerradas hoy\n"
        "(ninguno)\n",
        encoding="utf-8",
    )
    radar = tmp_path / "r.md"
    radar.write_text(
        "## Action items abiertos (consolidado)\n\n"
        "- [ ] @ana already-here _[m1]_\n"
        "- [ ] @bob brand-new _[m2]_\n"
        "- [ ] @cici another-new _[m3]_\n",
        encoding="utf-8",
    )
    n = mod.update_pending(radar, pending, today="2026-04-30")
    body = pending.read_text(encoding="utf-8")
    assert n == 2
    assert "brand-new" in body
    assert "another-new" in body
    # already-here is NOT added twice
    assert body.count("already-here") == 1


def test_update_pending_is_idempotent(tmp_path):
    mod = _load()
    pending = tmp_path / "PENDING.md"
    pending.write_text(
        "# PENDING\n\n## Acciones esta semana\n(ninguno)\n",
        encoding="utf-8",
    )
    radar = tmp_path / "r.md"
    radar.write_text(
        "## Action items abiertos (consolidado)\n\n"
        "- [ ] @ana item1 _[m1]_\n"
        "- [ ] @bob item2 _[m2]_\n",
        encoding="utf-8",
    )
    n1 = mod.update_pending(radar, pending, today="2026-04-30")
    body1 = pending.read_text(encoding="utf-8")
    n2 = mod.update_pending(radar, pending, today="2026-04-30")
    body2 = pending.read_text(encoding="utf-8")
    assert n1 == 2
    assert n2 == 0
    assert body1 == body2


def test_update_pending_creates_section_if_missing(tmp_path):
    mod = _load()
    pending = tmp_path / "PENDING.md"
    pending.write_text("# PENDING\n\n", encoding="utf-8")
    radar = tmp_path / "r.md"
    radar.write_text(
        "## Action items abiertos (consolidado)\n\n"
        "- [ ] @x do-it _[m]_\n",
        encoding="utf-8",
    )
    n = mod.update_pending(radar, pending, today="2026-04-30")
    body = pending.read_text(encoding="utf-8")
    assert n == 1
    assert "## Acciones esta semana" in body
    assert "do-it" in body


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
