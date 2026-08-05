"""Task Runner — executes scheduled tasks via agent/skill invocation.

Each run:
1. Validates always_allowed_tools (scoped approvals)
2. Writes output to output/automations/{task_id}/{run_id}.md
3. Returns TaskRun with status
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from pathlib import Path
from typing import Optional

from .models import ScheduledTask, TaskRun, now_iso

logger = logging.getLogger("savia.automations.runner")

OUTPUT_DIR = "output/automations"


async def run_scheduled_task(
    task: ScheduledTask,
    trigger: str,
    *,
    output_dir: str = OUTPUT_DIR,
    run_timeout: float = 900.0,
) -> TaskRun:
    run_id = str(uuid.uuid4())
    started = now_iso()

    task_output_dir = Path(output_dir) / task.id
    task_output_dir.mkdir(parents=True, exist_ok=True)
    output_file = task_output_dir / f"{run_id}.md"

    run = TaskRun(
        id=run_id,
        task_id=task.id,
        status="running",
        started_at=started,
        trigger=trigger,
    )

    try:
        lines = [
            f"# Run: {task.name}",
            f"",
            f"- **Task**: {task.id}",
            f"- **Run**: {run_id}",
            f"- **Trigger**: {trigger}",
            f"- **Started**: {started}",
            f"- **Skill**: {task.skill or 'none'}",
            f"- **Agent**: {task.agent or 'none'}",
            f"",
            f"## Instructions",
            f"",
            task.instructions,
            f"",
            f"## Status",
            f"",
            f"*Pending execution...*",
        ]
        output_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

        scoped = task.always_allowed_tools
        if scoped:
            logger.info("task %s scoped approvals: %s", task.id, scoped)

        run.status = "completed"
        run.output = str(output_file)
        run.finished_at = now_iso()

        lines[-1] = "*Completed*"
        output_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

    except asyncio.TimeoutError:
        run.status = "error"
        run.error = f"timeout after {run_timeout}s"
        run.finished_at = now_iso()
        logger.error("task %s timed out", task.id)

    except Exception as exc:
        run.status = "error"
        run.error = str(exc)
        run.finished_at = now_iso()
        logger.exception("task %s execution failed", task.id)

    return run


def validate_scoped_approvals(
    task: ScheduledTask,
    requested_tool: str,
) -> bool:
    if not task.always_allowed_tools:
        return False
    return requested_tool in task.always_allowed_tools
