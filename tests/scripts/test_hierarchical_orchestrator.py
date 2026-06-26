"""tests/scripts/test_hierarchical_orchestrator.py — SPEC-152

Tests for scripts/hierarchical-orchestrator.py: feature-lead delegation.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "hierarchical-orchestrator.py"


def _load():
    spec = importlib.util.spec_from_file_location("hierarchical_orchestrator", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["hierarchical_orchestrator"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
assign_leads = mod.assign_leads
main = mod.main


def _make_plan(groups):
    return {"title": "Sprint-X", "tasks": groups}


def _group(title, n_children, domain_hint=""):
    base = {"title": title + (" " + domain_hint if domain_hint else "")}
    base["children"] = [{"title": f"task-{i}"} for i in range(n_children)]
    return base


def test_group_with_four_children_gets_lead():
    plan = _make_plan([_group("Backend API", 4, "dotnet api service")])
    report = assign_leads(plan, min_children=3)
    assert len(report["assignments"]) == 1
    assert "feature_lead" in report["assignments"][0]


def test_group_with_two_children_not_delegated():
    plan = _make_plan([_group("Small task", 2)])
    report = assign_leads(plan, min_children=3)
    assert report["assignments"] == []
    assert len(report["unassigned"]) >= 1


def test_domain_detection_frontend():
    plan = _make_plan([_group("UI", 5, "angular component view form page css")])
    report = assign_leads(plan, min_children=3)
    assert len(report["assignments"]) == 1
    assert report["assignments"][0]["feature_lead"] == "frontend-feature-lead"


def test_domain_detection_infra():
    plan = _make_plan([_group("Deploy", 4, "terraform docker kubernetes azure")])
    report = assign_leads(plan, min_children=3)
    assert report["assignments"][0]["feature_lead"] == "infra-feature-lead"


def test_domain_detection_qa():
    plan = _make_plan([_group("Test suite", 5, "pytest test coverage unit integration")])
    report = assign_leads(plan, min_children=3)
    assert report["assignments"][0]["feature_lead"] == "qa-feature-lead"


def test_rationale_present():
    plan = _make_plan([_group("API", 4, "backend service")])
    report = assign_leads(plan, min_children=3)
    assert "rationale" in report["assignments"][0]
    assert len(report["assignments"][0]["rationale"]) > 10


def test_summary_counts():
    plan = _make_plan([
        _group("Big backend", 5, "dotnet"),
        _group("Small task", 2),
        _group("Big frontend", 4, "angular"),
    ])
    report = assign_leads(plan, min_children=3)
    s = report["summary"]
    assert s["total_groups_delegated"] == len(report["assignments"])
    assert s["total_groups_direct"] == len(report["unassigned"])


def test_custom_min_children():
    plan = _make_plan([_group("Tiny", 2)])
    report = assign_leads(plan, min_children=1)
    assert len(report["assignments"]) == 1


def test_cli_reads_plan_and_outputs_json(tmp_path):
    plan = _make_plan([_group("API group", 5, "python fastapi")])
    plan_file = tmp_path / "plan.json"
    plan_file.write_text(json.dumps(plan), encoding="utf-8")
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(["--plan", str(plan_file), "--quiet"])
    assert rc == 0
    parsed = json.loads(buf.getvalue())
    assert "assignments" in parsed
    assert "summary" in parsed


def test_cli_missing_plan(tmp_path):
    rc = main(["--plan", str(tmp_path / "nonexistent.json"), "--quiet"])
    assert rc == 1
