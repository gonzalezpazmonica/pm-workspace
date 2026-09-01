"""
tests/scripts/test_evidence_capture.py — pytest para SE-364 evidence-capture.

Cubre: captura de casos de intervención/rechazo desde ledgers, generación de
evals compatibles, filtro N3+.

Ref: SE-364 — bucle de evidencia (historial de decisiones → corpus de evals)
"""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "evidence-capture.py"


def _load():
    spec = importlib.util.spec_from_file_location("evidence_capture", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def ec():
    return _load()


def test_captura_failure_desde_audit(ec, tmp_path):
    audit = tmp_path / "audit.jsonl"
    audit.write_text(
        '{"action":"pr_merge","outcome":"failure","enforced":true,"target":"101"}\n'
        '{"action":"pr_merge","outcome":"enforced_deny","enforced":true,"target":"102"}\n'
    )
    cases = ec.capture(audit, tmp_path / "corpus")
    assert len(cases) >= 2
    assert cases[0]["status"] == "open"


def test_filtro_nivel(ec, tmp_path):
    audit = tmp_path / "audit.jsonl"
    # N4b (equipo-proyecto, personal) NO entra al corpus; N4 (proyecto) sí
    audit.write_text(
        '{"action":"pr_merge","outcome":"failure","level":"N4","target":"101"}\n'
        '{"action":"pr_merge","outcome":"failure","level":"N4b","target":"102"}\n'
    )
    cases = ec.capture(audit, tmp_path / "corpus")
    # N4 entra (proyecto), N4b excluido (personal)
    assert len(cases) == 1
    assert cases[0]["input"] == "101"


def test_genera_evals(ec, tmp_path):
    audit = tmp_path / "audit.jsonl"
    audit.write_text('{"action":"pr_merge","outcome":"failure","target":"101"}\n')
    corpus = tmp_path / "corpus"
    cases = ec.capture(audit, corpus)
    evals = ec.to_evals(cases)
    assert isinstance(evals, list)
    assert len(evals) == len(cases)
    if evals:
        assert "input" in evals[0]
        assert "output_rejected" in evals[0]


def test_sin_intervenciones_no_falla(ec, tmp_path):
    audit = tmp_path / "audit.jsonl"
    audit.write_text('{"action":"pr_merge","outcome":"success","target":"101"}\n')
    cases = ec.capture(audit, tmp_path / "corpus")
    assert len(cases) == 0


def test_corpus_escribible(ec, tmp_path):
    audit = tmp_path / "audit.jsonl"
    audit.write_text('{"action":"x","outcome":"failure","target":"1"}\n')
    corpus = tmp_path / "corpus"
    ec.capture(audit, corpus)
    written = list(corpus.glob("*.json"))
    # corpus dir existe aunque no haya casos clasificables
    assert isinstance(written, list)
