# Spec: SE-310 — Savia Conversacional (S0): interfaz de voz bidireccional en Savia Transcriptor

**Task ID:**        SE-310
**PBI padre:**      SE-310 — Savia conversacional: Savia habla con la operadora (extension de SE-308)
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-07
**Creado por:**     Savia (auditoria de capacidades de voz existentes)

**Developer Type:** agent-team
**Asignado a:**     python-developer + frontend-developer (React)
**Estado:**         PROPOSED

**Decisiones de diseño (2026-08-07, propuestas para aprobacion):**

| Decision | Eleccion | Justificacion |
|---|---|---|
| Alcance S0 | **Conversacion bidireccional push-to-talk** | Cierra "Savia habla conmigo" con lo ya existente. Participacion en vivo en S1/S2 (fuera de alcance) |
| Entrada de voz | **Reusar dictado push-to-talk existente** (release-to-send) | Ya captura audio por hotkey + transcribe con faster-whisper; cero infra nueva |
| Hotkey conversacion | **SEPARADO del dictado** (default `ctrl+alt+win`) | El dictado pega en el cursor; la conversacion envia al LLM. El mismo hotkey no puede hacer ambos: el release seria indeterminado. Hotkey propio con callbacks propios |
| Cerebro | **Reusar `OpenAICompatibleProvider`** (OpenAI/Groq/OpenRouter/LM Studio/Ollama) | Ya existe con streaming; default Ollama = todo local N3 |
| Salida de voz | **`TTSProvider` pluggable**: backend `subprocess` + `none` | Patron `$SAVIA_TTS_CMD` de SE-075 (placeholders `{out}/{text}`); reutiliza `savia-kokoro.py` si esta en PATH/visible |
| TTS por defecto | **`none` (solo texto)** | Misma filosofia que `SAVIA_VOICE=off` (SE-075): no hablar sin opt-in explicito |
| Control de voz | **Un solo switch `voice_enabled` + backend config** | `voice_enabled=false` fuerza no hablar (toggle runtime); `tts_backend=none` es el backend por defecto. Si `voice_enabled=true` pero `tts_backend=none` → el toggle no hace nada visible (doc de settings lo aclara); no hay mas estados |
| Latencia de TTS | **Chunking por frase** (sentence-buffer) + **cap de cola** | Streaming del LLM → TTS por frase. La cola SERIAL tiene tope (default 3 frases): si el LLM va mas rapido que Kokoro, las frases viejas se descartan (barge-in) para que la voz no llegue 30s tarde |
| Audio output | **sounddevice OutputStream** (dependencia ya presente) | Reproduce WAV en el altavoz sin dependencias nuevas |
| Persistencia | **Append por mensaje** en `conversaciones/YYYY-MM-DD-HH-MM.md` | Cada mensaje completo se persiste al terminar (no al cerrar sesion): sobrevive a un cierre de app; `digested` en `index.db` |
| Concurrencia | **Conversacion y grabacion de reunion coexisten** | Dictado ya coexiste con grabacion; la conversacion usa el mismo path de captura push-to-talk (mismo arbitraje de device que el dictado) |
| Confidencialidad | **N3 local**: audio nunca sale de la maquina | STT local (whisper), TTS local (Kokoro); solo TEXT al endpoint LLM configurado; API keys via keyring |
| Sistema de prompt | **Inyectable** (default identidad Savia) | Config `conversation.system_prompt`; evita hardcodear la personalidad |

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 360 min (estimacion inicial) |
| Human effort | 16 h |
| Review effort | 60 min |
| Context risk | low |
| Agent-capable | partial (audio real requiere humano) |
| Fallback | Si agente falla: humano necesita 8h |

---

## 1. Contexto y Objetivo

