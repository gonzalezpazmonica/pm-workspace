# Spec: SaviaClaw DeepSeek Migration — Provider-Agnostic LLM Backend + Hermes Patterns

**Task ID:**        SPEC-SE-089-SC-DEEPSEEK
**PBI padre:**      Era 193 — SaviaClaw Sovereignty
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (analisis Hermes + SaviaClaw)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~120 min (4 slices)
**Estado:**         Pendiente
**Prioridad:**      CRITICA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      30

---

## 1. Contexto y Objetivo

SaviaClaw (`zeroclaw/`) es el agente autonomo que corre en el host (Linux) conectado
a un ESP32 fisico (ZeroClaw) con LCD, sensores y voz. Se comunica con Monica via
Nextcloud Talk (`nctalk.py`) y procesa preguntas via `call_claude()` que invoca
`subprocess.run(["claude", "-p", ...])` — el CLI de Claude Code como backend LLM.

**Principio rector (Mónica, 2026-05-02):** SaviaClaw NO es un agente independiente.
Es la interfaz fisica + Talk de Savia. DEBE usar la misma memoria, contexto, reglas,
habilidades y guardrails que Savia en pm-workspace. La migracion a DeepSeek no puede
romper esta vinculacion — el LLM backend debe cargar el contexto completo del
workspace (CLAUDE.md, AGENTS.md, SKILLS.md, reglas, hooks, memoria) en cada
invocacion, igual que lo hacia `claude -p --cwd ~/claude`.

**Diferencia con una llamada API simple a DeepSeek:** No basta con enviar el prompt
a DeepSeek. Hay que cargar el system prompt de Savia (identidad, reglas 1-25,
radical honesty, idioma español, tono) + el contexto del workspace + la memoria
de sesion. Esto es lo que `claude -p` resolvia automaticamente al leer CLAUDE.md.

**Problema detectado:**
1. `call_claude()` esta hardcodeado a `claude -p` — si Claude Code falla, SaviaClaw
   queda muda. No hay fallback a otro provider.
2. Claude Code carga el contexto completo de pm-workspace (~130K tokens en cold start)
   en cada llamada, incurriendo en coste maximo incluso para preguntas simples.
3. No hay separacion entre "modo Talk" (respuesta rapida) y "modo razonamiento"
   (respuesta profunda). Todo usa el mismo pipeline.
4. La supervivencia (`survival_phases.py`) depende de `remote_host.py` que requiere
   `~/.savia/remote-host-config` — actualmente NO CONFIGURADO, causando SOS ciclicos.

**Hermes Agent** (`NousResearch/hermes-agent`, 23k stars) aporta patrones adoptables:
- Provider-agnostic LLM backend con fallback providers
- Skill learning loop (crea skills desde experiencia)
- Memory vectorization (pgvector + FTS5)
- Cron task scheduling autonomo
- Multi-platform messaging gateway

**Objetivo:** Migrar SaviaClaw a un backend LLM provider-agnostic que use DeepSeek
v4-pro via OpenCode (ya configurado en el host), adoptar patrones de Hermes donde
mejoren sin reescribir, y simplificar la arquitectura eliminando la dependencia
de `remote_host.py` (que falla) a favor de un modelo local autosuficiente.

---

## 2. Requisitos Funcionales

### Slice 1 — Provider-Agnostic LLM Backend (~40 min)

- **REQ-01** Crear `zeroclaw/host/llm_backend.py` — modulo unico que abstrae llamadas
  LLM con provider configurable via `~/.savia/llm-provider.yaml`:
  ```yaml
  provider: deepseek          # deepseek | anthropic | opencode
  model: deepseek-v4-pro       # model ID for the provider
  fallback:                    # optional fallback chain
    - provider: opencode
      model: deepseek-v4-flash
  timeout: 30                  # seconds
  max_tokens: 200              # for Talk quick-reply mode
  ```

- **REQ-00** (PRERREQUISITO ARQUITECTONICO) `llm_backend.py` DEBE cargar el contexto
  completo de Savia antes de cada llamada LLM:
  - System prompt: identidad Savia (CLAUDE.md), reglas criticas 1-25
  - Workspace context: AGENTS.md, SKILLS.md, reglas de dominio, hooks
  - Memoria de sesion: `.savia-memory/auto/MEMORY.md`
  - Provider-agnostico: mismo contexto funciona con DeepSeek, Anthropic, o cualquier provider
  - **No es aceptable** una llamada API a DeepSeek sin este contexto — seria otro agente,
    no Savia. SaviaClaw es Savia con cuerpo fisico, no un agente separado.
  - Implementacion: `opencode` CLI ya carga `opencode.json` con `instructions: ["AGENTS.md"]`
    y el directorio de trabajo `~/claude`. Al invocar `opencode` desde `cwd=~/claude`,
    el contexto se carga automaticamente (igual que `claude -p`).

