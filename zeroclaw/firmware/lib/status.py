# ZeroClaw status LED — visual feedback for the human
import machine
import time


class StatusLED:
    """Controls the built-in LED for status indication.

    Patterns:
      on()       — solid: processing
      off()      — off: idle
      pulse()    — single blink: acknowledgment
      blink(n)   — n blinks: step count
      error()    — rapid blinks: error
      listening() — slow pulse: waiting for input
    """

    def __init__(self, pin=2):
        self.led = machine.Pin(pin, machine.Pin.OUT)
        self.led.value(0)

    def on(self):
        self.led.value(1)

    def off(self):
        self.led.value(0)

    def pulse(self, ms=200):
        self.led.value(1)
        time.sleep_ms(ms)
        self.led.value(0)

    def blink(self, count=1, on_ms=150, off_ms=150):
        for _ in range(count):
            self.led.value(1)
            time.sleep_ms(on_ms)
            self.led.value(0)
            time.sleep_ms(off_ms)

    def error(self):
        self.blink(count=5, on_ms=80, off_ms=80)

    def listening(self):
        # Slow fade-like blink
        self.blink(count=2, on_ms=400, off_ms=400)

    def pattern(self, name):
        patterns = {
            "ok": lambda: self.pulse(200),
            "error": self.error,
            "listening": self.listening,
            "step": lambda: self.blink(1),
        }
        fn = patterns.get(name, self.pulse)
        fn()
