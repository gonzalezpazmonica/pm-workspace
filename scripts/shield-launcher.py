#!/usr/bin/env python3
"""
shield-launcher.py — Start/stop Shield daemon + proxy as detached processes.

On Windows, nohup/disown don't survive terminal close. This launcher uses
DETACHED_PROCESS creation flags so both services persist independently.

WARNING: shield-ner-daemon.py is NOT started here. The unified daemon
(savia-shield-daemon.py) already bundles NER (Presidio+spaCy) internally.
Starting both would cause a port conflict on :8444.

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
LOG_DIR = PID_DIR
DAEMON_PID = PID_DIR / "shield-daemon.pid"
PROXY_PID = PID_DIR / "shield-proxy.pid"

DAEMON_PORT = int(os.environ.get("SAVIA_SHIELD_PORT", "8444"))
PROXY_PORT = int(os.environ.get("SAVIA_SHIELD_PROXY_PORT", "8443"))
START_TIMEOUT_S = int(os.environ.get("SAVIA_SHIELD_START_TIMEOUT", "20"))

IS_WINDOWS = sys.platform == "win32"
IS_WSL = not IS_WINDOWS and "microsoft" in (os.uname().release.lower() if hasattr(os, 'uname') else "")


def log(msg: str):
    ts = time.strftime("%H:%M:%S")
    with open(LOG_DIR / "shield-launcher.log", "a") as f:
        f.write(f"[{ts}] {msg}\n")


def health(port: int, timeout: int = 3) -> dict | None:
    try:
        url = f"http://127.0.0.1:{port}/health"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read())
    except Exception:
        return None


def read_pid(path: Path) -> int | None:
    try:
        pid = int(path.read_text().strip())
        return pid if pid > 0 else None
    except (FileNotFoundError, ValueError):
        return None


def pid_alive(pid: int | None) -> bool:
    if pid is None:
        return False
    try:
        if IS_WINDOWS:
            r = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
                capture_output=True, text=True, timeout=5,
            )
            return str(pid) in r.stdout
        else:
            os.kill(pid, 0)
            return True
    except (OSError, subprocess.TimeoutExpired):
        return False


def kill_pid(pid: int | None):
    if pid is None:
        return
    try:
        if IS_WINDOWS:
            subprocess.run(
                ["taskkill", "/PID", str(pid), "/F"],
                capture_output=True, timeout=5,
            )
        else:
            os.kill(pid, signal.SIGTERM)
    except Exception:
        pass


def preflight_check(script_name: str, label: str) -> bool:
    """Verify python3 is available and the target script exists."""
    py = sys.executable
    if not py or not Path(py).exists():
        log(f"preflight FAIL: no python3 executable ({py})")
        print(f"  {label}: python3 not found")
        return False
    script_path = SCRIPT_DIR / script_name
    if not script_path.exists():
        log(f"preflight FAIL: {script_path} not found")
        print(f"  {label}: script not found ({script_path})")
        return False
    # Quick import check: can the script be parsed?
    try:
        compile(script_path.read_text(), str(script_path), "exec")
    except SyntaxError as e:
        log(f"preflight FAIL: {script_name} syntax error: {e}")
        print(f"  {label}: syntax error")
        return False
    return True


def start_service(script_name: str, pid_file: Path, port: int, label: str, timeout_s: int = START_TIMEOUT_S) -> bool:
    """Start a Python script as a fully detached process."""
    if not preflight_check(script_name, label):
        return False

    h = health(port, timeout=2)
    if h:
        log(f"{label}: already running on :{port} (ner={h.get('ner', '?')})")
        print(f"  {label}: already running on :{port}")
        return True

    old_pid = read_pid(pid_file)
    if old_pid and pid_alive(old_pid):
        log(f"{label}: killing stale PID {old_pid}")
        kill_pid(old_pid)
        time.sleep(1)

    script_path = str(SCRIPT_DIR / script_name)
    PID_DIR.mkdir(parents=True, exist_ok=True)
    stderr_log = open(str(LOG_DIR / f"{label}.log"), "a")

    log(f"{label}: launching {script_name} on :{port}")

    if IS_WINDOWS:
        flags = 0x00000008 | 0x00000200 | 0x08000000
        proc = subprocess.Popen(
            [sys.executable, script_path],
            creationflags=flags,
            stdout=subprocess.DEVNULL,
            stderr=stderr_log,
            stdin=subprocess.DEVNULL,
        )
    else:
        proc = subprocess.Popen(
            [sys.executable, script_path],
            stdout=subprocess.DEVNULL,
            stderr=stderr_log,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )

    pid_file.write_text(str(proc.pid))
    log(f"{label}: PID {proc.pid}")

    # WSL cold start: spaCy model loading can take 15s+
    wait_msg = f"  {label}: waiting up to {timeout_s}s on :{port}"
    if IS_WSL:
        wait_msg += " (WSL — cold start may be slow)"
    print(wait_msg)

    for attempt in range(timeout_s):
        time.sleep(1)
        h = health(port, timeout=3)
        if h:
            ner_status = f" ner={h.get('ner', '?')}" if label == "daemon" else ""
            log(f"{label}: started (PID {proc.pid}, :{port}){ner_status}")
            print(f"  {label}: started after {attempt + 1}s (PID {proc.pid})")
            return True

    log(f"{label}: FAILED to start after {timeout_s}s (PID {proc.pid})")
    print(f"  {label}: FAILED to start after {timeout_s}s (check {LOG_DIR / label}.log)")
    return False


def stop_service(pid_file: Path, port: int, label: str):
    pid = read_pid(pid_file)
    if pid and pid_alive(pid):
        kill_pid(pid)
        time.sleep(1)
        if not pid_alive(pid):
            log(f"{label}: stopped (was PID {pid})")
            print(f"  {label}: stopped (was PID {pid})")
        else:
            log(f"{label}: FAILED to stop PID {pid}")
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
    log("=== start ===")
    print("Starting Savia Shield...")
    log("WSL mode" if IS_WSL else "Native mode")
    start_service("savia-shield-daemon.py", DAEMON_PID, DAEMON_PORT, "daemon")
    start_service("savia-shield-proxy.py", PROXY_PID, PROXY_PORT, "proxy")


def cmd_stop():
    print("Stopping Savia Shield...")
    stop_service(PROXY_PID, PROXY_PORT, "proxy")
    stop_service(DAEMON_PID, DAEMON_PORT, "daemon")
    log("=== stopped ===")


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
    LOG_DIR.mkdir(parents=True, exist_ok=True)
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
