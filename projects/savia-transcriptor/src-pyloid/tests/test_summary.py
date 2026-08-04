"""Tests for slice 10 — SummaryService (single-shot + map-reduce)."""

from __future__ import annotations

from typing import Callable, Optional

import pytest

from services.recording.summary import (
    LONG_TRANSCRIPT_THRESHOLD_CHARS,
    SummaryService,
)
from services.transcription import CancelToken


class _FakeProvider:
    """Records every chat() call and returns a deterministic response."""

    def __init__(self, response: str = "## TL;DR\nA fake summary."):
        self.response = response
        self.calls: list[dict] = []

    def chat(self, messages, model=None, on_stream=None, cancel_token=None) -> str:
        if cancel_token is not None and cancel_token.is_cancelled:
            from services.recording.llm import LLMStreamCancelled
            raise LLMStreamCancelled()
        self.calls.append({"messages": messages, "model": model})
        if on_stream is not None:
            for tok in self.response.split(" "):
                on_stream(tok + " ")
                if cancel_token is not None and cancel_token.is_cancelled:
                    from services.recording.llm import LLMStreamCancelled
                    raise LLMStreamCancelled()
        return self.response


# ---------- short transcripts: single chat call ----------

class TestShortTranscript:
    def test_short_transcript_makes_one_call(self):
        provider = _FakeProvider()
        svc = SummaryService()
        out = svc.summarize(
            transcript="hello world",
            segments=[{"start_ms": 0, "end_ms": 1000, "text": "hello world"}],
            provider=provider,
            prompt_template="Summarize:\n{transcript}",
        )
        assert "TL;DR" in out
        assert len(provider.calls) == 1

    def test_prompt_template_interpolated(self):
        provider = _FakeProvider()
        svc = SummaryService()
        svc.summarize(
            transcript="the cat",
            segments=[],
            provider=provider,
            prompt_template="Hello {transcript} world",
        )
        sent = provider.calls[0]["messages"][-1]["content"]
        assert "Hello the cat world" == sent

    def test_streams_partial_summary_to_caller(self):
        provider = _FakeProvider(response="hello there world")
        svc = SummaryService()
        chunks: list[str] = []
        svc.summarize(
            transcript="x",
            segments=[],
            provider=provider,
            prompt_template="{transcript}",
            on_stream=chunks.append,
        )
        assert len(chunks) > 0
        assert "".join(chunks).strip() == "hello there world"


# ---------- long transcripts: map-reduce ----------

def _long_transcript_and_segments():
    """Build a transcript that comfortably exceeds the threshold so map-reduce
    must kick in. Segments boundaries are spaced so chunks split cleanly."""
    text = ""
    segments = []
    cursor_ms = 0
    chunk_size = 5000  # chars per segment
    n_segments = (LONG_TRANSCRIPT_THRESHOLD_CHARS // chunk_size) + 4
    for i in range(n_segments):
        seg_text = ("word " * (chunk_size // 5)).strip()
        segments.append({
            "start_ms": cursor_ms,
            "end_ms": cursor_ms + 1000,
            "text": seg_text,
        })
        text += seg_text + " "
        cursor_ms += 1000
    return text, segments


class TestMapReduce:
    def test_long_transcript_triggers_multiple_calls(self):
        provider = _FakeProvider(response="chunk summary")
        svc = SummaryService()
        transcript, segments = _long_transcript_and_segments()
        svc.summarize(
            transcript=transcript,
            segments=segments,
            provider=provider,
            prompt_template="{transcript}",
        )
        # At minimum: one call per chunk + one reduce call.
        assert len(provider.calls) >= 3

    def test_short_transcript_no_map_reduce(self):
        provider = _FakeProvider()
        svc = SummaryService()
        svc.summarize(
            transcript="short",
            segments=[],
            provider=provider,
            prompt_template="{transcript}",
        )
        assert len(provider.calls) == 1


# ---------- cancellation ----------

class TestSummaryCancellation:
    def test_propagates_cancel_token_to_provider(self):
        provider = _FakeProvider()
        svc = SummaryService()
        token = CancelToken()
        token.cancel()
        from services.recording.llm import LLMStreamCancelled
        with pytest.raises(LLMStreamCancelled):
            svc.summarize(
                transcript="x", segments=[], provider=provider,
                prompt_template="{transcript}", cancel_token=token,
            )
