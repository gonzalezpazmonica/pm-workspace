# SaviaClaw heartbeat — periodic status report + LCD rotation
import time
import gc
import machine


class Heartbeat:
    """Periodic status update on LCD and serial."""

    def __init__(self, lcd=None, interval_ms=10000):
        self.lcd = lcd
        self.interval = interval_ms
        self.last_tick = time.ticks_ms()
        self.boot_time = time.ticks_ms()
        self.messages = []  # rotating messages
        self.msg_idx = 0
        self.wifi_ip = None

    def set_wifi(self, ip):
        self.wifi_ip = ip

    def add_message(self, line1, line2=""):
        self.messages.append((line1, line2))

    def clear_messages(self):
        self.messages = []
        self.msg_idx = 0

    def uptime_str(self):
        secs = time.ticks_diff(time.ticks_ms(), self.boot_time) // 1000
        mins = secs // 60
        hrs = mins // 60
        if hrs > 0:
            return f"{hrs}h{mins%60}m"
        if mins > 0:
            return f"{mins}m{secs%60}s"
        return f"{secs}s"

    def tick(self):
        """Call this in main loop. Updates LCD if interval elapsed."""
        now = time.ticks_ms()
        if time.ticks_diff(now, self.last_tick) < self.interval:
            return False
        self.last_tick = now

        if not self.lcd:
            return True

        # Rotate through status screens
        screens = []

        # Screen 1: identity + uptime
        up = self.uptime_str()
        ram = gc.mem_free() // 1024
        screens.append((f"SaviaClaw {up}", f"RAM:{ram}KB"))

        # Screen 2: WiFi status
        if self.wifi_ip:
            screens.append(("WiFi OK", self.wifi_ip[:16]))
        else:
            screens.append(("WiFi: offline", "Serial mode"))

        # Screen 3+: custom messages
        for m in self.messages[-3:]:
            screens.append(m)

        if screens:
            idx = self.msg_idx % len(screens)
            l1, l2 = screens[idx]
            self.lcd.message(l1[:16], l2[:16])
            self.msg_idx += 1

        return True
