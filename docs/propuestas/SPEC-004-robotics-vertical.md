---
id: SPEC-004
title: SPEC-004: Savia Robotics Vertical — IA en el mundo físico
status: PROPOSED
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
priority: baja
---

# SPEC-004: Savia Robotics Vertical — IA en el mundo físico

> Status: **DRAFT** · Fecha: 2026-03-21
> Visión: preparar a Savia para el salto de la IA al mundo físico

---

## Contexto

La IA está cruzando del software al hardware. Los foundation models (RT-X,
LeRobot, Pi0) ya controlan robots reales. micro-ROS conecta microcontroladores
a ROS2. Embassy pone Rust en ESP32. MicroPython democratiza la programación
de MCUs. La seguridad robótica es el nuevo OWASP.

Savia necesita ser experta en este dominio AHORA, antes de que el mercado
lo normalice.

---

## Stack tecnológico del mundo físico

```
┌─────────────────────────────────────────────────┐
│  CAPA 5 — AI/ML Foundation Models               │
│  LeRobot, RT-X, Pi0, SmolVLA, GR00T             │
│  Imitation Learning, RL, Vision-Language-Action   │
├─────────────────────────────────────────────────┤
│  CAPA 4 — Robot Operating System                 │
│  ROS2 (Jazzy/Rolling), Navigation2, MoveIt2      │
│  DDS middleware, SROS2 security, tf2 transforms   │
├─────────────────────────────────────────────────┤
│  CAPA 3 — Edge Computing                         │
│  Raspberry Pi 5, Jetson Orin, Orange Pi           │
│  Linux RT, Docker, micro-ROS Agent               │
├─────────────────────────────────────────────────┤
│  CAPA 2 — Microcontroladores                     │
│  ESP32, STM32, RP2040, Arduino, Teensy            │
│  FreeRTOS, Zephyr, NuttX, bare-metal              │
│  C/C++, Rust (Embassy), MicroPython               │
├─────────────────────────────────────────────────┤
│  CAPA 1 — Hardware Físico                        │
│  Sensores (IMU, LIDAR, cámaras, ultrasonido)      │
│  Actuadores (servos, steppers, DC motors, grippers)│
│  Protocolos: I2C, SPI, UART, CAN, PWM            │
└─────────────────────────────────────────────────┘
```

---

## Lenguajes por capa

| Capa | Lenguaje principal | Alternativa | Por qué |
|------|-------------------|-------------|---------|
| 5 AI/ML | Python (PyTorch) | — | Ecosistema ML |
| 4 ROS2 | C++ (rclcpp) | Python (rclpy) | Rendimiento RT |
| 3 Edge | Python + C++ | Rust | Versatilidad |
| 2 MCU | C/C++ (Arduino) | Rust (Embassy), MicroPython | Según MCU |
| 1 HW | — | — | Datasheets |

---

## Seguridad robótica — Modelo de amenazas

### STRIDE para robótica

| Amenaza | Ejemplo robótico | Mitigación |
|---------|-------------------|------------|
| Spoofing | Suplantación de nodo ROS2 | SROS2 + PKI mutual auth |
| Tampering | Inyección de comandos motores | Firmado de mensajes DDS |
| Repudiation | Negación de acción del robot | Audit log inmutable |
| Info Disclosure | Fuga de mapa SLAM/cámara | Cifrado AES-GCM en topics |
| DoS | Saturar bus CAN/topic ROS | Rate limiting + QoS DDS |
| Elevation | Escalar de sensor a actuador | Access control por enclave |

### Capas de seguridad

```
Capa | Mecanismo | Herramienta
─────┼───────────┼─────────────────────────
DDS  | Cifrado, auth, access control | SROS2, governance.p7s
ROS2 | Enclaves de seguridad | ros2 security CLI
MCU  | Secure boot, flash encryption | ESP32 eFuse, STM32 RDP
Físico | E-stop hardware, watchdog | Circuito independiente
Red  | TLS, VPN, firewall | WireGuard, iptables
AI   | Guardrails de acción | Geofencing, torque limits
```

---

## Language Packs para robótica

### Robotics C++ (ROS2/Embedded)

```yaml
paths: ["**/*.cpp", "**/*.hpp", "**/CMakeLists.txt", "**/*.launch.py"]
conventions:
  - RAII para recursos de hardware
  - std::unique_ptr para ownership de nodos
  - No excepciones en código RT (return codes)
  - Callbacks non-blocking (< 1ms en fast timer)
rules:
  - REJECT: malloc/new en path RT (usar pool allocators)
  - REJECT: sleep() en callbacks (usar timers ROS2)
  - REJECT: topic sin QoS profile explícito
  - REQUIRE: watchdog en todo nodo que controla actuador
```

### Robotics Rust (Embassy/ESP)

