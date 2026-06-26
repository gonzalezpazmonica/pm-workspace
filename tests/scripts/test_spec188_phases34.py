"""Tests for SPEC-188 Phases 3+4 MVP

Covers:
- causal-confidence-scorer: 0 evidence -> insufficient
- causal-confidence-scorer: 3+ evidence -> high confidence
- causal-confidence-scorer: output JSON has all required fields
- causal-confidence-scorer: confidence_score in [0, 1]
- causal-confidence-scorer: alternatives reduce confidence
- diagnostic-metrics: --record appends entry to JSONL
- diagnostic-metrics: --report calculates accuracy_rate correctly
- diagnostic-metrics: JSONL append-only (2 records -> 2 lines)
- diagnostic-metrics: --list returns N entries
- diagnostic-metrics: required fields present in entry
"""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CAUSAL_SCORER = ROOT / "scripts" / "causal-confidence-scorer.py"
DIAG_TRACKER = ROOT / "scripts" / "diagnostic-metrics-tracker.py"

REQUIRED_CAUSAL_FIELDS = {
    "cause",
    "confidence_score",
    "supporting_evidence",
    "contradicting_evidence",
    "alternative_causes",
    "verdict",
}

REQUIRED_ENTRY_FIELDS = {
    "ts",
    "investigation_id",
    "time_to_identify_min",
    "confidence_score",
    "was_correct",
    "rework_needed",
}


