"""Tests for the auto-rename title module."""

from __future__ import annotations

import pytest

from services.recording.title import (
    _MAX_TITLE_CHARS,
    _TITLE_PROMPT_CHAR_LIMIT,
    _clean_title,
    generate_title,
    is_default_title,
)


class _FakeProvider:
    """Captures every chat() call and returns a configurable response."""

    def __init__(self, response: str = "Q1 planning sync"):
        self.response = response
        self.calls: list[dict] = []

    def chat(self, messages, model=None, on_stream=None, cancel_token=None) -> str:
        self.calls.append({"messages": messages, "model": model})
        return self.response


# ─────────────────────────────────────────────────────────────── _clean_title


class TestCleanTitle:
    def test_strips_surrounding_double_quotes(self):
        assert _clean_title('"Q1 planning sync"') == "Q1 planning sync"

    def test_strips_surrounding_smart_quotes(self):
        assert _clean_title("“Q1 planning sync”") == "Q1 planning sync"

    def test_strips_title_prefix_case_insensitive(self):
        assert _clean_title("Title: Roadmap review") == "Roadmap review"
        assert _clean_title("TITLE:Roadmap review") == "Roadmap review"
        assert _clean_title("Meeting Title: Roadmap review") == "Roadmap review"

    def test_strips_trailing_punctuation(self):
        assert _clean_title("Roadmap review.") == "Roadmap review"
        assert _clean_title("Roadmap review!") == "Roadmap review"
        assert _clean_title("Roadmap review!!!") == "Roadmap review"

    def test_collapses_interior_whitespace(self):
        assert _clean_title("Roadmap    review") == "Roadmap review"

    def test_takes_first_nonempty_line(self):
        # Some providers like to add a chatty preamble or trailing explanation.
        raw = "\n\nQ1 planning sync\n\nThis title summarizes …"
        assert _clean_title(raw) == "Q1 planning sync"

    def test_empty_input(self):
        assert _clean_title("") == ""
        assert _clean_title("   \n\n  ") == ""

    def test_caps_length(self):
        long = "word " * 100
        assert len(_clean_title(long)) <= _MAX_TITLE_CHARS


# ───────────────────────────────────────────────────────────── is_default_title


class TestIsDefaultTitle:
    @pytest.mark.parametrize(
        "title",
        [
            "Meeting Tue May 12 18:28",      # backend %a %b %d %H:%M
            "Meeting Mon Jan 1 09:00",        # single-digit day
            "Tuesday, May 12, 6:28 PM",       # frontend toLocaleString default
            "Tuesday, May 12 at 6:28 PM",     # frontend with "at" separator
            "Wednesday, Dec 3, 11:45 AM",
            "Sunday, Feb 28, 12:00 PM",
            "Untitled meeting",
            "untitled meeting",                # placeholder, case-insensitive
            "",
            "    ",
            None,
        ],
    )
    def test_matches_default_shapes(self, title):
        assert is_default_title(title) is True

    @pytest.mark.parametrize(
        "title",
        [
            "Tuesday standup",                # weekday word but not the full shape
            "Q1 planning",
            "Meeting with Bob",
            "Meeting Tuesday",                # incomplete backend shape
            "Roadmap review for May",
            "May 12 sync",
            "1:1 with Alex",
        ],
    )
    def test_rejects_user_titles(self, title):
        assert is_default_title(title) is False


# ───────────────────────────────────────────────────────────── generate_title


class TestGenerateTitle:
    def test_calls_provider_once_with_transcript(self):
        provider = _FakeProvider(response="Q1 planning sync")
        result = generate_title("We need to ship by end of quarter.", provider)
        assert result == "Q1 planning sync"
        assert len(provider.calls) == 1

    def test_cleans_provider_output(self):
        provider = _FakeProvider(response='Title: "Roadmap review."\n')
        assert generate_title("Hello world", provider) == "Roadmap review"

    def test_truncates_long_transcript_in_prompt(self):
        provider = _FakeProvider(response="A title")
        transcript = "x" * (_TITLE_PROMPT_CHAR_LIMIT * 3)
        generate_title(transcript, provider)
        sent = provider.calls[0]["messages"][0]["content"]
        # The transcript portion sits after the "Transcript:\n" marker in the
        # prompt — anything before that is the static template (which itself
        # contains letters like 'x', so we can't just count the whole string).
        marker = "Transcript:\n"
        embedded_transcript = sent.split(marker, 1)[1]
        assert len(embedded_transcript) == _TITLE_PROMPT_CHAR_LIMIT
        assert embedded_transcript == "x" * _TITLE_PROMPT_CHAR_LIMIT

    def test_raises_on_empty_transcript(self):
        provider = _FakeProvider()
        with pytest.raises(ValueError):
            generate_title("", provider)
        with pytest.raises(ValueError):
            generate_title("   \n\n  ", provider)

    def test_raises_on_empty_response(self):
        provider = _FakeProvider(response="")
        with pytest.raises(ValueError):
            generate_title("Real transcript text here.", provider)

    def test_raises_on_whitespace_only_response(self):
        provider = _FakeProvider(response="   \n\n  ")
        with pytest.raises(ValueError):
            generate_title("Real transcript text here.", provider)