```yaml
paths: ["**/*.rs", "**/Cargo.toml", "**/memory.x"]
conventions:
  - no_std por defecto, std solo en edge
  - Embassy async para multitarea cooperativa
  - HAL traits de embedded-hal para portabilidad
  - Typestate pattern para estado de periféricos
rules:
  - REJECT: unsafe sin comentario justificativo
  - REJECT: unwrap() en código de producción (usar defmt)
  - REQUIRE: #[embassy_executor::task] para tareas async
  - REQUIRE: timeout en toda operación I/O
```

### Robotics MicroPython (ESP32 prototipado)

```yaml
paths: ["**/*.py", "**/boot.py", "**/main.py"]
conventions:
  - machine module para GPIO, I2C, SPI, PWM
  - uasyncio para concurrencia cooperativa
  - micropython.const() para constantes optimizadas
  - gc.collect() explícito en loops largos
rules:
  - REJECT: import os (usar uos)
  - REJECT: float en cálculos de control (usar int escalado)
  - REQUIRE: try/except en todo acceso a periférico
  - REQUIRE: watchdog timer (machine.WDT)
```

---

## Agentes especializados (propuesta)

| Agente | Modelo | Especialidad |
|--------|--------|-------------|
| `ros2-developer` | Sonnet | Nodos ROS2, launch files, Nav2, MoveIt2 |
| `embedded-developer` | Sonnet | C/C++ para MCU, Arduino, PlatformIO |
| `rust-embedded-developer` | Sonnet | Embassy, esp-hal, no_std Rust |
| `micropython-developer` | Sonnet | MicroPython en ESP32, RP2040 |
| `robotics-security-auditor` | Opus | SROS2, STRIDE robótico, secure boot |
| `hardware-architect` | Opus | Selección MCU, sensores, actuadores, BOM |

---

## Integración con ESP32 (lab de test)

Con el ESP32 disponible + MicroPython:

### Setup

```bash
# Flash MicroPython al ESP32
esptool.py --chip esp32 erase_flash
esptool.py --chip esp32 write_flash -z 0x1000 esp32-micropython.bin

# Conectar desde Savia
mpremote connect /dev/ttyUSB0 repl
```

### Test automatizado desde Savia

```python
# Savia puede ejecutar código en el ESP32 via serial
import serial
esp = serial.Serial('/dev/ttyUSB0', 115200)
esp.write(b"import machine; led = machine.Pin(2, machine.Pin.OUT)\r\n")
esp.write(b"led.value(1)\r\n")  # LED on
# Verificar respuesta
response = esp.readline()
```

### Flujo: Spec → Code → Flash → Test → Verify

```
/spec-generate "Control de servo via WiFi con ESP32"
  → Spec con endpoints REST, PWM config, safety limits
  → micropython-developer genera código
  → Flash al ESP32 via mpremote
  → Test E2E: enviar HTTP → verificar posición servo
  → Security audit: WiFi auth, rate limiting, watchdog
```

---

## Roadmap de implementación

### Fase 1 — Fundamentos (Sprint actual)

- [ ] Investigación y spec (este documento)
- [ ] Language pack: MicroPython para ESP32
- [ ] Regla: `robotics-safety.md` (E-stop, watchdog, limits)
- [ ] Skill: `web-research` para buscar datasheets y docs HW

### Fase 2 — Prototipado con ESP32 (Siguiente sprint)

- [ ] Agente: `micropython-developer`
- [ ] Comando: `/flash-esp32` (compilar + flashear via serial)
- [ ] Tests E2E: control de LED, servo, sensor de temp vía serial
- [ ] Integración con lab físico (ESP32 conectado por USB)

### Fase 3 — Embedded Rust (Sprint +2)

- [ ] Language pack: Rust Embassy para ESP32
- [ ] Agente: `rust-embedded-developer`
- [ ] PlatformIO integration para build/flash
- [ ] Reglas de seguridad: secure boot, flash encryption

### Fase 4 — ROS2 Integration (Sprint +3)

- [ ] Language pack: ROS2 C++/Python
- [ ] Agente: `ros2-developer`
- [ ] micro-ROS bridge ESP32 ↔ ROS2
- [ ] SROS2 security configuration

### Fase 5 — AI Physical Control (Sprint +4)

- [ ] Integración LeRobot para imitation learning
- [ ] Pipeline: grabar demo → entrenar → desplegar en robot
- [ ] Safety guardrails: geofencing, torque limits, E-stop
- [ ] Agente: `robotics-security-auditor`

---

## Principios de seguridad robótica

```
1. SIEMPRE E-stop hardware independiente del software
2. SIEMPRE watchdog timer en todo actuador
3. SIEMPRE límites de torque/velocidad en firmware
4. SIEMPRE geofencing para robots móviles
5. NUNCA control directo de actuador desde red sin auth
6. NUNCA firmware OTA sin firma criptográfica
7. NUNCA confiar en un solo sensor para decisiones de seguridad
8. SIEMPRE redundancia en sistemas de seguridad críticos
9. SIEMPRE audit log de todas las acciones físicas
10. SIEMPRE fail-safe: si algo falla, el robot SE PARA
```
