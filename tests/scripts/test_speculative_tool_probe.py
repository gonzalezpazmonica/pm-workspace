"""Tests for scripts/speculative-tool-predictor.py and speculative-tool-probe.py -- SE-220 S0."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PREDICTOR_SCRIPT = ROOT / "scripts" / "speculative-tool-predictor.py"
PROBE_SCRIPT = ROOT / "scripts" / "speculative-tool-probe.py"

AVAILABLE_TOOLS = ["Bash", "Read", "Grep", "Edit", "Write"]


# ---------------------------------------------------------------------------
# Loader helpers
# ---------------------------------------------------------------------------

def _load_predictor():
    spec = importlib.util.spec_from_file_location("speculative_tool_predictor", PREDICTOR_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_probe():
    spec = importlib.util.spec_from_file_location("speculative_tool_probe", PROBE_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def predictor():
    return _load_predictor()


@pytest.fixture(scope="module")
def probe():
    return _load_probe()


# ---------------------------------------------------------------------------
# Predictor unit tests
# ---------------------------------------------------------------------------

def test_predictor_read_intent(predictor):
    """Intent with 'lee el fichero' must predict Read."""
    result = predictor.predict("lee el fichero docs/propuestas/SE-220.md", AVAILABLE_TOOLS)
    assert "Read" in result["predicted_tools"], (
        f"Expected Read in predicted_tools, got {result['predicted_tools']}"
    )


def test_predictor_grep_intent(predictor):
    """Intent with 'busca la funcion' must predict Grep."""
    result = predictor.predict("busca la funcion calculate_velocity en el codigo", AVAILABLE_TOOLS)
    assert "Grep" in result["predicted_tools"], (
        f"Expected Grep in predicted_tools, got {result['predicted_tools']}"
    )


def test_predictor_edit_intent(predictor):
    """Intent with 'modifica el metodo' must predict Edit."""
    result = predictor.predict("modifica el metodo parse_wiql para soportar multiples proyectos", AVAILABLE_TOOLS)
    assert "Edit" in result["predicted_tools"], (
        f"Expected Edit in predicted_tools, got {result['predicted_tools']}"
    )


def test_predictor_write_intent(predictor):
    """Intent with 'crea el fichero' must predict Write."""
    result = predictor.predict("crea el fichero scripts/new-tool.py con el esqueleto", AVAILABLE_TOOLS)
    assert "Write" in result["predicted_tools"], (
        f"Expected Write in predicted_tools, got {result['predicted_tools']}"
    )


def test_predictor_bash_intent(predictor):
    """Intent with 'ejecuta' must predict Bash."""
    result = predictor.predict("ejecuta los tests de pytest en tests/scripts/", AVAILABLE_TOOLS)
    assert "Bash" in result["predicted_tools"], (
        f"Expected Bash in predicted_tools, got {result['predicted_tools']}"
    )


def test_predictor_confidence_range(predictor):
    """Confidence must always be between 0.0 and 1.0 inclusive."""
    test_intents = [
        "lee el fichero",
        "busca la funcion",
        "modifica el metodo",
        "ejecuta el script",
        "crea el fichero",
        "algo que no tiene patron reconocible xyzzyx",
    ]
    for intent in test_intents:
        result = predictor.predict(intent, AVAILABLE_TOOLS)
        conf = result["confidence"]
        assert 0.0 <= conf <= 1.0, (
            f"Confidence {conf} out of range [0,1] for intent '{intent}'"
        )


def test_predictor_output_schema(predictor):
    """Output must contain predicted_tools (list), confidence (float), rationale (str)."""
    result = predictor.predict("lee el fichero docs/architecture.md", AVAILABLE_TOOLS)
    assert isinstance(result["predicted_tools"], list), "predicted_tools must be a list"
    assert isinstance(result["confidence"], float), "confidence must be a float"
    assert isinstance(result["rationale"], str), "rationale must be a str"
    assert len(result["predicted_tools"]) >= 1, "predicted_tools must have at least one entry"


def test_predictor_tools_constrained_to_available(predictor):
    """Predicted tools must be a subset of available_tools."""
    limited = ["Read", "Grep"]
    result = predictor.predict("busca la funcion y muestra el fichero", limited)
    for tool in result["predicted_tools"]:
        assert tool in limited, f"Predicted tool '{tool}' not in available set {limited}"


def test_predictor_unknown_intent_returns_default(predictor):
    """An intent with no pattern match must still return a valid response."""
    result = predictor.predict("xyzzy abcde nonce string 0x12345", AVAILABLE_TOOLS)
    assert len(result["predicted_tools"]) >= 1
    assert 0.0 <= result["confidence"] <= 1.0


# ---------------------------------------------------------------------------
# Probe unit tests
# ---------------------------------------------------------------------------

def test_probe_dataset_size(probe):
    """Probe dataset must have >= 15 cases."""
    assert len(probe.DATASET) >= 15, (
        f"Dataset has only {len(probe.DATASET)} cases, need >= 15"
    )


def test_probe_acceptance_rate_calculated(probe):
    """run_probe() must return acceptance_rate in [0, 1]."""
    results = probe.run_probe()
    rate = results["acceptance_rate"]
    assert 0.0 <= rate <= 1.0, f"acceptance_rate {rate} out of range [0,1]"


def test_probe_verdict_proceed(probe):
    """A dataset where all cases match must produce verdict PROCEED."""
    all_correct = [
        {"id": str(i), "intent": "lee el fichero docs/test.md", "expected": "Read"}
        for i in range(10)
    ]
    results = probe.run_probe(dataset=all_correct)
    assert results["verdict"] == "PROCEED", (
        f"Expected PROCEED, got {results['verdict']} (rate={results['acceptance_rate']})"
    )


def test_probe_verdict_abort(probe):
    """A dataset where no cases match must produce verdict ABORT."""
    # Use an intent that predicts Bash but we label expected as Write
    no_match = [
        {"id": str(i), "intent": "ejecuta el build", "expected": "Write"}
        for i in range(10)
    ]
    results = probe.run_probe(dataset=no_match)
    assert results["verdict"] == "ABORT", (
        f"Expected ABORT, got {results['verdict']} (rate={results['acceptance_rate']})"
    )


def test_probe_output_has_cases_list(probe):
    """run_probe() output must include a cases list with per-case details."""
    results = probe.run_probe()
    assert "cases" in results
    assert isinstance(results["cases"], list)
    assert len(results["cases"]) == results["total_cases"]
    required = {"id", "intent", "expected", "predicted", "hit", "confidence"}
    for case in results["cases"]:
        missing = required - set(case.keys())
        assert not missing, f"Case {case.get('id')} missing fields: {missing}"


def test_probe_correct_plus_incorrect_equals_total(probe):
    """correct + incorrect must equal total_cases."""
    results = probe.run_probe()
    assert results["correct"] + results["incorrect"] == results["total_cases"]


def test_probe_full_dataset_achieves_threshold(probe):
    """Full 20-case dataset must achieve acceptance_rate >= 0.60."""
    results = probe.run_probe()
    assert results["acceptance_rate"] >= 0.60, (
        f"acceptance_rate {results['acceptance_rate']:.2%} < 60% threshold -- SE-220 would be INFEASIBLE"
    )
    assert results["verdict"] == "PROCEED"
