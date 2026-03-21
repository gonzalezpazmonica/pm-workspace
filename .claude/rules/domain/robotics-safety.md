# Robotics Safety — Reglas de seguridad para el mundo físico

> El código que controla hardware puede causar daño físico.
> Estas reglas son INMUTABLES en todo proyecto robótico.

## Principio

**Fail-safe by default.** Si algo falla, el robot SE PARA.
No hay "graceful degradation" en seguridad física — hay STOP.

## Reglas REJECT (bloquean commit)

### ROB-01: Actuador sin watchdog

Todo código que controle un actuador (motor, servo, gripper) DEBE
tener un watchdog timer. Si el software deja de responder, el
watchdog detiene el actuador.

```python
# MicroPython — REJECT sin watchdog
servo.duty(position)  # ❌ Sin watchdog

# CORRECTO
from machine import WDT
wdt = WDT(timeout=2000)  # 2 segundos
wdt.feed()
servo.duty(position)
```

### ROB-02: Control de actuador sin límites

Todo comando a actuador DEBE estar acotado por límites físicos
definidos en constantes (nunca magic numbers).

```python
SERVO_MIN = 40   # microsegundos
SERVO_MAX = 115
def safe_move(pos):
    return max(SERVO_MIN, min(SERVO_MAX, pos))
```

### ROB-03: Acceso a actuador desde red sin autenticación

NUNCA exponer control de actuadores en un endpoint HTTP/MQTT
sin autenticación. Mínimo: token bearer o mutual TLS.

### ROB-04: OTA sin firma

NUNCA aceptar firmware OTA sin verificar firma criptográfica.
ESP32: usar secure boot v2. STM32: usar RDP level 2.

### ROB-05: Single point of failure en sensores de seguridad

Si un sensor es crítico para seguridad (distancia, fin de carrera,
temperatura), DEBE haber redundancia o fail-safe si el sensor falla.

## Reglas REQUIRE (obligatorias)

### ROB-06: E-stop

Todo robot con actuadores DEBE tener un mecanismo de parada de
emergencia accesible. Preferiblemente hardware (botón físico),
complementado con software (comando /stop).

### ROB-07: Timeout en toda operación I/O

Toda lectura de sensor o escritura a actuador DEBE tener timeout.
Un periférico que no responde no puede bloquear el sistema.

### ROB-08: Log de acciones físicas

Toda acción sobre un actuador DEBE registrarse con timestamp,
valor comandado, y valor leído (si hay feedback).

### ROB-09: Geofencing para robots móviles

Robots con capacidad de movimiento DEBEN tener límites geográficos
definidos. Si se exceden, el robot se detiene.

### ROB-10: Rate limiting en comandos

Los comandos a actuadores DEBEN tener rate limiting para evitar
oscilaciones y desgaste mecánico. Máximo configurable por actuador.

## Clasificación de riesgo

| Categoría | Ejemplo | Nivel |
|-----------|---------|-------|
| LED, buzzer, display | Indicadores | Bajo |
| Servo pequeño (<1kg) | Brazo hobby | Medio |
| Motor DC/stepper | Robot móvil | Alto |
| Gripper, brazo industrial | Manipulación | Crítico |
| Robot colaborativo | Cerca de humanos | Crítico+ |

## Integración con pm-workspace

- `/security-review` incluye checklist robótico si proyecto tiene MCU
- `commit-guardian` verifica ROB-01 a ROB-05 en código embedded
- `/threat-model` incluye STRIDE robótico como template
- `/robotics-safety-audit` — comando nuevo (Fase 2)
