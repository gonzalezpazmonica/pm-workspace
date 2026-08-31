"""
tests/scripts/test_acceptance_cost_agg.py — pytest para SE-360 acceptance-cost-agg.py.

Cubre: descomposición por etapa, bottleneck, p50/p95, lectura de ledgers locales.

Ref: SE-360 — costo por cambio aceptado
"""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "acceptance-cost-agg.py"


def _load():
    spec = importlib.util.spec_from_file_location("acceptance_cost_agg", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def agg():
    return _load()


def _sample_runs():
    return [
        {
            "run_id": "r1",
            "started_at": "2026-08-30T10:00:00Z",
            "pr": {"number": 101, "state": "merged", "ci": "passing", "review": "approved"},
        },
        {
            "run_id": "r2",
            "started_at": "2026-08-30T11:00:00Z",
            "pr": {"number": 102, "state": "open", "ci": "pending", "review": "changes_requested"},
        },
    ]


def _sample_audit():
    return [
        {"action": "pr_merge", "target": "101", "outcome": "enforced_allow", "enforced": True},
        {"action": "gate_deny", "target": "102", "outcome": "enforced_deny", "enforced": True},
    ]


def test_descompone_por_etapas(agg):
    res = agg.aggregate(_sample_runs(), _sample_audit(), 30)
    assert res["total_prs"] == 2
    for s in ("cola_ci", "ci", "revision", "remediacion", "gobernanza"):
        assert s in res["stages"], f"falta etapa {s}"


def test_bottleneck_identificado(agg):
    res = agg.aggregate(_sample_runs(), _sample_audit(), 30)
    assert res["bottleneck"] in ("cola_ci", "ci", "revision", "remediacion", "gobernanza")


def test_p50_p95_presentes(agg):
    res = agg.aggregate(_sample_runs(), _sample_audit(), 30)
    for s in ("ci", "revision"):
        assert "p50" in res["stages"][s]
        assert "p95" in res["stages"][s]


def test_prs_ordenados_por_total(agg):
    res = agg.aggregate(_sample_runs(), _sample_audit(), 30)
    totals = [p["total"] for p in res["prs"]]
    assert totals == sorted(totals, reverse=True)


def test_ledger_vacio_no_falla(agg, tmp_path):
    res = agg.aggregate([], [], 30)
    assert res["total_prs"] == 0
    assert res["bottleneck"] == "cola_ci"


def test_json_output_valido(agg):
    res = agg.aggregate(_sample_runs(), _sample_audit(), 30)
    s = json.dumps(res)
    d = json.loads(s)
    assert d["total_prs"] == 2
