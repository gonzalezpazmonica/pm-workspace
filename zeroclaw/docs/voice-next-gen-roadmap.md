# ZeroClaw Voice — Roadmap Next-Gen

> Investigacion marzo 2026. Estado del arte en conversacion por voz.

---

## Donde estamos (v2)

- Arquitectura turn-based: hablar → esperar → respuesta → esperar
- Latencia total: 15-25s por turno
- Mic bloqueado mientras Savia piensa o habla
- Sin barge-in (no puedes interrumpir)

## Donde necesitamos llegar

- Full-duplex: escuchar y hablar simultaneamente
- Barge-in: el usuario interrumpe y Savia para
- Feedback asincrono: "dame un momento" mientras piensa
- Streaming TTS: empieza a hablar la primera frase sin esperar
- Latencia objetivo: <5s al primer audio de respuesta

---

## 3 Gaps criticos y como resolverlos

### Gap 1: Mic siempre abierto (full-duplex)

**Problema**: `is_processing = True` bloquea el mic.

**Solucion**: Separar en 3 hilos independientes con colas:

```
Hilo 1 (AUDIO):   mic → VAD → cola_audio (NUNCA se para)
Hilo 2 (PIPELINE): cola_audio → STT → LLM → cola_tts
Hilo 3 (SPEAKER):  cola_tts → TTS → altavoz
```

El hilo de audio SIEMPRE esta escuchando. Si detecta habla
mientras Savia habla (barge-in), envia senal al hilo speaker
para que pare la reproduccion.

**Referencia**: [full_duplex_assistant](https://github.com/leo007-htun/full_duplex_assistant),
[LiveKit agents](https://github.com/livekit/agents)

### Gap 2: Streaming TTS (first-audio latency)

**Problema**: Esperamos respuesta COMPLETA antes de sintetizar.

**Solucion**: Leer tokens parciales del stream-json de Claude Code
y sintetizar frase a frase.

```
Claude genera: "Hola Monica, | aqui tienes | el resumen."
                    ↓ TTS         ↓ TTS          ↓ TTS
                 (reproduce)   (en cola)      (en cola)
```

Con `--include-partial-messages`, Claude Code emite `stream_event`
con tokens individuales. Acumulamos hasta un punto/coma y lanzamos
TTS de esa frase mientras siguen llegando tokens.

**Impacto estimado**: First-audio de 7-13s → 2-4s

**Referencia**: [OpenAI Realtime API](https://platform.openai.com/docs/guides/realtime),
[Softcery voice architecture](https://softcery.com/lab/ai-voice-agents-real-time-vs-turn-based-tts-stt-architecture)

### Gap 3: Barge-in (interrupcion)

**Problema**: No puedes interrumpir a Savia.

**Solucion**: El hilo de audio monitorea VAD incluso durante
reproduccion. Si detecta habla del usuario:

1. Para la reproduccion TTS inmediatamente
2. Descarta las frases pendientes en cola
3. Captura nueva utterance del usuario
4. La pasa al pipeline normal

**Requisito**: Acoustic Echo Cancellation (AEC) para que el VAD
no confunda la voz de Savia (por altavoz) con la del usuario.
En PC con auriculares/Jabra no es problema. Con altavoz+mic
abierto se necesita AEC (speexdsp o webrtcvad).

**Referencia**: [NVIDIA PersonaPlex](https://research.nvidia.com/labs/adlr/personaplex/),
[Gnani barge-in](https://www.gnani.ai/resources/blogs/real-time-barge-in-ai-for-voice-conversations-31347)

---

## Plan de implementacion

### v2.1 — Feedback asincrono (HECHO)
- "Dame un momento" cuando LLM tarda >5s
- "Sigo trabajando" cada 8s adicionales
- Timeout 60s en vez de 30s

### v2.2 — Streaming TTS por frases
- Leer stream_event de Claude Code
- Acumular tokens hasta punto/coma
- Lanzar TTS por frase, reproducir en secuencia
- First-audio target: <4s

### v2.3 — Mic siempre abierto + barge-in
- 3 hilos con colas (audio, pipeline, speaker)
- VAD activo durante reproduccion
- Barge-in para y captura nueva utterance
- AEC basico para altavoz abierto

### v2.4 — Reuniones (modo transcript)
- Whisper small para precision
- Diarizacion con pyannote/ECAPA-TDNN
- Transcripcion continua sin turnos
- Digestion post-reunion con meeting-digest agent

### v3.0 — ESP32 como satelite
- Firmware ESP32: I2S + WebSocket + WakeNet
- Audio streaming bidireccional
- ZeroClaw como mic/speaker remoto del daemon

---

## Metricas objetivo

| Metrica | v2 actual | v2.3 | v3.0 |
|---------|-----------|------|------|
| First-audio | 8-13s | <4s | <3s |
| Turn total | 15-25s | 6-10s | 5-8s |
| Barge-in | No | Si | Si |
| Duplex | No | Si | Si |
| STT accuracy | ~90% | ~90% | ~92% |

---

## Fuentes

- [Full Duplex Assistant](https://github.com/leo007-htun/full_duplex_assistant)
- [LiveKit Agents](https://github.com/livekit/agents) — framework realtime
- [FireRedChat](https://arxiv.org/html/2509.06502v1) — full-duplex cascaded
- [NVIDIA PersonaPlex](https://research.nvidia.com/labs/adlr/personaplex/)
- [OpenAI Realtime API](https://platform.openai.com/docs/guides/realtime)
- [Voice AI Stack 2026](https://www.assemblyai.com/blog/the-voice-ai-stack-for-building-agents)
- [Gnani Barge-in](https://www.gnani.ai/resources/blogs/real-time-barge-in-ai-for-voice-conversations-31347)
- [Softcery Architecture](https://softcery.com/lab/ai-voice-agents-real-time-vs-turn-based-tts-stt-architecture)
