# LCD 16x2 I2C driver for PCF8574 backpack
# Address: 0x3F, SCL=23, SDA=22
from machine import Pin, SoftI2C
import time

BACKLIGHT = 0x08
EN = 0x04
RS = 0x01


class LCD:
    def __init__(self, scl=23, sda=22, addr=0x3F, cols=16, rows=2):
        self.i2c = SoftI2C(scl=Pin(scl), sda=Pin(sda), freq=400000)
        self.addr = addr
        self.cols = cols
        self.rows = rows
        self.bl = BACKLIGHT
        self._init()

    def _write4(self, data):
        self.i2c.writeto(self.addr, bytes([data | self.bl | EN]))
        self.i2c.writeto(self.addr, bytes([data | self.bl]))

    def _send(self, byte, mode=0):
        self._write4((byte & 0xF0) | mode)
        self._write4(((byte << 4) & 0xF0) | mode)
        time.sleep_us(50)

    def _init(self):
        time.sleep_ms(50)
        for _ in range(3):
            self._write4(0x30)
            time.sleep_ms(5)
        self._write4(0x20)
        time.sleep_ms(2)
        self.cmd(0x28)
        self.cmd(0x0C)
        self.cmd(0x06)
        self.clear()

    def cmd(self, c):
        self._send(c, 0)
        time.sleep_ms(2)

    def char(self, ch):
        self._send(ord(ch) if isinstance(ch, str) else ch, RS)

    def clear(self):
        self.cmd(0x01)
        time.sleep_ms(2)

    def set_cursor(self, col, row):
        offsets = [0x00, 0x40, 0x14, 0x54]
        self.cmd(0x80 | (offsets[row % self.rows] + col))

    def write(self, text, row=0, col=0):
        self.set_cursor(col, row)
        for ch in text[:self.cols - col]:
            self.char(ch)

    def message(self, line1, line2=""):
        self.clear()
        self.write(line1, 0)
        if line2:
            self.write(line2, 1)

    def backlight(self, on=True):
        self.bl = BACKLIGHT if on else 0
        self.i2c.writeto(self.addr, bytes([self.bl]))
