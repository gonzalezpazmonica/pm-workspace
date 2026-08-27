---
id: SE-347
title: "SE-347 — Evaluación controlada de Prime Agent (RLM self-hosted)"
status: PROPOSED
priority: baja
---

# SE-347 — Evaluación controlada de Prime Agent (RLM self-hosted)

**Status:** PROPOSED
**Fecha:** 2026-08-26
**Area:** Providers / Autonomía / Soberanía de modelos
**Branch sugerida:** `agent/se347-prime-agent-evaluacion`
**Estimacion total:** ~16h (3 slices)
**Inspiracion:** PrimeIntellect-ai/prime-agent — https://github.com/PrimeIntellect-ai/prime-agent
**Criterio rector:** CRIT-001 — ante opciones equivalentes, gana la que mantiene los datos en infraestructura propia.

---

## Contexto y evidencia (2026-08-26)

Research completo en `output/research/prime-agent-20260826.md`. Prime Agent (PMA)
es un agente de código e investigación open-source (MIT) de Prime Intellect,
diseñado para trabajo de larga duración. Dos abstracciones:

1. **RLM (Recursive Language Model)** — contexto como variables
   (`prompt-as-a-variable`) y tools/subagentes como llamadas a función dentro de
   un REPL persistente (IPython como única tool modelo built-in).
2. **Continual Harness** — estado durable (memorias, skills, subagent specs) que
   el propio agente refina con `/refine` basado en evidencia, local por defecto.

**Relevancia para pm-workspace**: comparte filosofía con Savia (memoria
persistente, subagentes, autonomía acotada, daemon). El punto crítico es su capa
de providers: `models.json` permite apuntar a modelos **propios** (Ollama, vLLM,
LM Studio, cualquier servidor OpenAI/Anthropic/Google-compatible) con
`compat.thinkingFormat` para `qwen`/`deepseek`/`zai` — cubre los modelos locales
del host (qwen2.5, gemma4).

**Conclusión del research**: PMA es **CRIT-001-compatible** si se configura
(a) provider local vía `models.json`, (b) telemetría OFF (`telemetry.enabled:false`
+ `PRIME_AGENT_TELEMETRY=0` + `--offline`), (c) sessionDir en disco propio.
NO sustituye a OpenCode/Savia como frontend principal; se posiciona como
**alternativa de evaluación** para workloads de larga duración con modelos
propios y como **banco de pruebas** del paradigma RLM.

**Nota de numeración**: el research menciona "spec SE-346" para esta evaluación,
pero SE-346 ya está asignado a `SE-346-surrogate-incertidumbre.spec.md`
(SmartSim). Esta propuesta usa SE-347.

---

## Objetivo

Evaluar Prime Agent en un **período de prueba controlado y acotado** antes de
cualquier adopción, verificando empíricamente las afirmaciones del research bajo
CRIT-001 y sin exponer datos N3+ a ningún proveedor cloud:

1. **Instalar y configurar PMA en modo local**: provider Ollama/vLLM vía
   `models.json`, telemetría OFF, `--offline`, sessionDir en infraestructura
   propia.
2. **Verificar CRIT-001 en runtime**: tráfico de red saliente (audit con tcpdump
   o `strace` de syscalls de red) durante una sesión de prueba; confirmar que con
   telemetría OFF + `--offline` no hay contacto con primeintellect.ai ni ningún
   host externo.
3. **Probar los patrones RLM** relevantes: `rlm(...)` (subagentes), skills
   Python importables, daemon/reattach, compaction.
4. **Benchmark comparativo acotado**: PMA-local vs Savia sobre un task sintético
   de digestión/análisis (mismo modelo local), para cuantificar si el paradigma
   RLM aporta valor real o es solo un cambio de interfaz.
5. **Emitir veredicto de adopción**: ADOPTAR (como runtime complementario) |
   RECHAZAR | RE-EVALUAR en 3 meses, con métricas y evidencia.

---

## Out of scope

- NO sustituir OpenCode/Savia como frontend principal del workspace.
- NO portar el daemon/supervisor de PMA a Savia.
- NO integrar el modelo de programación RLM/IPython como capa de control de Savia
  (eso sería un spec posterior si el veredicto es ADOPTAR).
- NO ejecutar código no confiable con PMA (no es sandbox; mismo principio que
  Savia).
