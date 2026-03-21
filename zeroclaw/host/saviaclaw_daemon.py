#!/usr/bin/env python3
"""SaviaClaw Daemon — keeps Savia alive and connected to ZeroClaw.

Runs as background process. Reconnects automatically if serial drops.
Processes 'ask' commands via claude -p. Updates LCD with status.
Logs everything to ~/.savia/zeroclaw/daemon.log.

Usage:
  python3 zeroclaw/host/saviaclaw_daemon.py &          # background
  python3 zeroclaw/host/saviaclaw_daemon.py --once      # single run
"""
import serial
import subprocess
import json
import time
import sys
import os
import argparse
import logging

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "daemon.log")
PORTS = ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyACM0"]
BAUD = 115200
RECONNECT_DELAY = 5
HEARTBEAT_INTERVAL = 30


def setup_logging():
    os.makedirs(LOG_DIR, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(LOG_FILE, maxBytes=1_000_000),
            logging.StreamHandler(),
        ],
    )
    return logging.getLogger("saviaclaw")


def find_port():
    for p in PORTS:
        if os.path.exists(p):
            return p
    return None


def send_cmd(ser, text, wait=2):
    ser.write((text + "\r\n").encode())
    ser.flush()
    time.sleep(wait)
    return ser.read(ser.in_waiting).decode("utf-8", errors="ignore").strip()


def call_claude(question):
    try:
        r = subprocess.run(
            ["claude", "-p", question],
            capture_output=True, text=True, timeout=30,
            cwd=os.path.expanduser("~/claude"),
        )
        return r.stdout.strip()[:200] if r.returncode == 0 else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def truncate_lcd(text):
    clean = text.replace("\n", " ").strip()
    l1 = clean[:16]
    l2 = clean[16:32] if len(clean) > 16 else ""
    return l1, l2


def run_daemon(log, once=False):
    log.info("SaviaClaw daemon starting")
    while True:
        port = find_port()
        if not port:
            log.warning("No ESP32 found. Retrying in %ds", RECONNECT_DELAY)
            if once:
                return
            time.sleep(RECONNECT_DELAY)
            continue

        try:
            ser = serial.Serial(port, BAUD, timeout=3)
            time.sleep(2)
            ser.read(ser.in_waiting)
            log.info("Connected to %s", port)
            send_cmd(ser, "lcd Savia daemon | Connected", 2)

            buf = ""
            last_heartbeat = time.time()

            while True:
                # Read serial
                data = ser.read(ser.in_waiting or 1)
                if data:
                    buf += data.decode("utf-8", errors="ignore")
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        line = line.strip()
                        if not line:
                            continue
                        # Parse JSON responses from ESP32
                        try:
                            msg = json.loads(line)
                            if msg.get("cmd") == "ask" and msg.get("ok"):
                                q = msg["data"].get("ask", "")
                                if q:
                                    log.info("Q: %s", q)
                                    send_cmd(ser, "lcd Pensando...", 1)
                                    ans = call_claude(q)
                                    if ans:
                                        log.info("A: %s", ans[:80])
                                        l1, l2 = truncate_lcd(ans)
                                        cmd = f"lcd {l1} | {l2}" if l2 else f"lcd {l1}"
                                        send_cmd(ser, cmd, 1)
                                    else:
                                        send_cmd(ser, "lcd Sin respuesta | Intenta de nuevo", 1)
                        except json.JSONDecodeError:
                            pass

                # Periodic heartbeat
                if time.time() - last_heartbeat > HEARTBEAT_INTERVAL:
                    last_heartbeat = time.time()
                    log.debug("heartbeat")

                if once:
                    return

        except serial.SerialException as e:
            log.error("Serial error: %s", e)
            if once:
                return
            time.sleep(RECONNECT_DELAY)
        except KeyboardInterrupt:
            log.info("Daemon stopped by user")
            try:
                send_cmd(ser, "lcd Savia offline | Daemon stopped", 1)
            except Exception:
                pass
            return


def main():
    p = argparse.ArgumentParser(description="SaviaClaw Daemon")
    p.add_argument("--once", action="store_true", help="Single run")
    args = p.parse_args()
    log = setup_logging()
    run_daemon(log, once=args.once)


if __name__ == "__main__":
    main()
