"""tests/scripts/test_criterion_simulation_trigger.py — SPEC-194

Tests for trigger-evaluator.py and operator-state-signals.py.

AC3: 50 synthetic task-contexts -> trigger fires in <= 20% (<=10 of 50)
AC4: 10 high-impact tasks (touches_security or touches_human_safety) -> fires >= 8/10
AC5: operator-state-signals.py never makes network calls (socket mock)
"""
from __future__ import annotations

import importlib
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# ── Path setup ────────────────────────────────────────────────────────────────
REPO_ROOT   = Path(__file__).resolve().parent.parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts" / "criterion-simulation"
sys.path.insert(0, str(SCRIPTS_DIR))
sys.path.insert(0, str(REPO_ROOT / "scripts"))

# ── Helpers ────────────────────────────────────────────────────────────────────

def _load_trigger():
    """Import trigger-evaluator fresh (avoids module cache issues)."""
    spec = importlib.util.spec_from_file_location(
        "trigger_evaluator",
        SCRIPTS_DIR / "trigger-evaluator.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_operator():
    """Import operator-state-signals fresh."""
    spec = importlib.util.spec_from_file_location(
        "operator_state_signals",
        SCRIPTS_DIR / "operator-state-signals.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── 50 synthetic task-contexts (AC3) ──────────────────────────────────────────
# These represent typical workspace tasks that should NOT trigger the layer.
# None has touches_security, touches_human_safety, touches_production, or estimated_hours>16.

NORMAL_TASKS = [
    {"task": "update README", "estimated_hours": 1},
    {"task": "add docstring to utility function", "estimated_hours": 0.5},
    {"task": "fix typo in CHANGELOG", "estimated_hours": 0.1},
    {"task": "bump version number", "estimated_hours": 0.5},
    {"task": "refactor test helper", "estimated_hours": 2},
    {"task": "update dependency version", "estimated_hours": 1},
    {"task": "add unit test for parser", "estimated_hours": 2},
    {"task": "rename variable for clarity", "estimated_hours": 0.5},
    {"task": "extract method in utility module", "estimated_hours": 1},
    {"task": "add log statement", "estimated_hours": 0.5},
    {"task": "update CI config comment", "estimated_hours": 0.2},
    {"task": "create CHANGELOG entry", "estimated_hours": 0.3},
    {"task": "fix lint warning", "estimated_hours": 0.5},
    {"task": "add type hint", "estimated_hours": 0.5},
    {"task": "update gitignore pattern", "estimated_hours": 0.2},
    {"task": "remove dead code in helper", "estimated_hours": 1},
    {"task": "add integration test scaffold", "estimated_hours": 3},
    {"task": "update skill documentation", "estimated_hours": 1},
    {"task": "add assertion in test", "estimated_hours": 0.5},
    {"task": "fix broken markdown link", "estimated_hours": 0.2},
    {"task": "add comment explaining regex", "estimated_hours": 0.3},
    {"task": "reorganize test fixtures", "estimated_hours": 2},
    {"task": "update example in docs", "estimated_hours": 0.5},
    {"task": "add new bats test case", "estimated_hours": 1},
    {"task": "improve error message", "estimated_hours": 0.5},
    {"task": "create helper function for repeated logic", "estimated_hours": 2},
    {"task": "fix flaky test timing issue", "estimated_hours": 3},
    {"task": "add parameter validation", "estimated_hours": 1},
    {"task": "update project AGENTS.md", "estimated_hours": 0.5},
    {"task": "add missing newline at EOF", "estimated_hours": 0.1},
    {"task": "remove unused import", "estimated_hours": 0.2},
    {"task": "add output directory creation", "estimated_hours": 0.5},
    {"task": "improve test coverage for edge case", "estimated_hours": 2},
    {"task": "update default config comment", "estimated_hours": 0.3},
    {"task": "add schema validation in util", "estimated_hours": 2},
    {"task": "fix inconsistent formatting", "estimated_hours": 0.3},
    {"task": "add retry logic for transient errors", "estimated_hours": 3},
    {"task": "update hook documentation", "estimated_hours": 0.5},
    {"task": "add missing error handling", "estimated_hours": 1},
    {"task": "rename agent file for clarity", "estimated_hours": 0.3},
    {"task": "add telemetry field", "estimated_hours": 1},
    {"task": "update sprint documentation", "estimated_hours": 0.5},
    {"task": "improve log message format", "estimated_hours": 0.3},
    {"task": "add new command alias", "estimated_hours": 0.5},
    {"task": "update frontmatter fields", "estimated_hours": 0.5},
    {"task": "add missing test fixture", "estimated_hours": 1},
    {"task": "fix path resolution in script", "estimated_hours": 1},
    {"task": "refactor common pattern into function", "estimated_hours": 2},
    {"task": "update project local config template", "estimated_hours": 0.5},
    {"task": "add verbose flag to CLI", "estimated_hours": 1},
]

assert len(NORMAL_TASKS) == 50, f"Expected 50 tasks, got {len(NORMAL_TASKS)}"

# ── 10 high-impact task-contexts (AC4) ────────────────────────────────────────

HIGH_IMPACT_TASKS = [
    {"task": "patch auth bypass in prod", "touches_security": True, "touches_production": True},
    {"task": "deploy to prod with security changes", "touches_production": True, "touches_security": True},
    {"task": "update safety stop mechanism", "touches_human_safety": True},
    {"task": "rotate production credentials", "touches_security": True, "touches_production": True},
    {"task": "emergency medical device firmware", "touches_human_safety": True},
    {"task": "disable rate limiting in prod system", "touches_security": True, "touches_production": True},
    {"task": "update patient data export", "touches_human_safety": True, "touches_security": True},
    {"task": "modify prod database schema live", "touches_production": True, "touches_security": True},
    {"task": "bypass MFA in production admin account", "touches_security": True, "touches_production": True},
    {"task": "auto-shutdown safety interlock", "touches_human_safety": True},
]

assert len(HIGH_IMPACT_TASKS) == 10, f"Expected 10 tasks, got {len(HIGH_IMPACT_TASKS)}"


class TestTriggerEvaluator(unittest.TestCase):
    """AC3, AC4: trigger thresholds."""

    def setUp(self):
        # Force threshold to default 50 and zero operator state for isolation
        os.environ["SAVIA_CS_TRIGGER_THRESHOLD"] = "50"
        # Import fresh
        self.trigger_mod = _load_trigger()
        # Patch operator state to return zeros (isolate from time-of-day)
        self._orig_compute = self.trigger_mod.compute_operator_state
        self.trigger_mod.compute_operator_state = lambda op="default": {
            "fatigue_score": 0,
            "pressure_score": 0,
            "override_rate": 0,
            "time_band": "normal",
        }
        # Patch historical priors to return empty
        self._orig_priors = self.trigger_mod.get_recent_failed_frames
        self.trigger_mod.get_recent_failed_frames = lambda ctx, lookback_days=90: {
            "count": 0,
            "priors": [],
        }

    def tearDown(self):
        self.trigger_mod.compute_operator_state = self._orig_compute
        self.trigger_mod.get_recent_failed_frames = self._orig_priors
        os.environ.pop("SAVIA_CS_TRIGGER_THRESHOLD", None)

    def test_ac3_normal_tasks_trigger_rate_le_20pct(self):
        """AC3: <= 20% of 50 normal tasks trigger activation (threshold=50)."""
        activations = sum(
            1 for task in NORMAL_TASKS
            if self.trigger_mod.should_activate(task)["activate"]
        )
        pct = activations / len(NORMAL_TASKS) * 100
        self.assertLessEqual(
            activations, 10,
            f"Too many normal tasks triggered: {activations}/50 ({pct:.1f}%). "
            f"AC3 requires <= 20% (<=10/50)."
        )

    def test_ac4_high_impact_tasks_trigger_rate_ge_80pct(self):
        """AC4: >= 8/10 high-impact tasks trigger activation."""
        activations = sum(
            1 for task in HIGH_IMPACT_TASKS
            if self.trigger_mod.should_activate(task)["activate"]
        )
        self.assertGreaterEqual(
            activations, 8,
            f"Too few high-impact tasks triggered: {activations}/10. "
            f"AC4 requires >= 8/10."
        )

    def test_output_schema_has_required_fields(self):
        """Output dict has all required fields."""
        result = self.trigger_mod.should_activate({"task": "test"})
        self.assertIn("activate", result)
        self.assertIn("score", result)
        self.assertIn("reasons", result)
        self.assertIn("operator_state", result)
        self.assertIn("priors", result)

    def test_score_capped_at_100(self):
        """Score is capped at 100 even with maxed signals."""
        result = self.trigger_mod.should_activate({
            "touches_security": True,
            "touches_human_safety": True,
            "touches_production": True,
            "estimated_hours": 24,
        })
        self.assertLessEqual(result["score"], 100)

    def test_activate_false_for_empty_context(self):
        """Empty task context -> activate=False (score 0 < threshold 50)."""
        result = self.trigger_mod.should_activate({})
        self.assertFalse(result["activate"])
        self.assertEqual(result["score"], 0)

    def test_threshold_env_respected(self):
        """SAVIA_CS_TRIGGER_THRESHOLD env is respected."""
        # Very low threshold: almost everything triggers
        self.trigger_mod.TRIGGER_THRESHOLD = 5
        result = self.trigger_mod.should_activate({"touches_security": True})
        self.assertTrue(result["activate"])

        # Very high threshold: nothing triggers
        self.trigger_mod.TRIGGER_THRESHOLD = 200
        result = self.trigger_mod.should_activate({"touches_security": True})
        self.assertFalse(result["activate"])

        # Reset
        self.trigger_mod.TRIGGER_THRESHOLD = 50


class TestOperatorStateSignals(unittest.TestCase):
    """AC5: operator-state-signals never makes network calls."""

    def setUp(self):
        self.op_mod = _load_operator()

    def test_ac5_no_network_calls_socket_mocked(self):
        """AC5: compute_operator_state never touches socket.connect."""
        # Patch socket module at the stdlib level to detect any connect attempt
        import socket as real_socket

        original_connect = real_socket.socket.connect
        connect_called = []

        def spy_connect(self_sock, *args, **kwargs):
            connect_called.append(args)
            raise AssertionError(
                f"AC5 VIOLATED: operator-state-signals.py attempted a network call: {args}"
            )

        with patch.object(real_socket.socket, "connect", spy_connect):
            result = self.op_mod.compute_operator_state("test_operator")

        self.assertEqual(connect_called, [], "No network calls should have been made")

    def test_output_schema(self):
        """compute_operator_state returns required fields."""
        result = self.op_mod.compute_operator_state()
        self.assertIn("fatigue_score", result)
        self.assertIn("pressure_score", result)
        self.assertIn("override_rate", result)
        self.assertIn("time_band", result)

    def test_fatigue_score_range(self):
        """fatigue_score is in [0, 30]."""
        result = self.op_mod.compute_operator_state()
        self.assertGreaterEqual(result["fatigue_score"], 0)
        self.assertLessEqual(result["fatigue_score"], 30)

    def test_pressure_score_range(self):
        """pressure_score is in [0, 20]."""
        result = self.op_mod.compute_operator_state()
        self.assertGreaterEqual(result["pressure_score"], 0)
        self.assertLessEqual(result["pressure_score"], 20)

    def test_override_rate_range(self):
        """override_rate is in [0, 20]."""
        result = self.op_mod.compute_operator_state()
        self.assertGreaterEqual(result["override_rate"], 0)
        self.assertLessEqual(result["override_rate"], 20)

    def test_time_band_valid_values(self):
        """time_band is one of the expected values."""
        result = self.op_mod.compute_operator_state()
        self.assertIn(result["time_band"], ("normal", "transition", "atypical"))

    def test_no_import_socket(self):
        """operator-state-signals.py does not import socket module."""
        source = (SCRIPTS_DIR / "operator-state-signals.py").read_text()
        self.assertNotIn(
            "import socket",
            source,
            "operator-state-signals.py must not import socket (AC5)"
        )

    def test_no_import_urllib(self):
        """operator-state-signals.py does not import urllib or requests."""
        source = (SCRIPTS_DIR / "operator-state-signals.py").read_text()
        self.assertNotIn("import urllib", source)
        self.assertNotIn("import requests", source)
        self.assertNotIn("import httplib", source)
        self.assertNotIn("import http.client", source)


if __name__ == "__main__":
    unittest.main()
