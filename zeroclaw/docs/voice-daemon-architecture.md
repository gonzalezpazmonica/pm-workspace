# ZeroClaw Voice Daemon — Architecture v2

> El daemon de voz NO es un chatbot. Es un adaptador I/O
> que conecta audio con una sesion REAL de Claude Code.

---

## Principio fundamental

```
Hablar con Savia por voz = escribir en Claude Code con el teclado
```

Mismo contexto, mismas reglas, misma memoria, misma personalidad.
La voz es solo otro canal de entrada/salida.

---

## Arquitectura

```
                    ┌─────────────────────────────────┐
                    │     Claude Code (sesion real)    │
                    │  CLAUDE.md + rules + profiles +  │
                    │  memory + projects + agents      │
                    │  --resume <session_id>           │
                    └──────────┬──────────┬────────────┘
                        stdin  │          │ stdout
                     (stream-json)   (stream-json)
                               │          │
                    ┌──────────▼──────────▼────────────┐
                    │       Voice Daemon (Python)       │
                    │                                   │
                    │  ┌─────────┐  ┌──────────────┐   │
                    │  │ Silero  │  │ faster-whisper│   │
                    │  │  VAD    │  │   STT (tiny)  │   │
                    │  └────┬────┘  └──────┬───────┘   │
                    │       │              │            │
                    │  ┌────▼──────────────▼────────┐  │
                    │  │    Session Manager          │  │
                    │  │  - mantiene session_id      │  │
                    │  │  - envia user messages      │  │
                    │  │  - recibe stream-json       │  │
                    │  │  - extrae texto respuesta   │  │
                    │  └────────────┬───────────────┘  │
                    │               │                   │
                    │  ┌────────────▼───────────────┐  │
                    │  │       edge-tts             │  │
                    │  │    (Elvira es-ES)          │  │
                    │  └───────────────────────────┘  │
                    └──────┬─────────────────┬────────┘
                      Mic  │                 │ Speaker
                    ┌──────▼─────┐    ┌──────▼──────┐
                    │  INMP441   │    │  MAX98357A  │
                    │  (o PC mic)│    │  (o PC spk) │
                    └────────────┘    └─────────────┘
```

---

## Protocolo Claude Code stream-json

### Input (stdin): un JSON por linea

```json
{
  "type": "user",
  "message": {"role": "user", "content": "texto del usuario"},
  "parent_tool_use_id": null,
  "session_id": ""
}
```

### Output (stdout): NDJSON con eventos

| Evento | Significado |
|--------|------------|
| `system/init` | Inicio sesion, contiene `session_id` |
| `assistant` | Respuesta (parcial o completa) |
| `result` | Fin del turno, contiene texto final |
| `stream_event` | Token individual (con --include-partial-messages) |

### Persistencia entre turnos

```
Turno 1: claude -p --output-format stream-json --input-format stream-json --verbose
  → capturar session_id de system/init

Turno 2+: claude -p --resume <session_id> --output-format stream-json ...
  → misma sesion, mismo contexto, misma memoria
```

---

## Ventajas vs v1

| Aspecto | v1 (claude -p simple) | v2 (stream-json + resume) |
|---------|----------------------|---------------------------|
| Contexto | Sin CLAUDE.md, sin reglas | TODO el contexto de pm-workspace |
| Personalidad | System prompt hardcoded | Savia real (profiles, rules) |
| Memoria | Sin memoria entre turnos | Sesion persistente |
| Herramientas | Solo texto | Puede usar Bash, Read, etc. |
| Streaming | Espera respuesta completa | Token a token (parcial) |
| PII | Hardcoded en codigo | Cero, lee del workspace |

---

## Componentes del daemon

### 1. AudioCapture
- sounddevice InputStream 16kHz mono
- Buffer circular

### 2. VADDetector
- Silero VAD, <1ms/chunk
- Detecta inicio/fin de habla
- Configurable: threshold, silence timeout

### 3. Transcriber
- faster-whisper tiny, ~0.9s
- initial_prompt con vocabulario del workspace
- El prompt se lee de un fichero configurable

### 4. SessionManager (NUEVO - pieza clave)
- Gestiona proceso claude -p con stream-json
- Mantiene session_id entre turnos
- Parsea NDJSON stdout
- Extrae texto de respuesta (parcial o completa)
- Timeout y error handling

### 5. TTSSynthesizer
- edge-tts (Elvira es-ES por defecto)
- Voz configurable por fichero local
- Lead-in silence configurable
- Conversion mp3 → wav → sounddevice

### 6. Config (NUEVO)
- Fichero config.yaml (gitignored) para datos del usuario
- Defaults sensatos sin config (funciona out of the box)
- Whisper prompt leido de fichero (extensible)

---

## Ficheros

```
zeroclaw/savia-voice/
├── daemon.py              ← Orquestador principal
├── audio.py               ← AudioCapture + VADDetector
├── transcriber.py         ← Wrapper faster-whisper
├── session.py             ← SessionManager (claude stream-json)
├── tts.py                 ← TTSSynthesizer (edge-tts)
├── config.py              ← Carga de config
├── config.default.yaml    ← Defaults (en git)
├── config.local.yaml      ← Overrides del usuario (gitignored)
└── requirements.txt       ← Dependencias pip
```

---

## Config por defecto (config.default.yaml)

```yaml
audio:
  sample_rate: 16000
  channels: 1
  blocksize: 512

vad:
  threshold: 0.5
  silence_timeout: 1.2
  min_speech_duration: 0.4

stt:
  model: tiny
  language: es
  prompt_file: null  # fichero con vocabulario adicional

tts:
  engine: edge-tts
  voice: es-ES-ElviraNeural
  lead_in_silence: 1.0

claude:
  model: sonnet
  permission_mode: default
  append_system_prompt: null  # fichero con prompt adicional
```

## Overrides locales (config.local.yaml, gitignored)

```yaml
stt:
  prompt_file: ~/.savia/whisper-vocab.txt

tts:
  voice: es-ES-ElviraNeural
  lead_in_silence: 0.5  # sin bluetooth = menos delay

claude:
  model: haiku  # si prefieres velocidad sobre calidad
  append_system_prompt: ~/.savia/voice-context.md
```

---

## Requisitos

- Python 3.10+
- Claude Code CLI instalado y autenticado (cualquier plan)
- ffmpeg (para conversion mp3 → wav)
- Dependencias pip en requirements.txt
- Microfono y altavoz (PC o ESP32 via WebSocket)
