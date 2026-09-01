"""
tests/scripts/test_governance_sync.py — pytest para SE-363 governance-sync.

Cubre: extracción de CRIT de CRITERIO.md, generación de criterios.jsonl,
idempotencia, drift-check, query.

Ref: SE-363 — registros-no-archivos (capa consultable sobre Markdown)
"""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "governance-sync.py"

SAMPLE_CRITERIO = """---
lang: es
---

# CRITERIO

## riesgo

CRIT-022 — Reversibilidad decide la velocidad
  dureza: preferencia | constitucion: T2
  principio: Decisiones reversibles se toman rapido.
  enforcement: solo-criterio
  provenance: INFERRED

CRIT-023 — Fail-closed ante ambiguedad
  dureza: linea_roja | constitucion: T3
  principio: Ante duda se falla cerrado.
  enforcement: guards
  provenance: INFERRED
"""


def _load():
    spec = importlib.util.spec_from_file_location("governance_sync", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def gs():
    return _load()


def test_extrae_crits(gs, tmp_path):
    p = tmp_path / "CRITERIO.md"
    p.write_text(SAMPLE_CRITERIO)
    crits = gs.extract_crits(p)
    assert len(crits) == 2
    assert crits[0]["id"] == "CRIT-022"
    assert crits[0]["dureza"] == "preferencia"
    assert crits[1]["id"] == "CRIT-023"


def test_genera_jsonl(gs, tmp_path):
    p = tmp_path / "CRITERIO.md"
    p.write_text(SAMPLE_CRITERIO)
    out = tmp_path / "criterios.jsonl"
    crits = gs.extract_crits(p)
    gs.write_jsonl(crits, out)
    lines = out.read_text().strip().split("\n")
    assert len(lines) == 2
    assert '"id": "CRIT-022"' in lines[0]


def test_idempotente(gs, tmp_path):
    p = tmp_path / "CRITERIO.md"
    p.write_text(SAMPLE_CRITERIO)
    out = tmp_path / "criterios.jsonl"
    crits = gs.extract_crits(p)
    gs.write_jsonl(crits, out)
    gs.write_jsonl(crits, out)  # re-ejecución
    lines = out.read_text().strip().split("\n")
    assert len(lines) == 2  # no duplica


def test_drift_check(gs, tmp_path):
    p = tmp_path / "CRITERIO.md"
    p.write_text(SAMPLE_CRITERIO)
    out = tmp_path / "criterios.jsonl"
    crits = gs.extract_crits(p)
    gs.write_jsonl(crits, out)
    # quito un crit del MD → drift
    p.write_text("# CRITERIO\n\n## riesgo\n\nCRIT-022 — X\n")
    crits2 = gs.extract_crits(p)
    drift = gs.check_drift(crits2, out)
    # CRIT-023 está en el registro pero ya no en el MD
    assert "CRIT-023" in drift["missing_in_md"]
    assert drift["total_registry"] == 2


def test_query_status(gs, tmp_path):
    p = tmp_path / "CRITERIO.md"
    p.write_text(SAMPLE_CRITERIO)
    out = tmp_path / "criterios.jsonl"
    crits = gs.extract_crits(p)
    # dar estado ACTIVE a todos
    for c in crits:
        c["status"] = "ACTIVE"
    gs.write_jsonl(crits, out)
    active = gs.query(out, status="ACTIVE")
    assert len(active) == 2
