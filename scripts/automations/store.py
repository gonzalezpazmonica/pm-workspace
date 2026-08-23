"""Task Store — JSON persistence for scheduled tasks and runs.

.savia/automations/
  tasks.json            — array of ScheduledTask
  config.yaml           — global config (tick_seconds, max_concurrent)
  runs/{task_id}/
    {run_id}.json       — individual run records
"""

from __future__ import annotations

import json
import os
import uuid
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List

from .models import ScheduledTask, TaskRun, Schedule, now_iso


class TaskStore:
    def __init__(self, data_dir: str = ".savia/automations") -> None:
        self.data_dir = Path(data_dir)
        self.tasks_file = self.data_dir / "tasks.json"
        self.runs_dir = self.data_dir / "runs"
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.runs_dir.mkdir(parents=True, exist_ok=True)
        if not self.tasks_file.exists():
            self.tasks_file.write_text("[]", encoding="utf-8")

    def _load_tasks(self) -> list[dict]:
        try:
            raw = self.tasks_file.read_text(encoding="utf-8")
            data = json.loads(raw)
            return data if isinstance(data, list) else []
        except (json.JSONDecodeError, FileNotFoundError):
            return []

    def _save_tasks(self, tasks: list[dict]) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        tmp = self.tasks_file.with_name(f".tasks.json.{os.getpid()}.tmp")
        tmp.write_text(
            json.dumps(tasks, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        tmp.replace(self.tasks_file)

    def all(self) -> List[ScheduledTask]:
        return [ScheduledTask.from_dict(d) for d in self._load_tasks()]

    def enabled(self) -> List[ScheduledTask]:
        return [t for t in self.all() if t.enabled]

    def due(self, now: Optional[str] = None) -> List[ScheduledTask]:
        ref = now or now_iso()
        result = []
        for task in self.enabled():
            if task.next_run and task.next_run <= ref:
                result.append(task)
        return result

    def get(self, task_id: str) -> Optional[ScheduledTask]:
        for t in self.all():
            if t.id == task_id:
                return t
        return None

    def save(self, task: ScheduledTask) -> None:
        tasks = self._load_tasks()
        task.updated_at = now_iso()
        if not task.created_at:
            task.created_at = task.updated_at
        task.next_run = self._compute_next_run(task.schedule)
        d = task.to_dict()
        for i, existing in enumerate(tasks):
            if existing.get("id") == task.id:
                tasks[i] = d
                break
        else:
            tasks.append(d)
        self._save_tasks(tasks)

    def delete(self, task_id: str) -> bool:
        tasks = self._load_tasks()
        new_tasks = [t for t in tasks if t.get("id") != task_id]
        if len(new_tasks) == len(tasks):
            return False
        self._save_tasks(new_tasks)
        return True

    def add_run(self, run: TaskRun) -> None:
        run_dir = self.runs_dir / run.task_id
        run_dir.mkdir(parents=True, exist_ok=True)
        run_file = run_dir / f"{run.id}.json"
        run_file.write_text(
            json.dumps(run.to_dict(), indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    def update_run(self, run: TaskRun) -> None:
        self.add_run(run)

    def get_run(self, task_id: str, run_id: str) -> Optional[TaskRun]:
        run_file = self.runs_dir / task_id / f"{run_id}.json"
        if not run_file.exists():
            return None
        try:
            return TaskRun.from_dict(
                json.loads(run_file.read_text(encoding="utf-8"))
            )
        except (json.JSONDecodeError, KeyError):
            return None

    def list_runs(self, task_id: str, limit: int = 100) -> List[TaskRun]:
        run_dir = self.runs_dir / task_id
        if not run_dir.is_dir():
            return []
        runs = []
        for f in sorted(run_dir.iterdir(), reverse=True):
            if not f.name.endswith(".json"):
                continue
            try:
                runs.append(
                    TaskRun.from_dict(
                        json.loads(f.read_text(encoding="utf-8"))
                    )
                )
            except (json.JSONDecodeError, KeyError):
                continue
        return runs[:limit]

    _HUMAN_DAYS = {
        "sun": 0, "sunday": 0, "mon": 1, "monday": 1, "tue": 2, "tuesday": 2,
        "wed": 3, "wednesday": 3, "thu": 4, "thursday": 4, "fri": 5, "friday": 5,
        "sat": 6, "saturday": 6,
    }

    def _normalize_cron(self, cron: str) -> Optional[str]:
        """Normalize human cron notation to 5-field cron.

        Supported human forms (case-insensitive):
          daily HH:MM            → MM HH * * *
          daily                 → 0 8 * * *   (default 08:00)
          weekly DOW HH:MM      → MM HH * * DOW
          weekly HH:MM          → 0 HH * * *
        Any already-5-field cron passes through unchanged.
        Returns None if unparseable.
        """
        if not cron:
            return None
        raw = cron.strip().lower()
        parts = raw.split()
        # Already standard 5-field? Pass through.
        if len(parts) == 5 and all(
            _tok in "*0123456789,/-" for _tok in "".join(parts)
        ):
            return " ".join(parts)
        try:
            if parts and parts[0] == "daily":
                if len(parts) >= 2 and ":" in parts[1]:
                    hh, mm = parts[1].split(":")
                    return f"{int(mm)} {int(hh)} * * *"
                return "0 8 * * *"  # daily default 08:00
            if parts and parts[0] == "weekly":
                if len(parts) >= 2 and parts[1] in self._HUMAN_DAYS:
                    dow = self._HUMAN_DAYS[parts[1]]
                    if len(parts) >= 3 and ":" in parts[2]:
                        hh, mm = parts[2].split(":")
                        return f"{int(mm)} {int(hh)} * * {dow}"
                    return f"0 8 * * {dow}"
                if len(parts) >= 2 and ":" in parts[1]:
                    hh, mm = parts[1].split(":")
                    return f"{int(mm)} {int(hh)} * * *"
                return "0 8 * * *"
        except (ValueError, IndexError):
            return None
        return None

    def _compute_next_run(self, schedule: Schedule) -> Optional[str]:
        if schedule.kind == "once":
            return schedule.fire_at
        normalized = self._normalize_cron(schedule.cron) if schedule.cron else None
        if not normalized:
            return None

        parts = normalized.split()
        if len(parts) != 5:
            return None

        try:
            minute, hour, dom, month, dow = parts
            now = datetime.now(timezone.utc)
            candidates = []
            for day_offset in range(8):
                candidate = now.replace(
                    hour=int(hour),
                    minute=int(minute),
                    second=0,
                    microsecond=0,
                )
                from datetime import timedelta
                candidate = candidate + timedelta(days=day_offset)
                if candidate <= now:
                    continue
                if dom != "*":
                    try:
                        if candidate.day != int(dom):
                            continue
                    except ValueError:
                        pass
                if month != "*":
                    try:
                        if candidate.month != int(month):
                            continue
                    except ValueError:
                        pass
                if dow != "*":
                    try:
                        if candidate.weekday() != int(dow) % 7:
                            continue
                    except ValueError:
                        pass
                candidates.append(candidate)
            if candidates:
                return candidates[0].isoformat()
        except (ValueError, IndexError):
            return None
        return None
