#!/usr/bin/env python3
"""Tests for meeting participant + context guardian."""
import sys
import os
import time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.meeting_participant import MeetingParticipant
from host.context_guardian import ContextGuardian

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


def test_window_not_open_during_speech():
    p = MeetingParticipant()
    p.add_note("risk", "Critical risk", severity="critical")
    p.on_speech_detected()  # someone is talking
    result = p.on_silence()
    assert result is None, "should not intervene during speech"


def test_window_opens_after_silence():
    p = MeetingParticipant()
    p.add_note("risk", "Critical risk", severity="critical")
    p.last_speech_end = time.time() - 5  # 5s ago
    p.last_intervention = 0  # never intervened
    result = p.on_silence()
    assert result is not None, "should intervene after 3s silence"
    assert result["type"] == "proactive"


def test_max_interventions_respected():
    p = MeetingParticipant({"max_interventions": 1})
    p.add_note("risk", "Risk 1", severity="critical")
    p.add_note("risk", "Risk 2", severity="critical")
    p.last_speech_end = time.time() - 5
    r1 = p.on_silence()
    assert r1 is not None
    p.last_speech_end = time.time() - 5
    r2 = p.on_silence()
    assert r2 is None, "should stop after max interventions"


def test_cooldown_respected():
    p = MeetingParticipant({"cooldown_minutes": 10})
    p.add_note("risk", "Risk", severity="critical")
    p.last_speech_end = time.time() - 5
    p.last_intervention = time.time() - 60  # 1 min ago (< 10 min cooldown)
    p.interventions = 0  # reset count to isolate cooldown test
    r = p.on_silence()
    assert r is None, "should respect cooldown"


def test_mode_switch():
    p = MeetingParticipant()
    r = p.set_mode("silencioso")
    assert r["proactive"] is False
    r = p.set_mode("activo")
    assert r["proactive"] is True


def test_query_response():
    p = MeetingParticipant()
    p.add_note("info", "Sprint velocity is 43 story points")
    r = p.on_query("what is the velocity?")
    assert r["type"] == "query_response"


def test_non_critical_not_queued():
    p = MeetingParticipant()
    p.add_note("info", "Minor observation", severity="info")
    assert len(p.pending_critical) == 0


def test_stop_returns_summary():
    p = MeetingParticipant()
    p.add_note("risk", "Risk", severity="critical")
    r = p.stop()
    assert "total_notes" in r
    assert r["total_notes"] == 1


def test_guardian_detects_action_item():
    g = ContextGuardian()
    obs = g.check_transcript_line("Carlos", "Yo me encargo del deploy")
    types = [o["type"] for o in obs]
    assert "action_item" in types


def test_guardian_detects_risk():
    g = ContextGuardian()
    obs = g.check_transcript_line("Maria", "Esto está bloqueado desde ayer")
    types = [o["type"] for o in obs]
    assert "risk" in types


def test_guardian_detects_question():
    g = ContextGuardian()
    obs = g.check_transcript_line("Pedro", "¿Cuándo termina el sprint?")
    types = [o["type"] for o in obs]
    assert "question" in types


def test_file_sizes():
    for f in ['meeting_participant.py', 'context_guardian.py']:
        path = os.path.join(os.path.dirname(__file__), '..', 'host', f)
        with open(path) as fh:
            assert len(fh.readlines()) <= 150, f"{f} over 150 lines"


if __name__ == "__main__":
    print("Meeting Participant + Context Guardian Tests")
    print("─" * 50)
    test("No intervention during speech", test_window_not_open_during_speech)
    test("Intervention after 3s silence", test_window_opens_after_silence)
    test("Max interventions respected", test_max_interventions_respected)
    test("Cooldown respected", test_cooldown_respected)
    test("Mode switch works", test_mode_switch)
    test("Query response", test_query_response)
    test("Non-critical not queued", test_non_critical_not_queued)
    test("Stop returns summary", test_stop_returns_summary)
    test("Guardian: action item", test_guardian_detects_action_item)
    test("Guardian: risk detection", test_guardian_detects_risk)
    test("Guardian: question detection", test_guardian_detects_question)
    test("File sizes ≤150", test_file_sizes)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
