#!/usr/bin/env python3
"""ZeroClaw Host Bridge — connects ESP32 to Savia via serial.

Usage:
  python3 zeroclaw/host/bridge.py                    # auto-detect port
  python3 zeroclaw/host/bridge.py --port /dev/ttyUSB0
  python3 zeroclaw/host/bridge.py --test              # run self-test
"""
import serial
import json
import time
import sys
import os
import argparse
import threading


class ZeroClawBridge:
    """Serial bridge between host PC and ZeroClaw ESP32."""

    def __init__(self, port=None, baud=115200, timeout=2):
        self.port = port or self._detect_port()
        self.baud = baud
        self.timeout = timeout
        self.ser = None
        self.connected = False

    def _detect_port(self):
        for p in ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyACM0',
                   '/dev/ttyACM1', 'COM3', 'COM4', 'COM5']:
            if os.path.exists(p):
                return p
        return None

    def connect(self):
        if not self.port:
            print("❌ No ESP32 detected. Connect via USB and retry.")
            return False
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=self.timeout)
            time.sleep(2)  # Wait for ESP32 reset after serial connect
            self._flush()
            self.connected = True
            print(f"✅ Connected to ZeroClaw on {self.port}")
            return True
        except serial.SerialException as e:
            print(f"❌ Serial error: {e}")
            return False

    def _flush(self):
        if self.ser and self.ser.in_waiting:
            self.ser.read(self.ser.in_waiting)

    def send_command(self, cmd, args=None):
        """Send JSON command to ESP32, return parsed response."""
        if not self.connected:
            return {"error": "not connected"}
        msg = json.dumps({"cmd": cmd, "args": args or {}})
        self.ser.write((msg + "\n").encode())
        self.ser.flush()
        # Read response (with timeout)
        deadline = time.time() + self.timeout
        lines = []
        while time.time() < deadline:
            if self.ser.in_waiting:
                line = self.ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    try:
                        return json.loads(line)
                    except json.JSONDecodeError:
                        lines.append(line)
            time.sleep(0.05)
        return {"error": "timeout", "raw": lines}

    def send_text(self, text):
        """Send plain text command."""
        if not self.connected:
            return {"error": "not connected"}
        self.ser.write((text + "\n").encode())
        self.ser.flush()
        deadline = time.time() + self.timeout
        while time.time() < deadline:
            if self.ser.in_waiting:
                line = self.ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    try:
                        return json.loads(line)
                    except json.JSONDecodeError:
                        return {"raw": line}
            time.sleep(0.05)
        return {"error": "timeout"}

    def ping(self):
        return self.send_command("ping")

    def info(self):
        return self.send_command("info")

    def led(self, action="blink", count=3):
        return self.send_command("led", {"action": action, "count": count})

    def sensors(self):
        return self.send_command("sensors")

    def gpio(self, pin, action="read"):
        return self.send_command("gpio", {"pin": pin, "action": action})

    def close(self):
        if self.ser:
            self.ser.close()
            self.connected = False


if __name__ == "__main__":
    from cli import main
    main()
