"""tests/unit/context_update/test_discovery_store.py

Unit tests for F0 discovery and run store.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §10.2.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import pytest

_SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"
sys.path.insert(0, str(_SCRIPTS))

from lib.context_update import discovery, store


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

class TestDiscovery:
    def test_discover_returns_dict_with_files(self):
        result = discovery.discover(scope="content")
        assert isinstance(result, dict)
        assert "files" in result
        assert isinstance(result["files"], list)

    def test_discover_files_have_path(self):
        result = discovery.discover(scope="content")
        for f in result["files"][:5]:
            assert "path" in f, f"File missing 'path': {f}"

    def test_discover_scope_opencode(self):
        result = discovery.discover(scope="opencode")
        assert "files" in result

    def test_workspace_root_is_path(self):
        root = discovery.workspace_root()
        assert isinstance(root, Path)
        assert root.exists()

    def test_slug_filter_reduces_results(self):
        all_files  = discovery.discover(scope="all")["files"]
        slug_files = discovery.discover(scope="all", slug="acme-project")["files"]
        # Either same count (slug not found) or fewer
        assert len(slug_files) <= len(all_files)


# ---------------------------------------------------------------------------
# Store
# ---------------------------------------------------------------------------

class TestStore:
    def test_new_run_id_is_string(self):
        rid = store.new_run_id()
        assert isinstance(rid, str)
        assert len(rid) > 8

    def test_new_run_ids_are_unique(self):
        ids = [store.new_run_id() for _ in range(5)]
        assert len(set(ids)) == 5

    def test_run_dir_returns_path(self):
        rid = store.new_run_id()
        d = store.run_dir(rid)
        assert isinstance(d, Path)

    def test_write_json_creates_file(self, tmp_path, monkeypatch):
        rid = "test-run-001"
        monkeypatch.setattr(
            store, "run_dir",
            lambda r: tmp_path / r
        )
        store.write_json(rid, "F0", "discovery", {"files": [], "test": True})
        expected = tmp_path / rid / "F0" / "discovery.json"
        assert expected.exists()
        data = json.loads(expected.read_text())
        assert data["test"] is True

    def test_append_metrics_creates_ledger(self, tmp_path, monkeypatch):
        monkeypatch.setattr(store, "METRICS_LEDGER",
                            tmp_path / "context-update-metrics.jsonl")
        rid = store.new_run_id()
        store.append_metrics(rid, "all", {"total_findings": 42})
        lines = (tmp_path / "context-update-metrics.jsonl").read_text().splitlines()
        assert len(lines) == 1
        entry = json.loads(lines[0])
        assert entry["total_findings"] == 42

    def test_read_trend_returns_list(self, tmp_path, monkeypatch):
        monkeypatch.setattr(store, "METRICS_LEDGER",
                            tmp_path / "context-update-metrics.jsonl")
        for i in range(3):
            store.append_metrics(f"run-{i}", "all", {"total_findings": i * 10})
        trend = store.read_trend(n=3, scope="all")
        assert isinstance(trend, list)
        assert len(trend) == 3

    def test_read_trend_filters_by_scope(self, tmp_path, monkeypatch):
        monkeypatch.setattr(store, "METRICS_LEDGER",
                            tmp_path / "context-update-metrics.jsonl")
        store.append_metrics("r1", "all",     {"total_findings": 1})
        store.append_metrics("r2", "content", {"total_findings": 2})
        store.append_metrics("r3", "all",     {"total_findings": 3})
        trend = store.read_trend(n=5, scope="content")
        assert len(trend) == 1
        assert trend[0]["total_findings"] == 2