Savia Transcriptor (SE-308, fork de VoiceFlow) ya **graba reuniones** de forma
autonoma: VAD (silero-vad) detecta voz, graba `audio.wav` + screenshots y
transcribe localmente con faster-whisper. El workspace ya tiene **voz de salida**
local: SE-075 Slice 3 (Kokoro 82M, CPU, espanol) implementado el 2026-06-24
(`scripts/savia-kokoro.py`, `scripts/savia-voice-speak.sh`, `savia-voice-chunk.sh`).

**Hueco**: nadie ha unido las dos mitades. Savia puede ESCUCHAR (transcriptor)
y puede HABLAR (Kokoro), pero no hay un bucle conversacional: la operadora no
puede decirle algo por microfono y recibir respuesta por voz en una conversacion
continua.

**Objetivo S0**: convertir Savia Transcriptor en una **interfaz conversacional
de Savia** para el objetivo "hablar conmigo":

1. La operadora pulsa el hotkey de push-to-talk (reusado del dictado) y habla.
2. El Transcriptor transcribe localmente (faster-whisper).
3. Envia el texto al cerebro (OpenAICompatibleProvider → Ollama/OpenRouter, con
   el system prompt de Savia).
4. Transmite la respuesta en streaming a la UI **y** la sintetiza por frases
   (TTSProvider → Kokoro via subprocess) reproduciendola por el altavoz.
5. Guarda el transcripto de la conversacion en `~/.savia/transcriptor/conversaciones/`
   para que Savia la digiera despues (transcriptor-digest), como ya hace con reuniones.

**Diferenciador**: no es un chat de voz genérico. Es la misma Savia (identidad,
memoria, skills) hablando por el mismo pipeline local N3 que el workspace usa
por texto. La conversacion queda persistida como un artefacto digerible, igual
que una reunion.

---

## 2. Arquitectura

### 2.1 Bucle conversacional

```
┌──────────────────────────────────────────────────────────────────┐
│                    Savia Transcriptor (app)                        │
│                                                                    │
│  [hotkey push-to-talk]  ┌──────────────────────────────────────┐  │
│       release-to-send   │ ConversationService                   │  │
│  ┌─────────▼────────┐   │                                       │  │
│  │ DictationPath    │──►│ 1. transcribe (faster-whisper, local)│  │
│  │ (existente)      │   │ 2. build_context (history + prompt)  │  │
│  └──────────────────┘   │ 3. stream LLM (OpenAICompatible)     │──┐ │
│                         │ 4. sentence-buffer -> TTSProvider    │  │ │
│  ┌──────────────────┐   │ 5. persist -> ConversationStore      │  │ │
│  │ TTSProvider      │◄──┘                                       │  │ │
│  │  subprocess      │                                           │  │ │
│  │  (savia-kokoro)  │                                           │  │ │
│  └─────────┬────────┘                                           │  │ │
│            │ WAV                                                │  │ ▼
│  ┌─────────▼────────┐   ┌───────────────────────────────┐        │  │
│  │ AudioOutput      │   │ ConversationStore             │        │  │
│  │ (sounddevice)    │   │ ~/.savia/transcriptor/        │        │  │
│  └──────────────────┘   │   conversaciones/YYYY-MM-DD/  │        │  │
│                         └───────────────┬───────────────┘        │  │
└─────────────────────────────────────────┼────────────────────────┘──┘
                                          │
                              [savia-kokoro.py via subprocess]  (workspace, si configurado)
                                          │
                              Savia digiere la conversacion via transcriptor-digest
```

### 2.2 Contratos

