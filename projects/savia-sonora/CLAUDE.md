# Savia Sonora — la voz y el oído de Savia

> **Proyecto unificado de interfaz hablada** · Unifica Savia Transcriptor, el
> motor TTS local (Kokoro), la conversación por voz (SE-310) y el post-proceso
> de reuniones. Creado 2026-08-07.

## Nombre

- **Nombre**: Savia Sonora
- **Slug**: `savia-sonora`
- **Histórico absorbido**: Savia Voice (SE-075, SE-042) · Savia Transcriptor (SE-308)

## Descripción

Savia Sonora es la **interfaz hablada de Savia**: su voz y su oído. Escucha
(transcripción local), habla (síntesis local), graba y participa en reuniones,
razona sobre las **cúpulas de contexto de SaviaVaults** y produce **audio
fundamentado** (briefs). Todo local-first (N3), con el mismo cerebro que el
workspace.

No es un asistente de voz genérico: es **Savia** — identidad, memoria y
conocimiento — accesible oralmente, igual que por texto.

## Scope futuro (hacia dónde crece)

| Capacidad | Estado |
|---|---|
| Grabación de reuniones (VAD + whisper + screenshots) | ✅ Implementado (ex-Savia Transcriptor) |
| Motor TTS local (Kokoro CPU, es/ing) | ✅ Implementado (SE-075 Slice 3) |
| Conversación bidireccional push-to-talk | 📐 Spec SE-310 (S0-A..I: proactividad, memoria, visión, cúpulas, briefs) |
| Digest de reuniones/conversaciones | ✅ Implementado (transcriptor-digest, meeting-digest) |
| Voice inbox (WhatsApp/Nextcloud → acción) | ✅ Implementado (voice-inbox) |
| Cúpulas de contexto (consume + alimenta) | 📐 Spec SE-310 S0-H (A2A SaviaVaults) |
| Audio briefs fundamentados (patrón NotebookLM) | 📐 Spec SE-310 S0-I |
| Voz entrenada de Savia (clonación de persona) | 🔒 SE-042 (GPU-blocked) — módulo futuro |
| Cliente móvil (continuidad cross-device) | 📱 savia-mobile-android — fase futura aparte |

## Mapa de módulos (qué consolida)

| Módulo | Origen | Rol en Savia Sonora |
|---|---|---|
| Núcleo de audio (STT) | `projects/savia-transcriptor` (SE-308) | Captura, VAD, whisper, screenshots, SQLite, dictado |
| Motor de síntesis (TTS) | `scripts/savia-kokoro.py`, `savia-voice-speak.sh`, `savia-voice-chunk.sh`, `sentence-splitter.py` (SE-075) | Kokoro CPU + chunking + protocolo `SAVIA_VOICE`/`SAVIA_TTS_CMD` |
| Conversación | Spec SE-310 (S0-A..I) | Push-to-talk, barge-in, proactividad, memoria, visión, cúpulas, briefs |
| Digest post-proceso | skill `transcriptor-digest` + `meeting-digest`/`meeting-risk-analyst` | Convierte reuniones/conversaciones en conocimiento |
| Voice inbox | skill `voice-inbox` | Entrada de voz asíncrona (WhatsApp/Nextcloud) |
| Transcript de Teams | skill `meeting-transcript-extract` | Entrada de reuniones remotas |
| Conocimiento (cúpulas) | `projects/savia-vaults` (A2A) | RAG consume + alimenta (dependencia, no se fusiona) |
| Voz entrenada | SE-042 (GPU-blocked) | Futuro: perfil de voz clonado con consentimiento |
| Cliente móvil | `projects/savia-mobile-android` | Futuro: continuidad cross-device (fuera de alcance por ahora) |

## Arquitectura conceptual

```
            ┌──────────────────────────────────────────────────┐
            │               SAVIA SONORA (app)                   │
            │                                                    │
            │  OIDOS:  STT (whisper) + VAD + dictado + voice-inbox │
            │  VOZ:    TTS (Kokoro) + chunk + briefs              │
            │  MENTE:  LLM local (Ollama) — analizar/construir/    │
            │          contestar (SE-310 §2.9)                    │
            │  MEMORIA: contexto + memory.md (S0-F)               │
            │  OJOS:   vision (S0-G, opt-in)                      │
            └───────────────┬──────────────────┬─────────────────┘
                            │ A2A (HTTP local) │ ficheros (decoplado)
              ┌─────────────▼───────────┐   ┌───▼──────────────────┐
              │ SaviaVaults (cúpulas)   │   │ ~/.savia/sonora/     │
              │  consume + alimenta     │   │  reuniones/          │
              │  (S0-H)                 │   │  conversaciones/     │
              └─────────────────────────┘   │  audio-briefs/       │
                                            └──────────────────────┘
```

**Decisión clave**: Savia Sonora **no se fusiona con SaviaVaults**. SaviaVaults
es el conocimiento (cúpulas, grafo); Savia Sonora es la interfaz hablada que lo
consume y alimenta vía A2A HTTP — mismo patrón decoplado que SE-308.

## Plan de consolidación (no destructivo)

### Fase 0 — Identidad unificada (2026-08-07, este fichero)
- [x] Nombre + descripción + mapa de módulos + roadmap (Era 202)
- [ ] PR de la identidad

### Fase 1 — Reubicación física (requiere aprobación)
- [ ] `git mv projects/savia-transcriptor → projects/savia-sonora/app` (núcleo)
- [ ] Mover scripts de voz a `projects/savia-sonora/engine/` (kokoro, speak, chunk, splitter)
- [ ] Actualizar referencias: `kokoro-voice-protocol.md`, SE-042, skills, tests BATS, ROADMAP, specs SE-308/SE-310
- [ ] Espec SE-310 pasa a `projects/savia-sonora/specs/`

### Fase 2 — Migración de skills
- [ ] `transcriptor-digest`, `meeting-transcript-extract`, `voice-inbox` → referencian el proyecto (paths actualizados)

### Fase 3 — Módulos futuros
- [ ] SE-042 (voz entrenada) cuando GPU esté disponible
- [ ] Savia Mobile como cliente (fase aparte, tras S0 probado)

## Referencias

| Recurso | Path |
|---|---|
| Spec conversación | `projects/savia-transcriptor/specs/SE-310-savia-conversacional.spec.md` (hasta Fase 1) |
| Spec app original | `projects/savia-transcriptor/specs/SE-308-savia-transcriptor.spec.md` |
| Protocolo TTS | `docs/rules/domain/kokoro-voice-protocol.md` |
| SE-075 (TTS adoptado) | `docs/propuestas/SE-075-voicebox-adoption.md` |
| SE-042 (voz entrenada) | `docs/propuestas/SE-042-savia-voice-training-pipeline.md` |
| Cúpulas de contexto | `projects/savia-vaults/` (A2A `127.0.0.1:8923`) |

## OpenCode Implementation Plan

- **Portability**: SINGLE_BINDING_DEFERRED. La app es un binario independiente;
  los únicos bindings (digest skills, scripts TTS compartidos) ya son
  cross-frontend via symlink/`scripts/`.
- **Verification**: pytest (app) + BATS (`test-transcriptor.bats`) + tests de
  plugin TS del guard; SKIP justificado para audio real (requiere hardware).
