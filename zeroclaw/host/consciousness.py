"""Savia Consciousness — scheduled autonomous tasks via ZeroClaw.
ZeroClaw always on → host daemon → Claude headless → result on LCD + log.
"""
import json
import time
import os
import logging
import subprocess
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
TASK_LOG = os.path.join(LOG_DIR, "task-results.jsonl")
SCHEDULE_FILE = os.path.join(LOG_DIR, "schedule.json")
IDENTITY_FILE = os.path.join(os.path.dirname(__file__), "identity.json")

DEFAULT_SCHEDULE = [
    {"name": "heartbeat", "interval_min": 5,
     "action": "ping", "type": "device"},
    {"name": "memory-consolidate", "interval_min": 60,
     "action": "claude -p '/memory-stats' --output-format text",
     "type": "claude"},
    {"name": "git-status", "interval_min": 30,
     "action": "git -C ~/claude log --oneline -1 2>&1; git -C ~/claude status --short 2>&1 | head -5",
     "type": "shell", "silent_empty": True},
    {"name": "sensor-check", "interval_min": 10,
     "action": "sensors", "type": "device"},
    {"name": "check-talk", "interval_min": 0,
     "action": "poll_talk", "type": "talk"},
    {"name": "check-gmail", "interval_min": 5,
     "action": "check_gmail", "type": "gmail"},
    {"name": "gdrive-sync", "interval_min": 360,
     "action": "python3 zeroclaw/host/gdrive_sync.py sync",
     "type": "shell", "notify": "on_error"},
]

log = logging.getLogger("consciousness")

from .consciousness_comms import (  # notification + comms helpers
    notify_failure as _notify_failure, notify_success as _notify_success,
    poll_talk as _poll_talk, check_gmail as _check_gmail,
)
from .survival import survival_tick as _survival_tick


def load_identity():
    if os.path.isfile(IDENTITY_FILE):
        with open(IDENTITY_FILE) as f: return json.load(f)
    return {"name": "SaviaClaw", "device_id": "unknown"}

def load_schedule():
    if os.path.isfile(SCHEDULE_FILE):
        with open(SCHEDULE_FILE) as f: return json.load(f)
    return DEFAULT_SCHEDULE


def save_schedule(schedule):
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(SCHEDULE_FILE, "w") as f:
        json.dump(schedule, f, indent=2)


def log_result(task_name, result, success=True):
    os.makedirs(LOG_DIR, exist_ok=True)
    entry = {"ts": datetime.now(timezone.utc).isoformat(),
             "task": task_name, "ok": success,
             "result": str(result)[:300]}
    with open(TASK_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")


def run_device_task(ser, action):
    from .daemon_util import send_cmd
    return send_cmd(ser, action, 2)
def run_shell_task(action):
    try:
        r = subprocess.run(action, shell=True, capture_output=True, text=True, timeout=15)
        if r.returncode == 0:
            return r.stdout.strip()[:300] or "(ok)"
        return None  # signal failure for notification
    except Exception:
        return None

def run_claude_task(action):
    try:  # Run from /tmp to avoid loading pm-workspace CLAUDE.md (130K tokens)
        r = subprocess.run(action, shell=True, capture_output=True, text=True,
                           timeout=60, cwd="/tmp")
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception as e: return str(e)


def tick(ser, schedule, last_runs):
    """Check schedule, run due tasks. Called from daemon loop."""
    now = time.time()
    for task in schedule:
        name = task["name"]
        interval = task["interval_min"] * 60
        last = last_runs.get(name, 0)
        if now - last < interval:
            continue
        last_runs[name] = now
        log.info("Running scheduled task: %s", name)

        try:
            if task["type"] == "device":
                result = run_device_task(ser, task["action"])
            elif task["type"] == "shell":
                result = run_shell_task(task["action"])
            elif task["type"] == "claude":
                result = run_claude_task(task["action"])
            elif task["type"] == "talk":
                _poll_talk(run_claude_task); result = "polled"
            elif task["type"] == "gmail":
                _check_gmail(run_claude_task); result = "checked"
            else:
                result = f"Unknown type: {task['type']}"

            log_result(name, result, success=bool(result))
            log.info("Task %s completed: %s", name, str(result)[:80])

            # Show on LCD (task status)
            from .daemon_util import send_cmd, lcd_task_status
            l1, l2 = lcd_task_status(name, result)
            send_cmd(ser, f"lcd {l1}" + (f" | {l2}" if l2 else ""), 1)

            # Notify on failure or if task requests it
            if result is None and not task.get("silent_empty"):
                _notify_failure(name)
            elif task.get("notify") is True:
                _notify_success(name, result)

        except Exception as e:
            log.error("Task %s failed: %s", name, e)
            log_result(name, str(e), success=False)

    _survival_tick(ser, run_claude_task)
    return last_runs


def get_recent_results(n=10):
    """Get last N task results for session context."""
    if not os.path.isfile(TASK_LOG):
        return []
    results = []
    with open(TASK_LOG) as f:
        for line in f:
            try:
                results.append(json.loads(line.strip()))
            except json.JSONDecodeError:
                continue
    return results[-n:]