```python
# services/conversation/tts_provider.py
class TTSProvider(Protocol):
    # TODAS las implementaciones son NO-BLOQUEANTES: encolan en un worker
    # thread y devuelven al instante (nunca congelan la UI). Reproduccion
    # SERIAL: una frase por vez; la siguiente espera a que termine la anterior.
    def speak(self, text: str) -> None: ...
    def stop(self) -> None: ...            # corta cola + audio en curso (interrupcion)

class SubprocessTTS:
    """Backend subprocess. Contrato: el comando escribe el audio en `{out}`
    (WAV 16kHz mono) y recibe el texto en `{text}` (patron SE-075).
    Ejemplo default: kokoro | python3 savia-kokoro.py --text {text} --output {out} --json
    Si el comando no existe o falla -> degrada a none (no rompe la conversacion)."""
    def __init__(self, command_template: str, playback: AudioOutput,
                 worker: "SerialAudioQueue"): ...

class NoopTTS:
    """Backend none: solo texto. Es el default (opt-in de voz)."""

def build_tts(settings) -> TTSProvider: ...

# services/conversation/audio_output.py
class AudioOutput:
    """Reproduce WAV 16kHz mono via soundfile.read + sounddevice.OutputStream.
    Stop() corta el stream actual. Sin dependencias nuevas."""

# services/conversation/conversation_service.py
class ConversationMessage(TypedDict):
    role: Literal["user", "assistant"]
    content: str
    timestamp: str

class ConversationService:
    """Orquesta push-to-talk -> transcribe -> LLM stream -> TTS -> persist.
    Ejecuta en background thread; la UI recibe eventos IPC (nunca bloqueo)."""
    def __init__(self, transcriber, llm: OpenAICompatibleProvider,
                 tts: TTSProvider, store: ConversationStore,
                 system_prompt: str, max_history: int = 20): ...

    def on_push_to_talk_released(self, audio: np.ndarray) -> None: ...
        # 1. transcribe audio (REUSA el modelo whisper global ya cargado, sin recargar)
        # 2. si transcripto vacio/silencio -> descarta, no envia nada al LLM
        # 3. add user msg -> stream llm (max_history)
        #    on token: event conversation:token (UI live) + sentence-buffer
        #    frase completa -> tts.speak(frase)
        # 4. on complete: persist to store, event conversation:state=idle
        # 5. on error: event conversation:error, estado recuperable

    def cancel(self) -> None: ...          # interrumpir respuesta: para LLM stream + tts.stop()
    def reset(self) -> None: ...           # nueva conversacion
    def history(self) -> list[ConversationMessage]: ...
```

**Hotkey / desambiguacion**: el dictado (`ctrl+win`) y la conversacion
(`ctrl+alt+win`) son hotkeys DISTINTOS. El `HotkeyService` registra callbacks
separados: el release del hotkey de conversacion llama a
`ConversationService.on_push_to_talk_released` (nunca al path de dictado).
Si el usuario pulsa ambos hotkeys a la vez, gana el primero registrado; el
segundo release se ignora hasta que el primero complete (guard anti-solapamiento).

**Arbitraje de device de audio**: el push-to-talk de conversacion captura por
el MISMO path que el dictado (ya coexiste con la grabacion de reunion en SE-308).
No se abre un segundo stream sobre el device del mic mientras el dictado o la
reunion lo usan — se serializa la captura push-to-talk con un lock de un solo
usuario a la vez. Si el lock esta tomado (reunion grabando), el push-to-talk de
conversacion se encola y arranca al soltar la reunion (max wait 2s, si no → aviso).

**Estado ocupado**: mientras el estado NO es `idle` (transcribiendo/pensando/
hablando), un nuevo push-to-talk se rechaza con `conversation:notice`
("Savia esta respondiendo") salvo que se cancele primero. Evita colas de
peticiones sin control y respuestas solapadas.

**Carga del modelo whisper**: lazy-load compartido con el resto de la app. La
primera conversacion puede pagar la carga del modelo (segundos); el spec NO
exige recargar por conversacion. El modelo usado es el global configurado; si se
quiere menor latencia, la operadora configura un modelo pequeno (settings).

**IPC contract (Pyloid bridge, backend → frontend):**

