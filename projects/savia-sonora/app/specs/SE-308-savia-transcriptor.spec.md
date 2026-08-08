# Spec: SE-308 — Savia Transcriptor

**Task ID:**        SE-308
**PBI padre:**      SE-308 — Aplicacion de escritorio capturadora de reuniones
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     python-developer + frontend-developer (React)
**Estado:**         PROPOSED

**Decisiones de diseño (2026-08-04, aprobadas por la operadora):**

| Decisión | Elección | Justificación |
|---|---|---|---|
| Detección de reunión | **Solo VAD** (voz continua >3s) | Simple y robusto entre OS. Sin fragilidad de detección de ventana |
| Audio | **Mic + sistema en 1 pista** (estéreo) | Hereda de VoiceFlow, sin diarización en v1 |
| Capturas | **Monitor configurable, default principal** | Cubre la mayoría de reuniones |
| Transcripción | **La app transcribe al terminar** | faster-whisper → VTT+MD automático, Savia solo digiere |
| Base | **Fork de VoiceFlow** | Reutiliza audio+GUI+whisper+SQLite |
| Confidencialidad | **Todo N3 local** | Sin filtros de zona en v1, todo en `~/.savia/`, nunca al repo |
| Modelo Whisper | **Auto-selección** | Detecta idioma del sistema y elige small/medium según capacidad |
| Resolución capturas | **Configurable** | Default redimensionar a 1920px ancho (ahorra ~70% disco) |
| Integración Savia | **Binario independiente** | Savia observa `~/.savia/transcriptor/reuniones/` y digiere por carpeta. Cero acoplamiento |
| Retención | **Conservar todo** | Audio re-transcribible + capturas re-analizables. N3 local, disco barato |
| Primer paso | **Fork + audio (S1)** | Base sólida antes de añadir features |

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 240 min (estimacion inicial) |
| Human effort | 16 h |
| Review effort | 90 min |
| Context risk | medium |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 8h |

---

## 1. Contexto y Objetivo

Savia necesita alimentarse de reuniones y chats del equipo para generar contexto
de proyecto, alertas y digests. La via corporativa (Microsoft Graph API) depende
de admins de tenant a los que no se tiene acceso. La alternativa viable: una
**aplicacion local de escritorio** que capture lo que pasa en la pantalla y el
audio del usuario, sin depender de permisos corporativos.

**Concepto**: Savia Transcriptor es una app de escritorio (Windows, Linux, macOS)
que:

1. **Escucha el audio del sistema continuamente** (mic + sistema)
2. **Detecta automaticamente cuando hay una reunion** — al recibir senal de voz
   (Voice Activity Detection), inicia la grabacion
3. **Graba el audio** como OBS Studio (loopback WASAPI/PipeWire/BlackHole)
4. **Captura la pantalla** en vez de video: screenshots cada X segundos (configurable)
5. **Transcribe el audio localmente** con Whisper (faster-whisper)
6. **Organiza todo en carpetas de reuniones** que Savia puede digerir luego:
   audio + transcripcion VTT + capturas PNG

**Diferenciador vs OBS**: OBS graba video continuo. Savia Transcriptor captura
solo cuando hay voz (auto-trigger), y guarda screenshots periodicos en lugar de
video — mucho mas ligero, mas privado, y mas facil de procesar por un LLM.

---

## 2. Stack y Base

### 2.1 Base: VoiceFlow (MIT, 405★)

