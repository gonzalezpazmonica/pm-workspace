"""tests/scripts/test_sdd_reaction_engine.py — SPEC-050

Tests for scripts/sdd-reaction-engine.py: SDD Pipeline Reaction Engine.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "sdd-reaction-engine.py"


def _load():
    spec = importlib.util.spec_from_file_location("sdd_reaction_engine", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["sdd_reaction_engine"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
resolve_reaction = mod.resolve_reaction


# ── test 1: spec-approved → notify action ─────────────────────────────────────
def test_spec_approved_notify():
    result = resolve_reaction("spec-approved")
    assert result.event == "spec-approved"
    assert result.action == "notify"
    assert result.auto is True


# ── test 2: ci-failed → send-to-agent with retries ───────────────────────────
def test_ci_failed_send_to_agent():
    result = resolve_reaction("ci-failed")
    assert result.action == "send-to-agent"
    assert result.retries_allowed >= 1
    assert result.auto is True


# ── test 3: approved-and-green → NOT auto (safety rule) ──────────────────────
def test_approved_and_green_not_auto():
    result = resolve_reaction("approved-and-green")
    assert result.auto is False, "approved-and-green must never be auto (autonomous-safety.md)"


# ── test 4: unknown event → unknown-event action ─────────────────────────────
def test_unknown_event():
    result = resolve_reaction("nonexistent-event-xyz")
    assert result.action == "unknown-event"
    assert result.auto is False


# ── test 5: context is included in message ────────────────────────────────────
def test_context_in_message():
    result = resolve_reaction("tests-failed", context="3 failures in auth module")
    assert "auth module" in result.message


# ── test 6: changes-requested → escalate_after > retries ─────────────────────
def test_changes_requested_escalation():
    result = resolve_reaction("changes-requested")
    assert result.escalate_after > result.retries_allowed


# ── test 7: output serializes to valid JSON dict ─────────────────────────────
def test_result_to_dict():
    result = resolve_reaction("pr-created")
    d = result.to_dict()
    assert isinstance(d, dict)
    assert "event" in d
    assert "action" in d
    assert "auto" in d
    assert "retries_allowed" in d
    assert "message" in d


# ── test 8: all known events resolve without error ────────────────────────────
def test_all_known_events_resolve():
    for event in mod.KNOWN_EVENTS:
        result = resolve_reaction(event)
        assert result.event == event
        assert result.action != ""


# ── test 9: rules file override works ────────────────────────────────────────
def test_rules_file_override(tmp_path):
    rules_file = tmp_path / "reaction-rules.yaml"
    rules_file.write_text(
        "reactions:\n"
        "  ci-failed:\n"
        "    action: escalate\n"
        "    auto: false\n"
        "    retries: 0\n"
        "    escalate_after: 1\n"
    )
    result = resolve_reaction("ci-failed", rules_path=rules_file)
    assert result.action == "escalate"
    assert result.auto is False
    assert result.source == "rules-file"


# ── test 10: CLI --list-events returns valid JSON ─────────────────────────────
def test_cli_list_events(monkeypatch, capsys):
    lines: list[str] = []
    monkeypatch.setattr("builtins.print", lambda *a, **kw: lines.append(" ".join(str(x) for x in a)))
    rc = mod.main(["--list-events"])
    assert rc == 0
    parsed = json.loads("\n".join(lines))
    assert "known_events" in parsed
    assert len(parsed["known_events"]) > 0
