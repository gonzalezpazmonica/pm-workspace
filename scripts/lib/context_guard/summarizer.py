"""Context Guard — Summarizer module.

Invokes the `context-summarizer` agent (prompt in .opencode/agents/context-summarizer.md),
validates the summary_v1 YAML structure, and retries with elevated tier on failure.

Spec §2.3: plantilla summary_v1 (structured metadata + prose).
Spec §2.7: rechaza malformados; reintenta con tier elevado; fallo explícito si vuelve a fallar.
Rule #26: Python for structured logic.
"""

from __future__ import annotations

import logging
import warnings
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Literal

import yaml
from pydantic import BaseModel, Field, field_validator

logger = logging.getLogger(__name__)

TIER_LITERAL = Literal["heavy", "mid", "fast"]

_TIER_ELEVATION: dict[str, str] = {
    "fast": "mid",
    "mid": "heavy",
    "heavy": "heavy",  # already at top — no further elevation
}


# ---------------------------------------------------------------------------
# Pydantic models for summary_v1
# ---------------------------------------------------------------------------


class TimeSpan(BaseModel):
    first_turn_at: str  # ISO-8601 or empty
    last_turn_at: str   # ISO-8601 or empty


class ArtifactRef(BaseModel):
    id: str
    kind: str
    location: str


class ErrorRef(BaseModel):
    type: str
    message: str


class ToolInvocation(BaseModel):
    name: str
    count: int = Field(ge=0)