| Evento | Payload | Significado |
|---|---|---|
| `conversation:state` | `idle\|listening\|transcribing\|thinking\|speaking\|error` | Maquina de estados visible en UI |
| `conversation:message` | `{role, content, timestamp}` | Mensaje completo (user o assistant), persistido al completar |
| `conversation:token` | `{delta}` | Token parcial en streaming |
| `conversation:error` | `{message, recoverable}` | Fallo de LLM/TTS, UI no se corrompe; NO incluye prompt ni tokens |
| `conversation:history` | `messages[]` | Al abrir la vista: carga la sesion persistida en curso (o vacio si es nueva) |
| `conversation:notice` | `{kind, text}` | Avisos no-bloqueantes: "voz no disponible, respondo por texto" (una vez por sesion), "hotkey en uso", etc. |

**Interrupcion**: el usuario puede parar la respuesta de Savia (segundo pulso del
hotkey o boton UI) → `ConversationService.cancel()` → corta el stream LLM y el
TTS. Es la interaccion de "Savia, para". La parte ya completada queda persistida.

**Sentence buffer**: flushes en `.?!\n` o tras N chars (N=180 default). Si una
frase excede N sin puntuacion, se corta por el ultimo espacio (no bloquea el stream).

**Cola TTS (barge-in)**: `SerialAudioQueue` reproduce UNA frase a la vez. Si
llegan mas de `tts_queue_cap` (default 3) frases pendientes, la mas antigua se
descarta (la voz no se acumula detras del texto). El texto de la UI SIEMPRE
muestra la respuesta completa aunque la voz se descarte.

**Redaccion en logs**: `transcriptor.log` NUNCA registra el contenido de
mensajes de conversacion (solo eventos: `conversation:started`, `message:ok`,
`error:llm_timeout`, con duraciones/IDs). El contenido vive solo en
`conversaciones/*.md` y `index.db` (ambos N3).

### 2.3 Configuracion (settings)

| Clave | Default | Descripcion |
|---|---|---|
| `conversation.enabled` | `true` | Activa la vista y el hotkey de conversacion |
| `conversation.hotkey` | `ctrl+alt+win` | Hotkey push-to-talk SEPARADO del dictado (`ctrl+win`); release = enviar al LLM |
| `conversation.max_seconds` | `60` | Limite de duracion del push-to-talk; el audio mas largo se corta y avisa (bound de input a whisper) |
| `conversation.llm_endpoint` | (reusa global) | OpenAI-compatible endpoint; `http://localhost:11434/v1` (Ollama) |
| `conversation.llm_model` | (reusa global) | Modelo |
| `conversation.llm_api_key` | keyring | Via keyring (ya en VoiceFlow); vacio = endpoint local sin auth |
| `conversation.llm_timeout_s` | `30` | Timeout por turno; al expirar → `conversation:error` recuperable (el provider global usa read 120s; la conversacion exige respuesta en 30s) |
| `conversation.system_prompt` | Identidad Savia | Texto inyectable; default identidad de Savia |
| `conversation.max_history` | `20` | Mensajes de contexto; cada mensaje se TRUNCA a `max_message_chars` (token budget efectivo) |
| `conversation.max_message_chars` | `4000` | Trunca contenido largo por mensaje antes de enviar al LLM |
| `conversation.tts_backend` | `none` | `none` \| `subprocess` |
| `conversation.tts_command` | `` | Plantilla `{out}`/`{text}` (ej. `savia-kokoro --text {text} --output {out} --json`); WAV temporal en `~/.savia/transcriptor/tmp-tts/` con limpieza al arrancar |
| `conversation.tts_queue_cap` | `3` | Frases pendientes max en la cola TTS; exceso = descartar la mas antigua (barge-in) |
| `conversation.voice_enabled` | `false` | Interruptor runtime (sin recargar): hablar si/no. Inefectivo si `tts_backend=none` (doc de settings lo aclara) |

### 2.4 Persistencia

```
~/.savia/transcriptor/conversaciones/
├── 2026-08-07-18-00.md        # transcripto en markdown, estilo transcript.md
└── index.db                   # SQLite, misma DB que MeetingStore
```

