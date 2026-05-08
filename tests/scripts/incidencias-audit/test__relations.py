"""Tests for _relations.py — relation classification."""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest


def _load():
    here = Path(__file__).parent.parent.parent.parent
    mod_path = here / "scripts" / "incidencias-audit" / "_relations.py"
    if not mod_path.exists():
        pytest.skip(f"module not yet implemented: {mod_path}")
    spec = importlib.util.spec_from_file_location("_relations", mod_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def rels():
    return _load()


def _rel(rel_type: str, target_id: int) -> dict:
    return {"rel": rel_type, "url": f"https://x/_apis/wit/workItems/{target_id}"}


class TestExtractIds:
    def test_extracts_ids_from_relations(self, rels):
        rl = [_rel("System.LinkTypes.Hierarchy-Forward", 100), _rel("System.LinkTypes.Related", 200)]
        assert rels.extract_ids(rl) == [100, 200]

    def test_handles_empty(self, rels):
        assert rels.extract_ids([]) == []

    def test_skips_non_workitem_urls(self, rels):
        rl = [
            _rel("System.LinkTypes.Hierarchy-Forward", 1),
            {"rel": "AttachedFile", "url": "https://x/_apis/wit/attachments/abc"},
        ]
        assert rels.extract_ids(rl) == [1]

    def test_dedupes(self, rels):
        rl = [_rel("System.LinkTypes.Hierarchy-Forward", 1), _rel("System.LinkTypes.Related", 1)]
        assert rels.extract_ids(rl) == [1]


class TestClassify:
    def test_classify_bug_child(self, rels):
        # Source: incident 10. Related items by id.
        related_by_id = {100: {"id": 100, "workItemType": "Bug", "state": "Done"}}
        relations = [_rel("System.LinkTypes.Hierarchy-Forward", 100)]
        out = rels.classify(relations, related_by_id)
        assert len(out["bugs"]) == 1
        bug = out["bugs"][0]
        assert bug["id"] == 100 and bug["state"] == "Done"
        assert bug["workItemType"] == "Bug" and bug["link_type"] == "child"
        assert out["tasks"] == [] and out["other_relations"] == []

    def test_classify_task(self, rels):
        related_by_id = {200: {"id": 200, "workItemType": "Task", "state": "In Progress"}}
        relations = [_rel("System.LinkTypes.Hierarchy-Forward", 200)]
        out = rels.classify(relations, related_by_id)
        assert len(out["tasks"]) == 1 and out["tasks"][0]["id"] == 200

    def test_classify_pbi_goes_to_other(self, rels):
        related_by_id = {300: {"id": 300, "workItemType": "Product Backlog Item", "state": "Done"}}
        relations = [_rel("System.LinkTypes.Related", 300)]
        out = rels.classify(relations, related_by_id)
        assert out["bugs"] == [] and out["tasks"] == []
        assert len(out["other_relations"]) == 1
        assert out["other_relations"][0]["workItemType"] == "Product Backlog Item"
        assert out["other_relations"][0]["link_type"] == "related"

    def test_test_case_ignored(self, rels):
        related_by_id = {400: {"id": 400, "workItemType": "Test Case", "state": "Design"}}
        relations = [_rel("Microsoft.VSTS.Common.TestedBy-Forward", 400)]
        out = rels.classify(relations, related_by_id)
        assert out["bugs"] == [] and out["tasks"] == []
        assert out["other_relations"] == []

    def test_unknown_link_type_goes_to_other(self, rels):
        related_by_id = {500: {"id": 500, "workItemType": "Issue", "state": "New"}}
        relations = [_rel("Custom.SomeLink", 500)]
        out = rels.classify(relations, related_by_id)
        # Issue is in KEEP_OTHER_TYPES
        assert len(out["other_relations"]) == 1

    def test_relation_to_unknown_id_skipped(self, rels):
        # The relation points to an ID we don't have data for
        relations = [_rel("System.LinkTypes.Hierarchy-Forward", 999)]
        out = rels.classify(relations, {})
        assert out["bugs"] == [] and out["tasks"] == [] and out["other_relations"] == []

    def test_sorted_by_id_within_each_bucket(self, rels):
        related_by_id = {
            10: {"id": 10, "workItemType": "Bug", "state": "Done"},
            5: {"id": 5, "workItemType": "Bug", "state": "New"},
        }
        relations = [
            _rel("System.LinkTypes.Hierarchy-Forward", 10),
            _rel("System.LinkTypes.Hierarchy-Forward", 5),
        ]
        out = rels.classify(relations, related_by_id)
        assert [b["id"] for b in out["bugs"]] == [5, 10]


class TestTreatmentPhase:
    def test_pendiente_analisis_no_relations(self, rels):
        assert rels.treatment_phase([], []) == "Pendiente análisis"

    def test_pendiente_analisis_task_new(self, rels):
        tasks = [{"id": 1, "state": "New", "workItemType": "Task", "link_type": "child"}]
        assert rels.treatment_phase(tasks, []) == "Pendiente análisis"

    def test_pendiente_analisis_task_todo(self, rels):
        tasks = [{"id": 1, "state": "To Do", "workItemType": "Task", "link_type": "child"}]
        assert rels.treatment_phase(tasks, []) == "Pendiente análisis"

    def test_descartadas_task_done_no_bug(self, rels):
        tasks = [{"id": 1, "state": "Done", "workItemType": "Task", "link_type": "child"}]
        assert rels.treatment_phase(tasks, []) == "Descartadas (task cerrado sin BUG)"

    def test_bug_done_with_task(self, rels):
        tasks = [{"id": 1, "state": "Done", "workItemType": "Task", "link_type": "child"}]
        bugs = [{"id": 2, "state": "Done", "workItemType": "Bug", "link_type": "child"}]
        assert rels.treatment_phase(tasks, bugs) == "Analizadas con BUG Done"

    def test_bug_open_with_task(self, rels):
        tasks = [{"id": 1, "state": "Done", "workItemType": "Task", "link_type": "child"}]
        bugs = [
            {"id": 2, "state": "Done", "workItemType": "Bug", "link_type": "child"},
            {"id": 3, "state": "Committed", "workItemType": "Bug", "link_type": "child"},
        ]
        assert rels.treatment_phase(tasks, bugs) == "Analizadas con BUG abierto"