class SummaryV1(BaseModel):
    """Validated structure for summary_v1 YAML output from context-summarizer.

    Spec §2.3 — ALL fields are required; lists may be empty but must be present.
    """

    turn_count: int = Field(ge=0)
    time_span: TimeSpan
    key_decisions: list[str]
    artifacts_produced: list[ArtifactRef]
    errors_encountered: list[ErrorRef]
    tools_invoked: list[ToolInvocation]
    prose_summary: str

    @field_validator("prose_summary")
    @classmethod
    def prose_not_empty(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("prose_summary must not be empty.")
        return v

    @field_validator("turn_count")
    @classmethod
    def turn_count_positive(cls, v: int) -> int:
        if v < 0:
            raise ValueError("turn_count must be >= 0.")
        return v


# ---------------------------------------------------------------------------
# Serialisation helpers
# ---------------------------------------------------------------------------


def _parse_summary_yaml(raw: str) -> SummaryV1:
    """Parse YAML string into SummaryV1.  Raises ValueError on any failure."""
    try:
        data = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        raise ValueError(f"YAML parse error: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError(f"Expected YAML dict, got {type(data).__name__}.")

    # Accept top-level key `summary_v1:` (as produced by the agent) or bare dict.
    if "summary_v1" in data:
        inner = data["summary_v1"]
    else:
        inner = data

    try:
        return SummaryV1.model_validate(inner)
    except Exception as exc:  # noqa: BLE001
        raise ValueError(f"summary_v1 schema validation failed: {exc}") from exc


# ---------------------------------------------------------------------------
# Summarizer class
# ---------------------------------------------------------------------------

#: Type alias for a callable that invokes the LLM agent and returns raw YAML.
AgentInvokeFn = Callable[[str, TIER_LITERAL], str]


@dataclass
class SummarizationResult:
    """Result returned by Summarizer.summarize()."""

    summary: SummaryV1
    tier_used: TIER_LITERAL
    retried: bool
    tokens_before: int
    tokens_after: int  # estimated from prose_summary


class SummarizationError(RuntimeError):
    """Raised when summarization fails even after retry."""


class Summarizer:
    """Invokes context-summarizer agent, validates summary_v1, retries on failure.

    Args:
        invoke_fn: Callable(prompt, tier) → raw YAML string.
            In production this wraps the OpenCode/Anthropic API call.
            In tests, pass a stub.
        initial_tier: Tier to use on first attempt ("fast" by default).
        max_retries: How many additional attempts after the first (default 1).
    """

    def __init__(
        self,
        invoke_fn: AgentInvokeFn,
        initial_tier: TIER_LITERAL = "fast",
        max_retries: int = 1,
    ) -> None:
        self._invoke_fn = invoke_fn
        self._initial_tier = initial_tier
        self._max_retries = max_retries

    def summarize(
        self,
        turns_text: str,
        tokens_before: int,
    ) -> SummarizationResult:
        """Summarize ``turns_text``.

        Attempts ``initial_tier`` first; on validation failure retries with
        the elevated tier (fast→mid→heavy). If all attempts fail, raises
        ``SummarizationError`` — never silently discards context.

        Args:
            turns_text: Concatenated text of turns to summarize.
            tokens_before: Token count of the original turns (for metadata).

        Returns:
            ``SummarizationResult`` with the validated summary.

        Raises:
            SummarizationError: If all attempts fail validation.
        """
        tier: TIER_LITERAL = self._initial_tier
        last_error: Exception | None = None
        retried = False

        for attempt in range(1 + self._max_retries):
            try:
                raw = self._invoke_fn(turns_text, tier)
                summary = _parse_summary_yaml(raw)
                tokens_after = _estimate_output_tokens(summary.prose_summary)
                logger.info(
                    "Summarizer: success on attempt %d with tier=%s. "
                    "tokens_before=%d tokens_after=%d.",
                    attempt + 1,
                    tier,
                    tokens_before,
                    tokens_after,
                )
                return SummarizationResult(
                    summary=summary,
                    tier_used=tier,
                    retried=retried,
                    tokens_before=tokens_before,
                    tokens_after=tokens_after,
                )
            except (ValueError, SummarizationError) as exc:
                last_error = exc
                logger.warning(
                    "Summarizer: attempt %d with tier=%s failed: %s",
                    attempt + 1,
                    tier,
                    exc,
                )
                if attempt < self._max_retries:
                    elevated = _TIER_ELEVATION[tier]
                    if elevated == tier:
                        # Already at heavy — no further elevation possible
                        logger.warning(
                            "Summarizer: already at tier=%s, cannot elevate further.",
                            tier,
                        )
                    else:
                        logger.info(
                            "Summarizer: elevating tier %s → %s for retry.",
                            tier,
                            elevated,
                        )
                        tier = elevated  # type: ignore[assignment]
                    retried = True

        raise SummarizationError(
            f"Summarization failed after {1 + self._max_retries} attempt(s). "
            f"Last error: {last_error}"
        ) from last_error


def _estimate_output_tokens(prose: str) -> int:
    """Quick word-based estimate for the output summary prose tokens."""
    return max(1, int(len(prose.split()) * 1.35))


def build_summarizer_prompt(turns_text: str) -> str:
    """Build the prompt sent to the context-summarizer agent.

    The prompt instructs the agent to output strict summary_v1 YAML.
    """
    return (
        "You are the context-summarizer agent for Savia.\n"
        "Produce a summary of the conversation turns below.\n"
        "Output ONLY valid YAML following the summary_v1 schema exactly.\n"
        "Do NOT include any prose outside the YAML block.\n\n"
        "Required schema:\n"
        "summary_v1:\n"
        "  turn_count: <int>\n"
        "  time_span:\n"
        "    first_turn_at: <ISO-8601 or empty string>\n"
        "    last_turn_at: <ISO-8601 or empty string>\n"
        "  key_decisions:\n"
        "    - <string>\n"
        "  artifacts_produced:\n"
        "    - { id: <str>, kind: <str>, location: <str> }\n"
        "  errors_encountered:\n"
        "    - { type: <str>, message: <str> }\n"
        "  tools_invoked:\n"
        "    - { name: <str>, count: <int> }\n"
        "  prose_summary: |\n"
        "    <markdown summary>\n\n"
        "---TURNS START---\n"
        f"{turns_text}\n"
        "---TURNS END---\n"
        "Output ONLY the YAML. No explanation."
    )
