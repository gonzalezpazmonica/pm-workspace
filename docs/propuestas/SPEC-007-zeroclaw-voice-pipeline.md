---
id: SPEC-007
title: SPEC-007: ZeroClaw Voice Pipeline — Conversación bidireccional fluida
status: PROPOSED
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-007: ZeroClaw Voice Pipeline — Conversación bidireccional fluida

> Status: **DRAFT** · Fecha: 2026-03-21
> "Hablar con Savia como hablas con una persona."

---

## Problema

ZeroClaw tiene micro y altavoz, pero sin un pipeline de voz
completo es solo un walkie-talkie. Necesitamos:
1. El humano habla → ZeroClaw escucha → texto llega a Savia
2. Savia responde → texto se convierte en voz → ZeroClaw habla
3. Todo fluido, sin botones, con wake word

## Arquitectura: 3 niveles de procesamiento

```
┌──────────────────────────────────────────────────┐
│ NIVEL 1 — EN EL ESP32 (siempre activo, <1s)     │
│                                                   │
│  Wake Word Detection (ESP-SR WakeNet)             │
│  "Oye Savia" → activa grabación                  │
│  VAD (Voice Activity Detection) → detecta fin    │
│  Audio capture I2S → buffer → stream WiFi        │
├──────────────────────────────────────────────────┤
│ NIVEL 2 — EN EL HOST (PC/RPi, ~1-3s)            │
│                                                   │
│  STT: whisper.cpp (tiny/base, 273-388MB RAM)     │
│  LLM: Claude via Claude Code (o local vía Ollama)│
│  TTS: Piper (local, ~50ms/frase) o pyttsx3      │
│  Audio encode → stream WiFi → ESP32 altavoz      │
├──────────────────────────────────────────────────┤
│ NIVEL 3 — EN LA NUBE (opcional, mejor calidad)   │
│                                                   │
│  STT: Whisper API (si el usuario lo permite)      │
│  LLM: Claude API (vía Claude Code)               │
│  TTS: ElevenLabs/OpenAI TTS (si el usuario paga) │
└──────────────────────────────────────────────────┘
```

### Flujo completo

```
Humano dice "Oye Savia, ¿qué pin uso para el servo?"
  │
  ▼ ESP32 (Nivel 1)
  WakeNet detecta "Oye Savia" → LED azul
  I2S graba audio → VAD detecta fin de frase
  Stream PCM 16kHz/16bit via WiFi HTTP POST
  │
  ▼ Host (Nivel 2)
  whisper.cpp transcribe → "¿qué pin uso para el servo?"
  Claude Code procesa → genera respuesta
  Protocolo Voz/Consola decide qué va a voz y qué a pantalla
  Piper TTS genera WAV de la respuesta de voz
  Stream WAV via WiFi → ESP32
  │
  ▼ ESP32 (Nivel 1)
  I2S reproduce audio → altavoz
  LED verde durante reproducción
  Vuelve a escuchar wake word
```

---

## Stack de software libre

### En el ESP32 (MicroPython o ESP-IDF C)

| Componente | Proyecto | Licencia |
|-----------|----------|----------|
| Wake word | ESP-SR WakeNet | Apache 2.0 |
| VAD | ESP-SR VADNet | Apache 2.0 |
| Audio I2S | ESP-IDF driver | Apache 2.0 |
| WiFi HTTP | urequests/ESP-IDF | Apache 2.0 |

### En el Host (Python)

| Componente | Proyecto | Licencia | Recurso |
|-----------|----------|----------|---------|
| STT | whisper.cpp + bindings | MIT | ~273MB RAM (tiny) |
| TTS | Piper TTS | MIT/GPL | ~50ms/frase, español |
| TTS fallback | pyttsx3 + espeak | MIT | Zero deps extra |
| VAD server | Silero VAD | MIT | Detecta silencios |
| Audio stream | Wyoming protocol | MIT | JSONL + PCM |
| LLM | Claude Code (nativo) | — | Ya disponible |

### Alternativa MicroPython pura (Fase 0)

Para el ESP32 que tienes ahora (sin ESP-SR):
```python
# Sin wake word: botón físico activa grabación
# Sin I2S mic: audio via serial desde PC
# TTS: pyttsx3 en el PC, reproducción local
```

---

## Protocolo Wyoming adaptado para ZeroClaw

```
# Handshake
ESP32 → Host: {"type": "describe", "device": "zeroclaw-01"}
Host → ESP32: {"type": "info", "stt": "whisper-tiny", "tts": "piper-es"}

# Wake word detected
ESP32 → Host: {"type": "wake-word", "word": "oye-savia", "ts": "..."}

# Audio stream (chunked)
ESP32 → Host: {"type": "audio-start", "rate": 16000, "width": 2, "ch": 1}
ESP32 → Host: [raw PCM bytes, 512 samples per chunk]
ESP32 → Host: {"type": "audio-stop"}

# Transcription result
Host → ESP32: {"type": "transcript", "text": "¿qué pin uso para el servo?"}

# Savia response (may be split voice + console)
Host → ESP32: {"type": "voice-response", "text": "Usa el GPIO 23 con PWM"}
Host → ESP32: {"type": "audio-start", "rate": 22050, "width": 2, "ch": 1}
Host → ESP32: [raw PCM bytes from Piper TTS]
Host → ESP32: {"type": "audio-stop"}
```

---

## Latencia objetivo

| Fase | Tiempo | Acumulado |
|------|--------|-----------|
| Wake word detection | <200ms | 200ms |
| Audio capture (frase típica) | ~2s | 2.2s |
| WiFi transfer (16kHz, 2s) | ~100ms | 2.3s |
| STT whisper.cpp tiny | ~1s | 3.3s |
| Claude Code response | ~2s | 5.3s |
| TTS Piper | ~200ms | 5.5s |
| WiFi transfer audio back | ~200ms | 5.7s |
| **Total wake-to-voice** | | **~6s** |

Comparable a un asistente de voz comercial. Mejorable con:
- Streaming STT (transcribir mientras habla) → -1s
- Streaming TTS (empezar a hablar antes de terminar) → -1s
- Modelo Whisper quantizado → -0.5s

---

## Fases de implementación

### Fase 0 — Serial + pyttsx3 (tu ESP32 actual)

- Botón en ESP32 → señal serial → PC graba audio del micro del PC
- pyttsx3 en PC para TTS
- Sin wake word, sin WiFi audio
- Prueba de concepto del protocolo

### Fase 1 — WiFi audio unidireccional

- ESP32-S3 + INMP441 mic
- Audio I2S → HTTP POST al host
- whisper.cpp en host → transcript
- Savia responde en consola (sin TTS aún)

### Fase 2 — TTS bidireccional

- Piper TTS en host → WAV stream → ESP32
- ESP32 + MAX98357A reproduce
- Flujo completo: hablar → escuchar → responder

### Fase 3 — Wake word + VAD

- ESP-SR WakeNet en ESP32-S3 (requiere ESP-IDF, no MicroPython)
- "Oye Savia" activa escucha
- VAD detecta fin de frase automáticamente
- Conversación hands-free completa

### Fase 4 — Streaming optimizado

- STT streaming (transcribir mientras habla)
- TTS streaming (hablar mientras genera)
- Latencia target: <4s wake-to-voice
