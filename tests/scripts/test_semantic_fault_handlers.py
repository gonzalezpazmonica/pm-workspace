"""tests/scripts/test_semantic_fault_handlers.py — SPEC-059

Tests for scripts/semantic-fault-handlers.py: error classification,
suggested handlers, retry strategies, and confidence scores.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "semantic-fault-handlers.py"


def _load():
    spec = importlib.util.spec_from_file_location("semantic_fault_handlers", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["semantic_fault_handlers"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
classify = mod.classify
main = mod.main
CATEGORIES = mod.CATEGORIES
CATEGORY_DEFAULTS = mod.CATEGORY_DEFAULTS


# ── Helpers ───────────────────────────────────────────────────────────────────

def _cat(error_text: str, context: str = "") -> str:
    return classify(error_text, context).category


def _handler(error_text: str) -> str:
    return classify(error_text).suggested_handler


def _strategy(error_text: str) -> str:
    return classify(error_text).retry_strategy


def _confidence(error_text: str) -> float:
    return classify(error_text).confidence


# ── TC-1: TRANSIENT ───────────────────────────────────────────────────────────

class TestTransientClassification:
    """Timeout / network errors map to TRANSIENT."""

    def test_timeout_after_seconds(self):
        assert _cat("timeout after 30s") == "TRANSIENT"

    def test_timed_out(self):
        assert _cat("Connection timed out") == "TRANSIENT"

    def test_rate_limit(self):
        assert _cat("rate limit exceeded, please retry later") == "TRANSIENT"

    def test_network_error(self):
        assert _cat("network error: connection refused") == "TRANSIENT"

    def test_service_unavailable(self):
        assert _cat("503 service unavailable") == "TRANSIENT"


# ── TC-2: FORMAT ──────────────────────────────────────────────────────────────

class TestFormatClassification:
    """Output structure problems map to FORMAT."""

    def test_missing_required_field(self):
        assert _cat("output missing required field 'result'") == "FORMAT"

    def test_invalid_json(self):
        assert _cat("invalid JSON in agent output") == "FORMAT"

    def test_parse_error(self):
        assert _cat("parse error: unexpected token at position 12") == "FORMAT"

    def test_wrong_output_format(self):
        assert _cat("wrong output format, expected JSON") == "FORMAT"

    def test_missing_key(self):
        assert _cat("missing key 'status' in response") == "FORMAT"


# ── TC-3: CAPACITY ────────────────────────────────────────────────────────────

class TestCapacityClassification:
    """Context/token exhaustion maps to CAPACITY."""

    def test_context_window_exceeded(self):
        assert _cat("context window exceeded") == "CAPACITY"

    def test_token_limit(self):
        assert _cat("token limit exceeded, cannot continue") == "CAPACITY"

    def test_prompt_too_long(self):
        assert _cat("prompt too long for model") == "CAPACITY"

    def test_context_exhausted(self):
        assert _cat("context exhausted after 128k tokens") == "CAPACITY"


# ── TC-4: VALIDATION ─────────────────────────────────────────────────────────

class TestValidationClassification:
    """AC and test failures map to VALIDATION."""

    def test_ac_fails(self):
        assert _cat("task completed but AC-3 fails") == "VALIDATION"

    def test_acceptance_criteria_not_met(self):
        assert _cat("acceptance criteria not met for AC-5") == "VALIDATION"

    def test_tests_failed(self):
        assert _cat("tests failed: 3/42 failing") == "VALIDATION"

    def test_validation_failed(self):
        assert _cat("validation failed: schema mismatch") == "VALIDATION"


# ── TC-5: SCOPE ───────────────────────────────────────────────────────────────

class TestScopeClassification:
    """Scope violations map to SCOPE."""

    def test_too_many_files(self):
        assert _cat("implementation changed 50 files instead of 2") == "SCOPE"

    def test_files_instead_of(self):
        assert _cat("modified 10 files instead of 3") == "SCOPE"

    def test_scope_exceeded(self):
        assert _cat("scope exceeded: unauthorized action on config files") == "SCOPE"

    def test_outside_allowed(self):
        assert _cat("touched files outside allowed scope") == "SCOPE"


# ── TC-6: suggested_handler TRANSIENT → "retry" ───────────────────────────────

class TestSuggestedHandlerForTransient:
    """TRANSIENT errors suggest retry."""

    def test_timeout_handler_is_retry(self):
        assert _handler("timeout after 30s") == "retry"

    def test_network_handler_is_retry(self):
        assert _handler("network error: connection refused") == "retry"


# ── TC-7: suggested_handler CAPACITY → "decompose" ────────────────────────────

class TestSuggestedHandlerForCapacity:
    """CAPACITY errors suggest decompose."""

    def test_context_window_handler(self):
        assert _handler("context window exceeded") == "decompose"

    def test_token_limit_handler(self):
        assert _handler("token limit exceeded") == "decompose"


# ── TC-8: confidence in [0, 1] ────────────────────────────────────────────────

class TestConfidenceInRange:
    """confidence is always in [0, 1]."""

    def test_timeout_confidence_range(self):
        c = _confidence("timeout after 30s")
        assert 0.0 <= c <= 1.0

    def test_format_confidence_range(self):
        c = _confidence("missing required field")
        assert 0.0 <= c <= 1.0

    def test_capacity_confidence_range(self):
        c = _confidence("context window exceeded")
        assert 0.0 <= c <= 1.0

    def test_unknown_error_confidence_range(self):
        c = _confidence("something completely unexpected xyzabc123")
        assert 0.0 <= c <= 1.0

    def test_empty_error_still_in_range(self):
        c = _confidence("   ")
        assert 0.0 <= c <= 1.0


# ── TC-9: retry strategies ────────────────────────────────────────────────────

class TestRetryStrategies:
    """retry_strategy values match category defaults."""

    def test_transient_uses_backoff(self):
        assert _strategy("timeout after 30s") == "backoff"

    def test_format_uses_immediate(self):
        assert _strategy("missing required field id") == "immediate"

    def test_capacity_uses_none(self):
        assert _strategy("context window exceeded") == "none"

    def test_logic_uses_none(self):
        assert _strategy("incorrect algorithm: wrong sort order") == "none"


# ── TC-10: output structure ───────────────────────────────────────────────────

class TestOutputStructure:
    """Output dict has all required keys."""

    def test_to_dict_has_all_keys(self):
        result = classify("timeout after 30s")
        d = result.to_dict()
        assert "category" in d
        assert "confidence" in d
        assert "suggested_handler" in d
        assert "retry_strategy" in d

    def test_category_is_valid_value(self):
        result = classify("timeout after 30s")
        assert result.category in CATEGORIES

    def test_suggested_handler_is_valid(self):
        valid_handlers = {"regenerate", "decompose", "escalate", "retry", "abort"}
        result = classify("timeout after 30s")
        assert result.suggested_handler in valid_handlers


# ── TC-11: CLI ────────────────────────────────────────────────────────────────

class TestCLIOutput:
    """CLI returns valid JSON with expected fields."""

    def test_cli_json_output(self, capsys):
        rc = main(["--error", "timeout after 30s"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert parsed["category"] == "TRANSIENT"

    def test_cli_with_context(self, capsys):
        rc = main(["--error", "missing required field", "--context", "agent returned plain text"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert parsed["category"] in CATEGORIES
        assert 0.0 <= parsed["confidence"] <= 1.0
