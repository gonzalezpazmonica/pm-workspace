"""Tests for context_guard.summarizer — Summarizer + SummaryV1 validation.

Summarizer contributes 5 test cases including malformed fixture coverage + retry logic.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

from context_guard.summarizer import (
    SummarizationError,
    Summarizer,
    SummaryV1,
    _parse_summary_yaml,
)

FIXTURES = Path(__file__).parent / "fixtures" / "context-guard"


# ---------------------------------------------------------------------------
# Helpers — stub invoke_fn
# ---------------------------------------------------------------------------


def _make_valid_yaml() -> str:
    return """
summary_v1:
  turn_count: 3
  time_span:
    first_turn_at: "2026-05-09T10:00:00Z"
    last_turn_at: "2026-05-09T10:15:00Z"
  key_decisions:
    - Chose PostgreSQL
  artifacts_produced:
    - { id: schema-v1, kind: schema, location: schemas/db.sql }
  errors_encountered: []
  tools_invoked:
    - { name: bash, count: 2 }
  prose_summary: |
    Discussed persistence. Chose PostgreSQL. Created schema.
"""


# ---------------------------------------------------------------------------
# _parse_summary_yaml
# ---------------------------------------------------------------------------


class TestParseSummaryYaml:
    def test_valid_yaml_parses_correctly(self) -> None:
        summary = _parse_summary_yaml(_make_valid_yaml())
        assert isinstance(summary, SummaryV1)
        assert summary.turn_count == 3
        assert "Chose PostgreSQL" in summary.key_decisions

    def test_fixture_valid_summary_parses(self) -> None:
        raw = (FIXTURES / "valid_summary.yaml").read_text()
        summary = _parse_summary_yaml(raw)
        assert summary.turn_count == 3

    def test_fixture_malformed_missing_fields_raises(self) -> None:
        raw = (FIXTURES / "malformed_missing_fields.yaml").read_text()
        with pytest.raises(ValueError, match="schema validation failed"):
            _parse_summary_yaml(raw)

    def test_fixture_malformed_empty_prose_raises(self) -> None:
        raw = (FIXTURES / "malformed_empty_prose.yaml").read_text()
        with pytest.raises(ValueError):
            _parse_summary_yaml(raw)

    def test_not_a_dict_raises(self) -> None:
        with pytest.raises(ValueError, match="Expected YAML dict"):
            _parse_summary_yaml("- item1\n- item2\n")


# ---------------------------------------------------------------------------
# Summarizer — happy path
# ---------------------------------------------------------------------------


class TestSummarizer:
    def test_success_on_first_attempt(self) -> None:
        def ok_invoke(text: str, tier: str) -> str:
            return _make_valid_yaml()

        summarizer = Summarizer(invoke_fn=ok_invoke, initial_tier="fast")
        result = summarizer.summarize("some text", tokens_before=500)

        assert result.summary.turn_count == 3
        assert result.tier_used == "fast"
        assert result.retried is False
        assert result.tokens_before == 500
        assert result.tokens_after > 0

    def test_retry_with_elevated_tier_on_first_failure(self) -> None:
        calls: list[str] = []

        def flaky_invoke(text: str, tier: str) -> str:
            calls.append(tier)
            if tier == "fast":
                return "not valid yaml {"  # first call: malformed
            return _make_valid_yaml()  # elevated tier: valid

        summarizer = Summarizer(invoke_fn=flaky_invoke, initial_tier="fast", max_retries=1)
        result = summarizer.summarize("some text", tokens_before=300)

        assert result.retried is True
        assert result.tier_used == "mid"  # elevated from fast
        assert "fast" in calls
        assert "mid" in calls

    def test_all_attempts_fail_raises_summarization_error(self) -> None:
        def always_bad(text: str, tier: str) -> str:
            return "completely: broken: yaml: {"

        summarizer = Summarizer(
            invoke_fn=always_bad, initial_tier="fast", max_retries=1
        )
        with pytest.raises(SummarizationError, match="failed after"):
            summarizer.summarize("some text", tokens_before=200)

    def test_negative_turn_count_in_fixture_raises(self) -> None:
        raw = (FIXTURES / "malformed_negative_turn_count.yaml").read_text()
        with pytest.raises(ValueError):
            _parse_summary_yaml(raw)
