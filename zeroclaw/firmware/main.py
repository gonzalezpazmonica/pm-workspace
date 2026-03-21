# ZeroClaw main.py — command loop via serial or WiFi
# Fase 0: serial commands from host PC
import machine
import sys
import gc
import json
import time

from lib.status import StatusLED
from lib.commands import CommandHandler

# Initialize
led = StatusLED(pin=2)
handler = CommandHandler(led)

# Watchdog (10s timeout — resets ESP32 if main loop hangs)
try:
    wdt = machine.WDT(timeout=10000)
except Exception:
    wdt = None  # Some boards don't support WDT in dev mode

print("ZeroClaw v0.1.0 ready")
print("Commands: ping, led, info, sensors, repl, help")
led.pulse()

# Main command loop — reads JSON commands from serial
buf = ""
while True:
    # Feed watchdog
    if wdt:
        wdt.feed()

    # Check for serial input (non-blocking)
    if sys.stdin in [None]:
        time.sleep_ms(100)
        continue

    try:
        # Read available bytes
        if not sys.stdin.buffer.any():
            time.sleep_ms(50)
            continue

        char = sys.stdin.buffer.read(1)
        if char is None:
            continue

        c = char.decode('utf-8', 'ignore')
        if c == '\n' or c == '\r':
            line = buf.strip()
            buf = ""
            if not line:
                continue
            # Process command
            try:
                response = handler.process(line)
                print(json.dumps(response))
            except Exception as e:
                print(json.dumps({"error": str(e)}))
        else:
            buf += c
    except Exception as e:
        print(json.dumps({"error": f"loop: {e}"}))
        time.sleep_ms(100)
    gc.collect()
