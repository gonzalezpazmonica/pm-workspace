"""
Tests for scripts/pm-radar.py
Stdlib-only pytest tests covering core logic.
Run: pytest tests/scripts/test_pm-radar.py -v
"""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path


# ─────────────────────────────────────────────────────────────────────────────
# Helpers to load the module from path (no package install required)
# ─────────────────────────────────────────────────────────────────────────────

def _load_pm_radar():
    """Load pm-radar.py as a module without requiring it to be a package."""
    scripts_dir = Path(__file__).parent.parent.parent / "scripts"
    module_path = scripts_dir / "pm-radar.py"
    if not module_path.exists():
        raise ImportError(f"pm-radar.py not found at {module_path}")
    spec = importlib.util.spec_from_file_location("pm_radar", module_path)
    module = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


try:
    pm_radar = _load_pm_radar()
    MODULE_AVAILABLE = True
except ImportError:
    MODULE_AVAILABLE = False


import pytest

pytestmark = pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="pm-radar.py not yet implemented"
)


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests: scoring
# ─────────────────────────────────────────────────────────────────────────────

class TestScoring:
    def test_compute_score_max(self):
        score = pm_radar.compute_score(10, 10, 10, 10)
        assert score == 100

    def test_compute_score_formula(self):
        # urgencia*3 + importancia*3 + prioridad*2 + antiguedad*2
        score = pm_radar.compute_score(5, 5, 5, 5)
        assert score == 5 * 3 + 5 * 3 + 5 * 2 + 5 * 2

    def test_score_from_defaults_critico(self):
        score = pm_radar.score_from_defaults("critico")
        assert score > pm_radar.score_from_defaults("urgente")

    def test_score_from_defaults_ordering(self):
        scores = [pm_radar.score_from_defaults(b) for b in pm_radar.BAND_ORDER]
        # Each band should score less than the previous
        for i in range(len(scores) - 1):
            assert scores[i] > scores[i + 1], f"Band ordering broken at index {i}"

    def test_score_from_defaults_unknown_band(self):
        # Should not raise, falls back to seguimiento defaults
        score = pm_radar.score_from_defaults("nonexistent")
        assert isinstance(score, int)
        assert score >= 0


class TestInferBand:
    def test_critico_keyword(self):
        assert pm_radar.infer_band("Compromiso regulatorio crítico vencido") == "critico"

    def test_urgente_keyword(self):
        assert pm_radar.infer_band("Item urgente sin escalar") == "urgente"

    def test_importante_keyword(self):
        assert pm_radar.infer_band("Riesgo importante sin PBI") == "importante"

    def test_fallback_to_score(self):
        # No keywords, high score => critico
        assert pm_radar.infer_band("some random text", existing_score=80) == "critico"

    def test_fallback_default(self):
        # No keywords, no score
        assert pm_radar.infer_band("some random text") == "seguimiento"


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests: file parsing
# ─────────────────────────────────────────────────────────────────────────────

class TestParseAgentFile:
    def _write_tmp(self, content: str, name: str = "agent-test.md") -> Path:
        self._tmpdir = tempfile.mkdtemp()
        p = Path(self._tmpdir) / name
        p.write_text(content, encoding="utf-8")
        return p

    def test_parse_score_items(self):
        content = "- [86] UDB Plan B en PRE — compromiso REGULATORIO\n- [72] Email sin respuesta\n"
        path = self._write_tmp(content)
        items = pm_radar.parse_agent_file(path)
        assert len(items) >= 2
        scores = {i["score"] for i in items}
        assert 86 in scores
        assert 72 in scores

    def test_parse_bold_id_items(self):
        content = "- **ACTION-ALPHA** Preparar propuesta infra on-premise\n"
        path = self._write_tmp(content)
        items = pm_radar.parse_agent_file(path)
        assert len(items) >= 1
        assert any("ACTION-ALPHA" in i["id"] or "ALPHA" in i["id"] for i in items)

    def test_parse_nonexistent_file(self):
        items = pm_radar.parse_agent_file(Path("/tmp/nonexistent-agent.md"))
        assert items == []

    def test_parse_empty_file(self):
        path = self._write_tmp("")
        items = pm_radar.parse_agent_file(path)
        assert items == []

    def test_parse_deduplicates_ids(self):
        content = "- [80] Duplicate item\n- [80] Duplicate item\n"
        path = self._write_tmp(content)
        items = pm_radar.parse_agent_file(path)
        ids = [i["id"] for i in items]
        assert len(ids) == len(set(ids))


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests: state management
# ─────────────────────────────────────────────────────────────────────────────