Tabla `conversations` (aditiva, no toca las tablas de reuniones):

```sql
CREATE TABLE IF NOT EXISTS conversations (
    id          INTEGER PRIMARY KEY,
    started_at  TEXT NOT NULL,          -- ISO-8601
    dir         TEXT NOT NULL UNIQUE,   -- conversaciones/YYYY-MM-DD-HH-MM/
    message_count INTEGER NOT NULL DEFAULT 0,
    digested    INTEGER NOT NULL DEFAULT 0,
    meta_path   TEXT NOT NULL
);
```

`ConversationStore` reutiliza el patron de `MeetingStore` (carpeta por sesion,
`meta.json` con flag `digested`) para que `transcriptor-digest` y `meeting-digest`
puedan digerir conversaciones igual que reuniones, sin cambios en el skill.
El `transcripto` en `conversaciones/*.md` usa el mismo formato que
`transcript.md` de las reuniones (hablante: texto).

---

## 3. Inputs/Outputs

### Inputs
- Audio push-to-talk del mic (hotkey, reusado del dictado)
- Texto del LLM (streaming) + configuracion del usuario

### Outputs
- Texto de respuesta en streaming (UI)
- Voz sintetizada por el altavoz (si `voice_enabled` y `tts_backend` != none)
- `~/.savia/transcriptor/conversaciones/YYYY-MM-DD-HH-MM.md` — transcripto persistido
- Eventos IPC al frontend: `conversation:message`, `conversation:token`,
  `conversation:error`, `conversation:state`

---

## 4. Constraints and Limits

- **Local-first**: audio (entrada y salida) nunca sale de la maquina. Solo el
  TEXT del prompt viaja al endpoint LLM configurado. Si el endpoint es Ollama
  local, todo permanece N3 local.
- **Sin nuevos deps**: sounddevice, httpx, numpy, faster-whisper ya estan en
  `pyproject.toml`. El backend subprocess no exige empaquetar Kokoro en la app:
  usa el comando del sistema si existe; si no, degrada a `none`.
- **Latencia objetivo**: primera frase por voz < 5s desde el release del hotkey
  (whisper small + Ollama + Kokoro ~4s por 0.625s de audio). La respuesta
  completa por voz puede exceder (cola acotada); el texto es inmediato.
- **Concurrencia**: si hay una reunion en RECORDING, el push-to-talk de
  conversacion se serializa con un lock (max 2s de espera) y no interfiere con
  la grabacion.
- **No graba silencio**: solo captura cuando el hotkey esta pulsado, y como
  maximo `conversation.max_seconds` (default 60s).
- **Idioma conocido**: whisper auto-detecta; Kokoro sintetiza es/ing. Otros
  idiomas se transcriben pero suenan en la voz configurada (limitacion conocida,
  no bloquea S0).
- **Voz opt-in**: sin `voice_enabled` + backend configurado, Savia responde
  solo por texto (misma filosofia que `SAVIA_VOICE=off`).
- **Privacidad**: API keys via keyring, nunca en config plana ni logs; los logs
  de la app no contienen el contenido de conversaciones.

**Security review (gate pre-implementacion, SE-310)**: la feature trata datos
personales (voz de la operadora, contenido de conversaciones). Requisitos
minimos antes de implementar: (a) revisar que el audio nunca se escribe fuera
de `~/.savia/transcriptor/`; (b) que el subprocess de TTS no pase texto con
shell-expansion insegura (usar `subprocess` con lista de args / `shlex`, nunca
`shell=True`); (c) que `conversation:error` no filtre el contenido del prompt ni
tokens; (d) `digested=1` se respeta en el skill (no re-procesar). El audio de la
operadora es N3 (datos personales) — el code review E1 cubre estas 4 comprobaciones.

---

## 5. Test Scenarios

1. **Bucle completo (fakes)**: push-to-talk simulado → transcriber fake → LLM fake
   stream → TTS fake graba la frase → se persiste el transcripto.
