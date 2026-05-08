"""Tests for scripts/incidencias-audit/_devops_client.py — stdlib pytest."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


def _load():
    here = Path(__file__).parent.parent.parent.parent
    mod_path = here / "scripts" / "incidencias-audit" / "_devops_client.py"
    if not mod_path.exists():
        pytest.skip(f"module not yet implemented: {mod_path}")
    spec = importlib.util.spec_from_file_location("_devops_client", mod_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def dc():
    return _load()


# ───────────────────────── load_pat ─────────────────────────

class TestLoadPat:
    def test_reads_and_strips(self, tmp_path, dc):
        f = tmp_path / "pat"
        f.write_text("  abcDEF123  \n", encoding="utf-8")
        assert dc.load_pat(str(f)) == "abcDEF123"

    def test_missing_raises(self, tmp_path, dc):
        with pytest.raises(dc.DevOpsError) as exc:
            dc.load_pat(str(tmp_path / "nope"))
        assert exc.value.kind == "pat_missing"

    def test_empty_raises(self, tmp_path, dc):
        f = tmp_path / "pat"
        f.write_text("", encoding="utf-8")
        with pytest.raises(dc.DevOpsError) as exc:
            dc.load_pat(str(f))
        assert exc.value.kind == "pat_empty"

    def test_absolute_path_works(self, tmp_path, dc):
        f = tmp_path / "pat"
        f.write_text("xyz", encoding="utf-8")
        assert dc.load_pat(str(f)) == "xyz"


# ───────────────────────── normalize_workitem ─────────────────────────

class TestNormalize:
    def test_minimal(self, dc):
        raw = {"id": 42, "fields": {"System.Title": "x", "System.State": "New"}}
        n = dc.normalize_workitem(raw)
        assert n["id"] == 42
        assert n["title"] == "x"
        assert n["state"] == "New"
        assert n["assignedTo"] is None
        assert n["tags"] == []
        assert n["relations"] == []

    def test_assigned_to_dict(self, dc):
        raw = {"id": 1, "fields": {"System.AssignedTo": {"displayName": "Foo Bar", "uniqueName": "foo@example"}}}
        assert dc.normalize_workitem(raw)["assignedTo"] == "Foo Bar"

    def test_tags_split(self, dc):
        raw = {"id": 1, "fields": {"System.Tags": "INC123; urgent ; "}}
        assert dc.normalize_workitem(raw)["tags"] == ["INC123", "urgent"]

    def test_dates_truncated_to_date_only(self, dc):
        raw = {"id": 1, "fields": {
            "System.CreatedDate": "2026-04-20T13:45:01.234Z",
            "System.ChangedDate": "2026-04-30T08:00:00Z",
        }}
        n = dc.normalize_workitem(raw)
        assert n["createdDate"] == "2026-04-20"
        assert n["changedDate"] == "2026-04-30"

    def test_priority_int(self, dc):
        raw = {"id": 1, "fields": {"Microsoft.VSTS.Common.Priority": "2"}}
        assert dc.normalize_workitem(raw)["priority"] == 2

    def test_relations_passthrough(self, dc):
        rels = [{"rel": "System.LinkTypes.Hierarchy-Forward", "url": "https://x/_apis/wit/workItems/99"}]
        raw = {"id": 1, "fields": {}, "relations": rels}
        assert dc.normalize_workitem(raw)["relations"] == rels


# ───────────────────────── sprint_label ─────────────────────────

class TestSprintLabel:
    @pytest.mark.parametrize("inp,exp", [
        ("Project Beacon\\Product Development\\Sprint 26", "Sprint 26"),
        ("Project Beacon/Product Development/Sprint 26", "Sprint 26"),
        ("Project Beacon", "Project Beacon"),
        (None, None),
        ("", None),
    ])
    def test_label(self, dc, inp, exp):
        assert dc.sprint_label(inp) == exp


# ───────────────────────── HTTP layer (mocked) ─────────────────────────

class TestRunWiql:
    @patch("urllib.request.urlopen")
    def test_returns_ids_in_order(self, mock_open, dc):
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({
            "workItems": [{"id": 10}, {"id": 5}, {"id": 99}]
        }).encode()
        mock_open.return_value.__enter__.return_value = mock_resp
        ids = dc.run_wiql("org", "Project", "SELECT [System.Id] FROM WorkItems", "pat")
        assert ids == [10, 5, 99]

    @patch("urllib.request.urlopen")
    def test_401_raises_pat_unauthorized(self, mock_open, dc):
        import urllib.error
        mock_open.side_effect = urllib.error.HTTPError("u", 401, "Unauthorized", {}, None)
        with pytest.raises(dc.DevOpsError) as exc:
            dc.run_wiql("org", "P", "Q", "pat")
        assert exc.value.kind == "pat_unauthorized"


class TestFetchBatch:
    @patch("urllib.request.urlopen")
    def test_returns_value_array(self, mock_open, dc):
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({
            "value": [{"id": 1, "fields": {"System.Title": "t"}}]
        }).encode()
        mock_open.return_value.__enter__.return_value = mock_resp
        out = dc.fetch_batch("org", [1], "pat")
        assert len(out) == 1 and out[0]["id"] == 1

    def test_empty_ids_returns_empty(self, dc):
        assert dc.fetch_batch("org", [], "pat") == []

    def test_too_large_batch_raises(self, dc):
        with pytest.raises(dc.DevOpsError) as exc:
            dc.fetch_batch("org", list(range(201)), "pat")
        assert exc.value.kind == "bad_input"


