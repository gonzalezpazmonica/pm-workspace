# ZeroClaw Voice Architecture — Research Report

> Investigación: 2026-03-21 | Objetivo: Arquitectura de voz bidireccional
> ESP32 + Host Linux para Savia

---

## Estado del Arte (marzo 2026)

### Proyectos de referencia analizados

| Proyecto | Arquitectura | Wake Word | STT | TTS | Latencia |
|----------|-------------|-----------|-----|-----|----------|
| **Xiaozhi** (78/xiaozhi-esp32) | ESP32 + servidor WebSocket | WakeNet (on-device) | Whisper cloud | Cloud TTS | ~1-2s |
| **Willow** (heywillow.io) | ESP32-S3 + Willow Inference Server | On-device DSP | faster-whisper local | Piper local | 300-700ms |
| **ESPHome Voice** | ESP32-S3 + Home Assistant | microWakeWord (on-device) | Wyoming/Whisper | Wyoming/Piper | ~1s |
| **ESP32 Voice Assistant** (arpy8) | ESP32 + Python backend | Botón físico | faster-whisper tiny | Piper | ~800ms |

### Conclusión clave

**Willow es la referencia** — demuestra que 300-700ms de latencia es
alcanzable con procesamiento 100% local. La clave: ESP32 hace SOLO
captura de audio + wake word + reproducción. El host hace TODO lo pesado.

---

## Arquitectura Propuesta: ZeroClaw Voice

### Principio fundamental

```
ESP32 = oídos y boca (sensores + actuadores)
Host  = cerebro (STT + LLM + TTS)
```

El ESP32 NO hace inferencia de IA. Hace lo que mejor sabe hacer:
I2S, GPIO, WiFi, y ejecutar modelos tiny de wake word.

### Pipeline completo

```
[1] ESP32: Micrófono I2S → buffer PCM 16kHz/16bit
        ↓
[2] ESP32: Wake word detection (WakeNet/microWakeWord, ~200KB RAM)
        ↓ (wake word detectado)
[3] ESP32: LED azul + streaming audio via WebSocket al host
        ↓
[4] Host: Silero VAD detecta inicio/fin de habla (~1ms/chunk)
        ↓ (fin de habla detectado)
[5] Host: faster-whisper transcribe (~200-500ms en CPU, modelo tiny/base)
        ↓
[6] Host: Claude API / Savia procesa texto → genera respuesta
        ↓
[7] Host: Piper TTS sintetiza voz (~200ms, modelo es_ES medium)
        ↓
[8] Host: Streaming audio PCM via WebSocket al ESP32
        ↓
[9] ESP32: DAC/I2S → amplificador → altavoz
```

### Latencia estimada end-to-end

| Fase | Componente | Tiempo |
|------|-----------|--------|
| Wake word → stream start | ESP32 | ~50ms |
| VAD (detectar fin habla) | Silero VAD | ~300ms después de silencio |
| STT | faster-whisper tiny | ~200-400ms |
| LLM | Claude API | ~500-1500ms |
| TTS | Piper | ~150-300ms |
| Audio streaming back | WebSocket | ~50ms |
| **Total** | | **~1.2-2.6s** |

Para modo local sin Claude (respuestas predefinidas): **~700ms-1.2s**

---

## Componentes por Capa

### Capa 1: ESP32 (Firmware C/MicroPython)

| Componente | Opción recomendada | RAM | Alternativa |
|-----------|-------------------|-----|-------------|
| Wake word | ESP-SR WakeNet9s | ~200KB | microWakeWord (~50KB) |
| Audio capture | I2S INMP441 16kHz | ~32KB buffer | SPH0645 |
| Audio output | I2S MAX98357A | ~8KB buffer | DAC interno (peor calidad) |
| Protocolo | WebSocket binario | ~4KB | UDP (menos fiable) |
| LED feedback | NeoPixel/WS2812 | <1KB | LED RGB simple |

**Total RAM estimado**: ~250KB de ~520KB disponibles en ESP32-S3

### Capa 2: Host — Voice Daemon (Python)

