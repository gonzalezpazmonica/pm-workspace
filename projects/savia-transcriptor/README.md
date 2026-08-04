# Savia Transcriptor

App de escritorio que captura reuniones de forma automatica para alimentar el contexto de Savia.

## Por que existe

Savia necesita digerir reuniones (transcripciones + capturas de pantalla) para generar contexto
de proyecto, alertas y digests. La via corporativa (Microsoft Graph API) depende de admins de
tenant sin acceso. Esta app resuelve el problema localmente: escucha el audio, detecta cuando
hay una reunion por senal de voz, graba, transcribe y captura la pantalla.

## Que hace

1. **Escucha el audio** del mic + sistema continuamente
2. **Detecta reunion** por VAD (voz continua > 3s configurable) → empieza a grabar solo
3. **Graba audio** (wav, mic + sistema en una pista, como OBS)
4. **Captura pantalla** cada X segundos (configurable, default 15s) en PNG, no video
5. **Transcribe localmente** con faster-whisper → VTT + MD
6. **Organiza** todo en carpetas por reunion que Savia digiere despues

## Stack

| Aspecto | Eleccion |
|---------|----------|
| Base | [VoiceFlow](https://github.com/infiniV/VoiceFlow) (MIT, fork) |
| Shell | Pyloid (PySide6 + Qt WebEngine) |
| Frontend | React 18 + Vite + Tailwind |
| VAD | silero-vad |
| Transcripcion | faster-whisper (CTranslate2) |
| Screenshots | python-mss + PIL |
| Storage | SQLite + carpetas (`~/.savia/transcriptor/`) |

## Arquitectura (modulos nuevos sobre el fork)

| Modulo | Funcion |
|--------|---------|
| `services/paths.py` | Rutas centrales (`~/.savia/transcriptor/`) |
| `services/recording/vad.py` | VadSupervisor: maquina de estados IDLE→RECORDING→IDLE |
| `services/recording/vad_silero.py` | Backend silero-vad |
| `services/recording/auto_trigger.py` | AutoTrigger: listener + supervisor + callbacks |
| `services/recording/session_coordinator.py` | Une VAD → audio + screen capture |
| `services/recording/screen.py` | ScreenCapture (mss, monitor + resize) |
| `services/recording/postprocessor.py` | Transcribe audio → VTT + MD |
| `services/recording/meeting_store.py` | Carpetas de reuniones + estado digested |

## Integracion con Savia

- Skill `transcriptor-digest` — digiere transcripciones y capturas
- Comando `/transcriptor` — scan, digest, mark, status
- Scripts: `transcriptor-scan.sh`, `transcriptor-mark-digested.sh`
- Confidencialidad N3: datos locales, nunca al repo

## Quick Start (desarrollo)

```bash
cd projects/savia-transcriptor
pnpm run setup        # instala deps Node y Python
pnpm run dev          # Vite frontend + Pyloid backend
```

## Tests

- Unit: `src-pyloid/tests/` (paths, vad, screen, postprocessor, store, coordinator)
- Integracion: `tests/test-transcriptor.bats` (scripts de Savia)

## Specs

- SE-308: `specs/SE-308-savia-transcriptor.spec.md`
