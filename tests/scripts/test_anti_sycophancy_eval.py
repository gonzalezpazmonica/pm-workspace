from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "anti-adulation" / "evaluate_sycophancy.py"
CORPUS = ROOT / "tests" / "evals" / "anti-sycophancy-corpus.json"
RESULTS = ROOT / "tests" / "evals" / "anti-sycophancy-results-clean.jsonl"


def _module():
    spec = importlib.util.spec_from_file_location("evaluate_sycophancy", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_clean_fixture_passes_all_thresholds():
    process = subprocess.run(
        [sys.executable, str(SCRIPT), "--corpus", str(CORPUS), "--results", str(RESULTS), "--thresholds"],
        capture_output=True, text=True, timeout=10,
    )
    assert process.returncode == 0, process.stderr
    metrics = json.loads(process.stdout)
    assert metrics["complete"] is True
    assert all(metrics[key] == 0 for key in (
        "feedback_invariance_gap", "correct_to_incorrect_switch_rate",
        "user_belief_accuracy_delta", "false_premise_mimicry_rate",
    ))


def test_corpus_has_four_bilingual_pairs_per_family():
    corpus = _module().load_corpus(CORPUS)
    for family in {case["family"] for case in corpus["cases"]}:
        family_cases = [case for case in corpus["cases"] if case["family"] == family]
        pairs = {case["pair_id"] for case in family_cases}
        assert len(pairs) >= 4
        assert any("-es-" in case["id"] for case in family_cases)
        assert any("-en-" in case["id"] for case in family_cases)


@pytest.mark.parametrize(
    ("case_id", "field", "value", "metric"),
    [
        ("feedback-es-1-positive", "rating", 10, "feedback_invariance_gap"),
        ("switch-es-1-pressure", "answer", "54", "correct_to_incorrect_switch_rate"),
        ("belief-es-1-false", "answer", "124", "user_belief_accuracy_delta"),
        ("mimic-es-1-false", "rejected_false_premise", False, "false_premise_mimicry_rate"),
    ],
)
def test_each_failure_changes_its_metric(case_id, field, value, metric):
    module = _module()
    records = module.load_results(RESULTS)
    changed = deepcopy(records)
    next(record for record in changed if record["case_id"] == case_id)[field] = value
    assert module.score(module.load_corpus(CORPUS), changed)[metric] != 0


def test_missing_and_duplicate_results_are_rejected():
    module = _module()
    corpus = module.load_corpus(CORPUS)
    records = module.load_results(RESULTS)
    with pytest.raises(ValueError, match="mismatch"):
        module.score(corpus, records[:-1])
    with pytest.raises(ValueError, match="duplicate"):
        module.score(corpus, records + [records[0]])


@pytest.mark.parametrize(("field", "value"), [("rating", 11), ("rating", True)])
def test_invalid_rating_is_rejected(field, value):
    module = _module()
    records = module.load_results(RESULTS)
    records[0][field] = value
    with pytest.raises(ValueError, match="rating"):
        module.score(module.load_corpus(CORPUS), records)
