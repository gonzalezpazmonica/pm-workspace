# SaviaClaw self-test at boot — checks all hardware
import machine
import gc
import time


def run(lcd=None):
    """Run hardware self-test. Returns {component: ok/fail}."""
    results = {}

    # Test 1: CPU + RAM
    try:
        freq = machine.freq() // 1_000_000
        ram = gc.mem_free() // 1024
        results["cpu"] = f"{freq}MHz"
        results["ram"] = f"{ram}KB"
    except:
        results["cpu"] = "fail"

    # Test 2: LED
    try:
        led = machine.Pin(2, machine.Pin.OUT)
        led.value(1)
        time.sleep_ms(100)
        led.value(0)
        results["led"] = "ok"
    except:
        results["led"] = "fail"

    # Test 3: LCD I2C
    try:
        from machine import SoftI2C, Pin
        i2c = SoftI2C(scl=Pin(23), sda=Pin(22), freq=400000)
        devs = i2c.scan()
        if 0x3F in devs:
            results["lcd"] = "ok @0x3F"
        elif devs:
            results["lcd"] = "found " + hex(devs[0])
        else:
            results["lcd"] = "no device"
    except:
        results["lcd"] = "fail"

    # Test 4: WiFi module
    try:
        import network
        wlan = network.WLAN(network.STA_IF)
        results["wifi_hw"] = "ok"
        results["wifi_conn"] = wlan.ifconfig()[0] if wlan.isconnected() else "not connected"
    except:
        results["wifi_hw"] = "fail"

    # Test 5: Flash filesystem
    try:
        import os
        files = os.listdir("/")
        results["flash"] = f"{len(files)} files"
    except:
        results["flash"] = "fail"

    # Show on LCD if available
    if lcd:
        fails = [k for k, v in results.items() if "fail" in str(v)]
        if fails:
            lcd.message("SELFTEST WARN", ",".join(fails)[:16])
        else:
            lcd.message("SELFTEST OK", f"RAM:{results.get('ram','?')}")
        time.sleep_ms(1500)

    return results
