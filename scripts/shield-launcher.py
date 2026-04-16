#!/usr/bin/env python3
"""
shield-launcher.py — Start/stop Shield daemon + proxy as detached processes.

On Windows, nohup/disown don't survive terminal close. This launcher uses
DETACHED_PROCESS creation flags so both services persist independently.

Usage:
  python3 scripts/shield-launcher.py start   # start daemon + proxy
  python3 scripts/shield-launcher.py stop    # stop both
  python3 scripts/shield-launcher.py status  # check health
  python3 scripts/shield-launcher.py restart # stop + start
"""
import json
import os
import signal
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PID_DIR = Path.home() / ".savia"
DAEMON_PID = PID_DIR / "shield-daemon.pid"
PROXY_PID = PID_DIR / "shield-proxy.pid"

DAEMON_PORT = int(os.environ.get("SAVIA_SHIELD_PORT", "8444"))
PROXY_PORT = int(os.environ.get("SAVIA_SHIELD_PROXY_PORT", "8443"))

IS_WINDOWS = sys.platform == "win32"


def health(port, timeout=3):
    """Check if a service is healthy on localhost:port."""
    try:
        url = f"http://127.0.0.1:{port}/health"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read())
    except Exception:
        return None


def read_pid(path):
    try:
        pid = int(path.read_text().strip())
        return pid if pid > 0 else None
    except (FileNotFoundError, ValueError):
        return None


def pid_alive(pid):
    if pid is None:
        return False
    try:
        if IS_WINDOWS:
            # tasklist returns 0 if PID exists
            r = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
                capture_output=True, text=True, timeout=5
            )
            return str(pid) in r.stdout
        else:
            os.kill(pid, 0)
            return True
    except (OSError, subprocess.TimeoutExpired):
        return False


def kill_pid(pid):
    if pid is None:
        return
    try:
        if IS_WINDOWS:
            subprocess.run(
                ["taskkill", "/PID", str(pid), "/F"],
                capture_output=True, timeout=5
            )
        else:
            os.kill(pid, signal.SIGTERM)
    except Exception:
        pass


def start_service(script_name, pid_file, port, label):
    """Start a Python script as a fully detached process."""
    # Check if already running
    h = health(port, timeout=2)
    if h:
        print(f"  {label}: already running on :{port}")
        return True

    # Kill stale PID if any
    old_pid = read_pid(pid_file)
    if old_pid and pid_alive(old_pid):
        kill_pid(old_pid)
        time.sleep(1)

    script_path = str(SCRIPT_DIR / script_name)
    PID_DIR.mkdir(parents=True, exist_ok=True)

    if IS_WINDOWS:
        # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW
        flags = 0x00000008 | 0x00000200 | 0x08000000
        proc = subprocess.Popen(
            [sys.executable, script_path],
            creationflags=flags,
            stdout=subprocess.DEVNULL,
            stderr=open(str(PID_DIR / f"{label}.log"), "w"),
            stdin=subprocess.DEVNULL,
        )
    else:
        proc = subprocess.Popen(
            [sys.executable, script_path],
            stdout=subprocess.DEVNULL,
            stderr=open(str(PID_DIR / f"{label}.log"), "w"),
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )

    pid_file.write_text(str(proc.pid))

    # Wait for health
    for _ in range(10):
        time.sleep(1)
        if health(port, timeout=2):
            print(f"  {label}: started (PID {proc.pid}, :{port})")
            return True

    print(f"  {label}: FAILED to start (PID {proc.pid}, :{port})")
    return False


def stop_service(pid_file, port, label):
    """Stop a service by PID file, verify with health check."""
    pid = read_pid(pid_file)
    if pid and pid_alive(pid):
        kill_pid(pid)
        time.sleep(1)
        if not pid_alive(pid):
            print(f"  {label}: stopped (was PID {pid})")
        else:
            print(f"  {label}: FAILED to stop PID {pid}")
    elif health(port, timeout=1):
        print(f"  {label}: running but no PID file — cannot stop")
    else:
        print(f"  {label}: not running")
    try:
        pid_file.unlink(missing_ok=True)
    except Exception:
        pass


def cmd_start():
    print("Starting Savia Shield...")
    start_service("savia-shield-daemon.py", DAEMON_PID, DAEMON_PORT, "daemon")
    start_service("savia-shield-proxy.py", PROXY_PID, PROXY_PORT, "proxy")


def cmd_stop():
    print("Stopping Savia Shield...")
    stop_service(PROXY_PID, PROXY_PORT, "proxy")
    stop_service(DAEMON_PID, DAEMON_PORT, "daemon")


def cmd_status():
    print("Savia Shield Status:")
    for label, port, pid_file in [
        ("daemon", DAEMON_PORT, DAEMON_PID),
        ("proxy", PROXY_PORT, PROXY_PID),
    ]:
        h = health(port, timeout=2)
        pid = read_pid(pid_file)
        alive = pid_alive(pid)
        if h:
            extras = " | ".join(f"{k}={v}" for k, v in h.items()
                                if k != "status")
            pid_str = f"PID {pid}" if pid else "no PID file"
            print(f"  {label} :{port} — UP ({pid_str}) | {extras}")
        elif alive:
            print(f"  {label} :{port} — PID {pid} alive but not responding")
        else:
            print(f"  {label} :{port} — DOWN")


def main():
    if len(sys.argv) < 2:
        print("Usage: shield-launcher.py {start|stop|status|restart}")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "start":
        cmd_start()
    elif cmd == "stop":
        cmd_stop()
    elif cmd == "status":
        cmd_status()
    elif cmd == "restart":
        cmd_stop()
        time.sleep(1)
        cmd_start()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