- NO evaluar agent-to-agent messaging ni goals como parte del primer slice.
- NO almacenar ningún dato del workspace en `~/.prime/agent/` por defecto del
  sistema — todo en disco propio bajo `output/` o `~/.savia/prime-agent/`.

---

## Diseno

### S1 — Instalación y configuración CRIT-001-strict

`output/research/prime-agent-eval/` (log de la evaluación, no del workspace
principal):

- **Instalación**: release versionada vía script oficial verificando SHA-256, o
  build desde source en una rama `agent/*`. Preferir binario release (CI-built).
- **Configuración** (`~/.prime/agent/settings.json` + `models.json`):
  - `defaultProvider`/`defaultModel` → provider local (`ollama` o `vllm`).
  - `telemetry.enabled: false` (+ `PRIME_AGENT_TELEMETRY=0`, `DO_NOT_TRACK=1`).
  - `sessionDir` → `~/.savia/prime-agent/sessions` (disco propio, fuera del
    path default cloud-oriented).
  - `bundledSkills.websearch: false` (skill de red built-in; se desactiva para
    el benchmark offline).
  - `PI_SKIP_VERSION_CHECK=1`, `PI_OFFLINE=1`, invocación `--offline`.
- **models.json**: provider Ollama (`baseUrl: http://localhost:11434/v1`, api
  `openai-completions`, compat `supportsDeveloperRole:false`,
  `thinkingFormat: qwen`) apuntando al modelo local `qwen2.5-coder` o `gemma4`
  del host. El ejemplo del research sirve de base.
- **Gate de arranque**: la evaluación NO arranca si no hay provider local
  alcanzable (`curl localhost:11434/v1/models`) o si la telemetría no está
  desactivada (chequeo del fichero de settings + env).

### S2 — Auditoría de red en runtime (CRIT-001 empírico)

Durante UNA sesión de prueba de S1 (misma máquina, sesión interactiva corta):

- Captura con `tcpdump`/`ngrep` en la interfaz por defecto (o `strace -f -e
  trace=network`) limitada a los PID del daemon/kernel de PMA.
- **Criterio de paso**: cero conexiones salientes a hosts externos
  (primeintellect.ai, updates, CDNs, telemetry endpoints). Solo se admite
  localhost (`127.0.0.1:11434` provider + loopback del daemon).
- Resultado en `output/research/prime-agent-eval/red-audit-{fecha}.md` con la
  lista de hosts contactados (vacía = PASS).
- Si falla (hay tráfico externo no justificado): veredicto RECHAZAR para el
  modo sin `--offline`, y documentar la configuración exacta que lo evita.

### S3 — Pruebas de patrón y benchmark acotado

- **S3.1 Patrones RLM**: tarea sintética que use `rlm(...)` (un subagente de
  análisis), una skill Python importable (`release_audit`-like) y una sesión
  con detach/reattach del daemon.
- **S3.2 Benchmark vs Savia**: mismo task sintético (p.ej. digerir un fichero
  markdown estructurado y emitir un resumen tabular) ejecutado con PMA-local y
  con Savia sobre el **mismo modelo local** (`qwen2.5-coder`). Métricas:
  tokens consumidos, tiempo, calidad del output (revisión humana de ambos), y
  esfuerzo de configuración.
- **S3.3 Compaction**: verificar auto-compaction (reserva 16k, mantiene 20k) en
  una sesión que exceda el límite, y que el estado de los subagentes registrados
  sobrevive.
- Output de métricas en `output/research/prime-agent-eval/benchmark-{fecha}.md`.

---

## Criterios de aceptacion

### AC-S1: Instalación y configuración

- [x] AC-S1.1: binario PMA instalado y `prime-agent --version` responde desde una rama `agent/*`.
- [x] AC-S1.2: `settings.json` tiene `telemetry.enabled:false` y `sessionDir` en `~/.savia/prime-agent/sessions`.
- [x] AC-S1.3: `models.json` define provider local `ollama` (o `vllm`) y el modelo local del host; arranca sin provider cloud.
- [x] AC-S1.4: invocación con `--offline` y env `PRIME_AGENT_TELEMETRY=0` documentada en el log.
- [x] AC-S1.5: gate de arranque comprueba provider local y telemetría OFF; si falla, la evaluación no arranca.
- [x] AC-S1.6: `bundledSkills.websearch:false` activo.

### AC-S2: Auditoría de red

