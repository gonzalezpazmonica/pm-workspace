#!/usr/bin/env python3
"""Savia Brain Bridge — connects ZeroClaw to the LLM backend.

Listens on serial for queries from ESP32, sends them to OpenCode
(which loads pm-workspace context automatically), and returns the
response to ESP32's LCD + serial.

Usage:
  python3 zeroclaw/host/savia_brain.py                  # auto-detect
  python3 zeroclaw/host/savia_brain.py --port /dev/ttyUSB0
"""
import serial
import subprocess
import json
import time
import sys
import argparse
import os

MAX_RESPONSE_LCD = 32  # 2 lines x 16 chars
QUERY_PREFIX = "ask "  # ESP32 sends "ask <question>"
TIMEOUT_LLM = 30


def call_llm(prompt):
    """Provider-agnostic LLM call using OpenCode + DeepSeek."""
    from .llm_backend import talk_reply
    return talk_reply(prompt) or "No pude responder ahora"


def truncate_for_lcd(text, cols=16, rows=2):
    """Truncate response to fit LCD. Returns (line1, line2)."""
    clean = text.replace('\n', ' ').strip()
    if len(clean) <= cols:
        return clean, ""
    if len(clean) <= cols * rows:
        return clean[:cols], clean[cols:cols * rows]
    return clean[:cols], clean[cols:cols * rows - 3] + "..."


def send_lcd(ser, line1, line2=""):
    """Send lcd command to ESP32."""
    if line2:
        cmd = f"lcd {line1} | {line2}"
    else:
        cmd = f"lcd {line1}"
    ser.write((cmd + "\r\n").encode())
    ser.flush()
    time.sleep(1)
    ser.read(ser.in_waiting)  # consume response


def run_bridge(port=None):
    """Main bridge loop — listen for queries, call LLM, respond."""
    port = port or detect_port()
    if not port:
        print("No ESP32 detected")
        return

    ser = serial.Serial(port, 115200, timeout=3)
    time.sleep(2)
    ser.read(ser.in_waiting)

    send_lcd(ser, "Savia Brain", "Listening...")
    print(f"Savia Brain Bridge on {port}")
    print(f"ESP32 sends: ask <question>")
    print(f"Ctrl+C to stop\n")

    buf = ""
    while True:
        try:
            data = ser.read(ser.in_waiting or 1)
            if not data:
                continue
            buf += data.decode("utf-8", errors="ignore")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                if line.lower().startswith(QUERY_PREFIX):
                    question = line[len(QUERY_PREFIX):].strip()
                    if not question:
                        continue
                    print(f"Q: {question}")
                    send_lcd(ser, "Pensando...", question[:16])

                    response = call_llm(question)
                    print(f"A: {response[:200]}")

                    l1, l2 = truncate_for_lcd(response)
                    send_lcd(ser, l1, l2)

                    # Also send full response via serial
                    ser.write(json.dumps({
                        "savia": response
                    }).encode() + b"\r\n")
                    ser.flush()
        except KeyboardInterrupt:
            send_lcd(ser, "Savia offline", "Bridge stopped")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)

    ser.close()


def detect_port():
    for p in ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyACM0"]:
        if os.path.exists(p):
            return p
    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Savia Brain Bridge")
    parser.add_argument("--port", help="Serial port")
    args = parser.parse_args()
    run_bridge(args.port)
