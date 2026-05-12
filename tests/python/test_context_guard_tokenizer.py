"""Tests for context_guard.tokenizer — TierTokenizer.

Tokenizer contributes 4 test cases (tiktoken absent → fallback path tested).
"""

from __future__ import annotations

import sys
import warnings
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

import context_guard.tokenizer as tok_module
from context_guard.tokenizer import TierTokenizer, _FALLBACK_TOKENS_PER_WORD


# ---------------------------------------------------------------------------
# TierTokenizer — basic contract
# ---------------------------------------------------------------------------


class TestTierTokenizer:
    def test_invalid_tier_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown tier"):
            TierTokenizer(tier="ultrafast")  # type: ignore[arg-type]

    def test_count_empty_string_returns_zero(self) -> None:
        t = TierTokenizer(tier="fast")
        assert t.count("") == 0

    def test_count_returns_positive_for_nonempty(self) -> None:
        t = TierTokenizer(tier="mid")
        result = t.count("hello world this is a test sentence")
        assert result > 0

    def test_fallback_estimator_logic(self) -> None:
        """When tiktoken is absent the fallback must emit a warning and still count."""
        # Force tiktoken unavailable for this test scope
        original = tok_module._TIKTOKEN_AVAILABLE
        tok_module._TIKTOKEN_AVAILABLE = None  # reset detection cache

        with patch.dict("sys.modules", {"tiktoken": None}):
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")
                t = TierTokenizer(tier="fast")
                # Check: warning was emitted
                runtime_warnings = [x for x in w if issubclass(x.category, RuntimeWarning)]
                assert runtime_warnings, "Expected a RuntimeWarning when tiktoken absent"

            text = "this is a test with ten words here now ok"
            words = text.split()
            expected = max(1, int(len(words) * _FALLBACK_TOKENS_PER_WORD))
            assert t.count(text) == expected
            assert t.is_fallback is True

        # Restore
        tok_module._TIKTOKEN_AVAILABLE = original
