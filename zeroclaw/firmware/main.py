# ZeroClaw main.py v0.7
import machine, sys, gc, json, time, select
from lib.status import StatusLED
from lib.commands import CommandHandler

led = StatusLED(pin=2)
handler = CommandHandler(led)
lcd = None
http_server = None

try:
    from lib.lcd_i2c import LCD
    lcd = LCD()
    lcd.message('ZeroClaw v0.7', 'Booting...')
except:
    pass

try:
    import network
    wlan = network.WLAN(network.STA_IF)
    if wlan.isconnected():
        from lib.wifi_server import MiniHTTPServer
        http_server = MiniHTTPServer(handler, port=80)
        ip = http_server.start()
        if lcd:
            lcd.message('WiFi: ' + ip, 'v0.7')
except:
    pass

if lcd and not http_server:
    lcd.message('ZeroClaw v0.7', 'Serial ready')
led.pulse()
sys.stdout.write('ZeroClaw v0.7 ready\n')

try:
    wdt = machine.WDT(timeout=10000)
except:
    wdt = None

poll = select.poll()
poll.register(sys.stdin, select.POLLIN)
buf = ""

while True:
    if wdt:
        wdt.feed()
    if http_server:
        try:
            http_server.poll()
        except:
            pass
    ready = poll.poll(50)
    for obj, ev in ready:
        try:
            ch = sys.stdin.read(1)
            if ch in ('\n', '\r'):
                line = buf.strip()
                buf = ""
                if line:
                    resp = handler.process(line)
                    out = json.dumps(resp)
                    sys.stdout.write(out + '\n')
                    if lcd:
                        cn = resp.get("cmd", "?")
                        lcd.write(cn[:16], 0)
            elif ch:
                buf += ch
        except:
            pass
    gc.collect()
