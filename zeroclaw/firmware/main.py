# ZeroClaw main.py — dual-mode: serial + WiFi HTTP
import machine
import sys
import gc
import json
import time
import network

from lib.status import StatusLED
from lib.commands import CommandHandler

# Initialize
led = StatusLED(pin=2)
handler = CommandHandler(led)
http_server = None

# Start WiFi HTTP server if connected
wlan = network.WLAN(network.STA_IF)
if wlan.isconnected():
    from lib.wifi_server import MiniHTTPServer
    http_server = MiniHTTPServer(handler, port=80)
    ip = http_server.start()
    print(f"ZeroClaw v0.2.0 ready — WiFi: {ip}")
    led.blink(3)  # 3 blinks = WiFi mode
else:
    print("ZeroClaw v0.2.0 ready — Serial mode")
    led.pulse()

print("Commands: ping, led, info, sensors, gpio, help")

# Watchdog
try:
    wdt = machine.WDT(timeout=10000)
except Exception:
    wdt = None

# Main loop — handles serial AND WiFi simultaneously
buf = ""
while True:
    if wdt:
        wdt.feed()

    # Poll WiFi HTTP server (non-blocking)
    if http_server:
        http_server.poll()

    # Check serial input (non-blocking)
    try:
        if sys.stdin.buffer.any():
            char = sys.stdin.buffer.read(1)
            if char:
                c = char.decode('utf-8', 'ignore')
                if c in ('\n', '\r'):
                    line = buf.strip()
                    buf = ""
                    if line:
                        try:
                            response = handler.process(line)
                            print(json.dumps(response))
                        except Exception as e:
                            print(json.dumps({"error": str(e)}))
                else:
                    buf += c
        else:
            time.sleep_ms(20)
    except Exception as e:
        print(json.dumps({"error": f"loop: {e}"}))
        time.sleep_ms(100)
    gc.collect()
