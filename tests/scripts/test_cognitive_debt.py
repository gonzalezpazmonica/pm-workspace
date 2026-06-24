"""tests/scripts/test_cognitive_debt.py — SPEC-107 pytest suite.

Tests for scripts/cognitive-debt-monitor.py cognitive load scoring.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent.parent.parent / "scripts" / "cognitive-debt-monitor.py"

# ── unit-level tests via direct import ────────────────────────────────────────

# Add scripts to path for direct import
sys.path.insert(0, str(SCRIPT.parent))
import importlib.util

_spec = importlib.util.spec_from_file_location("cognitive_debt_monitor", SCRIPT)
_mod = importlib.util.module_from_spec(_spec)  # type: ignore[arg-type]
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]
compute_score = _mod.compute_score
_risk_level = _mod._risk_level


class TestScoreLow:
    """Short session + high verification → low score."""

    def test_score_is_low_for_short_session_high_verification(self):
        result = compute_score(
            session_hours=1.0,
            verification_rate=0.9,
            tasks_completed=5,
            hour_of_day=10,
        )
        assert result.cognitive_load_score == 0
        assert result.risk_level == "low"

    def test_session_hours_zero_produces_low_score(self):
        result = compute_score(
            session_hours=0,
            verification_rate=1.0,
            tasks_completed=0,
            hour_of_day=9,
        )
        assert result.cognitive_load_score == 0
        assert result.risk_level == "low"


class TestScoreHigh:
    """Long session + low verification → high score."""

    def test_score_high_for_long_session_low_verification(self):
        result = compute_score(
            session_hours=5.0,
            verification_rate=0.2,
            tasks_completed=10,
            hour_of_day=14,
        )
        # long_session (+30) + low_verification (+25) = 55
        assert result.cognitive_load_score == 55
        assert result.risk_level == "high"

    def test_all_contributors_active_caps_at_100(self):
        """session>4 + verif<0.5 + tasks>15/h + hour>20 = 30+25+20+15 = 90."""
        result = compute_score(
            session_hours=5.0,
            verification_rate=0.1,
            tasks_completed=100,  # 100/5 = 20 tasks/h
            hour_of_day=21,
        )
        assert result.cognitive_load_score == 90
        assert result.risk_level == "critical"


class TestRiskLevel:
    """risk_level thresholds per spec."""

    def test_critical_for_score_above_75(self):
        assert _risk_level(76) == "critical"
        assert _risk_level(100) == "critical"

    def test_high_for_score_51_to_75(self):
        assert _risk_level(51) == "high"
        assert _risk_level(75) == "high"

    def test_medium_for_score_26_to_50(self):
        assert _risk_level(26) == "medium"
        assert _risk_level(50) == "medium"

    def test_low_for_score_0_to_25(self):
        assert _risk_level(0) == "low"
        assert _risk_level(25) == "low"


class TestRecommendations:
    """recommendations non-empty for score > 50."""

    def test_recommendations_non_empty_for_score_above_50(self):
        result = compute_score(
            session_hours=5.0,
            verification_rate=0.2,
            tasks_completed=10,
            hour_of_day=14,
        )
        assert result.cognitive_load_score > 50
        assert len(result.recommendations) > 0

    def test_recommendations_empty_for_zero_score(self):
        result = compute_score(
            session_hours=1.0,
            verification_rate=1.0,
            tasks_completed=2,
            hour_of_day=10,
        )
        assert result.cognitive_load_score == 0
        assert result.recommendations == []


class TestCLI:
    """CLI integration tests."""

    def _run(self, args: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT)] + args,
            capture_output=True,
            text=True,
        )

    def test_json_flag_produces_valid_json(self):
        proc = self._run([
            "--session-hours", "3",
            "--tasks-completed", "5",
            "--verification-rate", "0.8",
            "--json",
        ])
        assert proc.returncode == 0, proc.stderr
        data = json.loads(proc.stdout)
        assert isinstance(data, dict)

    def test_json_output_has_required_fields(self):
        proc = self._run([
            "--session-hours", "5",
            "--verification-rate", "0.3",
            "--json",
        ])
        data = json.loads(proc.stdout)
        assert "cognitive_load_score" in data
        assert "risk_level" in data
        assert "recommendations" in data
        assert "breakdown" in data

    def test_risk_level_critical_via_cli(self):
        proc = self._run([
            "--session-hours", "5",
            "--verification-rate", "0.1",
            "--tasks-completed", "100",
            "--hour-of-day", "21",
            "--json",
        ])
        data = json.loads(proc.stdout)
        assert data["risk_level"] == "critical"

    def test_low_score_session_hours_zero(self):
        proc = self._run([
            "--session-hours", "0",
            "--verification-rate", "1.0",
            "--json",
        ])
        data = json.loads(proc.stdout)
        assert data["cognitive_load_score"] == 0
        assert data["risk_level"] == "low"
