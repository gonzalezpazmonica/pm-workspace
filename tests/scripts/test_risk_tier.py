"""
tests/scripts/test_risk_tier.py — pytest para SE-362 risk-tier.

Cubre: clasificación por tier, paths de secrets/infra → tier alto, docs-only → tier 1,
fail-closed con path desconocido, rationale presente.

Ref: SE-362 — gradación de riesgo para auto-merge
"""
import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "risk-tier.py"


def _load():
    spec = importlib.util.spec_from_file_location("risk_tier", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def rt():
    return _load()


def test_docs_only_tier_1(rt):
    res = rt.classify(["README.md", "docs/guide.md"])
    assert res["tier"] == 1
    assert res["requires_human"] is False


def test_secrets_tier_3(rt):
    res = rt.classify(["scripts/push-pr.sh"])
    assert res["tier"] >= 3
    assert res["requires_human"] is True


def test_infra_tier_4(rt):
    res = rt.classify(["infra/main.tf", ".github/workflows/prod.yml"])
    assert res["tier"] == 4
    assert res["requires_human"] is True


def test_migration_tier_3(rt):
    res = rt.classify(["db/migrations/001_add_users.py"])
    assert res["tier"] >= 3


def test_code_normal_tier_2(rt):
    res = rt.classify(["src/service.py", "tests/test_service.py"])
    assert res["tier"] == 2


def test_fail_closed_unknown(rt):
    res = rt.classify(["weird/path/file.bin"])
    assert res["tier"] == 3  # fail-closed: no asume bajo riesgo


def test_rationale_presente(rt):
    res = rt.classify(["src/x.py"])
    assert "rationale" in res and res["rationale"]
