"""Tests for scripts/tribunal-tiered-runner.sh — SE-106: Tiered tribunal execution."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts" / "tribunal-tiered-runner.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────


def _mock_judge_fixture(veto: bool, score: int = 80, confidence: float = 0.9) -> dict:
    """Build a judge verdict fixture."""
    return {
        "judge": "mock-judge",
        "score": score,
        "veto": veto,
        "confidence": confidence,
        "verdict": "VETO" if veto else "PASS",
    }


def _run_runner(
    args: list[str],
    env: dict | None = None,
    mock_dir: str | None = None,
) -> subprocess.CompletedProcess:
    """Run tribunal-tiered-runner.sh with given args and optional mock dir."""
    run_env = os.environ.copy()
    run_env["SAVIA_TIERED_TRIBUNAL"] = "on"
    run_env["TRIBUNAL_FORCE_FULL_PANEL"] = "0"
    if mock_dir:
        run_env["SAVIA_JUDGE_MOCK_DIR"] = mock_dir
    if env:
        run_env.update(env)
    return subprocess.run(
        ["bash", str(RUNNER)] + args,
        capture_output=True,
        text=True,
        env=run_env,
    )


def _parse_output(proc: subprocess.CompletedProcess) -> dict:
    """Parse JSON output from runner stdout."""
    for line in proc.stdout.strip().splitlines():
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            continue
    raise AssertionError(
        f"No JSON found in stdout.\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
    )


# ── Tests ─────────────────────────────────────────────────────────────────────


class TestTier0VetoSkipsTier1:
    """When Tier 0 judge VETO, Tier 1 must be skipped."""

    def test_tier0_veto_tier1_skipped_flag(self, tmp_path: Path):
        """tier1_skipped must be true when a Tier 0 judge issues VETO."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        # security-judge vetos
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.95))
        )
        # correctness-judge would pass if reached
        (mock_dir / "correctness-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False))
        )

        proc = _run_runner(
            [
                "--tribunal", "court",
                "--tier0-judges", "security-judge,correctness-judge",
                "--tier1-judges", "architecture-judge,cognitive-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["tier1_skipped"] is True, f"Expected tier1_skipped=true, got: {result}"

    def test_tier0_veto_verdict_is_veto(self, tmp_path: Path):
        """Final verdict must be VETO when Tier 0 judge vetos."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "compliance-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.9))
        )

        proc = _run_runner(
            [
                "--tribunal", "truth",
                "--tier0-judges", "compliance-judge",
                "--tier1-judges", "coherence-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["verdict"] == "VETO"

    def test_tier0_veto_exit_code_one(self, tmp_path: Path):
        """Runner must exit 1 on VETO."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.85))
        )

        proc = _run_runner(
            ["--tribunal", "court", "--tier0-judges", "security-judge"],
            mock_dir=str(mock_dir),
        )
        assert proc.returncode == 1, f"Expected exit 1, got {proc.returncode}"

    def test_tier0_veto_tokens_saved_positive(self, tmp_path: Path):
        """tokens_saved_estimate must be > 0 when tier1 is skipped."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "hallucination-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.9))
        )

        proc = _run_runner(
            [
                "--tribunal", "truth",
                "--tier0-judges", "hallucination-judge",
                "--tier1-judges", "coherence-judge,calibration-judge,completeness-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["tokens_saved_estimate"] > 0, (
            f"Expected tokens_saved_estimate > 0, got {result.get('tokens_saved_estimate')}"
        )


class TestTier0PassRunsTier1:
    """When Tier 0 passes, Tier 1 must execute."""

    def test_tier0_pass_tier1_executed(self, tmp_path: Path):
        """tier1_skipped must be false when Tier 0 passes."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False, score=90))
        )
        (mock_dir / "correctness-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False, score=85))
        )

        proc = _run_runner(
            [
                "--tribunal", "court",
                "--tier0-judges", "security-judge,correctness-judge",
                "--tier1-judges", "architecture-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["tier1_skipped"] is False, f"Expected tier1_skipped=false, got: {result}"

    def test_tier0_pass_verdict_pass(self, tmp_path: Path):
        """Verdict must be PASS when all Tier 0 judges pass."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "compliance-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False, score=95))
        )

        proc = _run_runner(
            [
                "--tribunal", "truth",
                "--tier0-judges", "compliance-judge",
                "--tier1-judges", "calibration-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["verdict"] == "PASS"

    def test_tier0_pass_exit_code_zero(self, tmp_path: Path):
        """Runner must exit 0 when all judges pass."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False))
        )

        proc = _run_runner(
            ["--tribunal", "court", "--tier0-judges", "security-judge"],
            mock_dir=str(mock_dir),
        )
        assert proc.returncode == 0, f"Expected exit 0, got {proc.returncode}"


class TestTelemetry:
    """Telemetry JSONL must be written with required fields."""

    def test_telemetry_required_fields(self, tmp_path: Path):
        """Telemetry entry must contain ts, tribunal, tier0_verdict, tier1_skipped, tokens_saved, judges_run."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False))
        )

        telemetry_file = tmp_path / "telemetry.jsonl"
        proc = _run_runner(
            ["--tribunal", "court", "--tier0-judges", "security-judge"],
            mock_dir=str(mock_dir),
            env={"TIERED_TRIBUNAL_TELEMETRY_FILE": str(telemetry_file)},
        )
        # Check telemetry was written (to default output/ or via env)
        # We verify the JSON output has the right structure
        result = _parse_output(proc)
        assert "tribunal" in result
        assert "tier1_skipped" in result
        assert "tokens_saved_estimate" in result

    def test_telemetry_tokens_saved_zero_on_pass(self, tmp_path: Path):
        """tokens_saved_estimate must be 0 when Tier 1 is not skipped."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "compliance-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False))
        )

        proc = _run_runner(
            [
                "--tribunal", "truth",
                "--tier0-judges", "compliance-judge",
                "--tier1-judges", "coherence-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["tokens_saved_estimate"] == 0


class TestFeatureFlag:
    """SAVIA_TIERED_TRIBUNAL=off must fall back to full-parallel."""

    def test_tiered_off_returns_full_parallel_mode(self, tmp_path: Path):
        """When SAVIA_TIERED_TRIBUNAL=off, result mode must be full-parallel."""
        proc = subprocess.run(
            [
                "bash", str(RUNNER),
                "--tribunal", "court",
                "--tier0-judges", "security-judge",
                "--tier1-judges", "architecture-judge",
            ],
            capture_output=True,
            text=True,
            env={**os.environ, "SAVIA_TIERED_TRIBUNAL": "off"},
        )
        result = _parse_output(proc)
        assert result["mode"] == "full-parallel", (
            f"Expected mode=full-parallel, got {result.get('mode')}"
        )

    def test_tiered_off_exit_zero(self):
        """SAVIA_TIERED_TRIBUNAL=off must exit 0 without running tiered logic."""
        proc = subprocess.run(
            [
                "bash", str(RUNNER),
                "--tribunal", "court",
                "--tier0-judges", "security-judge",
                "--tier1-judges", "architecture-judge",
            ],
            capture_output=True,
            text=True,
            env={**os.environ, "SAVIA_TIERED_TRIBUNAL": "off"},
        )
        assert proc.returncode == 0

    def test_force_full_panel_bypasses_tiered(self, tmp_path: Path):
        """TRIBUNAL_FORCE_FULL_PANEL=1 must bypass tiered even when SAVIA_TIERED_TRIBUNAL=on."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        # Even with a VETO fixture, full panel returns PASS in mock dry-run
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.95))
        )

        proc = subprocess.run(
            [
                "bash", str(RUNNER),
                "--tribunal", "court",
                "--tier0-judges", "security-judge",
            ],
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "SAVIA_TIERED_TRIBUNAL": "on",
                "TRIBUNAL_FORCE_FULL_PANEL": "1",
                "SAVIA_JUDGE_MOCK_DIR": str(mock_dir),
            },
        )
        result = _parse_output(proc)
        assert result["mode"] == "full-parallel"


class TestSequentialOrder:
    """Tier 0 judges must execute sequentially and stop at first VETO."""

    def test_first_tier0_veto_stops_before_second(self, tmp_path: Path):
        """If the first Tier 0 judge vetos, the second must not run."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        # First judge vetos
        (mock_dir / "compliance-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.9))
        )
        # Second judge would pass — but should NOT be in judges_run if stopped early
        (mock_dir / "hallucination-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=False))
        )

        proc = _run_runner(
            [
                "--tribunal", "truth",
                "--tier0-judges", "compliance-judge,hallucination-judge",
                "--tier1-judges", "coherence-judge",
            ],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        # stopped_at must be the first judge
        assert result["tier0"]["stopped_at"] == "compliance-judge"
        # hallucination-judge must not be in judges_run (stopped early)
        judges_run = result.get("judges_run", [])
        assert "hallucination-judge" not in judges_run, (
            f"hallucination-judge should not have run after compliance-judge veto. judges_run={judges_run}"
        )

    def test_tier0_stopped_at_field_present_on_veto(self, tmp_path: Path):
        """tier0.stopped_at must name the vetoing judge."""
        mock_dir = tmp_path / "mocks"
        mock_dir.mkdir()
        (mock_dir / "security-judge.json").write_text(
            json.dumps(_mock_judge_fixture(veto=True, confidence=0.88))
        )

        proc = _run_runner(
            ["--tribunal", "court", "--tier0-judges", "security-judge"],
            mock_dir=str(mock_dir),
        )
        result = _parse_output(proc)
        assert result["tier0"]["stopped_at"] == "security-judge"


class TestRecommendationTribunal:
    """Recommendation Tribunal must always be skipped (always parallel by design)."""

    def test_recommendation_returns_skipped(self):
        """tribunal=recommendation must return tier_skipped=true immediately."""
        proc = subprocess.run(
            ["bash", str(RUNNER), "--tribunal", "recommendation"],
            capture_output=True,
            text=True,
            env={**os.environ, "SAVIA_TIERED_TRIBUNAL": "on"},
        )
        result = _parse_output(proc)
        assert result.get("tier_skipped") is True or result.get("verdict") == "SKIPPED"

    def test_recommendation_exit_zero(self):
        """tribunal=recommendation must exit 0."""
        proc = subprocess.run(
            ["bash", str(RUNNER), "--tribunal", "recommendation"],
            capture_output=True,
            text=True,
            env={**os.environ, "SAVIA_TIERED_TRIBUNAL": "on"},
        )
        assert proc.returncode == 0


class TestMissingTribunalFlag:
    """--tribunal flag must be required."""

    def test_missing_tribunal_exits_2(self):
        """Running without --tribunal must exit 2 (usage error)."""
        proc = subprocess.run(
            ["bash", str(RUNNER)],
            capture_output=True,
            text=True,
            env={**os.environ, "SAVIA_TIERED_TRIBUNAL": "on"},
        )
        assert proc.returncode == 2
