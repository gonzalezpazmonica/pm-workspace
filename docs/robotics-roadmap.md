# Savia Robotics — Roadmap

> Preparando a Savia para el salto de la IA al mundo físico.

## Visión

Savia será experta en arquitectura, programación y seguridad robótica:
desde microcontroladores (ESP32, STM32) hasta robots controlados por IA
(LeRobot, ROS2). El objetivo: que cualquier equipo pueda diseñar,
programar y asegurar sistemas robóticos con la misma fluidez que hoy
gestionan sprints de software.

## Stack completo

| Capa | Tecnología | Lenguaje | Estado |
|------|-----------|----------|--------|
| AI/ML | LeRobot, RT-X, Pi0 | Python | Fase 5 |
| Robot OS | ROS2, Nav2, MoveIt2 | C++/Python | Fase 4 |
| Edge | RPi 5, Jetson, micro-ROS | Python/C++ | Fase 4 |
| MCU | ESP32, STM32, RP2040 | MicroPython, Rust, C | Fase 2-3 |
| Hardware | Sensores, actuadores | I2C/SPI/PWM | Fase 2 |

## Fases

### Fase 1 — Fundamentos (completada)

- Spec SPEC-004 con arquitectura completa
- Regla `robotics-safety.md` con 10 principios inmutables
- Language pack MicroPython (auto-carga en boot.py/main.py)
- Modelo STRIDE adaptado a robótica

### Fase 2 — Lab con ESP32

- Agente `micropython-developer`
- Conexión serial al ESP32 desde Savia
- Tests E2E: LED → sensor → servo → WiFi
- Comando `/flash-esp32`

### Fase 3 — Embedded Rust

- Language pack Rust Embassy
- Agente `rust-embedded-developer`
- Build con PlatformIO o cargo-espflash
- Secure boot + flash encryption

### Fase 4 — ROS2

- Language pack ROS2 C++/Python
- Agente `ros2-developer`
- micro-ROS bridge (ESP32 ↔ ROS2)
- SROS2 seguridad completa

### Fase 5 — IA Física

- LeRobot integration
- Pipeline: demo → train → deploy
- Safety guardrails (geofencing, torque limits)
- Agente `robotics-security-auditor`

## Seguridad — Los 10 mandamientos

1. E-stop hardware independiente del software
2. Watchdog en todo actuador
3. Límites de torque/velocidad en firmware
4. Geofencing para robots móviles
5. Auth obligatoria en control remoto
6. OTA solo con firma criptográfica
7. Redundancia en sensores de seguridad
8. Fail-safe: si falla, SE PARA
9. Audit log de acciones físicas
10. Rate limiting en comandos a actuadores

## Referencias

- [LeRobot](https://github.com/huggingface/lerobot) — IA para robótica
- [micro-ROS](https://micro.ros.org/) — ROS2 en microcontroladores
- [Embassy](https://github.com/embassy-rs/embassy) — Rust async embedded
- [ESP-HAL](https://github.com/esp-rs/esp-hal) — Rust en ESP32
- [MicroPython](https://micropython.org/) — Python en MCUs
- [SROS2](https://design.ros2.org/articles/ros2_dds_security.html) — seguridad ROS2
