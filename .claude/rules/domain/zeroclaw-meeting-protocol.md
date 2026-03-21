# ZeroClaw Meeting Protocol — Live Diarization + Voice Memory

> Savia escucha reuniones, identifica quién habla, y digiere el contexto.
> Voice embeddings = datos biométricos RGPD Art. 9. Máxima protección.

## Flujo

```
/zeroclaw meeting start → aviso audible de grabación
  → ZeroClaw captura audio continuo (PCM 16kHz)
  → Host: VAD → diarization → speaker ID → STT
  → Transcript JSONL con speaker labels
/zeroclaw meeting stop → meeting-digest agent → output
```

## Voice Enrollment

Para identificar hablantes, Savia necesita aprender sus voces:

```
/zeroclaw voice enroll "Carlos"
  → Carlos habla 10-15 segundos
  → SpeechBrain ECAPA-TDNN extrae embedding (vector 192d)
  → Guardado en ~/.savia/zeroclaw/voiceprints/ (N4b)
```

Requisitos: consentimiento explícito de la persona.

## Identificación durante reunión

| Confianza | Etiqueta | Acción |
|-----------|----------|--------|
| ≥75% | "Carlos" | Nombre confirmado |
| 50-74% | "Carlos?" | Nombre probable, marcar incertidumbre |
| <50% | "Unknown-1" | Voz no registrada |

Unknowns se agrupan por similaridad (mismo Unknown-N si es la misma
persona no registrada). Post-reunión: el PM puede etiquetar.

## Consentimiento obligatorio (guardrail en código)

Antes de grabar, ZeroClaw DEBE:
1. Emitir aviso audible: "Atención, esta reunión será transcrita"
2. LED rojo fijo durante grabación (visible para todos)
3. Registrar inicio/fin en audit log

NUNCA grabar sin aviso. El guardrail de rate-limiting (5 audio/min)
se relaja a 60/min durante modo meeting (buffer continuo).

## Almacenamiento

| Dato | Nivel | Retención | Ubicación |
|------|-------|-----------|-----------|
| Audio crudo | N3 | Borrar tras transcripción (max 1h) | raw/ |
| Transcript JSONL | N4 | 90 días | sessions/ |
| Voiceprints (.npy) | N4b | Hasta borrado explícito | voiceprints/ |
| Meeting digest | N4 | Indefinido | projects/{p}/ |

## Integración con meeting-digest agent

El transcript generado por ZeroClaw es compatible con el agente
`meeting-digest` existente. La diferencia: en vez de recibir un
fichero VTT/DOCX, recibe JSONL con speaker labels ya asignados.

El agente extrae: resumen, action items, decisiones, riesgos,
y actualiza perfiles de equipo con insights de la reunión.

## RGPD — Derecho de supresión

```
/zeroclaw voice delete "Carlos"
  → Borra embedding + todas las referencias en transcripts
  → Audit log: "voiceprint deleted per RGPD request"
```

## Degradación sin deps

| pyannote | speechbrain | whisper | Resultado |
|----------|-------------|---------|-----------|
| ✅ | ✅ | ✅ | Full: diarize + identify + transcribe |
| ❌ | ✅ | ✅ | Sin diarización, un solo "speaker" |
| ✅ | ❌ | ✅ | Diarización sin nombres (SPEAKER_0) |
| ❌ | ❌ | ✅ | Solo transcripción sin speakers |
| ❌ | ❌ | ❌ | Solo graba audio, digest manual |