2. **Voice off**: `voice_enabled=false` o `tts_backend=none` → la respuesta sale
   por texto, el TTS no se invoca (TTS fake registra 0 llamadas).
3. **Backend subprocess**: comando plantilla valido → se ejecuta con `{out}`
   y `{text}` sustituidos; comando inexistente → degrada a none, no rompe.
4. **LLM no alcanzable**: endpoint caido → evento `conversation:error`, la UI
   muestra error, la conversacion no se corrompe, reintento posible.
5. **Streaming**: el LLM fake emite tokens parciales → la UI los muestra en
   vivo y el sentence-buffer encola frases completas.
6. **Historia acotada**: 25 mensajes con `max_history=20` → el contexto enviado
   al LLM tiene 20, el resto se conserva en la UI/almacen.
7. **Persistencia**: tras N mensajes, `conversaciones/YYYY-MM-DD-HH-MM.md`
   contiene el transcripto y `index.db` registra la conversacion.
8. **Concurrencia**: con una reunion en RECORDING activa, un push-to-talk de
   conversacion se transcribe sin interrumpir la grabacion.
9. **System prompt**: el LLM fake verifica que `conversation.system_prompt`
   esta en el primer mensaje del contexto.
10. **Perf**: round-trip con modelos reales < 5s en hardware medio.
11. **Transcripcion vacia**: push-to-talk con silencio → `on_push_to_talk_released`
    descarta el audio, no envia nada al LLM, no rompe el estado.
12. **Cancelar**: mientras el LLM emite, `cancel()` corta el stream y el TTS
    (TTS fake registra `stop()`), la UI vuelve a `idle`, la conversacion queda
    parcial persistida sin corromperse.
13. **No bloqueo de UI**: el bucle corre en background; `conversation_service`
    nunca bloquea el hilo principal (verificable con un fake lento + timeout
    en el hilo UI).
14. **Shell-safe TTS**: el subprocess usa lista de args / `shlex.split`, nunca
    `shell=True` (test de inyeccion: texto con `; rm -rf` no ejecuta).
15. **Hotkeys desambiguados**: el release del hotkey de conversacion NUNCA
    invoca el path de dictado (mock del dictado registra 0 llamadas).
16. **Cap de cola TTS**: LLM fake rapido + TTS fake lento → nunca mas de
    `tts_queue_cap` pendientes; la frase mas antigua se descarta.
17. **Persistencia en cierre**: la app se "cierra" a mitad de respuesta → el
    `conversaciones/*.md` ya contiene los mensajes completados hasta ese punto
    (append por mensaje, no por sesion).
18. **Arbitraje de device**: reunion en RECORDING → push-to-talk de conversacion
    se encola y arranca al soltar (o avisa tras 2s); no abre segundo stream
    sobre el mic.
19. **max_seconds**: un push-to-talk mantenido 90s con `max_seconds=60` corta a
    los 60s y emite `conversation:notice`.
20. **Logs sin contenido**: tras una conversacion real, `transcriptor.log` no
    contiene ninguna cadena de los mensajes (solo eventos).

---

## 6. Ficheros a Crear/Modificar

### Crear (proyecto `projects/savia-transcriptor/`)

| Fichero | Proposito |
|---|---|
| `specs/SE-310-savia-conversacional.spec.md` | Esta spec |
| `src-pyloid/services/conversation/conversation_service.py` | Orquestador del bucle |
| `src-pyloid/services/conversation/tts_provider.py` | `TTSProvider` + `SubprocessTTS` + `NoopTTS` |
| `src-pyloid/services/conversation/sentence_splitter.py` | Split por frase (espanol, abreviaturas) |
| `src-pyloid/services/conversation/conversation_store.py` | Persistencia + `index.db` |
| `src-pyloid/services/conversation/audio_output.py` | Reproduccion WAV (sounddevice) |
| `src-pyloid/tests/test_conversation_service.py` | pytest bucle con fakes |
| `src-pyloid/tests/test_tts_provider.py` | pytest backends TTS |
| `src-pyloid/tests/test_sentence_splitter.py` | pytest splitter |
| `src-pyloid/tests/test_conversation_store.py` | pytest persistencia |
| `src/components/ConversationPage.tsx` | UI de conversacion |
| `src/pages/Conversation.tsx` | Pagina/panel en el dashboard |

