#!/usr/bin/env python3
"""Tests for speaker role permissions — deterministic access control."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.speaker_roles import SpeakerRoleManager, NEVER_VOICE

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


def test_default_role_is_observer():
    m = SpeakerRoleManager()
    assert m.get_role("stranger") == "observer"


def test_pm_can_access_everything():
    m = SpeakerRoleManager()
    m.set_role("monica", "pm")
    assert m.can_access("monica", "sprint_items")
    assert m.can_access("monica", "security")
    assert m.can_access("monica", "debt")
    assert m.can_access("monica", "architecture")


def test_developer_cannot_access_security():
    m = SpeakerRoleManager()
    m.set_role("alice", "developer")
    assert m.can_access("alice", "sprint_items")
    assert not m.can_access("alice", "security")
    assert not m.can_access("alice", "debt")


def test_external_gets_nothing():
    m = SpeakerRoleManager()
    m.set_role("vendor", "external")
    assert not m.can_access("vendor", "sprint_items")
    assert not m.can_access("vendor", "blockers")
    assert m.can_access("vendor", "public_info")


def test_nobody_gets_never_voice():
    m = SpeakerRoleManager()
    m.set_role("boss", "pm")
    for topic in NEVER_VOICE:
        assert not m.can_access("boss", topic), f"PM should not voice {topic}"


def test_filter_strips_unauthorized():
    m = SpeakerRoleManager()
    m.set_role("dev", "developer")
    data = {
        "sprint_items": ["AB#1", "AB#2"],
        "security": "SQL injection in auth",
        "debt": "High coupling in service layer",
    }
    filtered = m.filter_response("dev", data)
    assert "sprint_items" in filtered
    assert "security" not in filtered
    assert "debt" not in filtered


def test_filter_never_voice_even_for_pm():
    m = SpeakerRoleManager()
    m.set_role("pm", "pm")
    data = {
        "sprint_summary": "Sprint at 85%",
        "personal_evaluations": "Carlos: needs improvement",
        "credentials": "PAT=abc123",
    }
    filtered = m.filter_response("pm", data)
    assert "sprint_summary" in filtered
    assert "personal_evaluations" not in filtered
    assert "credentials" not in filtered


def test_set_invalid_role():
    m = SpeakerRoleManager()
    r = m.set_role("test", "superadmin")
    assert not r["ok"]


def test_case_insensitive():
    m = SpeakerRoleManager()
    m.set_role("Carlos", "tech_lead")
    assert m.get_role("carlos") == "tech_lead"
    assert m.get_role("CARLOS") == "tech_lead"


def test_file_size():
    path = os.path.join(os.path.dirname(__file__), '..', 'host',
                        'speaker_roles.py')
    with open(path) as f:
        assert len(f.readlines()) <= 150


if __name__ == "__main__":
    print("Speaker Roles Permission Tests")
    print("─" * 45)
    test("Default role is observer", test_default_role_is_observer)
    test("PM can access everything", test_pm_can_access_everything)
    test("Developer cannot access security", test_developer_cannot_access_security)
    test("External gets nothing sensitive", test_external_gets_nothing)
    test("NEVER_VOICE blocked for all", test_nobody_gets_never_voice)
    test("Filter strips unauthorized topics", test_filter_strips_unauthorized)
    test("NEVER_VOICE stripped even for PM", test_filter_never_voice_even_for_pm)
    test("Invalid role rejected", test_set_invalid_role)
    test("Case insensitive lookup", test_case_insensitive)
    test("File ≤150 lines", test_file_size)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
