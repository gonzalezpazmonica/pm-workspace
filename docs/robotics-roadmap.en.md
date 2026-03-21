# Savia Robotics — Roadmap

> Preparing Savia for AI's leap into the physical world.

## Vision

Savia will become expert in robotics architecture, programming, and
security: from microcontrollers (ESP32, STM32) to AI-controlled robots
(LeRobot, ROS2). The goal: any team can design, program, and secure
robotic systems as fluidly as they manage software sprints today.

## Full Stack

| Layer | Technology | Language | Phase |
|-------|-----------|----------|-------|
| AI/ML | LeRobot, RT-X, Pi0 | Python | Phase 5 |
| Robot OS | ROS2, Nav2, MoveIt2 | C++/Python | Phase 4 |
| Edge | RPi 5, Jetson, micro-ROS | Python/C++ | Phase 4 |
| MCU | ESP32, STM32, RP2040 | MicroPython, Rust, C | Phase 2-3 |
| Hardware | Sensors, actuators | I2C/SPI/PWM | Phase 2 |

## Phases

### Phase 1 — Foundations (completed)

- SPEC-004 with full architecture
- `robotics-safety.md` rule with 10 immutable principles
- MicroPython language pack (auto-loads on boot.py/main.py)
- STRIDE threat model adapted for robotics

### Phase 2 — ESP32 Lab

- `micropython-developer` agent
- Serial connection to ESP32 from Savia
- E2E tests: LED → sensor → servo → WiFi
- `/flash-esp32` command

### Phase 3 — Embedded Rust

- Rust Embassy language pack
- `rust-embedded-developer` agent
- Build with PlatformIO or cargo-espflash
- Secure boot + flash encryption

### Phase 4 — ROS2

- ROS2 C++/Python language pack
- `ros2-developer` agent
- micro-ROS bridge (ESP32 ↔ ROS2)
- Full SROS2 security

### Phase 5 — Physical AI

- LeRobot integration
- Pipeline: record demo → train → deploy to robot
- Safety guardrails (geofencing, torque limits)
- `robotics-security-auditor` agent

## Security — The 10 Commandments

1. Hardware E-stop independent from software
2. Watchdog timer on every actuator
3. Torque/speed limits in firmware
4. Geofencing for mobile robots
5. Mandatory auth for remote control
6. OTA only with cryptographic signature
7. Redundancy in safety-critical sensors
8. Fail-safe: if it fails, it STOPS
9. Audit log of all physical actions
10. Rate limiting on actuator commands

## References

- [LeRobot](https://github.com/huggingface/lerobot) — AI for robotics
- [micro-ROS](https://micro.ros.org/) — ROS2 on microcontrollers
- [Embassy](https://github.com/embassy-rs/embassy) — Rust async embedded
- [ESP-HAL](https://github.com/esp-rs/esp-hal) — Rust on ESP32
- [MicroPython](https://micropython.org/) — Python on MCUs
- [SROS2](https://design.ros2.org/articles/ros2_dds_security.html) — ROS2 security