def _run_causal(cause: str, evidence: list, alternatives: list) -> dict:
    result = subprocess.run(
        [
            sys.executable,
            str(CAUSAL_SCORER),
            "--cause", cause,
            "--evidence", json.dumps(evidence),
            "--alternatives", json.dumps(alternatives),
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, f"scorer failed: {result.stderr}"
    return json.loads(result.stdout)


def _run_tracker(args: list, log_path: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(DIAG_TRACKER), "--log", str(log_path)] + args,
        capture_output=True,
        text=True,
        timeout=30,
    )


# ── causal-confidence-scorer tests ────────────────────────────────────────────

class TestCausalConfidenceScorer:
    def test_zero_evidence_returns_insufficient(self):
        """AC: 0 evidence -> verdict='insufficient', confidence_score=0.0"""
        result = _run_causal("Some cause", [], [])
        assert result["verdict"] == "insufficient"
        assert result["confidence_score"] == 0.0

    def test_three_plus_evidence_returns_high_confidence(self):
        """AC: 3+ coherent evidence -> verdict='high', confidence_score >= 0.7"""
        evidence = [
            "Metrics show pool at maximum capacity",
            "Logs confirm timeout errors started after pool exhaustion",
            "Reproduced in staging under load test",
        ]
        result = _run_causal("Connection pool exhausted", evidence, [])
        assert result["verdict"] == "high", (
            f"Expected high, got {result['verdict']} with score={result['confidence_score']}"
        )
        assert result["confidence_score"] >= 0.70

    def test_output_json_has_all_required_fields(self):
        """AC: output JSON contains all required fields"""
        result = _run_causal("Some cause", ["Evidence A", "Evidence B"], [])
        missing = REQUIRED_CAUSAL_FIELDS - set(result.keys())
        assert not missing, f"Missing fields: {missing}"

    def test_confidence_score_in_unit_interval(self):
        """AC: confidence_score is in [0.0, 1.0]"""
        for evidence, alternatives in [
            ([], []),
            (["E1"], ["A1"]),
            (["E1", "E2", "E3", "E4", "E5"], []),
            (["E1", "E2"], ["A1", "A2", "A3"]),
        ]:
            result = _run_causal("Test cause", evidence, alternatives)
            score = result["confidence_score"]
            assert 0.0 <= score <= 1.0, (
                f"confidence_score={score} out of [0,1] for ev={evidence}, alts={alternatives}"
            )

    def test_alternatives_reduce_confidence(self):
        """AC: plausible alternatives reduce confidence vs no alternatives"""
        evidence = ["Evidence A", "Evidence B", "Evidence C"]
        result_no_alts = _run_causal("Cause X", evidence, [])
        result_with_alts = _run_causal("Cause X", evidence, ["Alt 1", "Alt 2"])
        assert result_with_alts["confidence_score"] < result_no_alts["confidence_score"], (
            f"Expected alternatives to reduce confidence: "
            f"no_alts={result_no_alts['confidence_score']}, "
            f"with_alts={result_with_alts['confidence_score']}"
        )

    def test_insufficient_verdict_fields(self):
        """AC: insufficient verdict returns correct supporting/contradicting lists"""
        result = _run_causal("No evidence cause", [], [])
        assert result["supporting_evidence"] == []
        assert result["contradicting_evidence"] == []

    def test_verdict_values_are_valid(self):
        """AC: verdict is one of high | medium | low | insufficient"""
        valid_verdicts = {"high", "medium", "low", "insufficient"}
        for evidence in [[], ["E1"], ["E1", "E2"], ["E1", "E2", "E3"]]:
            result = _run_causal("Cause", evidence, [])
            assert result["verdict"] in valid_verdicts, (
                f"Invalid verdict: {result['verdict']}"
            )


# ── diagnostic-metrics-tracker tests ─────────────────────────────────────────

class TestDiagnosticMetricsTracker:
    def test_record_appends_entry_to_jsonl(self, tmp_path):
        """AC: --record appends one line to JSONL"""
        log = tmp_path / "metrics.jsonl"
        result = _run_tracker([
            "--record",
            "--investigation-id", "INV-001",
            "--time-to-identify", "30",
            "--confidence", "0.80",
            "--correct", "true",
        ], log)
        assert result.returncode == 0, result.stderr
        assert log.exists()
        lines = [l for l in log.read_text().splitlines() if l.strip()]
        assert len(lines) == 1

    def test_report_calculates_accuracy_rate_correctly(self, tmp_path):
        """AC: --report accuracy_rate = correct_count / total"""
        log = tmp_path / "metrics.jsonl"
        # 2 correct, 1 incorrect -> accuracy = 0.6667
        for inv_id, correct in [("I1", "true"), ("I2", "true"), ("I3", "false")]:
            _run_tracker([
                "--record",
                "--investigation-id", inv_id,
                "--time-to-identify", "20",
                "--confidence", "0.70",
                "--correct", correct,
            ], log)
        result = _run_tracker(["--report"], log)
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert "accuracy_rate" in report
        assert abs(report["accuracy_rate"] - (2/3)) < 0.01, (
            f"Expected accuracy ~0.667, got {report['accuracy_rate']}"
        )

    def test_jsonl_append_only_two_records_two_lines(self, tmp_path):
        """AC: two --record calls produce exactly 2 JSONL lines"""
        log = tmp_path / "metrics.jsonl"
        _run_tracker([
            "--record", "--investigation-id", "A", "--time-to-identify", "10",
            "--confidence", "0.5", "--correct", "true",
        ], log)
        _run_tracker([
            "--record", "--investigation-id", "B", "--time-to-identify", "20",
            "--confidence", "0.6", "--correct", "false",
        ], log)
        lines = [l for l in log.read_text().splitlines() if l.strip()]
        assert len(lines) == 2

    def test_list_returns_n_entries(self, tmp_path):
        """AC: --list --n N returns at most N entries"""
        log = tmp_path / "metrics.jsonl"
        for i in range(5):
            _run_tracker([
                "--record", "--investigation-id", f"INV-{i:03d}",
                "--time-to-identify", "15",
                "--confidence", "0.7",
                "--correct", "true",
            ], log)
        result = _run_tracker(["--list", "--n", "3"], log)
        assert result.returncode == 0
        entries = json.loads(result.stdout)
        assert len(entries) == 3

    def test_entry_has_required_fields(self, tmp_path):
        """AC: recorded entry contains all required fields"""
        log = tmp_path / "metrics.jsonl"
        _run_tracker([
            "--record", "--investigation-id", "INV-CHECK",
            "--time-to-identify", "25", "--confidence", "0.85", "--correct", "true",
        ], log)
        line = [l for l in log.read_text().splitlines() if l.strip()][0]
        entry = json.loads(line)
        missing = REQUIRED_ENTRY_FIELDS - set(entry.keys())
        assert not missing, f"Entry missing fields: {missing}"

    def test_jsonl_created_if_not_exists(self, tmp_path):
        """AC: JSONL file is created on first --record even if it did not exist"""
        log = tmp_path / "new_subdir" / "metrics.jsonl"
        assert not log.exists()
        _run_tracker([
            "--record", "--investigation-id", "NEW",
            "--time-to-identify", "10", "--confidence", "0.5", "--correct", "false",
        ], log)
        assert log.exists()

    def test_report_on_empty_log_returns_zero_stats(self, tmp_path):
        """AC: --report on empty/missing log returns all-zero stats"""
        log = tmp_path / "empty.jsonl"
        result = _run_tracker(["--report"], log)
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert report["total_investigations"] == 0
        assert report["accuracy_rate"] == 0.0

    def test_was_correct_field_is_boolean(self, tmp_path):
        """AC: was_correct stored as boolean in JSONL"""
        log = tmp_path / "booltest.jsonl"
        _run_tracker([
            "--record", "--investigation-id", "BOOL",
            "--time-to-identify", "10", "--confidence", "0.9", "--correct", "true",
        ], log)
        line = [l for l in log.read_text().splitlines() if l.strip()][0]
        entry = json.loads(line)
        assert entry["was_correct"] is True

    def test_confidence_score_stored_correctly(self, tmp_path):
        """AC: confidence_score stored as float in JSONL"""
        log = tmp_path / "floattest.jsonl"
        _run_tracker([
            "--record", "--investigation-id", "FLOAT",
            "--time-to-identify", "10", "--confidence", "0.73", "--correct", "true",
        ], log)
        line = [l for l in log.read_text().splitlines() if l.strip()][0]
        entry = json.loads(line)
        assert abs(entry["confidence_score"] - 0.73) < 0.001

    def test_mean_confidence_in_report(self, tmp_path):
        """AC: --report mean_confidence is correct average"""
        log = tmp_path / "mean.jsonl"
        for conf in ["0.60", "0.80"]:
            _run_tracker([
                "--record", "--investigation-id", f"M{conf}",
                "--time-to-identify", "20", "--confidence", conf, "--correct", "true",
            ], log)
        result = _run_tracker(["--report"], log)
        report = json.loads(result.stdout)
        assert abs(report["mean_confidence"] - 0.70) < 0.01
