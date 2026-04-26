---
id: SE-075
title: SE-075 — Voicebox adoption — task_queue, auto-chunking, Kokoro CPU voice
status: APPROVED
origin: jamiepine/voicebox repo study 2026-04-26
author: Savia
priority: media
effort: M 8h (3 slices independientes)
related: SE-074, SE-042, savia-voice, emergency-mode
approved_at: "2026-04-26"
applied_at: null
expires: "2026-06-26"
era: 188
---

# SE-075 — Voicebox adoption

## Why

Voicebox (jamiepine/voicebox, 23k stars, MIT, push diario) es alternativa OSS a ElevenLabs: Tauri+FastAPI con 7 motores TTS, voice cloning zero-shot, 23 idiomas. Análisis 2026-04-26 identifica 3 patrones específicos extraíbles sin adoptar el stack completo (Tauri, GPU, multi-track editor).

Cost of inaction:
- **task_queue**: cada skill long-running de Savia reinventa cola+streaming. SE-074 paralelismo necesita cola serial intra-worktree para sub-tareas — sin patrón, cada slice reinventa la rueda.
- **auto-chunking**: savia-voice no maneja textos >30s sin cortes audibles. Bloquea narración de notas largas, daily summaries hablados.
- **Kokoro CPU voice**: SE-042 voice training está GPU-blocked. Sin alternativa CPU, Savia no tiene voz de salida en español hoy. Kokoro 82M corre 150x realtime en CPU y soporta español.

## Scope (3 slices independientes)

### Slice 1 (S, 2h) — task_queue.py adoption

Copiar `backend/services/task_queue.py` de voicebox (~3.7KB MIT, atribuir) → `scripts/lib/task-queue.py` con adaptaciones:

- Colas serial async + SSE streaming
- Auto-recovery de jobs stale en startup
- Integración inicial: SE-074 orquestador (sub-cola intra-worktree para steps SDD)
- Persistencia: SQLite en `output/task-queue/`

### Slice 2 (M, 3h) — auto-chunking long-form TTS

Patrón de voicebox `services/tts.py` para chunking:

- Sentence-boundary split (puntuación + abreviaturas español)
- Crossfade audio entre chunks (ffmpeg)
- Wrapper `scripts/savia-voice-chunk.sh` que toma texto largo, divide, sintetiza chunks paralelos (bounded concurrency 2), concatena
- Integra con savia-voice/whisper-env existente

### Slice 3 (M, 3h) — Kokoro CPU voice instalación + skill

- Instalar Kokoro 82M (`hexgrad/Kokoro-82M`) — modelo TTS CPU, español soportado
- Skill `.claude/skills/savia-voice-cpu/` (SKILL.md + DOMAIN.md)
- Wrapper `scripts/kokoro-tts.sh` con `--text`, `--lang es`, `--out path.wav`
- Documentar trade-off vs cloud TTS (calidad, latencia, sin GPU)
- NO bloquea SE-042 (que sigue siendo voice CLONING de calidad, GPU-required)

## Acceptance criteria

### Slice 1
- [ ] AC-01 `scripts/lib/task-queue.py` con atribución MIT a voicebox en header
- [ ] AC-02 SSE endpoint en bridge para subscribe a estado de cola
- [ ] AC-03 Auto-recovery testeado (kill job mid-flight, restart, verifica recover)
- [ ] AC-04 Tests BATS ≥15 score ≥80
- [ ] AC-05 Doc `docs/rules/domain/task-queue.md`

### Slice 2
- [ ] AC-06 `scripts/savia-voice-chunk.sh` toma texto >1KB, devuelve audio único sin glitches audibles en boundaries
- [ ] AC-07 Bounded concurrency 2 (no agotar CPU/RAM)
- [ ] AC-08 Tests con texto español que incluye abreviaturas (Sr., Dra., etc.)

### Slice 3
- [ ] AC-09 Kokoro instalado, modelo descargado a `~/.savia/kokoro/`
- [ ] AC-10 `scripts/kokoro-tts.sh` genera .wav español inteligible
- [ ] AC-11 Skill documentado con ejemplos
- [ ] AC-12 Latency < 2x realtime en hardware actual (verificable)

## No hacen

- NO adopta Tauri shell (Savia es CLI-first)
- NO adopta voice cloning zero-shot (sigue requiriendo GPU — SE-042 no se desbloquea)
- NO adopta multi-track editor, system audio capture, post-processing pedalboard
- NO sustituye whisper-env existente (Slice 3 añade salida CPU; transcripción sigue como está)
- NO instala torch/torchvision si Kokoro tiene runtime alternativo más ligero (verificar en Slice 3 prep)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Kokoro español calidad insuficiente | Media | Medio | Validación A/B vs cloud TTS antes de promote a default; sigue siendo opt-in |
| task_queue.py asume FastAPI runtime | Alta | Bajo | Adaptar a bridge existente o skill standalone |
| Chunking audible en boundaries | Media | Medio | Crossfade ajustable, fallback a no-chunk para textos cortos |
| Voicebox cambia API entre Slices | Baja | Bajo | Pinear commit hash en momento de adopción |
| Disco: Kokoro + deps ~500MB | Alta | Bajo | Documentar requisito; aceptable |

## Dependencias

- Slice 1 puede arrancar inmediatamente (independiente de SE-074)
- Slice 2 independiente de Slice 1
- Slice 3 independiente de los anteriores (Kokoro standalone)
- Los 3 slices no se bloquean entre sí — pueden ir en PRs separados o batch único

## Comparativa Kokoro vs alternativas para voz español

| Opción | GPU | Calidad ES | Latency | Estado en Savia |
|---|---|---|---|---|
| Cloud TTS (ElevenLabs/etc) | No | Alta | Latencia red | Disponible si key |
| Kokoro 82M (este SE-075) | No | Media-alta | 150x realtime CPU | Propuesto |
| SE-042 voice training | Sí | Alta personalizada | N/A (no implementado) | GPU-blocked |
| Espeak / Festival legacy | No | Baja | Real-time | Disponible degradado |

## Referencias

- `https://github.com/jamiepine/voicebox` — repo origen (MIT, 23k stars, push 2026-04-26)
- `https://github.com/jamiepine/voicebox/blob/main/backend/services/task_queue.py` — fuente Slice 1
- `https://github.com/jamiepine/voicebox/blob/main/backend/services/tts.py` — patrón Slice 2
- `https://github.com/hexgrad/Kokoro-82M` — modelo TTS Slice 3
- SE-042 voice training (GPU-blocked, complementario)
- SE-074 parallel spec execution (Slice 1 de SE-075 lo habilita)
- `.claude/skills/savia-voice/`, `~/.savia/whisper-env` — infra existente

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Slice 1 task_queue.py | módulo Python standalone | invocable igual, sin acoplamiento de frontend |
| Slice 2 auto-chunking | helper en `.claude/skills/savia-voice/` | autoload vía AGENTS.md (SE-078) |
| Slice 3 Kokoro CPU voice | dep Python `kokoro-onnx` | idéntico, sin binding específico |

### Verification protocol

- [ ] `bash scripts/savia-voice-smoke.sh` pasa tras switch a OpenCode v1.14
- [ ] `python3 -m savia_voice.task_queue --selftest` ejecuta sin Claude Code presente
- [ ] Tests Slice 1/2/3 son agnostic-frontend (BATS + pytest puros)

### Portability classification

- **PURE_BASH**: Los 3 slices son backend Python + scripts bash. No requieren hooks ni events específicos de Claude Code. Las invocaciones desde OpenCode resuelven igual que desde Claude Code (script paths absolutos en `scripts/` o `.claude/skills/`).
