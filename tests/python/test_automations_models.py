"""Tests for automation models (SE-304)."""

import json
import pytest
from automations.models import ScheduledTask, TaskRun, Schedule, now_iso


class TestSchedule:
    def test_cron_schedule(self):
        s = Schedule(kind="cron", cron="0 9 * * 1-5")
        assert s.kind == "cron"
        assert s.cron == "0 9 * * 1-5"
        assert s.timezone == "local"

    def test_once_schedule(self):
        s = Schedule(kind="once", fire_at="2026-08-15T10:00:00Z")
        assert s.kind == "once"
        assert s.cron is None
        assert s.fire_at == "2026-08-15T10:00:00Z"

    def test_default_timezone(self):
        s = Schedule(kind="cron", cron="* * * * *")
        assert s.timezone == "local"

    def test_roundtrip_dict(self):
        s = Schedule(kind="cron", cron="0 9 * * 1-5")
        d = s.to_dict()
        s2 = Schedule.from_dict(d)
        assert s2.kind == s.kind
        assert s2.cron == s.cron
        assert s2.timezone == s.timezone

    def test_roundtrip_once(self):
        s = Schedule(kind="once", fire_at="2026-08-15T10:00:00Z")
        d = s.to_dict()
        s2 = Schedule.from_dict(d)
        assert s2.kind == "once"
        assert s2.fire_at == "2026-08-15T10:00:00Z"


class TestScheduledTask:
    def test_defaults(self):
        t = ScheduledTask(
            id="t1",
            name="test-task",
            description="A test task",
            instructions="Do something useful",
            schedule=Schedule(kind="cron", cron="0 * * * *"),
        )
        assert t.enabled is True
        assert t.always_allowed_tools == []
        assert t.run_count == 0
        assert t.last_run is None
        assert t.last_status is None
        assert t.skill is None
        assert t.agent is None
        assert t.workspace == ""

    def test_roundtrip_dict(self):
        t = ScheduledTask(
            id="t1",
            name="test-task",
            description="Test description",
            instructions="Do something",
            schedule=Schedule(kind="cron", cron="0 9 * * *"),
            skill="my-skill",
            agent="my-agent",
            workspace="/tmp",
            enabled=False,
            always_allowed_tools=["read", "write"],
            run_count=5,
            last_run="2026-08-01T09:00:00Z",
            last_status="completed",
            next_run="2026-08-02T09:00:00Z",
            created_at="2026-08-01T00:00:00Z",
            updated_at="2026-08-01T09:00:00Z",
        )
        d = t.to_dict()
        t2 = ScheduledTask.from_dict(d)
        assert t2.id == t.id
        assert t2.name == t.name
        assert t2.enabled is False
        assert t2.run_count == 5
        assert t2.skill == "my-skill"
        assert t2.agent == "my-agent"
        assert t2.workspace == "/tmp"
        assert t2.always_allowed_tools == ["read", "write"]
        assert t2.schedule.kind == "cron"
        assert t2.schedule.cron == "0 9 * * *"


class TestTaskRun:
    def test_defaults(self):
        r = TaskRun(
            id="r1",
            task_id="t1",
            status="running",
            started_at="2026-08-01T09:00:00Z",
        )
        assert r.status == "running"
        assert r.trigger == "schedule"
        assert r.error is None
        assert r.output is None

    def test_roundtrip_dict(self):
        r = TaskRun(
            id="r1",
            task_id="t1",
            status="completed",
            started_at="2026-08-01T09:00:00Z",
            finished_at="2026-08-01T09:05:00Z",
            trigger="manual",
            output="output/automations/t1/r1.md",
        )
        d = r.to_dict()
        r2 = TaskRun.from_dict(d)
        assert r2.id == r.id
        assert r2.task_id == r.task_id
        assert r2.status == "completed"
        assert r2.trigger == "manual"
        assert r2.output == "output/automations/t1/r1.md"


class TestNowIso:
    def test_returns_string(self):
        assert isinstance(now_iso(), str)

    def test_contains_t(self):
        assert "T" in now_iso()
