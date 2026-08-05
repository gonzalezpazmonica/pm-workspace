"""Tests for TaskStore persistence (SE-304)."""

import json
import tempfile
import os
import pytest
from pathlib import Path

from automations.models import ScheduledTask, TaskRun, Schedule
from automations.store import TaskStore


@pytest.fixture
def store():
    with tempfile.TemporaryDirectory() as td:
        yield TaskStore(data_dir=td)


@pytest.fixture
def sample_task():
    return ScheduledTask(
        id="t1",
        name="test-task",
        description="Test description",
        instructions="Do something",
        schedule=Schedule(kind="cron", cron="0 9 * * 1-5"),
        created_at="2026-08-01T00:00:00Z",
        updated_at="2026-08-01T00:00:00Z",
    )


class TestTaskStoreCrud:
    def test_empty_store(self, store):
        assert store.all() == []

    def test_save_and_get(self, store, sample_task):
        store.save(sample_task)
        tasks = store.all()
        assert len(tasks) == 1
        assert tasks[0].id == "t1"
        assert tasks[0].name == "test-task"

    def test_get_by_id(self, store, sample_task):
        store.save(sample_task)
        t = store.get("t1")
        assert t is not None
        assert t.name == "test-task"

    def test_get_missing(self, store):
        assert store.get("nonexistent") is None

    def test_save_updates_existing(self, store, sample_task):
        store.save(sample_task)
        sample_task.name = "renamed"
        store.save(sample_task)
        tasks = store.all()
        assert len(tasks) == 1
        assert tasks[0].name == "renamed"

    def test_delete(self, store, sample_task):
        store.save(sample_task)
        assert store.delete("t1") is True
        assert store.all() == []

    def test_delete_missing(self, store):
        assert store.delete("nonexistent") is False

    def test_multiple_tasks(self, store):
        for i in range(5):
            t = ScheduledTask(
                id=f"t{i}",
                name=f"task-{i}",
                description=f"Task {i}",
                instructions=f"Do {i}",
                schedule=Schedule(kind="cron", cron="0 * * * *"),
            )
            store.save(t)
        assert len(store.all()) == 5

    def test_computes_next_run_on_save(self, store, sample_task):
        store.save(sample_task)
        t = store.get("t1")
        assert t is not None
        assert t.next_run is not None
        assert "T" in t.next_run

    def test_created_at_set_on_first_save(self, store):
        t = ScheduledTask(
            id="t2",
            name="no-created-at",
            description="",
            instructions="",
            schedule=Schedule(kind="cron", cron="* * * * *"),
        )
        store.save(t)
        loaded = store.get("t2")
        assert loaded is not None
        assert loaded.created_at != ""


class TestTaskStoreRuns:
    def test_add_run(self, store, sample_task):
        store.save(sample_task)
        run = TaskRun(
            id="r1",
            task_id="t1",
            status="completed",
            started_at="2026-08-01T09:00:00Z",
            finished_at="2026-08-01T09:05:00Z",
        )
        store.add_run(run)
        loaded = store.get_run("t1", "r1")
        assert loaded is not None
        assert loaded.status == "completed"

    def test_list_runs(self, store, sample_task):
        store.save(sample_task)
        for i in range(5):
            store.add_run(TaskRun(
                id=f"r{i}",
                task_id="t1",
                status="completed",
                started_at=f"2026-08-0{i+1}T09:00:00Z",
            ))
        runs = store.list_runs("t1")
        assert len(runs) == 5

    def test_list_runs_respects_limit(self, store, sample_task):
        store.save(sample_task)
        for i in range(10):
            store.add_run(TaskRun(
                id=f"r{i}",
                task_id="t1",
                status="completed",
                started_at=f"2026-08-{i+1:02d}T09:00:00Z",
            ))
        runs = store.list_runs("t1", limit=3)
        assert len(runs) == 3

    def test_get_run_missing(self, store):
        assert store.get_run("t1", "r1") is None

    def test_update_run(self, store, sample_task):
        store.save(sample_task)
        run = TaskRun(id="r1", task_id="t1", status="running", started_at="now")
        store.add_run(run)
        run.status = "completed"
        store.update_run(run)
        loaded = store.get_run("t1", "r1")
        assert loaded is not None
        assert loaded.status == "completed"


class TestDueFiltering:
    def test_enabled_filter(self, store):
        t1 = ScheduledTask(id="t1", name="enabled", description="", instructions="",
                           schedule=Schedule(kind="cron", cron="* * * * *"), enabled=True)
        t2 = ScheduledTask(id="t2", name="disabled", description="", instructions="",
                           schedule=Schedule(kind="cron", cron="* * * * *"), enabled=False)
        store.save(t1)
        store.save(t2)
        assert len(store.enabled()) == 1
        assert store.enabled()[0].id == "t1"

    def test_due_tasks(self, store):
        t = ScheduledTask(id="t1", name="due-task", description="", instructions="",
                          schedule=Schedule(kind="cron", cron="* * * * *"))
        t.next_run = "2020-01-01T00:00:00Z"
        store._save_tasks([t.to_dict()])
        due = store.due(now="2026-08-04T00:00:00Z")
        assert len(due) == 1
        assert due[0].id == "t1"

    def test_not_due_yet(self, store):
        t = ScheduledTask(id="t1", name="future-task", description="", instructions="",
                          schedule=Schedule(kind="cron", cron="* * * * *"))
        t.next_run = "2099-01-01T00:00:00Z"
        store._save_tasks([t.to_dict()])
        due = store.due(now="2026-08-04T00:00:00Z")
        assert len(due) == 0


class TestPersistenceAcrossInstances:
    def test_data_survives_new_instance(self, store, sample_task):
        path = store.data_dir
        store.save(sample_task)
        store2 = TaskStore(data_dir=str(path))
        assert len(store2.all()) == 1
        assert store2.get("t1").name == "test-task"
