# ZeroClaw Voice Daemon — Architecture v2

> El daemon de voz NO es un chatbot. Es un adaptador I/O
> que conecta audio con una sesión REAL de Claude Code.

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
                    │     Claude Code (sesión real)    │
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

### Input (stdin): un JSON por línea

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
| `system/init` | Inicio sesión, contiene `session_id` |
| `assistant` | Respuesta (parcial o completa) |
| `result` | Fin del turno, contiene texto final |
| `stream_event` | Token individual (con --include-partial-messages) |

### Persistencia entre turnos

```
Turno 1: claude -p --output-format stream-json --input-format stream-json --verbose
  → capturar session_id de system/init

Turno 2+: claude -p --resume <session_id> --output-format stream-json ...
  → misma sesión, mismo contexto, misma memoria
```

---

## Ventajas vs v1

| Aspecto | v1 (claude -p simple) | v2 (stream-json + resume) |
|---------|----------------------|---------------------------|
| Contexto | Sin CLAUDE.md, sin reglas | TODO el contexto de pm-workspace |
| Personalidad | System prompt hardcoded | Savia real (profiles, rules) |
| Memoria | Sin memoria entre turnos | Sesión persistente |
| Herramientas | Solo texto | Puede usar Bash, Read, etc. |
| Streaming | Espera respuesta completa | Token a token (parcial) |
| PII | Hardcoded en código | Cero, lee del workspace |

---

## Componentes del daemon (v2.4)

### 1. Audio + VAD + STT (audio.py)
- sounddevice InputStream 16kHz mono con callback non-blocking
- Silero VAD: <1ms/chunk, threshold/silence_timeout configurables
- faster-whisper (tiny por defecto): ~0.9s, initial_prompt configurable
- Whisper prompt se lee de fichero o usa vocabulario Savia por defecto

### 2. Conversation Model (conversation_model.py) — NUEVO v2.4
- Basado en Sacks-Schegloff-Jefferson turn-taking (1974)
- Clasifica overlaps: backchannel, collaborative, stop, followup
- Backchannels ("si", "claro", "vale") se ignoran — Savia sigue hablando
- Solo comandos explicitos ("para", "callate") interrumpen
- El resto se guarda como follow-up para procesar tras el turno de Savia

### 3. SessionManager (session.py) — Streaming por frases
- Claude Code stream-json + resume para sesión persistente
- Yield frase a frase (split en punto/coma) para streaming TTS
- Fillers asincrono: "Pues mira..." si LLM tarda >3s (via TTSCache)
- Stalls: "Dejame que lo mire" si >8s
- Timeout configurable (60s por defecto)

### 4. TTSSynthesizer (tts.py) — Kokoro local + edge-tts fallback
- Kokoro 82M (local, 24kHz, ~200ms/frase) como engine principal
- edge-tts (Elvira es-ES) como fallback si Kokoro no disponible
- Cola de reproduccion thread-safe (queue + playback loop)
- cancel() para barge-in: para audio, vacia cola
- is_playing property para detección de overlaps

### 5. TTS Pre-Cache (tts_cache.py) — NUEVO v2.4
- 20 respuestas exactas pre-generadas (0ms latencia)
- 20 fillers contextuales por categoria (inicio, reflexion, empatia...)
- 24 stalls por tipo de tarea (buscando, pensando, investigando...)
- Warm desde disco (WAVs pre-generados) o desde Kokoro en runtime
- generate_cache.py para pre-generar y commitear a git

### 6. Config (config.py)
- YAML: config.default.yaml (en git) + config.local.yaml (gitignored)
- Deep merge de defaults → default.yaml → local.yaml
- Soporta Kokoro o edge-tts como engine TTS

---

## Ficheros

```
zeroclaw/savia-voice/
├── daemon.py              ← Orquestador principal (full-duplex + conversation model)
├── audio.py               ← VAD (Silero) + STT (faster-whisper)
├── conversation_model.py  ← Clasificacion de overlaps (barge-in, backchannel)
├── session.py             ← SessionManager (claude stream-json + resume)
├── tts.py                 ← TTSSynthesizer (Kokoro local + edge-tts fallback)
├── tts_cache.py           ← Pre-cache de muletillas, fillers y stalls
├── text_utils.py          ← Segmentacion de frases para streaming TTS
├── config.py              ← Carga de config (default + local override)
├── config.default.yaml    ← Defaults (en git)
├── config.local.yaml      ← Overrides del usuario (gitignored)
├── generate_cache.py      ← Script para pre-generar audio cache en disco
├── voice-prompt.md        ← System prompt para modo voz
├── test_e2e.py            ← Tests end-to-end del daemon
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