### Modificar

| Fichero | Cambio |
|---|---|
| `src-pyloid/app_controller.py` | Cablear ConversationService, hotkey separado, eventos IPC |
| `src-pyloid/server.py` | Handlers IPC `conversation:*` |
| `src-pyloid/services/settings.py` | Claves de la seccion 2.3 |
| `src-pyloid/main.py` | Inicializar servicio |
| `src/App.tsx` | Ruta/pestana Conversacion |
| `src/components/Sidebar.tsx` | Navegacion |
| `docs/README.md` | Documentar el modo conversacional |
| `scripts/transcriptor-scan.sh` (workspace) | Escanear tambien `conversaciones/` (mismo formato `meta.json`/`digested`) — habilitador de AC-2 |
| `.claude/skills/transcriptor-digest/SKILL.md` | Solo doc: mencionar que escanea reuniones Y conversaciones (sin cambio de logica) |

---

## 7. Criterios de Aceptacion

- [ ] **AC-1** — Push-to-talk → Savia responde por voz (o texto si voz off);
      la PRIMERA frase audible sale en < 5s con modelos locales. La respuesta
      completa por voz puede tardar mas (cola TTS acotada por `tts_queue_cap`),
      pero el texto en UI es inmediato en streaming.
- [ ] **AC-2** — El transcripto se persiste por mensaje en
      `conversaciones/YYYY-MM-DD-HH-MM.md` y `index.db`; `transcriptor-scan.sh`
      se extiende para listar `conversaciones/` sin digerir (mismo formato
      `meta.json` con `digested`), y `transcriptor-digest` las digiere sin
      cambios de logica del skill.
- [ ] **AC-3** — `TTSProvider` es pluggable: `none` y `subprocess` (plantilla
      `{out}`/`{text}`, degradacion a none si falla), con tests de ambos.
- [ ] **AC-4** — La conversacion coexiste con la grabacion de reunion activa
      (lock de captura push-to-talk serializado; el push-to-talk de conversacion
      se encola si la reunion graba, max 2s).
- [ ] **AC-5** — N3: audio de entrada/salida local; solo TEXT al LLM; API keys
      via keyring; logs sin contenido de conversacion.
- [ ] **AC-6** — pytest del bucle con fakes (10+ tests) y los tests SE-308
      existentes siguen pasando sin cambios.
- [ ] **AC-7** — Hotkeys desambiguados: dictado (`ctrl+win`) y conversacion
      (`ctrl+alt+win`) con callbacks separados; release de conversacion NUNCA
      pasa por el path de dictado.
- [ ] **AC-8** — Cola TTS acotada: con un LLM fake rapido y un TTS fake lento,
      nunca hay mas de `tts_queue_cap` frases pendientes y la voz no se acumula
      (barge-in descarta la mas antigua).

---

## 8. Roadmap de Implementacion (dentro de S0)

### S0-A — Núcleo backend conversacional
- [ ] `ConversationStore` + `sentence_splitter` + `AudioOutput` (con tests)
- [ ] `TTSProvider` (`none` + `subprocess`) con degradacion
- [ ] `ConversationService` con el bucle completo (fakes)

### S0-B — Integracion app + UI
- [ ] Settings + cableado en `app_controller.py`/`server.py` (hotkey separado)
- [ ] `ConversationPage.tsx` (streaming, toggle voz, mic, boton cancelar)
- [ ] Persistencia por mensaje + flag `digested`

