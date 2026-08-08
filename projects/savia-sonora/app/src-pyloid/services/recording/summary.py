"""Map-reduce summarization for long meeting transcripts.

Short transcripts go through the LLM in one shot. Long ones are split on
segment boundaries into ~10 kchar chunks; each chunk gets a 'partial summary'
pass, then the concatenated partials get a final summary pass. The split
stays at segment boundaries so we never cut in the middle of a sentence.

No tokenizer dep — we use char counts as a rough token proxy, which is fine
because the threshold has plenty of safety margin.
"""

from __future__ import annotations

from typing import Callable, Optional

from services.transcription import CancelToken

LONG_TRANSCRIPT_THRESHOLD_CHARS = 12_000
CHUNK_TARGET_CHARS = 10_000

_CHUNK_PROMPT = (
    "You are summarizing one chunk of a longer meeting transcript. Produce a "
    "tight bullet list of the key topics, decisions, and action items mentioned "
    "in THIS chunk. Don't write a full structured summary — that comes later.\n\n"
    "Chunk:\n{transcript}\n"
)


class SummaryService:
    """Drives one or more LLM calls to produce a final markdown summary."""

    def summarize(
        self,
        transcript: str,
        segments: list[dict],
        provider,
        prompt_template: str,
        on_stream: Optional[Callable[[str], None]] = None,
        cancel_token: Optional[CancelToken] = None,
    ) -> str:
        if len(transcript) <= LONG_TRANSCRIPT_THRESHOLD_CHARS:
            return self._single_pass(
                transcript, provider, prompt_template, on_stream, cancel_token
            )
        return self._map_reduce(
            transcript, segments, provider, prompt_template, on_stream, cancel_token
        )

    # ------------------------------------------------------------------ internals

    def _single_pass(
        self,
        transcript: str,
        provider,
        prompt_template: str,
        on_stream: Optional[Callable[[str], None]],
        cancel_token: Optional[CancelToken],
    ) -> str:
        prompt = prompt_template.format(transcript=transcript)
        return provider.chat(
            messages=[{"role": "user", "content": prompt}],
            on_stream=on_stream,
            cancel_token=cancel_token,
        )

    def _map_reduce(
        self,
        transcript: str,
        segments: list[dict],
        provider,
        prompt_template: str,
        on_stream: Optional[Callable[[str], None]],
        cancel_token: Optional[CancelToken],
    ) -> str:
        chunks = _chunk_by_segments(segments, transcript)
        partials: list[str] = []
        for chunk_text in chunks:
            partial = provider.chat(
                messages=[
                    {"role": "user", "content": _CHUNK_PROMPT.format(transcript=chunk_text)}
                ],
                on_stream=None,  # don't stream partials — only the final summary streams
                cancel_token=cancel_token,
            )
            partials.append(partial)

        combined = "\n\n".join(partials)
        prompt = prompt_template.format(transcript=combined)
        return provider.chat(
            messages=[{"role": "user", "content": prompt}],
            on_stream=on_stream,
            cancel_token=cancel_token,
        )


def _chunk_by_segments(segments: list[dict], fallback_transcript: str) -> list[str]:
    """Group segments into ~CHUNK_TARGET_CHARS chunks at segment boundaries."""
    if not segments:
        # No segment info — split by char count, best-effort.
        return _split_by_chars(fallback_transcript, CHUNK_TARGET_CHARS)

    chunks: list[str] = []
    current: list[str] = []
    current_len = 0
    for seg in segments:
        text = (seg.get("text") or "").strip()
        if not text:
            continue
        if current_len + len(text) + 1 > CHUNK_TARGET_CHARS and current:
            chunks.append(" ".join(current))
            current = []
            current_len = 0
        current.append(text)
        current_len += len(text) + 1
    if current:
        chunks.append(" ".join(current))
    return chunks or [fallback_transcript]


def _split_by_chars(text: str, target: int) -> list[str]:
    return [text[i:i + target] for i in range(0, len(text), target)] or [""]