class TestLoadState:
    def test_missing_file_returns_empty(self):
        state = pm_radar.load_state(Path("/tmp/nonexistent-state.json"))
        assert state == {"items": {}, "runs": []}

    def test_valid_json_loaded(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump({"items": {"A": {"id": "A", "status": "active"}}, "runs": []}, f)
            tmp_path = Path(f.name)
        state = pm_radar.load_state(tmp_path)
        assert "A" in state["items"]
        tmp_path.unlink(missing_ok=True)

    def test_corrupt_json_returns_empty(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            f.write("{invalid json}")
            tmp_path = Path(f.name)
        state = pm_radar.load_state(tmp_path)
        assert state == {"items": {}, "runs": []}
        tmp_path.unlink(missing_ok=True)


class TestMergeItems:
    def _now(self) -> datetime:
        return datetime(2026, 4, 22, 10, 0, 0)

    def test_new_items_added(self):
        state = {"items": {}, "runs": []}
        new_items = [
            {"id": "ITEM-001", "title": "Test item", "band": "urgente", "score": 70, "source_file": "agent-test"}
        ]
        state, added, closed, reprio = pm_radar.merge_items(state, new_items, self._now())
        assert "ITEM-001" in state["items"]
        assert "ITEM-001" in added
        assert state["items"]["ITEM-001"]["status"] == "active"

    def test_existing_item_preserved(self):
        existing_item = {
            "id": "ITEM-002",
            "status": "active",
            "band": "critico",
            "score": 90,
            "first_seen": "2026-04-14T10:00:00",
            "note": "original note",
        }
        state = {"items": {"ITEM-002": existing_item}, "runs": []}
        new_items = [
            {"id": "ITEM-002", "title": "Same", "band": "urgente", "score": 70, "source_file": "agent-test"}
        ]
        state, added, closed, reprio = pm_radar.merge_items(state, new_items, self._now())
        # Should not re-add
        assert "ITEM-002" not in added
        # Note preserved
        assert state["items"]["ITEM-002"].get("note") == "original note"
        # first_seen preserved
        assert state["items"]["ITEM-002"]["first_seen"] == "2026-04-14T10:00:00"

    def test_deferred_item_reactivated(self):
        now = self._now()
        yesterday = (now - timedelta(days=1)).strftime("%Y-%m-%d")
        state = {
            "items": {
                "ITEM-DEF": {
                    "id": "ITEM-DEF",
                    "status": "deferred",
                    "defer_until": yesterday,
                    "band": "urgente",
                    "score": 65,
                }
            },
            "runs": [],
        }
        state, added, closed, reprio = pm_radar.merge_items(state, [], now)
        assert state["items"]["ITEM-DEF"]["status"] == "active"

    def test_deferred_future_stays_deferred(self):
        now = self._now()
        tomorrow = (now + timedelta(days=1)).strftime("%Y-%m-%d")
        state = {
            "items": {
                "ITEM-FUTURE": {
                    "id": "ITEM-FUTURE",
                    "status": "deferred",
                    "defer_until": tomorrow,
                    "band": "urgente",
                    "score": 65,
                }
            },
            "runs": [],
        }
        state, added, closed, reprio = pm_radar.merge_items(state, [], now)
        assert state["items"]["ITEM-FUTURE"]["status"] == "deferred"

    def test_band_upgrade_on_merge(self):
        state = {
            "items": {
                "ITEM-UP": {
                    "id": "ITEM-UP",
                    "status": "active",
                    "band": "importante",
                    "score": 50,
                }
            },
            "runs": [],
        }
        new_items = [
            {"id": "ITEM-UP", "title": "Now critical", "band": "critico", "score": 90, "source_file": "agent-test"}
        ]
        state, added, closed, reprio = pm_radar.merge_items(state, new_items, self._now())
        assert state["items"]["ITEM-UP"]["band"] == "critico"
        assert "ITEM-UP" in reprio

    def test_no_band_downgrade(self):
        state = {
            "items": {
                "ITEM-DOWN": {
                    "id": "ITEM-DOWN",
                    "status": "active",
                    "band": "critico",
                    "score": 90,
                }
            },
            "runs": [],
        }
        new_items = [
            {"id": "ITEM-DOWN", "title": "Now low", "band": "seguimiento", "score": 20, "source_file": "agent-test"}
        ]
        state, added, closed, reprio = pm_radar.merge_items(state, new_items, self._now())
        assert state["items"]["ITEM-DOWN"]["band"] == "critico"
        assert "ITEM-DOWN" not in reprio


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests: inconsistency detection
# ─────────────────────────────────────────────────────────────────────────────

class TestDetectInconsistencies:
    def _make_tmp(self) -> Path:
        return Path(tempfile.mkdtemp())

    def test_stale_action_detected(self):
        tmp = self._make_tmp()
        now = datetime(2026, 4, 22, 10, 0, 0)
        old_date = (now - timedelta(days=10)).strftime("%Y-%m-%d")
        content = f"- **{old_date}** | Reportar estado integraciones | Plazo: esta semana\n"
        (tmp / "agent-meetings-actions.md").write_text(content, encoding="utf-8")

        incons = pm_radar.detect_inconsistencies(tmp, now)
        stale = [i for i in incons if i["type"] == "action_stale"]
        assert len(stale) >= 1
        assert stale[0]["age_days"] >= 10

    def test_fresh_action_not_flagged(self):
        tmp = self._make_tmp()
        now = datetime(2026, 4, 22, 10, 0, 0)
        fresh_date = (now - timedelta(days=2)).strftime("%Y-%m-%d")
        content = f"- **{fresh_date}** | Tarea fresca | Plazo: mañana\n"
        (tmp / "agent-meetings-actions.md").write_text(content, encoding="utf-8")

        incons = pm_radar.detect_inconsistencies(tmp, now)
        stale = [i for i in incons if i["type"] == "action_stale"]
        assert len(stale) == 0

    def test_meeting_no_prep_detected(self):
        tmp = self._make_tmp()
        now = datetime(2026, 4, 22, 10, 0, 0)
        # Meeting in 2 hours
        meeting_time = (now + timedelta(hours=2)).strftime("%H:%M")
        end_time = (now + timedelta(hours=3)).strftime("%H:%M")
        content = f"- [{meeting_time}-{end_time}] Daily interna (Ana) | daily | prep=no\n"
        (tmp / "agent-calendar.md").write_text(content, encoding="utf-8")

        incons = pm_radar.detect_inconsistencies(tmp, now)
        no_prep = [i for i in incons if i["type"] == "meeting_no_prep"]
        assert len(no_prep) >= 1

    def test_roadmap_nopbi_detected(self):
        tmp = self._make_tmp()
        now = datetime(2026, 4, 22, 10, 0, 0)
        content = "## SIN PBI (riesgo)\n\n- [28 abr] **UDB Plan B en PRE** — compromiso REGULATORIO\n"
        (tmp / "agent-roadmap.md").write_text(content, encoding="utf-8")

        incons = pm_radar.detect_inconsistencies(tmp, now)
        no_pbi = [i for i in incons if i["type"] == "roadmap_no_pbi"]
        assert len(no_pbi) >= 1

    def test_no_files_no_crash(self):
        tmp = self._make_tmp()
        now = datetime(2026, 4, 22, 10, 0, 0)
        incons = pm_radar.detect_inconsistencies(tmp, now)
        assert isinstance(incons, list)


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests: atomic write
# ─────────────────────────────────────────────────────────────────────────────

class TestWriteStateAtomic:
    def test_writes_valid_json(self):
        with tempfile.TemporaryDirectory() as tmp_str:
            state_path = Path(tmp_str) / "state.json"
            state = {"items": {"X": {"id": "X"}}, "runs": []}
            pm_radar.write_state_atomic(state, state_path)
            assert state_path.exists()
            loaded = json.loads(state_path.read_text(encoding="utf-8"))
            assert "items" in loaded
            assert "X" in loaded["items"]

    def test_creates_parent_dirs(self):
        with tempfile.TemporaryDirectory() as tmp_str:
            state_path = Path(tmp_str) / "nested" / "deep" / "state.json"
            state = {"items": {}, "runs": []}
            pm_radar.write_state_atomic(state, state_path)
            assert state_path.exists()


# ─────────────────────────────────────────────────────────────────────────────
# Integration: build_report
# ─────────────────────────────────────────────────────────────────────────────

class TestBuildReport:
    def test_report_structure(self):
        now = datetime(2026, 4, 22, 10, 0, 0)
        state = {
            "items": {
                "ITEM-A": {"id": "ITEM-A", "status": "active", "band": "critico", "score": 90},
                "ITEM-B": {"id": "ITEM-B", "status": "closed", "band": "urgente", "score": 70},
            },
            "runs": [],
        }
        report = pm_radar.build_report(state, [], {}, now, "run-test")
        assert "items" in report
        assert "inconsistencies" in report
        assert "delta" in report
        assert "stats" in report
        assert "timestamp" in report
        # Closed items should not appear
        item_ids = {i["id"] for i in report["items"]}
        assert "ITEM-A" in item_ids
        assert "ITEM-B" not in item_ids

    def test_report_sorted_by_band(self):
        now = datetime(2026, 4, 22, 10, 0, 0)
        state = {
            "items": {
                "LOW": {"id": "LOW", "status": "active", "band": "seguimiento", "score": 20},
                "HIGH": {"id": "HIGH", "status": "active", "band": "critico", "score": 90},
                "MED": {"id": "MED", "status": "active", "band": "urgente", "score": 65},
            },
            "runs": [],
        }
        report = pm_radar.build_report(state, [], {}, now, "run-sort")
        ids = [i["id"] for i in report["items"]]
        assert ids.index("HIGH") < ids.index("MED")
        assert ids.index("MED") < ids.index("LOW")

    def test_stats_counts(self):
        now = datetime(2026, 4, 22, 10, 0, 0)
        state = {
            "items": {
                "C1": {"id": "C1", "status": "active", "band": "critico", "score": 90},
                "U1": {"id": "U1", "status": "active", "band": "urgente", "score": 70},
                "U2": {"id": "U2", "status": "active", "band": "urgente", "score": 68},
            },
            "runs": [],
        }
        report = pm_radar.build_report(state, [], {}, now, "run-stats")
        assert report["stats"]["critico"] == 1
        assert report["stats"]["urgente"] == 2
        assert report["stats"]["total_active"] == 3
