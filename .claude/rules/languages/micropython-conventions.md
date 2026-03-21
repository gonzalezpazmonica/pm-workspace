---
paths:
  - "**/boot.py"
  - "**/main.py"
  - "**/lib/**/*.py"
---

# MicroPython Conventions — ESP32, RP2040, STM32

> Auto-carga cuando se trabaja con ficheros MicroPython típicos.

## Estructura de proyecto

```
proyecto/
├── boot.py           ← Config inicial (WiFi, frecuencia CPU)
├── main.py           ← Punto de entrada principal
├── lib/              ← Módulos reutilizables
│   ├── sensors.py
│   ├── actuators.py
│   └── comms.py
├── config.json       ← Configuración (NO secrets)
└── tests/            ← Tests que corren en el MCU
```

## Convenciones de código

- `machine` module para GPIO, I2C, SPI, PWM, ADC, UART
- `uasyncio` para concurrencia (no threads, son cooperativos)
- `micropython.const()` para constantes (optimización RAM)
- `gc.collect()` explícito tras operaciones grandes
- `try/except` en todo acceso a periférico (pueden fallar)
- Nombres descriptivos: `SERVO_PIN = const(18)` no `PIN = 18`

## Patrones recomendados

### Lectura de sensor con timeout

```python
import machine, utime
i2c = machine.I2C(0, scl=machine.Pin(22), sda=machine.Pin(21))

def read_sensor(addr, timeout_ms=100):
    start = utime.ticks_ms()
    while utime.ticks_diff(utime.ticks_ms(), start) < timeout_ms:
        try:
            return i2c.readfrom(addr, 2)
        except OSError:
            utime.sleep_ms(10)
    return None  # timeout → caller debe manejar
```

### Control de actuador con límites

```python
from machine import Pin, PWM
import micropython

SERVO_MIN = micropython.const(40)
SERVO_MAX = micropython.const(115)
SERVO_PIN = micropython.const(18)

servo = PWM(Pin(SERVO_PIN), freq=50)

def move_servo(angle):
    duty = max(SERVO_MIN, min(SERVO_MAX, int(angle)))
    servo.duty(duty)
    return duty
```

### Async main loop con watchdog

```python
import uasyncio as asyncio
from machine import WDT

async def main():
    wdt = WDT(timeout=5000)
    while True:
        wdt.feed()
        await read_sensors()
        await update_actuators()
        await asyncio.sleep_ms(50)

asyncio.run(main())
```

## Anti-patterns

- `import os` → usar `uos` (más ligero)
- `float` en cálculos de control → usar `int` escalado (×100)
- `time.sleep()` en async → usar `await asyncio.sleep_ms()`
- Variables globales mutables → usar clases o dicts config
- Sin `gc.collect()` → memory fragmentation en loops largos

## Testing

```python
# En el MCU: test básico de periféricos
def test_led():
    led = machine.Pin(2, machine.Pin.OUT)
    led.value(1)
    utime.sleep_ms(100)
    led.value(0)
    print("LED test: OK")

def test_i2c_scan():
    i2c = machine.I2C(0, scl=Pin(22), sda=Pin(21))
    devices = i2c.scan()
    print(f"I2C devices: {devices}")
    assert len(devices) > 0, "No I2C devices found"
```

## Seguridad

- WiFi: usar WPA2, nunca AP abierto
- Passwords en `config.json` (gitignored), no en código
- WebREPL: desactivar en producción
- Secure boot: activar eFuse en ESP32 para producción
- Ver `@.claude/rules/domain/robotics-safety.md`
