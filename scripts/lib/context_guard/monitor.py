"""Context Guard — Monitor module.

Measures context size and decides when to fire summarization.

Spec §2.2: threshold_pct * context_window triggers summarizer.
Hard floor: threshold_pct >= 50 (Spec §6 risk table — prevents infinite loops).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Literal

from pydantic import BaseModel, field_validator, model_validator

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Tier → context window size in tokens (canonical Anthropic / generic values)
# ---------------------------------------------------------------------------
CONTEXT_WINDOW_BY_TIER: dict[str, int] = {
    "heavy": 200_000,  # Claude Opus class
    "mid": 200_000,    # Claude Sonnet class
    "fast": 200_000,   # Claude Haiku class
}

TIER_LITERAL = Literal["heavy", "mid", "fast"]

THRESHOLD_FLOOR = 50  # percent — hard floor from spec §6


class ContextGuardConfig(BaseModel):
    """Validated configuration extracted from agent/flow frontmatter.

    Spec §2.1:
        enabled: bool
        threshold_pct: int   (50-95, hard floor 50)
        recent_turns: int    (>= 1)
        summarizer_tier: Literal["heavy", "mid", "fast"]
        preserve_artifacts: bool
    """

    enabled: bool = False
    threshold_pct: int = 75
    recent_turns: int = 5
    summarizer_tier: TIER_LITERAL = "fast"
    preserve_artifacts: bool = True

    @field_validator("threshold_pct")
    @classmethod
    def validate_threshold(cls, v: int) -> int:
        if v < THRESHOLD_FLOOR:
            raise ValueError(
                f"threshold_pct={v} is below the hard floor of {THRESHOLD_FLOOR}. "
                "Values below 50% cause summarization loops. Set threshold_pct >= 50."
            )
        if v > 95:
            raise ValueError(
                f"threshold_pct={v} is above 95. Effective range is 50-95."
            )
        return v

    @field_validator("recent_turns")
    @classmethod
    def validate_recent_turns(cls, v: int) -> int:
        if v < 1:
            raise ValueError("recent_turns must be >= 1.")
        return v

    @model_validator(mode="after")
    def validate_enabled_consistency(self) -> "ContextGuardConfig":
        # When enabled=False, we still allow any config values (disabled = no-op).
        return self


@dataclass
class TurnMessage:
    """Minimal representation of a single conversation turn."""

    role: str        # "user" | "assistant" | "tool"
    content: str
    timestamp: str | None = None   # ISO-8601 or None
    is_artifact: bool = False


@dataclass
class MonitorDecision:
    """Result of a monitor check."""

    should_summarize: bool
    current_tokens: int
    context_window: int
    threshold_tokens: int
    pct_used: float
    turns_to_summarize: list[TurnMessage] = field(default_factory=list)
    recent_turns: list[TurnMessage] = field(default_factory=list)


class ContextMonitor:
    """Monitors context size and decides when to trigger summarization.

    Usage::

        from scripts.lib.context_guard.tokenizer import TierTokenizer
        from scripts.lib.context_guard.monitor import ContextMonitor, ContextGuardConfig

        config = ContextGuardConfig(enabled=True, threshold_pct=75, recent_turns=5)
        tokenizer = TierTokenizer(tier="fast")
        monitor = ContextMonitor(config=config, tokenizer=tokenizer)

        decision = monitor.check(turns)
        if decision.should_summarize:
            # fire summarizer on decision.turns_to_summarize
            ...
    """

    def __init__(
        self,
        config: ContextGuardConfig,
        tokenizer: "TierTokenizer",  # forward ref to avoid circular import
        tier: TIER_LITERAL = "fast",
    ) -> None:
        self._config = config
        self._tokenizer = tokenizer
        self._tier = tier
        self._context_window = CONTEXT_WINDOW_BY_TIER.get(tier, 200_000)

    @property
    def config(self) -> ContextGuardConfig:
        return self._config

    @property
    def context_window(self) -> int:
        return self._context_window

    def _count_tokens(self, turns: list[TurnMessage]) -> int:
        """Count total tokens across all turns."""
        total = 0
        for turn in turns:
            total += self._tokenizer.count(turn.content)
        return total

    def check(self, turns: list[TurnMessage]) -> MonitorDecision:
        """Decide whether summarization should fire.

        Partitions turns into:
        - ``recent_turns``: last N turns (always preserved)
        - ``turns_to_summarize``: everything before recent (summarizable)

        If ``preserve_artifacts=True``, artifact turns are moved to
        ``recent_turns`` regardless of position (not summarized).
        """
        if not self._config.enabled:
            current = self._count_tokens(turns)
            return MonitorDecision(
                should_summarize=False,
                current_tokens=current,
                context_window=self._context_window,
                threshold_tokens=int(
                    self._context_window * self._config.threshold_pct / 100
                ),
                pct_used=current / self._context_window * 100,
            )

        current_tokens = self._count_tokens(turns)
        threshold_tokens = int(
            self._context_window * self._config.threshold_pct / 100
        )
        pct_used = current_tokens / self._context_window * 100

        if current_tokens <= threshold_tokens:
            return MonitorDecision(
                should_summarize=False,
                current_tokens=current_tokens,
                context_window=self._context_window,
                threshold_tokens=threshold_tokens,
                pct_used=pct_used,
            )

        # Partition turns
        n = self._config.recent_turns
        recent = list(turns[-n:]) if n <= len(turns) else list(turns)
        to_summarize = list(turns[: len(turns) - len(recent)])

        if self._config.preserve_artifacts:
            artifacts = [t for t in to_summarize if t.is_artifact]
            to_summarize = [t for t in to_summarize if not t.is_artifact]
            recent = artifacts + recent

        logger.info(
            "ContextGuard threshold crossed: %.1f%% used (threshold %d%%). "
            "Turns to summarize: %d. Recent turns retained: %d.",
            pct_used,
            self._config.threshold_pct,
            len(to_summarize),
            len(recent),
        )

        return MonitorDecision(
            should_summarize=True,
            current_tokens=current_tokens,
            context_window=self._context_window,
            threshold_tokens=threshold_tokens,
            pct_used=pct_used,
            turns_to_summarize=to_summarize,
            recent_turns=recent,
        )
