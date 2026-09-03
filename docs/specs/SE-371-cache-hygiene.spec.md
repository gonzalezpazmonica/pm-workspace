# SE-371 — Cache Hygiene + Métricas: disciplina de prefijo para prompt caching

**Status:** APPROVED (2026-09-03, orden operadora: implementar mejoras de caché)
**Fecha:** 2026-09-03
**Área:** Contexto / Coste / Rendimiento
**Fuente de inspiración:** análisis de caché 2026-09-03 (artículo Daniel Ávila + aider `--cache-keepalive` + OpenCode rules estáticas) → diagnóstico de Savia (MEMORY.md en prefijo mutable, auto-regenerados AGENTS/SKILLS a mitad de sesión, multi-modelo, cero métricas).
**Criterio humano aplicable:** CRIT-001 (todo local; métricas y snapshots locales; cero egress).

---

## 1. Motivación

El prompt cache del provider es **prefijo-exacto**: un byte distinto en el prefijo invalida el cache desde ese punto. Savia monta un prefijo de instrucciones estable (11 ficheros en `opencode.json` + 6 @imports de CLAUDE.md), pero tres mecánicas lo rompen sin que nadie lo detecte:

1. `MEMORY.md` (estado mutable, se consolida con cada `save`) está en el prefijo de `instructions`.
2. `AGENTS.md`/`SKILLS.md` se auto-regeneran a mitad de sesión por hooks → el prefijo cambia entre turnos.
3. Cero métricas de cache: no se sabe hit rate ni coste de invalidación.

Sin higiene ni métrica no hay gestión. Esta spec entrega la **disciplina medible**: snapshot del prefijo al inicio de sesión, detector de mutación entre turnos, congelación de auto-regenerados durante sesiones activas, y un ledger local de métricas de cache consumible por sesión.

## 2. Alcance

**Dentro:**
- Manifest del orden canónico del prefijo (`config/cache-prefix.txt`) verificable.
- `scripts/cache-hygiene.sh`: `snapshot` (guarda hashes del prefijo), `check` (detecta mutación → avisa qué fichero), `--validate` (manifest coherente con `opencode.json`).
- Guard de congelación en los auto-regeneradores (`SAVIA_SESSION_ACTIVE=1` → abort sin tocar ficheros).
- `scripts/cache-metrics.sh`: `record` (ingiere usage del provider) y `report` (hit rate por modelo/sesión) en ledger local `data/cache-metrics.jsonl`.
- MEMORY.md fuera del prefijo de `opencode.json` (se carga bajo demanda vía auto-prime/recall).
- Principio de estabilidad de modelo por conversación documentado (sección 4).

**Fuera:**
- Keep-alive pings activos estilo aider (evaluar post-métricas; no es premisa de esta spec).
- Cache local de veredictos con grounding (fase 2 de L28, spec aparte).
- Migración de sesiones/frontends (Claude Code vs OpenCode) — el manifest cubre ambos por diseño.

## 3. Principios de diseño

1. **El prefijo es un contrato**: orden canónico versionado y verificable, no tácito.
2. **Mutable fuera, estable dentro**: nada que cambie por turno o por `save` vive en el prefijo.
3. **Congelación durante la sesión**: los auto-regenerados esperan al cierre; la consistencia no se persigue a mitad de una conversación viva.
4. **Medir antes de optimizar**: métricas locales de cache (hit/costes) sin telemetría a proveedor.
5. **CRIT-001**: snapshots, manifest y ledger son locales; cero red.

## 4. Modelo estable por conversación

Cambiar de modelo a mitad de una conversación principal deja el KV cache inalcanzable (los providers no comparten cache entre modelos). Regla de política (sección de diseño, no ejecutable):
- El **modelo del hilo principal** no cambia a mitad de conversación.
- El routing multi-modelo queda para **subagentes** (su cache no se comparte de todos modos y el aislamiento es una virtud) y para decisiones **entre** sesiones.
- `config/model-capabilities.yaml` documenta `recommended_compact_threshold_pct`; la compactación es complementaria al cache (tras compactar el prefijo cambia igualmente) — no un sustituto.

## 5. Diseño técnico

### 5.1 `config/cache-prefix.txt` (manifest)

Orden canónico del prefijo de instrucciones, un path por línea (los dos frontends):
```
AGENTS.md
SKILLS.md
CLAUDE.md
.claude/profiles/savia.md
.claude/profiles/active-user.md
docs/rules/domain/radical-honesty.md
docs/rules/domain/autonomous-safety.md
docs/rules/domain/caveman-default.md
docs/rules/domain/agents-catalog.md
.claude/CONSTITUCION.md
docs/critical-facts.md
```
Nota: `MEMORY.md` ya NO está en el prefijo (AC-4); se carga bajo demanda.

### 5.2 `scripts/cache-hygiene.sh`

- `snapshot [--out data/cache-prefix.snapshot]`: sha256 de cada path del manifest + línea `# manifest <sha>` del propio manifest.
- `check [--out ...]`: compara con el snapshot; por cada fichero mutado imprime `MUTATED <path>`; exit 0 limpio / 1 mutación / 2 sin snapshot.
- `--validate`: cada path del manifest existe; los primeros N del manifest coinciden con `instructions` de `opencode.json` en orden (con tolerancia a ficheros frontend-específicos al final).

