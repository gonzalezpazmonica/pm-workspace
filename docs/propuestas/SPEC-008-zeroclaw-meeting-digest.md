# SPEC-008: ZeroClaw Meeting Digest — Speaker Diarization + Voice Memory

> Status: **DRAFT** · Fecha: 2026-03-21
> "Savia escucha la reunión, sabe quién habla, y digiere todo."

---

## Problema

Las reuniones generan contexto valioso que se pierde si nadie
toma notas. Savia ya tiene un agente `meeting-digest` para
transcripciones de fichero, pero no puede escuchar reuniones
en vivo. ZeroClaw le da oídos, y con speaker diarization,
sabe QUIÉN dijo QUÉ.

## Arquitectura

```
Reunión en sala
  │
  ▼ ZeroClaw (ESP32 + mic INMP441)
  Audio I2S → buffer → stream WiFi (PCM 16kHz chunks)
  │
  ▼ Host PC (Python)
  ┌─────────────────────────────────────────┐
  │ 1. VAD (Silero) — detectar voz activa   │
  │ 2. Diarization (pyannote) — quién habla │
  │ 3. Speaker ID — match con voiceprints   │
  │ 4. STT (whisper.cpp) — transcribir      │
  │ 5. Digest (meeting-digest agent)        │
  └─────────────────────────────────────────┘
  │
  ▼ Output
  Transcript con speaker labels → digest → action items
```

## Voice Fingerprinting — Aprender voces

### Enrollment (aprender una voz nueva)

```
Humano: "Savia, aprende la voz de Carlos"
ZeroClaw: [LED azul — escuchando]
Carlos habla 10-15 segundos (frase libre)
Host: pyannote/speechbrain extrae embedding (vector 192-512 dims)
Savia: "Voz de Carlos registrada. Lo reconoceré en reuniones."
```

### Almacenamiento de voiceprints

```
~/.savia/zeroclaw/voiceprints/
├── index.json               ← {name, embedding_file, created, confidence}
├── carlos-abc123.npy        ← numpy array del embedding
├── maria-def456.npy
└── unknown-001.npy          ← voces no identificadas (para etiquetar después)
```

**Confidencialidad**: N4b (datos biométricos, solo la PM).
Voice embeddings son datos biométricos bajo RGPD Art. 9.
NUNCA en git, NUNCA compartidos, NUNCA enviados a APIs externas.

### Identificación en tiempo real

```python
# Durante la reunión, para cada segmento de audio:
segment_embedding = extract_embedding(audio_segment)
best_match, score = compare_voiceprints(segment_embedding)
if score > 0.75:
    speaker = best_match.name  # "Carlos"
elif score > 0.50:
    speaker = f"{best_match.name}?"  # "Carlos?" (baja confianza)
else:
    speaker = "Unknown-1"  # voz no registrada
```

## Pipeline de reunión en vivo

### Fase 1: Inicio

```
/zeroclaw meeting start
  → ZeroClaw: LED verde pulsante = grabando
  → Savia anuncia por altavoz (si hay): "Reunión iniciada"
  → Guardrails: verificar consentimiento (aviso audible)
  → Crear sesión: ~/.savia/zeroclaw/sessions/{timestamp}/
```

### Fase 2: Captura continua

```
ZeroClaw → Host: audio chunks (PCM 16kHz, 512 samples/chunk)
Host: buffer 30s de audio → procesar → siguiente buffer
  Para cada buffer:
    1. VAD: eliminar silencio
    2. Diarization: segmentos por hablante
    3. Speaker ID: match contra voiceprints
    4. STT: transcribir cada segmento
    5. Append a transcript.jsonl
```

### Fase 3: Fin

```
/zeroclaw meeting stop
  → ZeroClaw: LED apagado
  → Host: flush último buffer
  → Ejecutar meeting-digest agent sobre transcript completo
  → Generar: resumen, action items, decisiones, riesgos
  → Borrar audio crudo (guardrail: auto-expiry 1h)
```

## Formato del transcript

```jsonl
{"ts": "00:00:15", "speaker": "Carlos", "confidence": 0.89, "text": "Empecemos con el sprint review"}
{"ts": "00:00:22", "speaker": "Maria", "confidence": 0.92, "text": "Los PBIs del backend están al 80%"}
{"ts": "00:00:35", "speaker": "Unknown-1", "confidence": 0.0, "text": "¿Y el frontend?"}
{"ts": "00:00:41", "speaker": "Carlos", "confidence": 0.85, "text": "El frontend tiene un bloqueante"}
```

## Stack de software libre

| Componente | Herramienta | Licencia | Función |
|-----------|------------|----------|---------|
| Speaker diarization | pyannote-audio | MIT | Quién habla cuándo |
| Speaker embedding | SpeechBrain ECAPA-TDNN | Apache 2.0 | Fingerprint de voz |
| VAD | Silero VAD v5 | MIT | Detectar voz activa |
| STT | whisper.cpp / faster-whisper | MIT | Transcripción |
| Meeting digest | meeting-digest agent | pm-workspace | Resumen + acciones |

## Fases de implementación

### Fase A — Enrollment + storage (sin reunión en vivo)

- Registro de voces por serial/USB
- Almacenamiento de embeddings en ~/.savia/
- Comparación offline de audio grabado

### Fase B — Reunión en vivo vía ZeroClaw

- Stream de audio WiFi continuo
- Diarización + identificación en tiempo real
- Transcript con speaker labels

### Fase C — Integración con meeting-digest

- Pasar transcript al agente meeting-digest
- Generar digest con nombres reales de hablantes
- Actualizar perfiles de equipo con insights