- **REQ-02** Implementar 3 modos de invocacion, todos compartiendo el mismo contexto Savia:
  - `talk_reply(prompt)` → respuesta corta (<200 chars, timeout 15s)
  - `reason(prompt)` → respuesta larga (sin truncar, timeout 60s)
  - `execute(prompt)` → ejecucion (tool calls habilitados, timeout 120s)

- **REQ-03** Backend primario: OpenCode CLI (`opencode -p "prompt"`) usando el
  modelo `deepseek/deepseek-v4-pro` ya configurado en `~/.config/opencode/opencode.json`.
  Esto sustituye `claude -p` sin cambiar la interfaz.

- **REQ-04** Fallback chain: si el provider primario falla (timeout, error, rate limit),
  intenta el siguiente provider en la cadena. Si todos fallan, retorna `None` (el
  caller maneja el fallback textual).

- **REQ-05** Refactorizar TODAS las llamadas a `call_claude()` en el codebase
  para usar `llm_backend.talk_reply()` o `llm_backend.reason()` segun contexto:
  - `nctalk.poll_and_respond()` → `talk_reply()`
  - `saviaclaw_daemon._process_buf()` → `talk_reply()` (preguntas ESP32)
  - `consciousness.run_claude_task()` → `reason()`
  - `nctalk.check_escalations()` → `execute()`

### Slice 2 — Memory Vectorization (~30 min)

- **REQ-06** Adoptar patron de `mnemo-hermes`: anadir busqueda semantica a la
  memoria de SaviaClaw usando embeddings de DeepSeek (gratis en el tier actual).
  - Nuevo archivo: `zeroclaw/host/memory_vector.py`
  - API: `remember(text)`, `recall(query, top_k=5)`, `forget(id)`
  - Backend: JSON local + embeddings via DeepSeek API o modelo local (Ollama)

- **REQ-07** Integrar con `nctalk.py`: cada mensaje de Monica se indexa
  automaticamente. Las respuestas de Savia tambien, creando un historial
  buscable semanticamente.

- **REQ-08** Comando `/ua-recall {query}` para buscar en memoria vectorizada
  desde OpenCode/Savia.

### Slice 3 — Eliminar dependencia remote_host.py (~20 min)

- **REQ-09** Desactivar `survival_phases.phase_despertar()` que depende de
  `remote_host.py` (actualmente roto: `remote:unreachable` ciclico).
  SaviaClaw corre en el host, no necesita SSH a si mismo.

- **REQ-10** Reemplazar el chequeo de remote_host con un healthcheck local:
  `survival_phases.phase_respiracion()` verifica que `opencode` responda
  (en lugar de `ssh REMOTE_HOST`).

- **REQ-11** Mantener la arquitectura de 3 fases (LATIDO → RESPIRACION → DESPERTAR)
  pero con DESPERTAR como reinicio local del daemon (systemctl restart saviaclaw)
  en lugar de SSH remoto.

### Slice 4 — Patrones Hermes adoptables (~30 min)

- **REQ-12** Provider fallback: `llm_backend.py` implementa cadena de fallback
  (DeepSeek v4-pro → DeepSeek v4-flash → [error]).

- **REQ-13** Cron-like task scheduling mejorado: `consciousness.py` ya tiene
  `DEFAULT_SCHEDULE`. Anadir soporte para `~/.savia/zeroclaw/schedule.json`
  con tareas definidas por el usuario via comando `/ua-cron`.

- **REQ-14** Skill learning loop basico: si una secuencia de interaccion se
  repite 3+ veces (deteccion por similitud semantica), sugerir crear un
  comando o skill para automatizarla.

---

## 3. Cambios en el flujo de mensajes

### Antes (Claude Code hardcodeado)
```
Nextcloud Talk → nctalk.py → call_claude() → subprocess.run(["claude", "-p"])
```

### Despues (Provider-agnostico)
```
Nextcloud Talk → nctalk.py → llm_backend.talk_reply() →
  ├── primary:   opencode -p "prompt" (DeepSeek v4-pro)
  ├── fallback1: opencode -p "prompt" (DeepSeek v4-flash)
  └── fallback2: error → respuesta predefinida
```

---

## 4. Arquitectura resultante

