#!/usr/bin/env python3
"""SaviaClaw Daemon — background process keeping Savia connected to ZeroClaw."""
import serial
import json
import time
import os
import signal
import argparse
import logging
import threading
from logging.handlers import RotatingFileHandler

from .daemon_util import (
    LOG_DIR, LOG_FILE, BAUD, RECONNECT_DELAY, HEARTBEAT_INTERVAL,
    STUCK_TIMEOUT, find_port, send_cmd, call_claude, truncate_lcd,
    write_status, show_status,
)

_shutdown = False


def _handle_signal(signum, _frame):
    global _shutdown
    _shutdown = True


def setup_logging():
    os.makedirs(LOG_DIR, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3),
            logging.StreamHandler(),
        ],
    )
    return logging.getLogger("saviaclaw")


def run_daemon(log, once=False, voice=False):
    global _shutdown
    log.info("SaviaClaw daemon starting (pid=%d, voice=%s)", os.getpid(), voice)
    write_status("starting")
    queries = 0

    while not _shutdown:
        port = find_port()
        if not port:
            log.warning("No ESP32 found. Retrying in %ds", RECONNECT_DELAY)
            write_status("searching")
            if once:
                return
            time.sleep(RECONNECT_DELAY)
            continue

        ser = None
        try:
            ser = serial.Serial(port, BAUD, timeout=3)
            time.sleep(2)
            ser.read(ser.in_waiting)
            log.info("Connected to %s", port)
            write_status("connected", port)
            send_cmd(ser, "lcd Savia daemon | Connected", 2)
            if voice:
                from .voice_daemon import start as start_voice
                start_voice(ser, threading.Lock())

            buf = ""
            last_hb = time.time()
            last_act = time.time()

            while not _shutdown:
                data = ser.read(ser.in_waiting or 1)
                if data:
                    last_act = time.time()
                    buf += data.decode("utf-8", errors="ignore")
                    buf, queries = _process_buf(buf, ser, log, queries)

                now = time.time()
                if now - last_hb > HEARTBEAT_INTERVAL:
                    last_hb = now
                    write_status("connected", port, {"queries": queries})

                if now - last_act > STUCK_TIMEOUT:
                    log.warning("No activity for %ds, reconnecting", STUCK_TIMEOUT)
                    break

                if once:
                    return

        except serial.SerialException as e:
            log.error("Serial error: %s", e)
            if once:
                return
            write_status("reconnecting", port)
            time.sleep(RECONNECT_DELAY)
        finally:
            if ser:
                try:
                    ser.close()
                except Exception:
                    pass

    log.info("Daemon stopped (queries=%d)", queries)
    write_status("stopped", extra={"queries": queries})


def _process_buf(buf, ser, log, queries):
    while "\n" in buf:
        line, buf = buf.split("\n", 1)
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
            if msg.get("cmd") == "ask" and msg.get("ok"):
                q = msg["data"].get("ask", "")
                if q:
                    log.info("Q: %s", q)
                    send_cmd(ser, "lcd Pensando...", 1)
                    ans = call_claude(q)
                    queries += 1
                    if ans:
                        log.info("A: %s", ans[:80])
                        l1, l2 = truncate_lcd(ans)
                        cmd = f"lcd {l1} | {l2}" if l2 else f"lcd {l1}"
                        send_cmd(ser, cmd, 1)
                    else:
                        send_cmd(ser, "lcd Sin respuesta | Intenta de nuevo", 1)
        except json.JSONDecodeError:
            pass
    return buf, queries


def main():
    p = argparse.ArgumentParser(description="SaviaClaw Daemon")
    p.add_argument("--once", action="store_true", help="Single run")
    p.add_argument("--status", action="store_true", help="Show status")
    p.add_argument("--voice", action="store_true", help="Enable voice")
    args = p.parse_args()
    if args.status:
        return show_status()
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)
    run_daemon(setup_logging(), once=args.once, voice=args.voice)


if __name__ == "__main__":
    main()
