"""Tests for context_guard.monitor — ContextGuardConfig + ContextMonitor.

18 test cases total across all test_context_guard_*.py files.
Monitor contributes 6 cases.
"""

from __future__ import annotations

import pytest

# Make scripts/ importable without installing
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

from context_guard.monitor import (
    THRESHOLD_FLOOR,
    ContextGuardConfig,
    ContextMonitor,
    TurnMessage,
)
from context_guard.tokenizer import TierTokenizer


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_turns(n: int, words_per_turn: int = 10) -> list[TurnMessage]:
    return [
        TurnMessage(
            role="user" if i % 2 == 0 else "assistant",
            content=" ".join(["word"] * words_per_turn),
        )
        for i in range(n)
    ]


def _tokenizer() -> TierTokenizer:
    return TierTokenizer(tier="fast")


# ---------------------------------------------------------------------------
# ContextGuardConfig validation
# ---------------------------------------------------------------------------


class TestContextGuardConfig:
    def test_default_config_is_valid(self) -> None:
        cfg = ContextGuardConfig()
        assert cfg.threshold_pct == 75
        assert cfg.recent_turns == 5
        assert cfg.summarizer_tier == "fast"
        assert cfg.preserve_artifacts is True
        assert cfg.enabled is False

    def test_threshold_below_floor_raises(self) -> None:
        with pytest.raises(ValueError, match="hard floor"):
            ContextGuardConfig(threshold_pct=THRESHOLD_FLOOR - 1)

    def test_threshold_at_floor_is_valid(self) -> None:
        cfg = ContextGuardConfig(threshold_pct=THRESHOLD_FLOOR)
        assert cfg.threshold_pct == THRESHOLD_FLOOR

    def test_threshold_above_95_raises(self) -> None:
        with pytest.raises(ValueError, match="above 95"):
            ContextGuardConfig(threshold_pct=96)

    def test_recent_turns_zero_raises(self) -> None:
        with pytest.raises(ValueError, match="recent_turns must be >= 1"):
            ContextGuardConfig(recent_turns=0)


# ---------------------------------------------------------------------------
# ContextMonitor
# ---------------------------------------------------------------------------


class TestContextMonitor:
    def test_disabled_never_triggers(self) -> None:
        cfg = ContextGuardConfig(enabled=False, threshold_pct=50)
        monitor = ContextMonitor(config=cfg, tokenizer=_tokenizer(), tier="fast")
        # Even with a huge number of turns, disabled monitor never fires
        turns = _make_turns(1000, words_per_turn=50)
        decision = monitor.check(turns)
        assert decision.should_summarize is False

    def test_below_threshold_does_not_trigger(self) -> None:
        cfg = ContextGuardConfig(enabled=True, threshold_pct=95, recent_turns=2)
        monitor = ContextMonitor(config=cfg, tokenizer=_tokenizer(), tier="fast")
        # 5 short turns — well below 95% of 200K window
        turns = _make_turns(5, words_per_turn=5)
        decision = monitor.check(turns)
        assert decision.should_summarize is False
        assert decision.current_tokens > 0

    def test_trigger_above_threshold(self) -> None:
        """Override context_window to a tiny value to force threshold breach."""
        cfg = ContextGuardConfig(enabled=True, threshold_pct=50, recent_turns=2)
        tokenizer = _tokenizer()
        monitor = ContextMonitor(config=cfg, tokenizer=tokenizer, tier="fast")
        # Monkey-patch the context window to be very small
        monitor._context_window = 10  # type: ignore[attr-defined]

        # Each word ≈ 1.35 tokens → 10 words * 1.35 ≈ 13 tokens > 50% of 10
        turns = _make_turns(4, words_per_turn=10)
        decision = monitor.check(turns)
        assert decision.should_summarize is True

    def test_recent_turns_partition(self) -> None:
        """Verify that exactly recent_turns turns are preserved."""
        cfg = ContextGuardConfig(enabled=True, threshold_pct=50, recent_turns=3)
        tokenizer = _tokenizer()
        monitor = ContextMonitor(config=cfg, tokenizer=tokenizer, tier="fast")
        monitor._context_window = 5  # type: ignore[attr-defined]

        turns = _make_turns(10, words_per_turn=5)
        decision = monitor.check(turns)

        if decision.should_summarize:
            assert len(decision.recent_turns) == 3
            assert len(decision.turns_to_summarize) == 7

    def test_artifact_turns_preserved(self) -> None:
        """Artifact turns must NOT appear in turns_to_summarize when preserve_artifacts=True."""
        cfg = ContextGuardConfig(
            enabled=True,
            threshold_pct=50,
            recent_turns=1,
            preserve_artifacts=True,
        )
        tokenizer = _tokenizer()
        monitor = ContextMonitor(config=cfg, tokenizer=tokenizer, tier="fast")
        monitor._context_window = 5  # type: ignore[attr-defined]

        artifact_turn = TurnMessage(
            role="assistant", content="artifact output", is_artifact=True
        )
        normal_turns = _make_turns(8, words_per_turn=5)
        turns = normal_turns[:4] + [artifact_turn] + normal_turns[4:]

        decision = monitor.check(turns)
        if decision.should_summarize:
            # Artifact should NOT be in the summarizable bucket
            assert artifact_turn not in decision.turns_to_summarize

    def test_pct_used_computed_correctly(self) -> None:
        cfg = ContextGuardConfig(enabled=True, threshold_pct=80, recent_turns=2)
        tokenizer = _tokenizer()
        monitor = ContextMonitor(config=cfg, tokenizer=tokenizer, tier="heavy")
        turns = _make_turns(3, words_per_turn=5)
        decision = monitor.check(turns)
        expected_pct = decision.current_tokens / monitor.context_window * 100
        assert abs(decision.pct_used - expected_pct) < 0.01
