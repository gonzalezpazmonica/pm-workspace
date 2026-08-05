"""Tests for AutomationScheduler (SE-304)."""

import asyncio
import tempfile
import pytest

from automations.models import ScheduledTask, TaskRun, Schedule, now_iso
from automations.store import TaskStore
from automations.scheduler import AutomationScheduler


@pytest.fixture
def store():
    with tempfile.TemporaryDirectory() as td:
        yield TaskStore(data_dir=td)


@pytest.fixture
def due_task(store):
    t = ScheduledTask(
        id="t1",
        name="due-task",
        description="Test due task",
        instructions="Do something",
        schedule=Schedule(kind="cron", cron="* * * * *"),
        enabled=True,
    )
    t.next_run = "2020-01-01T00:00:00Z"
    store._save_tasks([t.to_dict()])
    return t


@pytest.fixture
def future_task(store):
    t = ScheduledTask(
        id="t2",
        name="future-task",
        description="Test future task",
        instructions="Do something later",
        schedule=Schedule(kind="cron", cron="* * * * *"),
        enabled=True,
    )
    t.next_run = "2099-01-01T00:00:00Z"
    store._save_tasks([t.to_dict()])
    return t


@pytest.fixture
def disabled_task(store):
    t = ScheduledTask(
        id="t3",
        name="disabled-task",
        description="Test disabled task",
        instructions="Should not run",
        schedule=Schedule(kind="cron", cron="* * * * *"),
        enabled=False,
    )
    t.next_run = "2020-01-01T00:00:00Z"
    store._save_tasks([t.to_dict()])
    return t


async def _noop_runner(task, trigger):
    return TaskRun(
        id="test-run",
        task_id=task.id,
        status="completed",
        started_at=now_iso(),
        finished_at=now_iso(),
        trigger=trigger,
    )


async def _slow_runner(task, trigger):
    await asyncio.sleep(0.1)
    return TaskRun(
        id="test-slow",
        task_id=task.id,
        status="completed",
        started_at=now_iso(),
        finished_at=now_iso(),
        trigger=trigger,
    )


async def _failing_runner(task, trigger):
    raise RuntimeError("deliberate failure")


class TestSchedulerLifecycle:
    @pytest.mark.asyncio
    async def test_start_stop(self, store):
        scheduler = AutomationScheduler(store, _noop_runner, tick_seconds=0.1)
        assert not scheduler.running
        await scheduler.start()
        assert scheduler.running
        await asyncio.sleep(0.01)
        await scheduler.stop()
        assert not scheduler.running

    @pytest.mark.asyncio
    async def test_start_twice_idempotent(self, store):
        scheduler = AutomationScheduler(store, _noop_runner, tick_seconds=0.1)
        await scheduler.start()
        await scheduler.start()
        await scheduler.stop()

    @pytest.mark.asyncio
    async def test_runner_is_called(self, store, due_task):
        called = []

        async def tracking_runner(task, trigger):
            called.append((task.id, trigger))
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, tracking_runner, tick_seconds=0.05)
        await scheduler.start()
        await asyncio.sleep(0.15)
        await scheduler.stop()
        assert len(called) >= 1


class TestCatchUp:
    @pytest.mark.asyncio
    async def test_catches_up_due_tasks(self, store, due_task):
        executed = []

        async def catcher(task, trigger):
            executed.append(trigger)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, catcher, tick_seconds=0.1)
        await scheduler.start()
        await asyncio.sleep(0.15)
        await scheduler.stop()
        assert "catchup" in executed


class TestSkipOnOverlap:
    @pytest.mark.asyncio
    async def test_skips_running_task(self, store, due_task):
        runs = []

        async def overlap_runner(task, trigger):
            runs.append(trigger)
            if trigger == "schedule":
                await asyncio.sleep(0.2)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, overlap_runner, tick_seconds=0.05)
        await scheduler.start()
        await asyncio.sleep(0.25)
        await scheduler.stop()
        catchup_count = sum(1 for r in runs if r == "catchup")
        schedule_count = sum(1 for r in runs if r == "schedule")
        assert catchup_count == 1
        assert schedule_count >= 1


class TestDisabledTasks:
    @pytest.mark.asyncio
    async def test_disabled_tasks_dont_run(self, store, disabled_task):
        executed = []

        async def tracker(task, trigger):
            executed.append(task.id)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, tracker, tick_seconds=0.1)
        await scheduler.start()
        await asyncio.sleep(0.15)
        await scheduler.stop()
        assert "t3" not in executed


class TestFutureTasks:
    @pytest.mark.asyncio
    async def test_future_tasks_dont_run(self, store, future_task):
        executed = []

        async def tracker(task, trigger):
            executed.append(task.id)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, tracker, tick_seconds=0.1)
        await scheduler.start()
        await asyncio.sleep(0.15)
        await scheduler.stop()
        assert "t2" not in executed


class TestErrorIsolation:
    @pytest.mark.asyncio
    async def test_failing_task_doesnt_stop_scheduler(self, store, due_task):
        runs = []

        async def mixed_runner(task, trigger):
            if trigger == "catchup":
                raise RuntimeError("boom")
            runs.append(trigger)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, mixed_runner, tick_seconds=0.05)
        await scheduler.start()
        await asyncio.sleep(0.15)
        await scheduler.stop()
        assert "schedule" in runs


class TestConcurrentLimit:
    @pytest.mark.asyncio
    async def test_respects_max_concurrent(self, store):
        for i in range(5):
            t = ScheduledTask(
                id=f"tc{i}",
                name=f"concurrent-{i}",
                description="",
                instructions="",
                schedule=Schedule(kind="cron", cron="* * * * *"),
                enabled=True,
            )
            t.next_run = "2020-01-01T00:00:00Z"
            store._save_tasks([t.to_dict()])

        running_at_once = {"max": 0, "current": 0}

        async def concurrent_runner(task, trigger):
            running_at_once["current"] += 1
            running_at_once["max"] = max(running_at_once["max"], running_at_once["current"])
            await asyncio.sleep(0.05)
            running_at_once["current"] -= 1
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, concurrent_runner, tick_seconds=0.05, max_concurrent=2)
        await scheduler.start()
        await asyncio.sleep(0.2)
        await scheduler.stop()
        assert running_at_once["max"] <= 2


class TestRunNow:
    @pytest.mark.asyncio
    async def test_manual_run(self, store, due_task):
        executed = []

        async def tracker(task, trigger):
            executed.append(trigger)
            return await _noop_runner(task, trigger)

        scheduler = AutomationScheduler(store, tracker)
        result = await scheduler.run_now("t1")
        assert result is not None
        assert "manual" in executed

    @pytest.mark.asyncio
    async def test_run_now_missing_task(self, store):
        scheduler = AutomationScheduler(store, _noop_runner)
        result = await scheduler.run_now("nonexistent")
        assert result is None
