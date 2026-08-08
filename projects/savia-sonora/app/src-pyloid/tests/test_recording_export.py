"""Tests for slice 11 — export a recording to TXT / MD / JSON / SRT."""

import json
import re

import pytest

from services.recording.export import (
    UnknownExportFormatError,
    export_recording,
    format_srt,
    format_timestamp_srt,
)


_SAMPLE = {
    "id": 7,
    "title": "Weekly sync",
    "created_at": "2026-05-12T10:00:00",
    "language": "en",
    "audio_duration_ms": 3500,
    "tags": ["product"],
    "summary": "## TL;DR\nWe shipped.",
    "transcript": "hello there. how are you. fine thanks.",
    "segments": [
        {"start_ms": 0,    "end_ms": 1200, "text": "hello there."},
        {"start_ms": 1300, "end_ms": 2400, "text": "how are you."},
        {"start_ms": 2500, "end_ms": 3500, "text": "fine thanks."},
    ],
}


# ---------- TXT ----------

class TestTXT:
    def test_writes_plain_transcript(self, tmp_path):
        path = export_recording(_SAMPLE, "txt", tmp_path)
        assert path.suffix == ".txt"
        content = path.read_text(encoding="utf-8")
        assert "hello there." in content
        assert "how are you." in content
        assert "fine thanks." in content

    def test_no_summary_in_txt(self, tmp_path):
        path = export_recording(_SAMPLE, "txt", tmp_path)
        # TXT is transcript only — no markdown headers from the summary.
        assert "## TL;DR" not in path.read_text(encoding="utf-8")


# ---------- MD ----------

class TestMD:
    def test_md_contains_title_summary_and_transcript(self, tmp_path):
        path = export_recording(_SAMPLE, "md", tmp_path)
        text = path.read_text(encoding="utf-8")
        assert path.suffix == ".md"
        # Title line
        assert "# Weekly sync" in text
        # Summary section preserved verbatim
        assert "## TL;DR" in text
        assert "We shipped." in text
        # Transcript with timestamps
        assert "hello there." in text
        assert "[00:00:00]" in text or "[0:00]" in text  # some timestamp format

    def test_md_handles_missing_summary(self, tmp_path):
        rec = {**_SAMPLE, "summary": None}
        path = export_recording(rec, "md", tmp_path)
        text = path.read_text(encoding="utf-8")
        assert "We shipped." not in text
        assert "hello there." in text  # transcript still there


# ---------- JSON ----------

class TestJSON:
    def test_json_round_trips(self, tmp_path):
        path = export_recording(_SAMPLE, "json", tmp_path)
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["id"] == 7
        assert data["title"] == "Weekly sync"
        assert data["segments"][1]["text"] == "how are you."

    def test_json_uses_correct_extension(self, tmp_path):
        path = export_recording(_SAMPLE, "json", tmp_path)
        assert path.suffix == ".json"


# ---------- SRT ----------

class TestSRT:
    def test_format_timestamp_srt(self):
        assert format_timestamp_srt(0) == "00:00:00,000"
        assert format_timestamp_srt(500) == "00:00:00,500"
        assert format_timestamp_srt(1_234) == "00:00:01,234"
        assert format_timestamp_srt(3_661_000) == "01:01:01,000"

    def test_srt_structure(self, tmp_path):
        path = export_recording(_SAMPLE, "srt", tmp_path)
        text = path.read_text(encoding="utf-8")
        assert path.suffix == ".srt"
        # Three entries, each with index + timestamps + text + blank line.
        entries = re.split(r"\n\s*\n", text.strip())
        assert len(entries) == 3
        # First entry checks
        assert entries[0].startswith("1")
        assert "00:00:00,000 --> 00:00:01,200" in entries[0]
        assert "hello there." in entries[0]
        # Third entry
        assert entries[2].startswith("3")
        assert "00:00:02,500 --> 00:00:03,500" in entries[2]

    def test_srt_handles_overlapping_segments(self):
        """If two segments overlap (rare with whisper but possible), the SRT
        emitter must not produce a non-monotonic range — bump end to before next start."""
        segs = [
            {"start_ms": 0, "end_ms": 2000, "text": "a"},
            {"start_ms": 1500, "end_ms": 3000, "text": "b"},
        ]
        out = format_srt(segs)
        # The first entry's end should be clipped so it doesn't overrun the next.
        lines = out.splitlines()
        # Parse the first entry's timestamp line.
        ts_a = lines[1]
        # End of A must be <= start of B (which is 00:00:01,500).
        assert "--> 00:00:01,500" in ts_a or "--> 00:00:01,499" in ts_a

    def test_srt_skips_empty_segments(self):
        segs = [
            {"start_ms": 0, "end_ms": 1000, "text": ""},
            {"start_ms": 1000, "end_ms": 2000, "text": "hi"},
        ]
        out = format_srt(segs)
        entries = re.split(r"\n\s*\n", out.strip())
        # Only one entry (the empty one was skipped). It's still numbered "1".
        assert len(entries) == 1
        assert entries[0].startswith("1")


# ---------- errors ----------

class TestErrors:
    def test_unknown_format_raises(self, tmp_path):
        with pytest.raises(UnknownExportFormatError):
            export_recording(_SAMPLE, "pdf", tmp_path)
