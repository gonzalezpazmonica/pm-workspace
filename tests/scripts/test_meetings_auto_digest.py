"""Tests for scripts/meetings_auto_digest.py — recursive transcript ingestion.

Cubre la regression: digest pipeline antes solo glob '*.vtt' en raiz, dejando
fuera (a) VTTs en subdirs por cuenta, (b) .transcript.txt del scrolling de
Teams web cuando no hay VTT descargable.
"""
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import meetings_auto_digest as mad


def test_transcript_patterns_includes_recursive_vtt_and_txt():
    assert "**/*.vtt" in mad.TRANSCRIPT_PATTERNS
    assert "**/*.transcript.txt" in mad.TRANSCRIPT_PATTERNS


def test_extract_transcript_txt_strips_header():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "20260430-teams-demo.transcript.txt"
        p.write_text(
            "# Teams transcript\n"
            "Title: Demo OCV\n"
            "Extracted: 2026-04-30 09:00\n\n"
            + ("=" * 60) + "\n"
            "[Speaker 1] Hola equipo\n"
            "[Speaker 2] Vamos al grano\n",
            encoding="utf-8",
        )
        body = mad.extract_transcript_txt(p)
        assert "Hola equipo" in body
        assert "Vamos al grano" in body
        assert "Title:" not in body
        assert "Extracted:" not in body


def test_extract_text_dispatches_on_extension():
    with tempfile.TemporaryDirectory() as d:
        vtt = Path(d) / "x.vtt"
        vtt.write_text(
            "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<v Ana>Hola</v>\n",
            encoding="utf-8",
        )
        txt = Path(d) / "y.transcript.txt"
        txt.write_text(
            "# Teams transcript\nTitle: x\nExtracted: 1\n\n"
            + ("=" * 60) + "\nLinea de cuerpo\n",
            encoding="utf-8",
        )
        other = Path(d) / "z.txt"
        other.write_text("nothing", encoding="utf-8")

        assert "Hola" in mad.extract_text(vtt)
        assert "Linea de cuerpo" in mad.extract_text(txt)
        assert mad.extract_text(other) == ""


def test_parse_title_from_txt_reads_title_header():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "x.transcript.txt"
        p.write_text(
            "# Teams transcript\n"
            "Title: Reunion Aurora 2026-04-30\n"
            "Extracted: 2026-04-30 10:00\n",
            encoding="utf-8",
        )
        assert mad.parse_title_from_txt(p) == "Reunion Aurora 2026-04-30"


def test_recursive_glob_finds_subdir_vtt(tmp_path):
    """Antes solo se buscaba en raiz; ahora debe descender a account1/account2/."""
    sub = tmp_path / "account1"
    sub.mkdir()
    vtt = sub / "20260430-meeting.vtt"
    vtt.write_text("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<v X>hola</v>\n", encoding="utf-8")
    txt = sub / "20260430-teams-foo.transcript.txt"
    txt.write_text("# Teams transcript\nTitle: foo\nExtracted: 1\n\n" + "=" * 60 + "\nbody\n", encoding="utf-8")

    found = []
    for pat in mad.TRANSCRIPT_PATTERNS:
        found.extend(tmp_path.glob(pat))

    names = sorted(p.name for p in found)
    assert "20260430-meeting.vtt" in names
    assert "20260430-teams-foo.transcript.txt" in names


def test_summarize_text_is_resilient_to_empty_input():
    s = mad.summarize_text("")
    assert s["total_lines"] == 0
    assert s["speakers"] == []


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
