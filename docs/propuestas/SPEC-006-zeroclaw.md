---
id: SPEC-006
title: SPEC-006: ZeroClaw — Los sentidos físicos de Savia
status: PROPOSED
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-006: ZeroClaw — Los sentidos físicos de Savia

> Status: **DRAFT** · Fecha: 2026-03-21
> "Savia puede pensar. ZeroClaw le da ojos, oídos y voz."

---

## Concepto

ZeroClaw es un dispositivo ESP32 que actúa como interfaz física
de Savia. Donde Savia es el cerebro (en Claude Code), ZeroClaw es
el cuerpo: un puente entre el mundo digital y el físico.

```
┌─────────────┐     WiFi/USB      ┌─────────────┐
│  Savia      │ ◄──────────────► │  ZeroClaw   │
│  (Claude)   │     JSON/MQTT     │  (ESP32)    │
│             │                   │             │
│  Piensa     │                   │  Oye  🎤    │
│  Decide     │                   │  Ve   📷    │
│  Habla      │                   │  Habla 🔊   │
│  Recuerda   │                   │  Siente 🌡️  │
│  Planifica  │                   │  Actúa ⚙️   │
└─────────────┘                   └─────────────┘
```

---

## Hardware mínimo (v0.1)

| Componente | Modelo | Precio aprox | Función |
|-----------|--------|-------------|---------|
| MCU | ESP32-S3 DevKit | ~8€ | Cerebro local + WiFi + BLE |
| Micrófono | INMP441 (I2S) | ~3€ | Escuchar al humano |
| Altavoz | MAX98357A (I2S) + speaker 3W | ~4€ | Hablar al humano |
| Cámara | OV2640 (ESP32-CAM) | ~5€ | Ver el entorno |
| Total v0.1 | | ~20€ | Oye + Habla + Ve |

### Hardware expandido (v0.2+)

| Componente | Función |
|-----------|---------|
| Sensor temp/hum (BME280) | Monitorizar entorno del lab |
| LED NeoPixel ring | Indicador visual de estado |
| Servo SG90 | Primera actuación física |
| Sensor distancia (VL53L0X) | Percepción espacial |
| Display OLED 0.96" (SSD1306) | Mostrar estado/mensajes |

---

## Arquitectura de software

### En el ESP32 (MicroPython)

```
zeroclaw/
├── boot.py              ← WiFi connect + config
├── main.py              ← Main loop + watchdog
├── lib/
│   ├── audio_in.py      ← Captura audio I2S (INMP441)
│   ├── audio_out.py     ← Reproducción I2S (MAX98357A)
│   ├── camera.py        ← Captura imagen OV2640
│   ├── sensors.py       ← Lectura de sensores
│   ├── actuators.py     ← Control de servos/LEDs
│   ├── comms.py         ← WiFi HTTP + MQTT + WebSocket
│   └── status.py        ← LED de estado + display OLED
├── config.json          ← WiFi SSID, Savia endpoint
└── certs/               ← TLS certs para auth
```

### Protocolo Savia ↔ ZeroClaw

```json
// ZeroClaw → Savia (evento)
{
  "type": "audio_capture",
  "device": "zeroclaw-01",
  "timestamp": "2026-03-21T20:00:00Z",
  "payload": {
    "audio_b64": "base64_wav_data...",
    "duration_ms": 3000,
    "sample_rate": 16000
  }
}

// Savia → ZeroClaw (comando)
{
  "type": "speak",
  "text": "Conecta el cable rojo al pin 3V3 del ESP32",
  "priority": "normal",
  "voice": "es-female"
}

// Savia → ZeroClaw (captura)
{
  "type": "capture_image",
  "resolution": "640x480",
  "reply_to": "assembly-verify-step-3"
}
```

### Tipos de mensaje

| Dirección | Tipo | Descripción |
|-----------|------|-------------|
| ZC → S | `audio_capture` | Audio grabado del micrófono |
| ZC → S | `image_capture` | Foto de la cámara |
| ZC → S | `sensor_data` | Lectura de sensores |
| ZC → S | `button_press` | Interacción física |
| ZC → S | `heartbeat` | Estado + uptime |
| S → ZC | `speak` | Texto para TTS local o audio stream |
| S → ZC | `capture_image` | Pedir foto |
| S → ZC | `set_led` | Color/patrón del LED de estado |
| S → ZC | `move_servo` | Mover actuador |
| S → ZC | `play_tone` | Beep/alarma |
| S → ZC | `ota_update` | Firmware update (firmado) |

---

## Flujo: Guía de ensamblaje con ZeroClaw

```
1. Usuario: "Savia, ayúdame a montar el sensor"
   → ZeroClaw captura audio → envía a Savia

2. Savia procesa (Whisper/local STT):
   → Identifica petición: assembly-guide bme280
   → Genera pasos

3. Savia → ZeroClaw: speak "Paso 1: Coge 4 cables Dupont"
   → ZeroClaw reproduce por altavoz

4. Usuario conecta cables

5. Usuario: "Listo" (o pulsa botón)
   → ZeroClaw envía audio/botón

6. Savia → ZeroClaw: capture_image
   → ZeroClaw toma foto → envía a Savia

7. Savia analiza foto (Claude Vision):
   → Verifica conexiones visualmente
   → "Los cables están correctos. Paso 2..."
   o "Veo que el cable amarillo no está en GPIO22, muévelo"
```

---

## Seguridad

### Comunicación

- WiFi con WPA2/WPA3 (nunca AP abierto)
- HTTPS/WSS para todo tráfico Savia ↔ ZeroClaw
- Token de auth rotado cada 24h
- mDNS para descubrimiento local (zeroclaw.local)

### Firmware

- Secure boot v2 en ESP32-S3
- Flash encryption habilitada
- OTA solo con firma ed25519
- Rollback automático si nuevo firmware falla

### Físico

- Watchdog obligatorio (5s timeout)
- Si pierde conexión con Savia >30s: modo standby
- LED parpadea rojo si no hay conexión
- Botón físico de reset accesible

---

## Implementación por fases

### Fase 0 — Proof of concept (tu ESP32 actual)

- MicroPython básico
- LED de estado (GPIO2 integrado)
- Comunicación serial USB con Savia
- Comando: "parpadea", "lee temperatura" (si hay sensor)

### Fase 1 — Audio (ESP32-S3 + INMP441 + MAX98357A)

- Captura de audio I2S → envío a Savia
- Reproducción de TTS desde Savia
- Protocolo JSON via WiFi HTTP

### Fase 2 — Visión (+ OV2640)

- Captura de imágenes bajo demanda
- Envío a Savia para análisis con Claude Vision
- Verificación visual de conexiones de hardware

### Fase 3 — Actuación (+ servos + sensores)

- Control de servos desde Savia
- Lectura de sensores ambientales
- ZeroClaw como estación de monitorización

### Fase 4 — Autonomía parcial

- Procesamiento local de comandos simples
- Cache de respuestas frecuentes
- Modo offline con comandos pre-programados

---

## Nombre: ZeroClaw

"Zero" — empezamos desde cero, bare-metal, sin OS pesado.
"Claw" — la garra, la extensión física. El primer contacto
de Savia con el mundo real. Cada vez que ZeroClaw agarre algo,
será Savia agarrando el mundo físico por primera vez.
