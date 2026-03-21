# ZeroClaw command handler — processes JSON commands from host
import machine
import gc
import sys
import json
import time


class CommandHandler:
    """Processes commands from the host (serial or WiFi).

    Command format (JSON):  {"cmd": "name", "args": {...}}
    Simple format (text):   name [args]
    Response format (JSON):  {"ok": true, "data": {...}} or {"error": "msg"}
    """

    def __init__(self, led):
        self.led = led
        self.start_time = time.ticks_ms()

    def process(self, line):
        """Process a command line. Accepts JSON or plain text."""
        # Try JSON first
        try:
            msg = json.loads(line)
            cmd = msg.get("cmd", "")
            args = msg.get("args", {})
        except (ValueError, TypeError):
            # Plain text: "cmd arg1 arg2"
            parts = line.split()
            cmd = parts[0] if parts else ""
            args = {"raw": parts[1:]} if len(parts) > 1 else {}

        # Dispatch
        handler = getattr(self, f"_cmd_{cmd}", None)
        if handler:
            self.led.on()
            try:
                result = handler(args)
                return {"ok": True, "cmd": cmd, "data": result}
            except Exception as e:
                return {"error": str(e), "cmd": cmd}
            finally:
                self.led.off()
        else:
            return {"error": f"unknown command: {cmd}", "commands": self._cmd_help({})}

    def _cmd_ping(self, args):
        return {"pong": True, "uptime_ms": time.ticks_diff(time.ticks_ms(), self.start_time)}

    def _cmd_led(self, args):
        action = args.get("action") or (args.get("raw", ["on"])[0])
        if action == "on":
            self.led.on()
        elif action == "off":
            self.led.off()
        elif action == "blink":
            count = int(args.get("count", args.get("raw", ["3"])[0] if "raw" in args else 3))
            self.led.blink(count)
        elif action == "pulse":
            self.led.pulse()
        else:
            return {"error": f"unknown action: {action}"}
        return {"led": action}

    def _cmd_info(self, args):
        return {
            "device": "zeroclaw-01",
            "version": "0.1.0",
            "platform": sys.platform,
            "freq_mhz": machine.freq() // 1_000_000,
            "free_ram": gc.mem_free(),
            "uptime_ms": time.ticks_diff(time.ticks_ms(), self.start_time),
        }

    def _cmd_sensors(self, args):
        # Built-in: internal temperature (ESP32)
        data = {}
        try:
            import esp32
            data["internal_temp_f"] = esp32.raw_temperature()
        except Exception:
            data["internal_temp"] = "not available"
        data["free_ram"] = gc.mem_free()
        data["freq_mhz"] = machine.freq() // 1_000_000
        return data

    def _cmd_lcd(self, args):
        raw = args.get("raw", [])
        text = " ".join(raw) if raw else args.get("text", "")
        if not text:
            return {"error": "usage: lcd <text> or lcd line1 | line2"}
        try:
            from lib.lcd_i2c import LCD
            lcd = LCD()
            if "|" in text:
                parts = text.split("|", 1)
                lcd.message(parts[0].strip(), parts[1].strip())
            else:
                lcd.message(text)
            return {"lcd": "ok", "text": text}
        except Exception as e:
            return {"error": "lcd: " + str(e)}

    def _cmd_gpio(self, args):
        pin_num = int(args.get("pin") or args.get("raw", [0])[0])
        action = args.get("action") or (args["raw"][1] if "raw" in args and len(args["raw"]) > 1 else "read")
        p = machine.Pin(pin_num)
        if action == "read":
            p.init(machine.Pin.IN)
            return {"pin": pin_num, "value": p.value()}
        elif action in ("high", "1", "on"):
            p.init(machine.Pin.OUT)
            p.value(1)
            return {"pin": pin_num, "set": 1}
        elif action in ("low", "0", "off"):
            p.init(machine.Pin.OUT)
            p.value(0)
            return {"pin": pin_num, "set": 0}
        return {"error": f"gpio action: read|high|low"}

    def _cmd_help(self, args):
        return ["ping", "led", "lcd", "info", "sensors", "gpio", "help"]

    def _cmd_repl(self, args):
        return {"message": "Entering REPL mode. Reset ESP32 to return to ZeroClaw."}
