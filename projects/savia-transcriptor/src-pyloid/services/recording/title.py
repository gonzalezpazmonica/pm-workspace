"""LLM-driven auto-rename for meeting recordings.

After transcription completes we have the conversation context; the default
title is still a timestamp like "Meeting Tue May 12 18:28" or
"Tuesday, May 12, 6:28 PM". This module asks the configured LLM provider for a
short, specific title and cleans up the response.

Kept tiny on purpose:
  * Single one-shot call (no map-reduce — we only need a title, the first few
    thousand chars of transcript are plenty of signal).
  * Caller decides when to invoke (controller checks the setting + pattern).
  * No streaming, no progress events — a 3-7 word answer doesn't need them.
"""

from __future__ import annotations

import re
from typing import Optional

from services.transcription import CancelToken

# Use enough of the transcript for the LLM to know what the meeting was about,
# but cap it so we never blow past a provider's context window. ~4k chars is
# roughly the first 2-3 minutes of conversation at typical speaking rates.
_TITLE_PROMPT_CHAR_LIMIT = 4_000

_TITLE_PROMPT = (
    "You are naming a meeting recording. Read the transcript below and produce "
    "a short, specific title that captures what the meeting was about. "
    "Hard rules:\n"
    "- 3 to 7 words\n"
    "- No surrounding quotes\n"
    "- No trailing punctuation\n"
    "- No prefixes like 'Title:' or 'Meeting about'\n"
    "- Plain English, sentence case\n"
    "Return ONLY the title text — nothing else.\n\n"
    "Transcript:\n{transcript}"
)

# Maximum length of the cleaned-up title we'll actually save to the DB.
_MAX_TITLE_CHARS = 80


# Default-title patterns — both ends of the boundary can emit a timestamp.
#
#  - Backend `_default_title()`  →  "Meeting Tue May 12 18:28"
#  - Frontend `defaultTitle()`   →  "Tuesday, May 12, 6:28 PM"
#                                  or "Tuesday, May 12 at 6:28 PM"
#
# We're permissive on whitespace / "at" vs "," but strict on the overall shape,
# so a user-typed title like "Tuesday standup" won't accidentally match.
_DEFAULT_TITLE_PATTERNS = (
    re.compile(r"^Meeting [A-Z][a-z]{2} [A-Z][a-z]{2} \d{1,2} \d{1,2}:\d{2}$"),
    re.compile(
        r"^(?:Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day,?"
        r" [A-Z][a-z]{2} \d{1,2}(?:,| at) \d{1,2}:\d{2}\s*(?:AM|PM)$"
    ),
    # Frontend Input placeholder if the user cleared the field then started.
    re.compile(r"^Untitled meeting$", re.IGNORECASE),
)


def is_default_title(title: Optional[str]) -> bool:
    """True when `title` looks like one of the auto-generated defaults.

    Empty/whitespace-only titles also count as default — they got there because
    nothing else was set."""
    if not title or not title.strip():
        return True
    return any(p.match(title.strip()) for p in _DEFAULT_TITLE_PATTERNS)


def generate_title(
    transcript: str,
    provider,
    cancel_token: Optional[CancelToken] = None,
) -> str:
    """Ask the LLM for a title for `transcript`. Returns a cleaned-up string.

    Raises whatever the provider raises on connection errors — the caller is
    responsible for wrapping and logging."""
    excerpt = (transcript or "").strip()[:_TITLE_PROMPT_CHAR_LIMIT]
    if not excerpt:
        raise ValueError("transcript is empty")

    raw = provider.chat(
        messages=[{"role": "user", "content": _TITLE_PROMPT.format(transcript=excerpt)}],
        on_stream=None,
        cancel_token=cancel_token,
    )
    cleaned = _clean_title(raw)
    if not cleaned:
        raise ValueError("LLM returned an empty title")
    return cleaned


def _clean_title(raw: str) -> str:
    """Strip the usual LLM cruft: surrounding quotes, trailing punctuation,
    leading 'Title:' prefixes, newlines, and overall length."""
    if not raw:
        return ""
    # Some providers respond with multiple lines / preambles — take the first
    # non-empty line as the title.
    for line in raw.splitlines():
        candidate = line.strip()
        if candidate:
            raw = candidate
            break
    else:
        return ""

    # Strip common prefixes.
    raw = re.sub(r"^(title|meeting title|name|subject)\s*:\s*", "", raw, flags=re.IGNORECASE)
    # Strip surrounding quotes (straight or curly, single or double).
    raw = raw.strip().strip('"“”‘’\'`')
    # Strip trailing punctuation.
    raw = re.sub(r"[.!?,;:\s]+$", "", raw)
    # Collapse interior whitespace.
    raw = re.sub(r"\s+", " ", raw).strip()
    return raw[:_MAX_TITLE_CHARS]