| Componente | Librería | Modelo | Tamaño | Latencia |
|-----------|---------|--------|--------|----------|
| VAD | Silero VAD | ONNX | ~2MB | <1ms/chunk |
| STT | faster-whisper | tiny.en / base | 75MB / 139MB | 200-500ms |
| TTS | Piper | es_ES medium | ~60MB | 150-300ms |
| Speaker ID | SpeechBrain ECAPA-TDNN | voxceleb | ~25MB | ~100ms |
| WebSocket | websockets (Python) | — | — | <10ms |

**Total disco**: ~300MB | **RAM runtime**: ~500MB-1GB

### Capa 3: Integración con Savia (Claude Code)

El voice daemon actúa como puente:

```
Voice Daemon ←→ Claude Code CLI (stdin/stdout pipe)
     ↑                    ↓
  Audio I/O          Texto I/O
     ↑                    ↓
  ESP32/Mic          Savia responde
```

Opciones de integración:
1. **Pipe directo**: `echo "comando" | claude -p` (simple, alta latencia)
2. **Socket local**: daemon se comunica con sesión Claude abierta
3. **API directa**: daemon llama a Anthropic API (más rápido, sin CLI)

**Recomendación**: empezar con pipe, migrar a API directa para latencia.

---

## Modos de Operación

### Modo 1: Conversación (siempre activo)

```
Wake word → escuchar → transcribir → Savia responde → TTS → hablar
```

### Modo 2: Reunión (transcripción continua)

```
VAD continuo → transcribir todo → speaker diarization → digest
```

### Modo 3: Comando rápido (sin LLM)

```
Wake word → escuchar → transcribir → pattern match local → TTS rápido
Ejemplo: "Savia, hora" → "Son las tres y cuarto"
```

### Modo 4: Asistencia hardware (guided work)

```
Wake word → escuchar → transcribir → Savia guía paso a paso → TTS
Ejemplo: "Savia, siguiente paso" → "Conecta el cable rojo al pin 3V3"
```

---

## Plan de Implementación

### Fase 1: Voice Daemon en Host (esta semana)

Sin ESP32, solo micrófono del PC:
1. Daemon Python con Silero VAD + faster-whisper + Piper
2. Escucha continua del micrófono
3. Transcribe cuando detecta habla
4. Pasa texto a Claude, recibe respuesta
5. Sintetiza y reproduce por altavoz

**Entregable**: hablar con Savia desde el PC

### Fase 2: ESP32 como Satélite (siguiente)

1. Firmware ESP32: I2S mic + WebSocket client + wake word
2. Voice daemon acepta conexiones WebSocket
3. Audio fluye ESP32 → Host → ESP32

**Entregable**: hablar con Savia desde ZeroClaw

### Fase 3: Speaker ID + Reuniones (después)

1. Enrollment de voces con ECAPA-TDNN
2. Diarización en tiempo real
3. Modo reunión con digest automático

---

## Dependencias a Instalar

```bash
# En el venv de whisper (~/.savia/whisper-env)
pip install faster-whisper    # STT optimizado
pip install silero-vad        # o torch hub
pip install piper-tts         # TTS local
pip install websockets        # comunicación ESP32
pip install sounddevice       # captura de audio del mic
pip install numpy             # procesamiento de audio
```

---

## Fuentes

- [Xiaozhi ESP32](https://github.com/78/xiaozhi-esp32) — MIT, referencia MCP
- [Willow](https://heywillow.io/) — Referencia latencia local
- [ESP-SR / ESP-Skainet](https://github.com/espressif/esp-sr) — Wake word Espressif
- [microWakeWord](https://esphome.io/components/micro_wake_word/) — Wake word ultraligero
- [Silero VAD](https://github.com/snakers4/silero-vad) — VAD 1ms/chunk, MIT
- [faster-whisper](https://github.com/SYSTRAN/faster-whisper) — STT 4x más rápido
- [Piper TTS](https://github.com/rhasspy/piper) — TTS local, 35+ idiomas
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) — Framework unificado STT/TTS/VAD
- [SpeechBrain ECAPA-TDNN](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb) — Speaker ID
- [Wyoming Protocol](https://www.home-assistant.io/integrations/wyoming/) — Estándar satélites
- [ESP32 Voice Assistant MCP](https://hackaday.io/project/204691-esp32-ai-voice-assistant-with-mcp-integration)
- [Hackaday ESP32 AI Voice](https://www.hackster.io/ElectroScopeArchive/esp32-ai-voice-assistant-with-mcp-integration-2598c8)
