#!/usr/bin/env python3
"""SaviaClaw Headless — autonomous server agent without ESP32 hardware.

Runs on the host (Ubuntu Linux), connects via Tailscale VPN, communicates
through Nextcloud Talk. Persistent consciousness with scheduled autonomous
tasks using DeepSeek v4-pro via OpenCode.

Equivalent to Hermes Agent / OpenClaw but built on SaviaClaw's architecture:
- LLM backend: OpenCode + DeepSeek v4-pro (provider-agnostic)
- Communication: Nextcloud Talk (existing)
- Tasks: consciousness scheduler (heartbeat, git-status, memory-consolidate, etc.)
- Memory: local filesystem in ~/.savia/zeroclaw/
- Security: zero exposed ports, no HTTP server, only outbound Talk polling

Usage:
    python3 zeroclaw/host/saviaclaw_headless.py
    python3 zeroclaw/host/saviaclaw_headless.py --once    # single tick, then exit
"""
import sys
import os
import time
import signal
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "headless.log")
STATUS_FILE = os.path.join(LOG_DIR, "headless-status.json")

_shutdown = False

def setup_logging():
    os.makedirs(LOG_DIR, exist_ok=True)
    handler = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    log = logging.getLogger("saviaclaw.headless")
    log.setLevel(logging.INFO)
    log.addHandler(handler)
    log.addHandler(logging.StreamHandler())
    return log

def handle_signal(signum, frame):
    global _shutdown
    _shutdown = True

def write_status(state, detail=""):
    import json
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(STATUS_FILE, "w") as f:
        json.dump({"state": state, "detail": detail, "ts": time.time()}, f)

def run_headless(log, once=False):
    global _shutdown
    log.info("SaviaClaw headless starting (pid=%d)", os.getpid())
    write_status("running")

    # Load consciousness
    from .consciousness import load_schedule, tick, load_identity, log_result
    identity = load_identity()
    log.info("Identity: %s (%s)", identity.get("name"), identity.get("device_id"))

    schedule = load_schedule()
    last_runs = {}
    log.info("Consciousness: %d scheduled tasks", len(schedule))

    # Filter: headless mode skips device tasks (no ESP32)
    headless_schedule = [t for t in schedule if t.get("type") != "device"]
    log.info("Headless tasks: %d (skipped %d device tasks)", len(headless_schedule),
             len(schedule) - len(headless_schedule))

    write_status("running", f"{len(headless_schedule)} tasks loaded")

    tick_count = 0
    while not _shutdown:
        try:
            tick_count += 1
            # Run consciousness tick: polls Talk, checks Gmail, runs scheduled tasks
            last_runs = tick(headless_schedule, last_runs, log)
            log.debug("Tick #%d complete", tick_count)

            if once:
                log.info("Single tick complete (--once). Exiting.")
                write_status("completed")
                return

            # Wait for next check cycle (30s between ticks)
            time.sleep(30)

        except Exception as e:
            log.error("Tick #%d error: %s", tick_count, e)
            time.sleep(10)

    log.info("Shutdown complete after %d ticks", tick_count)
    write_status("stopped")

def tick(schedule, last_runs, log):
    """Simplified tick for headless mode — no serial, no LCD."""
    from .consciousness import run_llm_task, run_shell_task, log_result
    now = time.time()

    # Import comms lazily
    try:
        from .consciousness_comms import poll_talk, check_gmail, notify_failure, notify_success
    except ImportError:
        poll_talk = check_gmail = notify_failure = notify_success = None

    for task in schedule:
        name = task["name"]
        interval = task["interval_min"] * 60
        last = last_runs.get(name, 0)
        if now - last < interval:
            continue
        last_runs[name] = now
        log.info("Running: %s", name)

        try:
            if task["type"] == "shell":
                result = run_shell_task(task["action"])
            elif task["type"] == "llm":
                result = run_llm_task(task["action"])
            elif task["type"] == "talk":
                if poll_talk:
                    poll_talk()
                result = "polled"
            elif task["type"] == "gmail":
                if check_gmail:
                    check_gmail()
                result = "checked"
            else:
                result = f"Unknown type: {task['type']}"

            if result is None and not task.get("silent_empty"):
                if notify_failure:
                    notify_failure(name)
            elif task.get("notify") is True and notify_success:
                notify_success(name, result)

            log_result(name, result, success=bool(result))
            log.info("Done: %s", name)

        except Exception as e:
            log.error("Task '%s' failed: %s", name, e)
            log_result(name, str(e), success=False)

    return last_runs

def main():
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    once = "--once" in sys.argv
    log = setup_logging()
    log.info("=" * 40)
    log.info("SaviaClaw Headless Agent starting")
    log.info("=" * 40)

    run_headless(log, once=once)

if __name__ == "__main__":
    main()
