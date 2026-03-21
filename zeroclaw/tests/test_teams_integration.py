#!/usr/bin/env python3
"""Tests for Teams integration + meeting orchestrator."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.teams_client import TeamsClient, _load_config
from host.meeting_orchestrator import MeetingOrchestrator

passed = 0
failed = 0


def test(name, fn):
    global passed, failed
    try:
        fn()
        print(f"  ✅ {name}")
        passed += 1
    except Exception as e:
        print(f"  ❌ {name}: {e}")
        failed += 1


def test_teams_not_configured():
    c = TeamsClient()
    assert not c.is_configured(), "should not be configured without env vars"


def test_teams_connect_fails_gracefully():
    c = TeamsClient()
    assert not c.connect(), "should fail without credentials"


def test_teams_status():
    c = TeamsClient()
    s = c.status()
    assert "configured" in s
    assert "authenticated" in s


def test_orchestrator_start_zeroclaw():
    o = MeetingOrchestrator()
    r = o.start("zeroclaw", "test-session")
    assert r["channel"] == "zeroclaw"


def test_orchestrator_start_teams():
    o = MeetingOrchestrator()
    r = o.start("teams", "teams-session")
    assert r["channel"] == "teams"


def test_orchestrator_process_utterance():
    o = MeetingOrchestrator()
    o.start("teams")
    r = o.process_utterance("Carlos", "El sprint está bloqueado")
    assert "observations" in r
    # "bloqueado" should trigger risk detection
    types = [obs["type"] for obs in r["observations"]]
    assert "risk" in types


def test_orchestrator_handle_query():
    o = MeetingOrchestrator()
    o.roles.set_role("maria", "developer")
    o.start("teams")
    r = o.handle_query("maria", "what are the blockers?")
    assert r["role"] == "developer"
    assert r["channel"] == "teams"


def test_orchestrator_mode_switch():
    o = MeetingOrchestrator()
    r = o.set_mode("silencioso")
    assert r["proactive"] is False


def test_orchestrator_stop():
    o = MeetingOrchestrator()
    o.start("teams")
    o.process_utterance("Alice", "Let's start")
    r = o.stop()
    assert r["transcript_lines"] == 1
    assert "notes_for_digest" in r


def test_orchestrator_same_brain():
    """Verify both channels use same participant/guardian/roles."""
    o = MeetingOrchestrator()
    o.roles.set_role("test", "pm")
    o.start("zeroclaw")
    assert o.roles.get_role("test") == "pm"
    o.stop()
    o.start("teams")
    assert o.roles.get_role("test") == "pm", "roles persist across channels"


def test_file_sizes():
    for f in ['teams_client.py', 'meeting_orchestrator.py']:
        path = os.path.join(os.path.dirname(__file__), '..', 'host', f)
        with open(path) as fh:
            assert len(fh.readlines()) <= 150, f"{f} over 150 lines"


if __name__ == "__main__":
    print("Teams Integration + Orchestrator Tests")
    print("─" * 50)
    test("Teams not configured without env", test_teams_not_configured)
    test("Teams connect fails gracefully", test_teams_connect_fails_gracefully)
    test("Teams status returns dict", test_teams_status)
    test("Orchestrator starts ZeroClaw", test_orchestrator_start_zeroclaw)
    test("Orchestrator starts Teams", test_orchestrator_start_teams)
    test("Orchestrator detects risk in utterance", test_orchestrator_process_utterance)
    test("Orchestrator handles query with roles", test_orchestrator_handle_query)
    test("Orchestrator mode switch", test_orchestrator_mode_switch)
    test("Orchestrator stop returns summary", test_orchestrator_stop)
    test("Same brain across channels", test_orchestrator_same_brain)
    test("File sizes ≤150", test_file_sizes)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