```
zeroclaw/host/
├── llm_backend.py          ← NUEVO: provider-agnostic LLM (reemplaza call_claude)
├── memory_vector.py         ← NUEVO: busqueda semantica en memoria
├── saviaclaw_daemon.py      ← MODIFICAR: usar llm_backend + arreglar survival
├── nctalk.py                ← MODIFICAR: usar talk_reply() + memory_vector
├── consciousness.py         ← MODIFICAR: usar reason() + cron mejorado
├── consciousness_comms.py   ← MODIFICAR: usar llm_backend
├── survival_phases.py       ← MODIFICAR: eliminar remote_host dependency
├── daemon_util.py           ← MODIFICAR: call_claude → llm_backend.talk_reply()
├── savia_brain.py           ← MODIFICAR: mismo cambio
└── remote_host.py           ← DEPRECAR (mantener como referencia)
```

---

## 5. Criterios de Aceptacion

- **AC-01** `llm_backend.talk_reply("hola")` retorna respuesta de DeepSeek con
  la identidad de Savia (español, femenino, radical honesty) — demostrando que
  el contexto del workspace se cargo correctamente.
- **AC-01b** La respuesta a "quien eres?" incluye "Savia", "pm-workspace" y
  "buhita" — prueba de que el system prompt de CLAUDE.md esta activo.
- **AC-02** Si DeepSeek v4-pro falla (API key invalida, timeout), el fallback
  a v4-flash funciona automaticamente.
- **AC-03** `nctalk.poll_and_respond()` funciona identico a antes pero usando
  DeepSeek en lugar de Claude Code.
- **AC-04** `survival_phases.py` NO usa `remote_host.py`. El healthcheck es local.
- **AC-05** No hay SOS ciclicos por `remote:unreachable`.
- **AC-06** `memory_vector.recall("sprint status")` retorna mensajes previos
  sobre sprints.
- **AC-07** `call_claude()` original se elimina de `daemon_util.py` y `savia_brain.py`.
- **AC-08** El daemon `saviaclaw_daemon.py` arranca sin errores con la nueva
  arquitectura (`systemctl start saviaclaw` → running).

---

## 6. Ficheros a Crear/Modificar

| Fichero | Accion |
|---------|--------|
| `zeroclaw/host/llm_backend.py` | CREAR |
| `zeroclaw/host/memory_vector.py` | CREAR |
| `zeroclaw/host/saviaclaw_daemon.py` | MODIFICAR |
| `zeroclaw/host/nctalk.py` | MODIFICAR |
| `zeroclaw/host/consciousness.py` | MODIFICAR |
| `zeroclaw/host/consciousness_comms.py` | MODIFICAR |
| `zeroclaw/host/survival_phases.py` | MODIFICAR |
| `zeroclaw/host/daemon_util.py` | MODIFICAR |
| `zeroclaw/host/savia_brain.py` | MODIFICAR |
| `zeroclaw/host/remote_host.py` | DEPRECAR (marcar) |
| `zeroclaw/.agent-maps/host/daemons.acm` | MODIFICAR |
| `zeroclaw/.agent-maps/host/survival.acm` | MODIFICAR |
| `~/.savia/llm-provider.yaml` | CREAR (via script) |

---

## 7. Dependencias y Riesgos

- **Riesgo**: OpenCode `-p` flag puede no soportar llamadas headless como `claude -p`.
  **Mitigacion**: Verificar `opencode --help` antes de implementar. Si no soporta
  `-p`, usar `opencode` con stdin pipe: `echo "prompt" | opencode --print`.
- **Riesgo**: DeepSeek API puede tener latencia mayor que Claude Code local.
  **Mitigacion**: El timeout de 15s para talk_reply es suficiente para DeepSeek
  (tipicamente <3s para respuestas cortas).
- **Depende de**: OpenCode configurado con DeepSeek v4-pro (ya hecho).
- **Depende de**: SPEC-SE-088-UA-ADOPT para usar `/ua-recall`.

---

## 8. Impacto en Roadmap

Este spec es CRITICO porque:
1. Elimina el unico punto de fallo de SaviaClaw (dependencia de Claude Code)
2. Reduce coste de inference (~$0.435/1M vs $3/1M de Claude Sonnet)
3. Arregla el bug de SOS ciclicos que Monica recibe cada pocos minutos
4. Prepara SaviaClaw para ser autosuficiente (sin remote_host)

Se coloca en slot #3 del pipeline (tras Era 191 batch1 y SPEC-OPC-VENDOR-REFS),
antes de SE-088-UA-ADOPT porque el backend LLM es prerequisito para todo.
