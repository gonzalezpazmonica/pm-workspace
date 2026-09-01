"""
tests/scripts/test_ci_duration_agg.py — pytest para SE-361 ci-duration.

Cubre: duración por job, detección de job > presupuesto, p50/p95 sobre ventana,
reporte markdown.

Ref: SE-361 — presupuesto de tiempo de CI
"""
import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "ci-duration-agg.py"


def _load():
    spec = importlib.util.spec_from_file_location("ci_duration_agg", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def agg():
    return _load()


def _sample_jobs():
    return [
        {"name": "BATS", "duration_ms": 180000, "conclusion": "success"},   # 3 min
        {"name": "Lint", "duration_ms": 600000, "conclusion": "success"},   # 10 min > budget
        {"name": "Validate", "duration_ms": 120000, "conclusion": "success"},
        {"name": "BATS", "duration_ms": 190000, "conclusion": "success"},   # otro run
    ]


def test_duration_por_job(agg):
    res = agg.aggregate(_sample_jobs(), budget_min=5)
    assert "BATS" in res["jobs"]
    assert "Lint" in res["jobs"]


def test_detecta_job_sobre_presupuesto(agg):
    res = agg.aggregate(_sample_jobs(), budget_min=5)
    assert res["jobs"]["Lint"]["over_budget"] is True
    assert res["jobs"]["BATS"]["over_budget"] is False


def test_p50_p95_ventana(agg):
    res = agg.aggregate(_sample_jobs(), budget_min=5)
    assert res["jobs"]["BATS"]["p50_ms"] > 0
    assert res["jobs"]["BATS"]["p95_ms"] > 0


def test_budget_por_defecto_5min(agg):
    res = agg.aggregate(_sample_jobs(), budget_min=5)
    assert res["budget_min"] == 5


def test_jobs_vacios_no_falla(agg):
    res = agg.aggregate([], budget_min=5)
    assert res["jobs"] == {}
    assert res["over_budget_count"] == 0