- [x] AC-S2.1: captura de red limitada a los PID de PMA durante ≥1 sesión de prueba.
- [x] AC-S2.2: informe `red-audit-{fecha}.md` con lista de hosts contactados.
- [x] AC-S2.3: cero conexiones salientes externas con la configuración del research (PASS).
- [x] AC-S2.4: si hay tráfico externo, veredicto RECHAZAR documentado con la configuración que lo provoca.

### AC-S3: Patrones y benchmark

- [x] AC-S3.1: `rlm("tarea")` devuelve handle inmediato y el hijo responde vía `agent_message.send`. *(Handle ✅; respuesta del hijo no capturada headless — ver benchmark-20260827.md)*
- [x] AC-S3.2: skill Python importable ejecutada desde el kernel (export por nombre import).
- [ ] AC-S3.3: sesión con detach/reattach: el worker sobrevive al cierre de la TUI. *(PARCIAL — es TUI-interactivo; no demostrable headless)*
- [ ] AC-S3.4: auto-compaction verificado y estado de subagentes sobrevive. *(No verificado: modelos locales no completan sesiones multi-turno)*
- [ ] AC-S3.5: benchmark PMA-local vs Savia ejecutado sobre el mismo modelo local con métricas comparadas en `benchmark-{fecha}.md`. *(INCONCLUSO — qwen2.5:3b es techo de capacidad, gemma4:26b techo de rendimiento en el host)*
- [x] AC-S3.6: veredicto ADOPTAR | RECHAZAR | RE-EVALUAR emitido con evidencia. *(RE-EVALUAR — ver sección Resultado 2026-08-27)*

### AC-S4: Registro

- [x] AC-S4.1: `docs/propuestas/INDEX.md` regenerado con SE-347.
- [x] AC-S4.2: entrada de resultado en `output/research/prime-agent-eval/veredicto-{fecha}.md`.
- [ ] AC-S4.3: decisión registrada en CRITERIO.md o como decision record si el veredicto es ADOPTAR. *(N/A: veredicto RE-EVALUAR, no ADOPTAR)*

---

## Resultado 2026-08-27

- **S1 ✅** (instalación/config CRIT-001, gate de arranque) — ver `output/research/prime-agent-eval/s1-instalacion-20260826.md`.
- **S2 ✅ PASS** (auditoría de red: 0 conexiones externas, 0 DNS) — ver `s2-red-audit-20260827.md`.
- **S3 ⚠️ parcial** — RLM admission ✅, skill Python ✅, detach/reattach parcial
  (TUI), benchmark INCONCLUSO (qwen2.5:3b techo de capacidad · gemma4:26b techo
  de rendimiento en el host · provider opencode→ollama no cableado headless),
  compaction no verificado — ver `benchmark-20260827.md`.
- **Veredicto: RE-EVALUAR en ~1-3 meses** con un modelo local ≥7-8B usable.
  Hallazgo transversal: la operación local-only con estos tamaños no conduce
  flujos agénticos → refuerza SE-346 (enrutar por incertidumbre).

## Ref

- Research: `output/research/prime-agent-20260826.md` (stack, arquitectura daemon/RLM,
  providers/models.json, settings y telemetría, CLI, long-running, gaps).
- Repo: https://github.com/PrimeIntellect-ai/prime-agent (MIT, 18.5k stars, 4,565 commits).
- Docs PMA: architecture.md, daemon.md, rlm.md, models.md, providers.md, settings.md,
  usage.md, long-running-agents.md (`packages/coding-agent/docs/`).
- Blog RLM: https://www.primeintellect.ai/blog/rlm
- arXiv: 2608.23552 (Prime Agent), 2605.09998 (Continual Harness).
- Savia: `docs/rules/domain/autonomous-safety.md` (gates, ramas agent/*, revisión
  humana), CRIT-001, `docs/rules/domain/savia-ethical-principles.md`.

## Plan de implementación propuesto

| Slice | Prioridad | Depende de | Estimación |
|---|---|---|---|
| S1 instalación + configuración CRIT-001-strict | alta | — | 4h |
| S2 auditoría de red en runtime | alta | S1 | 3h |
| S3 patrones RLM + benchmark acotado | media | S2 | 8h |
| S4 veredicto + registro | media | S3 | 1h |

Orden recomendado: S1 → S2 → S3 → S4. Cada slice con verificación humana
(Savia propone, la operadora dispone). El veredicto final es una decisión de
adopción → requiere aprobación humana explícita, no autonomía.
