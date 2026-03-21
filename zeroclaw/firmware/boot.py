# ZeroClaw boot.py — runs once at startup
# Configures WiFi (if available) and sets CPU frequency
import machine
import gc

# CPU at 240MHz for best performance
machine.freq(240000000)

# Status LED
led = machine.Pin(2, machine.Pin.OUT)
led.value(1)  # LED on during boot

# Try WiFi connection (non-blocking, optional for Fase 0)
try:
    import json
    with open('config.json', 'r') as f:
        cfg = json.load(f)
    if cfg.get('wifi_ssid'):
        import network
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        if not wlan.isconnected():
            wlan.connect(cfg['wifi_ssid'], cfg.get('wifi_pass', ''))
            import time
            for _ in range(20):  # 10s timeout
                if wlan.isconnected():
                    break
                time.sleep_ms(500)
        if wlan.isconnected():
            print(f"WiFi: {wlan.ifconfig()[0]}")
        else:
            print("WiFi: not connected (continuing without)")
except Exception:
    print("WiFi: no config (serial mode)")

gc.collect()
led.value(0)  # LED off, boot complete
print("ZeroClaw boot complete")
