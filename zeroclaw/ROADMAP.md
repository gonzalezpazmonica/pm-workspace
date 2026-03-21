# SaviaClaw Roadmap — De hardware a autonomia

> Estado: v0.9 | Ultima revision: 2026-03-21
> Objetivo: Savia con presencia fisica, voz, sensores y accion en el mundo real.

---

## Fase 0 — Fundamentos (COMPLETADA)

- [x] Firmware ESP32 (MicroPython): selftest, heartbeat, LCD, WiFi, comandos
- [x] Host bridge: serial bidireccional con JSON
- [x] Setup script: flash + deploy automatizado
- [x] Brain Bridge: ask → Claude CLI → LCD
- [x] Daemon systemd: reconexion automatica, background
- [x] Guardrails: 7 gates deterministas (size, rate, PII, storage, command, cleanup, audit)
- [x] Tests: 23 tests sin hardware (bridge + guardrails)
- [x] Context Guardian: deteccion de contradicciones en reuniones

## Fase 1 — Estabilidad (EN CURSO)

- [x] RotatingFileHandler en daemon (log no crece indefinidamente)
- [ ] Signal handling (SIGTERM/SIGINT → shutdown limpio)
- [ ] Health check: fichero de estado legible por scripts externos
- [ ] Auto-recovery: deteccion de estado stuck, restart del serial
- [ ] Daemon status command: `python3 saviaclaw_daemon.py --status`
- [ ] Tests del daemon (sin hardware)

## Fase 2 — Voz (PROXIMA)

- [ ] STT: integracion Whisper (local, modelo tiny/base)
- [ ] TTS: integracion Piper o espeak-ng (local, sin cloud)
- [ ] Voice module: mic del host → STT → Claude → TTS → speaker
- [ ] Wake word: deteccion "Savia" para activar escucha
- [ ] Voice-console protocol: que va a voz, que a pantalla
- [ ] LCD sync: mostrar estado de voz en LCD del ESP32

## Fase 3 — Sensores y mundo fisico

- [ ] BME280: temperatura, humedad, presion (I2C)
- [ ] Sensor de luz (ADC)
- [ ] Alertas autonomas: umbrales → notificacion
- [ ] Logging de series temporales en host
- [ ] Dashboard de sensores (consola o web local)

## Fase 4 — Actuadores

- [ ] Servo/motor control con limites de seguridad (ROB-01, ROB-02)
- [ ] E-stop fisico (ROB-06)
- [ ] Rate limiting en comandos de actuador (ROB-10)
- [ ] Watchdog por actuador (ROB-01)

## Fase 5 — Autonomia

- [ ] Behavior Tree engine en firmware (tick-based)
- [ ] Tareas programadas: monitoreo periodico sin host
- [ ] OTA firmware update con firma (ROB-04)
- [ ] Modo offline: ESP32 opera con rutinas locales si pierde host

## Fase 6 — Reunion y colaboracion

- [ ] Meeting mode completo: transcripcion + diarizacion + digest
- [ ] Voice enrollment (embeddings, con consentimiento RGPD)
- [ ] Participante proactiva: intervencion en ventanas de silencio
- [ ] Integracion con sprint: action items → backlog

---

## Principios inmutables

1. **Offline-first**: todo funciona sin internet. Cloud es bonus, no requisito.
2. **Fail-safe**: si algo falla, Savia para. No hay degradacion en seguridad.
3. **Privacy-first**: audio y fotos son N3 minimo (RGPD Art. 9).
4. **Hardware-verified**: nada se mergea sin probar en el ESP32 fisico.
5. **150 lineas max**: aplica tambien al firmware y host.

## Dependencias de hardware

| Componente | Estado | Necesario para |
|------------|--------|----------------|
| ESP32 DevKit | Conectado | Todo |
| LCD 16x2 I2C | Conectado | Fase 0+ |
| Microfono USB | Pendiente | Fase 2 |
| Speaker/buzzer | Pendiente | Fase 2 |
| BME280 | Pendiente | Fase 3 |
| Servo SG90 | Pendiente | Fase 4 |