### 5.3 Congelación de auto-regenerados

`agents-md-auto-regenerate.sh` y `skills-md-generate.sh`: si `SAVIA_SESSION_ACTIVE=1`, abortan (exit 3) sin regenerar. Justificación: regenerar a mitad de sesión invalida el prefijo en el siguiente turno. El valor lo establece el launcher de sesión interactiva (documentado); los runs autónomos/cron sin sesión viva regeneran con normalidad.

### 5.4 `scripts/cache-metrics.sh`

- `record --model M --input N --cache-read R --cache-creation C [--session S]` → append línea a `data/cache-metrics.jsonl` (local).
- `report [--session S] [--model M]`: agrega por modelo/sesión: total input, cache_read, ratio `R/(N+R)` (hit rate), y coste relativo estimado (reads×0.1 + writes×1.25 vs input full).
- `--validate`: schema de líneas.
- Entrada programática: un hook PostToolUse/Stop puede volcar `usage` de la respuesta del provider (formato Anthropic: `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`) vía `record --usage-json`.

### 5.5 MEMORY.md fuera del prefijo

`opencode.json` `instructions` deja de listar `.claude/external-memory/auto/MEMORY.md`. El acceso a memoria sigue disponible: `scripts/memory-store.sh recall`, auto-prime por turno, y skill `savia-memory`.

### 5.6 Activación en runtime (hooks)

- `.opencode/hooks/cache-hygiene-hook.sh` registrado en `.claude/settings.json`:
  - `SessionStart` → `start`: snapshot del prefijo + marker `data/.cache-session-active`.
  - `UserPromptSubmit` → `preturn`: `check` contra el snapshot; si hay mutación escribe en `output/.cache-hygiene.log` (nunca contamina el prompt, exit 0 siempre).
  - `SessionEnd` → `end`: limpia el marker y regeneración diferida de AGENTS/SKILLS solo si hay drift real (--check → --apply).
- Los generadores congelan si `SAVIA_SESSION_ACTIVE=1` **o** existe el marker (sesión viva) — SE-371 §5.3 extendido.

## 6. Criterios de aceptación

- **AC-0** `cache-hygiene.sh snapshot` genera el fichero de snapshot con hashes (test con manifest temporal).
- **AC-1** `cache-hygiene.sh check` detecta mutación de un fichero del prefijo (exit 1, mensaje `MUTATED`) (test: mutar un fichero temporal del manifest).
- **AC-1b** `check` limpio → exit 0 (test).
- **AC-2** `cache-hygiene.sh --validate` falla si un path del manifest no existe (exit 1) (test).
- **AC-3** Con `SAVIA_SESSION_ACTIVE=1`, los auto-regeneradores abortan (exit 3) sin tocar su fichero de salida (test: ejecutar con variable, comprobar que el fichero no cambia).
- **AC-4** `MEMORY.md` no está en `instructions` de `opencode.json` (test de grep).
- **AC-5** `cache-metrics.sh record` + `report` agregan correctamente (fixture determinista: 3 líneas, hit rate esperado) (test).
- **AC-6** `cache-metrics.sh record --usage-json` traduce el formato Anthropic a la línea del ledger (test con fixture).
- **AC-7** Suites BATS existentes de regresión: `test-se355-audit-receipts`, `test-se364-evidence-loop`, `test-context-*` verdes (test).

## 7. OpenCode Implementation Plan

### Bindings touched
- `config/cache-prefix.txt` (nuevo)
- `scripts/cache-hygiene.sh` (nuevo)
- `scripts/cache-metrics.sh` (nuevo)
- `data/cache-metrics.jsonl` (runtime, gitignored si procede)
- `.opencode/hooks/agents-md-auto-regenerate.sh` (guard SAVIA_SESSION_ACTIVE)
- `.opencode/hooks/skills-md-generate.sh` (guard SAVIA_SESSION_ACTIVE)
- `opencode.json` (quitar MEMORY.md de instructions)
- `docs/propuestas/ROADMAP-UNIFIED-20260827.md` (Batch 10)

### Verification protocol
```bash
bats tests/bats/test-cache-hygiene.bats
bash scripts/cache-hygiene.sh --validate
bash scripts/cache-hygiene.sh snapshot --out /tmp/snap && bash scripts/cache-hygiene.sh check --out /tmp/snap
SAVIA_SESSION_ACTIVE=1 bash scripts/savia-hooks-agent-regen.sh   # si existe; si no, directo en el hook
bash scripts/cache-metrics.sh record --model glm --input 100 --cache-read 900 --cache-creation 100
bash scripts/cache-metrics.sh report
```

### Portability classification
- Bash + sha256 + Python3 (report/parse opcional); local; portable; CRIT-001.

## 8. Preguntas abiertas
- ¿Hook de captura de usage por defecto o solo bajo `SAVIA_CACHE_METRICS=1`? Decidido: solo bajo env (evitar overhead por turno); documentar.
- ¿Congelación también para regeneración de `.scm`? No: `.scm` no está en el prefijo (se regenera sin restricción).

## Referencias
- Análisis caché 2026-09-03 (artículo prompt caching + aider caching + OpenCode rules)
- Savia: `docs/harness-map.md` (L28, rol cache), `.claude/skills/context-caching/SKILL.md`, `config/model-capabilities.yaml`, CRIT-001
