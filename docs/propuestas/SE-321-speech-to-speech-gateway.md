---
id: SE-321
title: "SE-321 — Speech-to-Speech gateway: pipeline VAD→STT→LLM→TTS con API Realtime"
status: PROPOSED
priority: media
---

# SE-321 — Speech-to-Speech gateway: pipeline VAD→STT→LLM→TTS con API Realtime

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Voice / Speech / savia-transcriptor
**Branch sugerida:** `agent/se321-speech-to-speech`
**Estimacion total:** ~32h (4 slices)
**Inspiracion:** `huggingface/speech-to-speech` (HF, pipeline modular + API OpenAI-Realtime-compatible)

---

## Contexto y evidencia (2026-08-09)

El repo `huggingface/speech-to-speech` implementa un pipeline de voz
`VAD → STT → LLM → TTS` con cada slot swappable, expuesto por una **API
OpenAI-Realtime-compatible** (WebSocket). El slot LLM habla protocolos
OpenAI-compatibles, así que puede apuntar a un proveedor hosted, a HF
Inference Providers, o a vLLM/llama.cpp local — stack 100% local y abierto.
Corre en producción como backend conversacional de miles de robots Reachy Mini.

Savia tiene:
- `savia-transcriptor` (ex-VoiceFlow, SE-308/SE-312): captura y digestión de
  reuniones (una dirección: graba → transcribe → digiere),
- `voice-inbox` (mensajes de voz → acciones),
- SE-310 (Savia Conversacional): interfaz de **voz bidireccional** en Savia
  Transcriptor (S0).

**El hueco.** SE-310 es la interfaz conversacional, pero la infraestructura de
voz en tiempo real (VAD, STT streaming, TTS, latencia) no está estandarizada:
cada integración (Teams, micrófono, reuniones) habla su propio protocolo. Un
gateway común con API Realtime-compatible permitiría a Savia *hablar* (no solo
escuchar) de forma uniforme, reutilizando el pipeline de speech-to-speech.

---

## Objetivo

Evaluar e integrar un gateway de voz bidireccional basado en el patrón de HF
speech-to-speech: servicio local `savia-voice-gateway` con pipeline
VAD→STT→LLM→TTS swappable y API OpenAI-Realtime-compatible, conectado al LLM
de Savia (con soporte para backend local vía savia-dual/emergency-mode).

---

## Out of scope

- NO reemplazar la digestión de reuniones de savia-transcriptor (eso es
  offline y unidireccional).
- NO desplegar a producción hasta validación con GPU/CPU local.
- NO depender de un proveedor de voz específico (todo swappable).

---

## Diseno

### S1 — Proceso de validación (feasibility probe)

- `feasibility-probe` time-boxed: levantar `speech-to-speech serve` local,
- medir latencia extremo-a-extremo (VAD→STT→LLM→TTS) en CPU y GPU,
- documentar en `output/research/speech-to-speech-{fecha}.md`.

### S2 — Gateway Savia (`savia-voice-gateway`)

- servicio que envuelve el pipeline HF con la config de Savia:
  - STT: Parakeet (local) o whisper (transcriptor), swappable,
  - LLM: endpoint OpenAI-compatible de Savia (savia-dual / emergency-mode),
  - TTS: Qwen3-TTS local,
- expone `ws://localhost:<port>/v1/realtime` (API OpenAI-Realtime-compatible),
- auth local con token de Savia (sin credenciales en repo).

### S3 — Cliente y comandos

- comando `/voice-chat` para conversación bidireccional con Savia,
- integración con `voice-inbox` (los mensajes de voz entrantes se procesan a
  través del mismo STT),
- telemetría SE-313: eventos `voice.session`, `voice.turn` con latencias.

### S4 — Fallback y soberanía

- si no hay GPU ni servidor local → degrada a STT offline (transcriptor) +
  TTS desactivado, aviso al operador,
- si el LLM cloud falla → savia-dual (failover local) sin romper el gateway.

---

## Criterios de aceptacion

### AC-S1: Validación

- [ ] AC-S1.1: probe levanta el pipeline local y mide latencias (documentado).
- [ ] AC-S1.2: veredicto GO/NO-GO con coste estimado y requisitos HW.

### AC-S2: Gateway

- [ ] AC-S2.1: `savia-voice-gateway` responde en `/v1/realtime` con handshake
  OpenAI-Realtime válido.
- [ ] AC-S2.2: el slot LLM apunta al endpoint de Savia (config, no hardcode).

### AC-S3: Cliente

- [ ] AC-S3.1: `/voice-chat` inicia sesión, transcribe, responde y sintetiza.
- [ ] AC-S3.2: `voice.turn` con latencia aparece en telemetría.

### AC-S4: Fallback

- [ ] AC-S4.1: sin GPU → degradación controlada sin crash.
- [ ] AC-S4.2: fallo del LLM cloud → savia-dual mantiene la sesión.

---

## Ref

- `huggingface/speech-to-speech` (README, `speech_to_speech/`)
- `docs/propuestas/SE-310-savia-conversacional.md` (S0)
- `.opencode/skills/savia-dual/SKILL.md`, `.opencode/skills/voice-inbox/SKILL.md`