[VoiceFlow](https://github.com/infiniV/VoiceFlow) es la base ideal — ya cubre:

| Capacidad | VoiceFlow | Gap para Savia |
|---|---|---|
| Captura mic + sistema en 1 pista | ✅ WASAPI/PipeWire | — |
| Transcripcion local faster-whisper | ✅ 16+ modelos, CUDA/CPU | — |
| SQLite historial | ✅ `~/.VoiceFlow/` | Reubicar a `~/.savia/transcriptor/` |
| Tray + hotkey + dashboard | ✅ Pyloid (PySide6+Qt WebEngine) | — |
| Export MD/TXT/SRT/JSON | ✅ | Añadir VTT + estructura de reuniones |
| Auto-trigger por voz (VAD) | ❌ (grabacion manual) | **Nuevo** |
| Screenshots periodicos | ❌ | **Nuevo** |
| macOS soportado | ⚠️ (no oficial) | Mejorar |
| Deteccion de ventana activa (¿es Teams/Zoom?) | ❌ | **Nuevo** |

### 2.2 Componentes

| Componente | Libreria | Motivo |
|---|---|---|
| VAD (deteccion de voz) | [silero-vad](https://github.com/snakers4/silero-vad) (9.8K★) | Trigger automatico, enterprise-grade |
| Transcripcion | [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | Local, CUDA/CPU, 99+ idiomas |
| Captura pantalla | [python-mss](https://github.com/BoboTiG/python-mss) (1.3K★) | Screenshots ultra-rapidos, cross-platform |
| Shell GUI | [Pyloid](https://github.com/pyloid/pyloid) | PySide6 + Qt WebEngine (ya en VoiceFlow) |
| Frontend | React 18 + Vite + Tailwind | Dashboard, ya en VoiceFlow |
| Storage | SQLite | Indice de reuniones + transcripciones |

---

## 3. Arquitectura

```
┌────────────────────────────────────────────────────────────┐
│                    Savia Transcriptor                        │
│                                                             │
│  ┌────────────────────┐    ┌───────────────────────────┐   │
│  │ Audio Pipeline      │    │ Screen Capture (mss)      │   │
│  │  mic + system       │    │  screenshot cada X s      │   │
│  │  (WASAPI/PipeWire)  │    │  (configurable, def 15s)  │   │
│  └─────────┬──────────┘    └─────────────┬─────────────┘   │
│            │  audio frames               │ PNG             │
│            ▼                             ▼                 │
│  ┌────────────────────┐    ┌───────────────────────────┐   │
│  │ VAD (silero)        │    │ Session Manager           │   │
│  │  ¿hay voz? ¿cuánto? │◄───│  arranca/para sesion      │   │
│  └─────────┬──────────┘    │  (trigger: VAD + ventana)  │   │
│            │ voz continua  └─────────────┬─────────────┘   │
│            ▼                             │                 │
│  ┌────────────────────┐    ┌─────────────▼─────────────┐   │
│  │ Audio Recorder      │    │ Meeting Store             │   │
│  │  (grabar solo       │    │  ~/.savia/transcriptor/   │   │
│  │   cuando sesion)    │    │  reuniones/YYYY-MM-DD/    │   │
│  └─────────┬──────────┘    │   ├─ audio.wav             │   │
│            │               │   ├─ transcript.vtt        │   │
│            │               │   ├─ capturas/xx.png       │   │
│            │               │   └─ meta.json             │   │
│            ▼               └────────────────────────────┘   │
│  ┌────────────────────┐                                       │
│  │ Transcriber         │◄────── Savia consume via skill      │
│  │  faster-whisper     │       (meeting-digest, visual-digest)│
│  │  post-reunion       │                                       │
│  └────────────────────┘                                       │
└────────────────────────────────────────────────────────────┘
```

### 3.1 Flujo de Sesion

```
Estado: IDLE (escuchando)

1. VAD detecta voz continua > 3s (configurable) → estado STARTING
2. Estado: RECORDING
   - audio se graba (wav, mic + sistema en 1 pista estéreo)
   - screenshot cada X s (mss, monitor configurable, default principal)
     → capturas/NNNN.png
3. VAD silencio continuo > 60s (configurable) → estado STOPPING
4. Confirmacion de fin (silencio mantenido o manual "stop") → FINISHED
5. Post-proceso automatico:
   - transcripcion faster-whisper → transcript.vtt + transcript.md
   - actualiza meta.json (duracion, frames, capturas, modelo)
6. Savia detecta carpeta nueva → skill de digest (meeting-digest + visual-digest)
```

**Decisión**: detección por solo VAD. No se analiza ventana activa — la voz
continua es el gatillo. Riesgo aceptado: podría grabar un podcast con voz; el
usuario puede detener manualmente o ajustar el threshold.

### 3.2 Deteccion de reunion por VAD

```python
# core/vad.py
import silero_vad
import numpy as np

class VoiceActivityDetector:
    """Detecta cuando empieza/termina una reunion por senal de voz."""

    def __init__(self, threshold: float = 0.5, speech_ms: int = 3000,
                 silence_ms: int = 60000):
        self.model = silero_vad.load_model()
        self.speech_threshold = threshold
        self.speech_required = speech_ms      # voz continua para START
        self.silence_to_stop = silence_ms     # silencio para STOP

    def feed(self, audio_chunk: np.ndarray) -> str:
        """Devuelve estado: IDLE | STARTING | RECORDING | STOPPING | STOPPED."""
        speech_prob = self.model(torch.from_numpy(audio_chunk))
        # acumular duracion de voz / silencio
        ...
```

### 3.3 Captura de Pantalla Periodica

```python
# core/screen.py
import mss
from pathlib import Path

class ScreenCapture:
    """Screenshot periodico durante una sesion.

    Configuracion:
    - monitor: 1 = principal (default), 0 = todos, N = especifico
    - resize_width: redimensionar a este ancho (default 1920, 0 = nativo)
    """

    def __init__(self, interval_seconds: int = 15, output_dir: Path = None,
                 monitor: int = 1, resize_width: int = 1920, quality: str = "png"):
        self.interval = interval_seconds
        self.output_dir = output_dir
        self.monitor = monitor  # 1 = principal (default), 0 = todos, N = especifico
        self.resize_width = resize_width  # 0 = resolucion nativa

    def capture_once(self) -> Path:
        """Captura 1 screenshot del monitor configurado."""
        with mss.mss() as sct:
            img = sct.grab(sct.monitors[self.monitor])
            png = self.output_dir / f"{timestamp}.png"
            mss.tools.to_png(img.rgb, img.size, output=str(png))
            if self.resize_width > 0:
                resize_to_width(png, self.resize_width)  # PIL: redimensionar
            return png
```

### 3.4 Seleccion Automatica de Modelo Whisper

```python
# core/model_selector.py
import locale

def select_whisper_model() -> str:
    """Elige modelo segun idioma del sistema + capacidad.

    - Espanol/catalan (no-ingles): medium (mas preciso)
    - Ingles: small (suficiente, mas rapido)
    - CPU debil o memoria < 8GB: forzar small
    """
    lang = locale.getdefaultlocale()[0].lower()
    if lang.startswith("es") or lang.startswith("ca"):
        return "medium"
    return "small"
```

### 3.5 Estructura de Datos

```
~/.savia/transcriptor/
├── config.yaml              # intervalo screenshots, VAD thresholds, modelo whisper
├── index.db                 # SQLite: reuniones, sesiones, transcripts
└── reuniones/
    ├── 2026-08-04-09-15/
    │   ├── audio.wav
    │   ├── transcript.vtt
    │   ├── transcript.md
    │   ├── resumen.md        # (opcional, tras digest de Savia)
    │   ├── capturas/
    │   │   ├── 20260804_091501.png
    │   │   ├── 20260804_091516.png
    │   │   └── ...
    │   └── meta.json
    └── 2026-08-04-11-00/
        └── ...
```

### 3.6 Integracion con Savia

El transcriptor es una **app independiente** que Savia consume pasivamente:

1. **Skill** `transcriptor-digest`: cuando aparece una carpeta nueva en
   `~/.savia/transcriptor/reuniones/`, Savia:
   - lee `transcript.vtt` → `meeting-digest` agent → notas estructuradas
   - analiza `capturas/` → `visual-digest` → contexto visual
   - cruza con reglas de negocio → `meeting-risk-analyst` → alertas
2. **Config**: Savia puede configurar la app via `config.yaml` (intervalo,
   thresholds, modelos) desde un comando `/transcriptor config`
3. **Nivel de confidencialidad**: todo en `~/.savia/` local, N3. Nunca al repo.

---

## 4. Inputs/Outputs

### Inputs
- Audio del mic + sistema (loopback WASAPI/PipeWire/BlackHole)
- Senal VAD (para trigger)
- Configuracion del usuario (intervalo capturas, thresholds, modelo)

### Outputs
- `~/.savia/transcriptor/reuniones/YYYY-MM-DD-HH-MM/` — carpetas de reunion
  - `audio.wav` — audio de la sesion
  - `transcript.vtt` + `transcript.md` — transcripcion local
  - `capturas/*.png` — screenshots periodicos
  - `meta.json` — metadata (duracion, modelo, frames)
- `~/.savia/transcriptor/index.db` — indice SQLite

---

## 5. Constraints and Limits

- **Local-first**: el audio nunca sale de la maquina (solo Whisper local)
- **Privacidad**: solo graba cuando hay voz (VAD) — no graba silencio continuo
- **Screenshots no video**: evita el peso y la complejidad de codificacion de video
- **Multi-OS**: Windows (WASAPI), Linux (PipeWire/PulseAudio), macOS (BlackHole + screen capture)
- **Consumo**: faster-whisper tiny (~75MB) para CPU, large-v3 para precision
- **Ciclo de vida**: sesion termina tras silencio continuo configurable
- **Nunca versiona**: la carpeta de reuniones es local, fuera de git

---

## 6. Test Scenarios

1. **VAD START**: se inyecta audio de voz 4s → estado RECORDING
2. **VAD STOP**: silencio 60s → sesion FINISHED
3. **Screenshot interval**: sesion de 2min con intervalo 15s → ~8 capturas
4. **Transcripcion**: audio real → transcript.vtt con texto legible
5. **Multi-sesion**: 2 reuniones en el mismo dia → 2 carpetas separadas
6. **Config cambio**: cambiar intervalo en runtime → aplica a la siguiente captura
7. **Falsa reunion**: musica de fondo (sin voz) → NO arranca sesion
8. **Perf**: 1h de reunion → < 500MB en disco (audio wav + ~240 capturas)

---

## 7. Ficheros a Crear

| Fichero | Proposito |
|---|---|
| `projects/savia-sonora/app/CLAUDE.md` | Entrypoint del proyecto |
| `projects/savia-sonora/app/README.md` | Documentacion |
| `projects/savia-sonora/app/ARCHITECTURE.md` | Arquitectura detallada |
| `projects/savia-sonora/app/specs/SE-308-savia-transcriptor.spec.md` | Esta spec |
| `core/vad.py` | Deteccion de voz (silero) |
| `core/screen.py` | Captura periodica (mss) |
| `core/recorder.py` | Grabacion de audio (loopback) |
| `core/transcriber.py` | Transcripcion (faster-whisper) |
| `core/session.py` | Session Manager (estados IDLE/RECORDING/FINISHED) |
| `core/store.py` | Meeting Store + SQLite index |
| `app/` | Pyloid shell + React dashboard |

---

## 8. Roadmap de Implementacion

### S1 — Núcleo de audio (base VoiceFlow)
- [ ] Fork de VoiceFlow a `savia-transcriptor`
- [ ] Reubicar storage de `~/.VoiceFlow/` a `~/.savia/transcriptor/`
- [ ] Verificar captura mic + sistema en las 3 OS

### S2 — VAD auto-trigger
- [ ] Integrar silero-vad en el pipeline de audio
- [ ] Maquina de estados IDLE → RECORDING → FINISHED
- [ ] Config thresholds (speech_ms, silence_ms)

### S3 — Captura de pantalla
- [ ] Integrar mss para screenshots periodicos
- [ ] Configuracion de intervalo + monitor
- [ ] Guardar en carpeta de reunion

### S4 — Transcripcion post-sesion
- [ ] faster-whisper → VTT + MD
- [ ] Actualizar index.db

### S5 — Integracion con Savia
- [ ] Skill `transcriptor-digest`
- [ ] Comando `/transcriptor`
- [ ] Detecta carpetas nuevas y dispara digests

### S6 — Tests + packaging
- [ ] BATS + pytest para VAD/session
- [ ] Builders Windows/Linux/macOS

---

## 9. Estado de Implementacion

- [x] **S1: Núcleo de audio (fork VoiceFlow)** — COMPLETADO 2026-08-04
  - [x] Fork de VoiceFlow a `projects/savia-sonora/app/`
  - [x] Storage reubicado: `~/.VoiceFlow/` → `~/.savia/transcriptor/` (módulo central `services/paths.py`)
  - [x] DB: `index.db`, log: `transcriptor.log`, secrets: `secrets.json`, cuda: `cuda/`
  - [x] Rebrand: `savia-transcriptor`, mutex y service name actualizados
  - [x] Captura de sistema verificada: monitor source detectado via `pactl` (PipeWire 35)
  - [ ] Tests del entorno completo (requieren venv con faster-whisper)
- [x] **S2: VAD auto-trigger** — COMPLETADO 2026-08-04
  - [x] `services/recording/vad.py` — VadSupervisor: maquina de estados IDLE→RECORDING→IDLE
    - voz continua >= speech_ms → `started` (arranca)
    - silencio continuo >= silence_ms → `stopped` (para)
    - voz interrumpida resetea el contador de inicio
  - [x] `services/recording/vad_silero.py` — backend silero-vad (lazy import, threshold)
  - [x] `services/recording/auto_trigger.py` — AutoTrigger: listener + supervisor + callbacks on_start/on_stop
  - [x] Settings: `vad_auto_trigger_enabled`, `vad_speech_ms` (3000), `vad_silence_ms` (60000), `vad_speech_threshold` (0.5), `vad_capture_interval_s` (15)
  - [x] Tests: test_vad (8 checks), test_vad_silero (2), test_auto_trigger (3), test_settings_vad (6)
- [x] **S3: Captura de pantalla** — COMPLETADO 2026-08-04
  - [x] `services/recording/screen.py` — ScreenCapture (python-mss)
    - monitor configurable (1 = principal, 0 = todos, N = especifico)
    - intervalo configurable (default 15s)
    - resize opcional (PIL, default 1920px ancho, 0 = nativo)
    - backend inyectable para tests (sin dependencia C)
  - [x] `services/recording/session_coordinator.py` — SessionCoordinator
    - une VAD → audio recorder + screen capture
    - start/stop simultaneos, sin doble arranque
  - [x] Tests: test_screen (5), test_session_coordinator (3)
- [x] **S4: Transcripcion post-sesion** — COMPLETADO 2026-08-04
  - [x] `services/recording/postprocessor.py` — MeetingPostProcessor
    - transcribe audio.wav (via transcriber inyectado) → transcript.vtt + transcript.md
    - timestamps VTT (00:00:00.000 --> 00:00:01.000)
    - actualiza meta.json (transcribed, language, transcript_files)
  - [x] `services/recording/meeting_store.py` — MeetingStore
    - carpetas reuniones/YYYY-MM-DD-HH-MM/ (colisiones con sufijo)
    - list_sessions, list_undigested, mark_digested, mark_transcribed
    - meta.json con estado digested (el hook que Savia usa)
  - [x] Tests: test_postprocessor (6), test_meeting_store (6)
- [x] **S5: Integracion con Savia** — COMPLETADO 2026-08-04
  - [x] Skill `transcriptor-digest` (.claude/skills/)
  - [x] Comando `/transcriptor` (scan, digest, mark, status)
  - [x] Scripts: `transcriptor-scan.sh`, `transcriptor-mark-digested.sh`
- [x] **S6: Tests + packaging** — COMPLETADO 2026-08-04
  - [x] Test BATS de integracion: `tests/test-transcriptor.bats` (6 tests)
  - [x] README actualizado con arquitectura completa
  - [ ] Builders de instaladores (requieren entorno con deps: faster-whisper, PySide6)
