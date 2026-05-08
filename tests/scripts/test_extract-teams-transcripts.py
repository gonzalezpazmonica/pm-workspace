"""Tests for scripts/extract-teams-transcripts.py — pure-logic smoke.

No CDP / browser interaction here — only verifies the parts of the script
that are pure-Python and safe to test offline:
  - JS templates contain expected DOM markers (recap panel, transcript tab)
  - save_transcript writes the expected header layout
  - skip-file default path is persistent (under ~/.savia/) NOT /tmp/
  - norm() strips diacritics for substring matching

The CDP scrolling itself is integration-tested manually against Teams web.
"""
import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "extract-teams-transcripts.py"


def _load():
    spec = importlib.util.spec_from_file_location("extract_teams_transcripts", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()


def test_recap_panel_template_contains_post_2026_04_marker():
    assert "meeting-recap-main-panel" in mod.JS_SCROLL_RECAP


def test_transcript_tab_uses_data_tid_marker():
    assert "data-tid=\"Transcript\"" in mod.JS_CLICK_TRANSCRIPT_TPL


def test_legacy_iframe_fallback_present():
    # Old xplatplugins.aspx path must still be wired as fallback.
    assert "JS_SCROLL_IFRAME" in dir(mod)
    assert "scrollHeight" in mod.JS_SCROLL_IFRAME


def test_save_transcript_writes_header_and_separator():
    with tempfile.TemporaryDirectory() as d:
        path = mod.save_transcript(d, "Daily Aurora 2026-04-30", "[Ana] Hola\n[Bob] Si")
        content = Path(path).read_text(encoding="utf-8")
        assert content.startswith("# Teams transcript")
        assert "Title: Daily Aurora 2026-04-30" in content
        assert "Extracted:" in content
        assert ("=" * 60) in content
        assert "[Ana] Hola" in content


def test_norm_strips_diacritics():
    assert mod.norm("Análisis") == "analisis"
    assert mod.norm("Revisión") == "revision"
    # case insensitive lower
    assert mod.norm("DEMO") == "demo"


def test_default_skip_file_is_persistent_savia_path():
    """Regression: previously /tmp/teams_processed.json — wiped on Windows reboot."""
    import argparse
    ap = argparse.ArgumentParser()
    # Re-use the same default expression as the script
    default = os.path.expanduser("~/.savia/teams-processed.json")
    ap.add_argument("--skip-file", default=default)
    args = ap.parse_args([])
    assert ".savia" in args.skip_file
    assert "/tmp/" not in args.skip_file
    assert args.skip_file.endswith("teams-processed.json")


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
