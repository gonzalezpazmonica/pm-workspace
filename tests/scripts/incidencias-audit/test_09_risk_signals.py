"""Tests for 09_risk_signals.py — the 8 risk signal rules."""
from __future__ import annotations

import importlib.util
from datetime import datetime, timezone, timedelta
from pathlib import Path

import pytest


def _load():
    here = Path(__file__).parent.parent.parent.parent
    mod_path = here / "scripts" / "incidencias-audit" / "09_risk_signals.py"
    if not mod_path.exists():
        pytest.skip(f"module not yet implemented: {mod_path}")
    spec = importlib.util.spec_from_file_location("risk_signals", mod_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def rs():
    return _load()


# A reference "now" for tests — RN: independent of system clock
NOW = "2026-04-30"


def _incident(**kwargs):
    """Build an enriched incident dict with sensible defaults."""
    base = {
        "id": 100,
        "title": "test incident",
        "state": "Implementing Solution",
        "priority": 2,
        "assignedTo": "someone",
        "iterationPath": "Project Beacon\\Product Development\\Sprint 26",
        "createdDate": "2026-04-01",
        "changedDate": "2026-04-29",
        "tasks": [],
        "bugs": [],
        "treatment_phase": "Pendiente análisis",
    }
    base.update(kwargs)
    return base


class TestBugsDoneIncidentOpen:
    def test_fires_when_all_bugs_done(self, rs):
        inc = _incident(
            bugs=[
                {"id": 200, "state": "Done"},
                {"id": 201, "state": "Done"},
            ],
            treatment_phase="Analizadas con BUG Done",
        )
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "BUGS_DONE_INCIDENT_OPEN" in codes

    def test_no_fire_when_one_bug_open(self, rs):
        inc = _incident(bugs=[{"id": 200, "state": "Done"}, {"id": 201, "state": "Committed"}])
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "BUGS_DONE_INCIDENT_OPEN" not in codes

    def test_no_fire_when_no_bugs(self, rs):
        inc = _incident(bugs=[])
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "BUGS_DONE_INCIDENT_OPEN" not in codes


class TestDiscardedNotClosed:
    def test_fires_when_task_done_no_bug(self, rs):
        inc = _incident(
            tasks=[{"id": 300, "state": "Done"}],
            bugs=[],
            treatment_phase="Descartadas (task cerrado sin BUG)",
        )
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "DISCARDED_NOT_CLOSED" in codes


class TestCriticalStalled:
    def test_fires_for_p1_stalled(self, rs):
        inc = _incident(priority=1, changedDate="2026-04-01")  # 29 days ago
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "CRITICAL_STALLED" in codes

    def test_no_fire_for_p2(self, rs):
        inc = _incident(priority=2, changedDate="2026-04-01")
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "CRITICAL_STALLED" not in codes

    def test_no_fire_when_recent(self, rs):
        inc = _incident(priority=1, changedDate="2026-04-25")  # 5 days ago
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "CRITICAL_STALLED" not in codes


class TestNoOwnerHighPrio:
    def test_fires_when_unassigned_p1(self, rs):
        inc = _incident(assignedTo=None, priority=1)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_OWNER_HIGH_PRIO" in codes

    def test_fires_when_unassigned_p2(self, rs):
        inc = _incident(assignedTo=None, priority=2)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_OWNER_HIGH_PRIO" in codes

    def test_no_fire_for_p3(self, rs):
        inc = _incident(assignedTo=None, priority=3)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_OWNER_HIGH_PRIO" not in codes

    def test_no_fire_when_assigned(self, rs):
        inc = _incident(assignedTo="alice", priority=1)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_OWNER_HIGH_PRIO" not in codes


class TestLongStaleOpen:
    def test_fires_when_old(self, rs):
        inc = _incident(createdDate="2025-12-01")  # ~150 days ago
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "LONG_STALE_OPEN" in codes

    def test_no_fire_when_recent(self, rs):
        inc = _incident(createdDate="2026-04-15")  # 15 days ago
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "LONG_STALE_OPEN" not in codes


class TestNoTractionBug:
    def test_fires_when_bug_new_old(self, rs):
        inc = _incident(bugs=[{"id": 200, "state": "New", "changedDate": "2026-04-01"}])
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_TRACTION_BUG" in codes

    def test_no_fire_when_bug_committed(self, rs):
        inc = _incident(bugs=[{"id": 200, "state": "Committed", "changedDate": "2026-04-01"}])
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "NO_TRACTION_BUG" not in codes


class TestHighPrioNoSprint:
    def test_fires_when_p1_no_sprint(self, rs):
        inc = _incident(priority=1, iterationPath=None)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "HIGH_PRIO_NO_SPRINT" in codes

    def test_fires_when_iteration_is_product_dev(self, rs):
        inc = _incident(priority=2, iterationPath="Project Beacon\\Product Development")
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "HIGH_PRIO_NO_SPRINT" in codes

    def test_no_fire_when_p3(self, rs):
        inc = _incident(priority=3, iterationPath=None)
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "HIGH_PRIO_NO_SPRINT" not in codes

    def test_no_fire_when_in_sprint(self, rs):
        inc = _incident(priority=1, iterationPath="Project Beacon\\Product Development\\Sprint 26")
        sigs = rs.evaluate_incident(inc, now=NOW)
        codes = [s["rule_code"] for s in sigs]
        assert "HIGH_PRIO_NO_SPRINT" not in codes


class TestSeverityOrder:
    def test_severities_assigned(self, rs):
        # Each rule has a severity 1, 2, or 3
        for code, sev in rs.RULE_SEVERITY.items():
            assert sev in (1, 2, 3), f"Rule {code} has invalid severity {sev}"

    def test_eight_rules_total(self, rs):
        assert len(rs.RULE_SEVERITY) == 8

    def test_critical_rules_severity_1(self, rs):
        assert rs.RULE_SEVERITY["CRITICAL_STALLED"] == 1
        assert rs.RULE_SEVERITY["NO_OWNER_HIGH_PRIO"] == 1


class TestAggregate:
    def test_aggregate_sorts_by_severity_then_id(self, rs):
        incidents = [
            _incident(id=200, priority=1, assignedTo=None),  # NO_OWNER_HIGH_PRIO (sev 1)
            _incident(id=100, priority=1, assignedTo=None),  # NO_OWNER_HIGH_PRIO (sev 1)
            _incident(id=300, createdDate="2025-01-01"),     # LONG_STALE_OPEN (sev 3)
        ]
        for inc in incidents:
            inc["risk_signals"] = []
        all_sigs = rs.aggregate(incidents, now=NOW)
        # Sorted by (severity asc, incident_id asc)
        sevs = [s["severity"] for s in all_sigs]
        assert sevs == sorted(sevs)
        # Within severity 1, IDs ascending
        sev1 = [s for s in all_sigs if s["severity"] == 1]
        assert [s["incident_id"] for s in sev1] == sorted(s["incident_id"] for s in sev1)

    def test_aggregate_count_matches_total_signals(self, rs):
        incidents = [
            _incident(id=1, priority=1, assignedTo=None, createdDate="2025-01-01"),
        ]
        all_sigs = rs.aggregate(incidents, now=NOW)
        # This incident triggers: NO_OWNER_HIGH_PRIO + LONG_STALE_OPEN + HIGH_PRIO_NO_SPRINT (no — has sprint by default)
        # Actually default has sprint=Sprint 26, so HIGH_PRIO_NO_SPRINT does NOT fire
        # CRITICAL_STALLED requires changedDate > 14d. Default changedDate=2026-04-29 (1 day) - no.
        # Fires: NO_OWNER_HIGH_PRIO + LONG_STALE_OPEN = 2
        assert len(all_sigs) == 2
