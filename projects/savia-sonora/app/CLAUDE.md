# Savia Sonora · app — Núcleo de audio (ex-Savia Transcriptor)

> **Módulo `app` de Savia Sonora** — la interfaz hablada de Savia. Este núcleo
> captura reuniones automaticamente: escucha el audio, detecta cuando hay una
> reunion por senal de voz (VAD), graba el audio y captura la pantalla
> (screenshots periodicos, no video). Transcripcion local con Whisper.
> Compatible con Windows (WASAPI), Linux (PipeWire) y macOS (BlackHole).
> Proyecto unificado: `projects/savia-sonora/CLAUDE.md`.

## Stack

| Aspecto | Eleccion |
|---------|----------|
| Lenguaje | Python 3.10+ (core) + React 18 (frontend) |
| Shell | Pyloid (PySide6 + Qt WebEngine) |
| Base | [VoiceFlow](https://github.com/infiniV/VoiceFlow) (MIT) |
| Audio | WASAPI (Win) / PipeWire (Linux) / BlackHole (macOS) |
| VAD | silero-vad |
| Transcripcion | faster-whisper (CTranslate2) |
| Screenshots | python-mss |
| Storage | SQLite (`~/.savia/transcriptor/index.db`) |

## Fork

Fork de VoiceFlow (MIT, `infiniV/VoiceFlow`). Cambios respecto al upstream:

- Storage reubicado de `~/.VoiceFlow/` a `~/.savia/transcriptor/`
- Rebrand de marca (VoiceFlow → Savia Transcriptor)

## Quick Start (desarrollo)

```bash
cd projects/savia-sonora/app
pnpm run setup        # instala deps Node y Python
pnpm run dev          # Vite frontend + Pyloid backend
```

## Datos

- Carpeta de reuniones: `~/.savia/transcriptor/reuniones/YYYY-MM-DD-HH-MM/`
- Cada reunion: `audio.wav` + `transcript.vtt` + `transcript.md` + `capturas/*.png` + `meta.json`

## Savia Model

- **Confidencialidad**: N3 — datos locales, nunca al repo
- **Privacidad**: local-first, audio nunca sale de la maquina
- **Autonomia**: graba solo cuando detecta voz (VAD), no en silencio continuo

## Specs

- SE-308: `specs/SE-308-savia-transcriptor.spec.md`
