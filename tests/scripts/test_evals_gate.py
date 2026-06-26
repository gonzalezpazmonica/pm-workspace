"""tests/scripts/test_evals_gate.py — SPEC-151 pytest suite.

Tests for scripts/evals-paired-delta.py and evals-runner.sh.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent
DELTA_SCRIPT = REPO_ROOT / "scripts" / "evals-paired-delta.py"
RUNNER_SCRIPT = REPO_ROOT / "scripts" / "evals-runner.sh"
DATASETS_DIR = REPO_ROOT / "tests" / "evals" / "datasets"
BASELINES_DIR = REPO_ROOT / "tests" / "evals" / "baselines"

# ── helpers ────────────────────────────────────────────────────────────────────

def _write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data))


def _run_delta(baseline_data, current_data, threshold=None, extra_env=None):
    """Run evals-paired-delta.py with given data, return (returncode, parsed_output)."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as bf:
        json.dump(baseline_data, bf)
        baseline_path = bf.name
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as cf:
        json.dump(current_data, cf)
        current_path = cf.name
    try:
        cmd = [sys.executable, str(DELTA_SCRIPT), "--baseline", baseline_path, "--current", current_path]
        if threshold is not None:
            cmd += ["--threshold", str(threshold)]
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)
        proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
        return proc.returncode, json.loads(proc.stdout)
    finally:
        Path(baseline_path).unlink(missing_ok=True)
        Path(current_path).unlink(missing_ok=True)


# ── paired-delta tests ─────────────────────────────────────────────────────────

class TestPairedDelta:

    def test_no_degradation_threshold_pass_true(self):
        """Same scores → mean_delta=0 → threshold_pass=True."""
        scores = [{"id": f"t-{i}", "score": 0.80} for i in range(5)]
        rc, result = _run_delta(scores, scores)
        assert result["threshold_pass"] is True
        assert result["mean_delta"] == pytest.approx(0.0, abs=1e-5)

    def test_degradation_above_5pct_threshold_pass_false(self):
        """6% degradation → threshold_pass=False."""
        baseline = [{"id": f"t-{i}", "score": 0.90} for i in range(5)]
        current  = [{"id": f"t-{i}", "score": 0.84} for i in range(5)]  # delta=-0.06
        rc, result = _run_delta(baseline, current)
        assert result["threshold_pass"] is False
        assert result["mean_delta"] < -0.05

    def test_improvement_always_passes(self):
        """Current better than baseline → always pass."""
        baseline = [{"id": f"t-{i}", "score": 0.70} for i in range(5)]
        current  = [{"id": f"t-{i}", "score": 0.85} for i in range(5)]
        rc, result = _run_delta(baseline, current)
        assert result["threshold_pass"] is True
        assert result["improvement_count"] == 5

    def test_delta_calculates_mean_correctly(self):
        """Verify arithmetic: mean_delta = mean(current) - mean(baseline)."""
        baseline = [{"id": "a", "score": 0.80}, {"id": "b", "score": 0.60}]
        current  = [{"id": "a", "score": 0.90}, {"id": "b", "score": 0.70}]
        # deltas: [+0.10, +0.10] → mean = +0.10
        _, result = _run_delta(baseline, current)
        assert result["mean_delta"] == pytest.approx(0.10, abs=1e-4)

    def test_negative_mean_delta_is_degradation(self):
        baseline = [{"id": f"t-{i}", "score": 0.85} for i in range(4)]
        current  = [{"id": f"t-{i}", "score": 0.79} for i in range(4)]  # delta = -0.06
        _, result = _run_delta(baseline, current)
        assert result["mean_delta"] < 0
        assert result["degradation_count"] >= 1

    def test_threshold_configurable_via_env(self):
        """SAVIA_EVAL_DELTA_THRESHOLD=0.10 should pass 6% degradation."""
        baseline = [{"id": f"t-{i}", "score": 0.90} for i in range(5)]
        current  = [{"id": f"t-{i}", "score": 0.84} for i in range(5)]  # -0.06
        _, result = _run_delta(baseline, current, extra_env={"SAVIA_EVAL_DELTA_THRESHOLD": "0.10"})
        # mean_delta=-0.06 >= -0.10 → pass
        assert result["threshold_pass"] is True

    def test_threshold_configurable_via_cli_flag(self):
        """--threshold 0.10 should pass 6% degradation."""
        baseline = [{"id": f"t-{i}", "score": 0.90} for i in range(5)]
        current  = [{"id": f"t-{i}", "score": 0.84} for i in range(5)]
        _, result = _run_delta(baseline, current, threshold=0.10)
        assert result["threshold_pass"] is True

    def test_output_has_all_required_fields(self):
        """Output JSON must contain all required fields."""
        scores = [{"id": f"t-{i}", "score": 0.80} for i in range(3)]
        _, result = _run_delta(scores, scores)
        required = {"mean_delta", "std_delta", "degradation_count", "improvement_count",
                    "threshold_pass", "threshold_used", "pairs_evaluated"}
        assert required.issubset(result.keys())

    def test_improvement_count_non_zero_on_improvement(self):
        baseline = [{"id": f"t-{i}", "score": 0.70} for i in range(4)]
        current  = [{"id": f"t-{i}", "score": 0.80} for i in range(4)]
        _, result = _run_delta(baseline, current)
        assert result["improvement_count"] == 4


# ── evals-runner tests ─────────────────────────────────────────────────────────

class TestEvalsRunner:

    def _run_mock(self, extra_args=None) -> subprocess.CompletedProcess:
        cmd = ["bash", str(RUNNER_SCRIPT), "--mock"]
        if extra_args:
            cmd += extra_args
        return subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT))

    def test_mock_produces_valid_json(self):
        proc = self._run_mock()
        assert proc.returncode == 0, proc.stderr
        data = json.loads(proc.stdout)
        assert isinstance(data, list)
        assert len(data) > 0

    def test_mock_output_has_required_fields(self):
        proc = self._run_mock()
        data = json.loads(proc.stdout)
        required = {"dataset", "baseline_score", "current_score", "delta", "threshold_pass"}
        for item in data:
            assert required.issubset(item.keys()), f"Missing fields in {item}"


# ── dataset integrity tests ────────────────────────────────────────────────────

class TestDatasets:

    def test_pbi_decomposition_jsonl_parseable(self):
        path = DATASETS_DIR / "skills" / "pbi-decomposition.jsonl"
        assert path.exists(), f"{path} does not exist"
        rows = []
        for line in path.read_text().splitlines():
            if line.strip():
                rows.append(json.loads(line))
        assert len(rows) >= 5

    def test_privacy_shield_jsonl_parseable(self):
        path = DATASETS_DIR / "hooks" / "privacy-shield.jsonl"
        assert path.exists(), f"{path} does not exist"
        rows = []
        for line in path.read_text().splitlines():
            if line.strip():
                rows.append(json.loads(line))
        assert len(rows) >= 5

    def test_baseline_pbi_decomposition_parseable(self):
        path = BASELINES_DIR / "pbi-decomposition-baseline.json"
        assert path.exists(), f"{path} does not exist"
        data = json.loads(path.read_text())
        assert isinstance(data, list)
        assert len(data) >= 3
        # Each entry must have id and score
        for item in data:
            assert "id" in item
            assert "score" in item