### S0-C — Integracion workspace (AC-2)
- [ ] `transcriptor-scan.sh` escanea `conversaciones/` sin digerir
- [ ] Digest end-to-end de una conversacion via `transcriptor-digest`

### S0-D — Verificacion real
- [ ] Round-trip real con Ollama + Kokoro en hardware de la operadora
- [ ] Actualizar README y `savia-transcriptor/CLAUDE.md`
- [ ] CI: pytest suite verde + BATS `test-transcriptor.bats` intacto

---

## 9. Fuera de alcance (S1/S2 — siguiente fase)

- **Wake word** y activacion por voz sin hotkey.
- **Participacion en vivo en reuniones** (S2): STT en streaming de baja latencia,
  politica de intervencion, TTS hacia la reunion con cancelacion de eco / ruteo
  de audio (virtual cable). Es el objetivo "participar conmigo en las reuniones"
  y NO se cubre aqui — requiere spec propia con su arquitectura de audio.
- **Voice cloning** (SE-042, GPU) y multi-voz.
- **Diarizacion** (quien habla en la reunion).

---

## 10. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Skill `transcriptor-digest` (consumidor) | `.claude/skills/transcriptor-digest/SKILL.md` | Symlink via `.opencode/skills/` |
| Scripts TTS workspace (`savia-kokoro.py`, `savia-voice-speak.sh`) | `scripts/` compartidos | `scripts/` compartidos |
| BATS `tests/test-transcriptor.bats` | Ruta compartida | Selector dinámico `.deps.json` |
| Comando `/transcriptor` | `.claude/commands/transcriptor.md` | `.opencode/commands/` (symlink) |

La app de escritorio (`src-pyloid/`, React) es un binario independiente (SE-308);
no consume bindings de Claude Code/OpenCode. El unico punto de acoplamiento es
el backend TTS subprocess, que invoca un comando externo configurable — si apunta
a `scripts/savia-kokoro.py`, ese script es shared y corre igual en cualquier motor.

### Verification protocol

- [ ] Funciona en runtime OpenCode (no solo Claude Code) — la app es agnostica;
      el TTS subprocess y el digest consumen paths compartidos
- [ ] Tests cubren ambos paths: pytest (app) + BATS (digest) — o SKIP justificado
      para audio real (requiere hardware)
- [ ] Si se anade algo a `.claude/skills/` o `.opencode/hooks/`: registrado en
      plugin `savia-gates`

### Portability classification

- [ ] **PURE_BASH** — logica en bash sin bindings de frontend, runs identico en cualquier motor
- [ ] **DUAL_BINDING** — implementado para Claude Code Y OpenCode desde Slice 1
- [x] **SINGLE_BINDING_DEFERRED** — app de escritorio independiente; el unico
      binding (digest de conversaciones) reutiliza `transcriptor-digest` ya
      cross-frontend via symlink; sin work adicional de port
- [ ] **CLAUDE_CODE_ONLY** — no aplica

---

## 11. Riesgos y mitigaciones

| Riesgo | Prob. | Impacto | Mitigacion |
|---|---|---|---|
| Kokoro no disponible en la maquina de la operadora | Media | Sin voz | Backend subprocess con degradacion a `none`; documentar instalacion SE-075 Slice 3 |
| Latencia LLM local alta (modelo grande en Ollama) | Media | Round-trip > 5s | Config de modelo; streaming visible en UI; TTS por frase enmascara la espera |
| Eco si Savia habla mientras hay reunion grabando | Baja en S0 | Calidad de grabacion | S0 usa altavoz solo en conversacion (no dentro de la reunion); eco es problema de S2 (fuera de alcance) |
| Bucle de audio (mic recoge el altavoz) | Baja en S0 | Respuesta transcrita a si misma | El push-to-talk es explicito y no se autoactiva; sin wake word no hay autoescucha |
| Drift con SE-308 (archivos ya existentes) | Baja | Rompe tests | AC-6 exige tests SE-308 intactos; cambios solo aditivos |
