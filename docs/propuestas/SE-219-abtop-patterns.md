---
spec_id: SE-219
title: "abtop patterns: session-status JSON, context% hook, orphan cleanup, multi-profile, tick separation"
status: PROPOSED
priority: P2
effort: M
era: 206
origin: https://github.com/graykode/abtop (2.7k stars, MIT)
resource: "https://github.com/graykode/abtop"
inspiration: graykode/abtop v0.4.8 — htop for AI coding agents
deps:
  - scripts/session-action-log.sh (implemented)
  - docs/rules/domain/autonomous-safety.md (implemented)
  - .claude/hooks/ (implemented)
  - savia-env.sh (implemented)
created: 2026-06-10
---

# SE-219 — abtop patterns: 5 patrones de observabilidad de sesiones de agente

## Contexto

[graykode/abtop](https://github.com/graykode/abtop) (MIT, 2.7k stars) es una TUI en Rust
que monitoriza sesiones de Claude Code, Codex CLI y OpenCode en tiempo real: tokens,
context window %, rate limits, procesos hijo, puertos huérfanos. Lee solo ficheros locales
y estado de procesos — sin API keys, sin auth. Ofrece `--json` para scripting y `--once`
para snapshots.

pm-workspace **no adopta el binario** — Rust + TUI son incompatibles con la arquitectura
bash/python. Lo que sí extrae son **5 patrones de diseño de observabilidad**:

1. JSON snapshot como contrato de scripting (`--json`)
2. Context window % como métrica de primer nivel con umbral de acción
3. Limpieza de procesos huérfanos al cerrar sesión
4. Multi-profile discovery automático por convención de nombres
5. Separación tick barato / operación costosa en loops autónomos

---

## Slice 1 — `scripts/session-status.sh --json` (~1h)

### Problema

No existe una forma de consultar el estado actual de la sesión de forma programática.
`session-action-log.sh` registra historia, pero no expone un snapshot del estado actual
(qué agente está activo, cuántas acciones se han ejecutado, últimos resultados, si hay
fallos consecutivos).

abtop resuelve esto con `abtop --json` — un snapshot estructurado que cualquier script
puede consumir sin parsear logs.

### Solución

`scripts/session-status.sh` con modo `--json`:

```bash
bash scripts/session-status.sh --json
# Output:
# {
#   "session_id": "...",
#   "started_at": "2026-06-10T...",
#   "actions_total": 42,
#   "actions_pass": 38,
#   "actions_fail": 4,
#   "consecutive_failures": 0,
#   "last_action": {"action": "pr-plan", "result": "pass", "ts": "..."},
#   "log_file": "output/session-action-log.jsonl",
#   "log_size_bytes": 12345
# }

bash scripts/session-status.sh          # resumen tabular para humanos
bash scripts/session-status.sh --once   # snapshot tabular y sale
```

Lee `$SESSION_ACTION_LOG` (default `output/session-action-log.jsonl`) y agrega
estadísticas en tiempo real.

### Contrato

```bash
# Exit: 0 siempre
# --json: JSON a stdout, silencio en stderr
# Sin log: JSON con campos vacíos/cero, exit 0
```

### Tests `tests/test-se-219-s1-session-status.bats`

8 tests mínimos:
1. script existe y es ejecutable
2. `set -uo pipefail` en línea 2
3. `--json` con log existente → JSON válido con campos requeridos
4. `--json` con log vacío → JSON válido con zeros
5. `--json` sin log → JSON válido (no crash)
6. JSON contiene `session_id`, `actions_total`, `last_action`
7. `--once` sale con exit 0
8. edge: log con entradas malformadas → JSON válido (no crash)

### Criterios de aceptación

- [ ] `session-status.sh --json` produce JSON válido en todos los paths
- [ ] Campos mínimos: `session_id`, `actions_total`, `actions_pass`, `actions_fail`, `consecutive_failures`, `last_action`
- [ ] Exit 0 siempre
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Slice 2 — Context window % como métrica de primer nivel (~2h)

### Problema

`spec156-token-budget-projection.sh` es un PostToolUse hook pasivo que emite warnings.
No hay un script consultable que devuelva el % de contexto actual para que otros hooks
tomen decisiones basadas en él. abtop muestra el context window % como la métrica más
visible, con barra de progreso y detección automática de compactación.

### Solución

`scripts/context-meter.sh` — consulta el estado del contexto de la sesión actual:

```bash
bash scripts/context-meter.sh
# OUTPUT (stdout):
# CONTEXT_PCT=67
# CONTEXT_TOKENS_USED=130000
# CONTEXT_TOKENS_MAX=200000
# CONTEXT_STATUS=ok          # ok | warn (>70%) | critical (>85%)

bash scripts/context-meter.sh --json
# {"pct": 67, "used": 130000, "max": 200000, "status": "ok"}

bash scripts/context-meter.sh --threshold-warn 70 --threshold-critical 85
# Configurable thresholds
```

Fuente de datos: el log de tokens de la sesión actual, o `$CONTEXT_WINDOW_USED` /
`$CONTEXT_WINDOW_MAX` si están en entorno (inyectados por OpenCode via hook).

**Hook de acción**: añadir al Stop hook existente una llamada a `context-meter.sh` que
registre en `session-action-log.sh` el % de contexto al cierre. Si es > 85%, emite
un warning en el log para que el siguiente arranque sepa que la sesión se cerró con
contexto alto.

### Contrato

```bash
# CONTEXT_PCT: entero 0-100
# CONTEXT_STATUS: ok | warn | critical
# Exit: 0 siempre (métricas no bloquean)
# Sin datos: CONTEXT_PCT=0, CONTEXT_STATUS=unknown, exit 0
```

### Tests `tests/test-se-219-s2-context-meter.bats`

8 tests:
1. script existe y es ejecutable
2. `set -uo pipefail` en línea 2
3. output contiene `CONTEXT_PCT=`
4. output contiene `CONTEXT_STATUS=`
5. `--json` produce JSON válido
6. JSON contiene `pct`, `status`
7. sin datos de contexto → exit 0, CONTEXT_PCT=0
8. edge: `--threshold-warn 0` → todos los estados son warn o critical (boundary)

### Criterios de aceptación

- [ ] `context-meter.sh` produce output con `CONTEXT_PCT` y `CONTEXT_STATUS`
- [ ] Exit 0 en todos los paths
- [ ] Umbrales configurables vía flags
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Slice 3 — Limpieza de procesos huérfanos al cerrar sesión (~1h)

### Problema

Cuando un agente lanza un proceso hijo (servidor de desarrollo, watcher, compilador) y
la sesión termina sin matarlo, el proceso queda huérfano ocupando recursos. abtop lo
detecta y permite matarlos con `X`. En sesiones overnight esto es frecuente.

Nuestra `autonomous-safety.md` tiene reglas de fail-safe pero no tiene un mecanismo de
limpieza de procesos hijo al cerrar sesión.

### Solución

`scripts/session-cleanup.sh` — limpieza de procesos hijo al cerrar sesión:

```bash
# Registrar un PID como proceso hijo de la sesión actual
bash scripts/session-cleanup.sh register --pid 12345 --label "dev-server"

# Listar procesos hijo registrados
bash scripts/session-cleanup.sh list

# Limpiar procesos hijo al cerrar (invocado desde Stop hook)
bash scripts/session-cleanup.sh cleanup

# Verificar si hay procesos huérfanos de sesiones anteriores
bash scripts/session-cleanup.sh orphans
```

El registro se guarda en `output/.session-pids-${SESSION_ID}.json`. El Stop hook
existente llama a `cleanup` — mata procesos SIGTERM, espera 3s, SIGKILL si persisten.
`orphans` detecta ficheros `.session-pids-*.json` de sesiones que ya no existen.

### Contrato

```bash
# register: añade PID al fichero de la sesión
# cleanup: mata PIDs registrados de la sesión actual, borra el fichero
# orphans: lista PIDs de sesiones antiguas sin proceso activo
# list: muestra PIDs registrados con estado (running/dead)
# Exit: 0 siempre (cleanup nunca bloquea cierre)
```

### Tests `tests/test-se-219-s3-session-cleanup.bats`

8 tests:
1. script existe y es ejecutable
2. `set -uo pipefail` en línea 2
3. `register --pid` crea fichero de registro
4. `list` muestra el PID registrado
5. `cleanup` mata proceso vivo y borra el fichero
6. `cleanup` con PID ya muerto → exit 0 (no crash)
7. `orphans` sin sesiones antiguas → output vacío, exit 0
8. edge: `register` con PID inválido → exit 2

### Criterios de aceptación

- [ ] Stop hook actualizado para llamar `session-cleanup.sh cleanup`
- [ ] `register` y `cleanup` funcionan sin race conditions simples
- [ ] Exit 0 en todos los paths de `cleanup` (nunca bloquea)
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Slice 4 — Multi-profile discovery automático (~1h)

### Problema

`savia-env.sh` tiene una cadena de resolución para encontrar el perfil activo, pero
es explícita y requiere configuración. abtop descubre automáticamente múltiples raíces
de Claude Code (`~/.claude`, `~/.claude-*`) por convención de nombres — cualquier
directorio que contenga `sessions/` y `projects/` es un perfil válido.

Nuestra resolución actual no soporta múltiples perfiles simultáneos ni descubrimiento
automático por convención.

### Solución

`scripts/profile-discover.sh` — descubre perfiles disponibles:

```bash
# Listar todos los perfiles Claude Code disponibles en el sistema
bash scripts/profile-discover.sh list
# OUTPUT:
# /home/monica/.claude          (active)
# /home/monica/.claude-work     (inactive)
# /home/monica/.claude-personal (inactive)

# Devuelve la ruta del perfil activo
bash scripts/profile-discover.sh active

# JSON para scripting
bash scripts/profile-discover.sh --json
```

Criterio de detección: directorio con nombre `~/.claude` o `~/.claude-*` que contenga
tanto `sessions/` como `projects/`. Lee también `claude_config_dirs` adicionales si existe
`~/.config/abtop/config.toml` (compatibilidad con abtop instalado).

### Contrato

```bash
# list: una línea por perfil con ruta y estado (active/inactive)
# active: ruta del perfil activo o vacío si no hay
# --json: array JSON de perfiles
# Exit: 0 siempre
```

### Tests `tests/test-se-219-s4-profile-discover.bats`

8 tests:
1. script existe y es ejecutable
2. `set -uo pipefail` en línea 2
3. `list` incluye el perfil `~/.claude` si existe
4. `active` devuelve una ruta o vacío (no crash)
5. `--json` produce JSON válido
6. JSON contiene array con campo `path`
7. directorio sin `sessions/` o `projects/` no es detectado como perfil
8. edge: sin ningún directorio `.claude*` → `list` vacío, exit 0

### Criterios de aceptación

- [ ] `profile-discover.sh list` detecta `~/.claude` y `~/.claude-*`
- [ ] Criterio de validación: `sessions/` + `projects/` presentes
- [ ] Exit 0 siempre
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Slice 5 — Separación tick barato / operación costosa en loops autónomos (~2h)

### Problema

`overnight-sprint` y `code-improvement-loop` no distinguen entre operaciones baratas
(leer ficheros, verificar estado de procesos) y operaciones costosas (llamadas LLM,
compilaciones). Cualquier tick puede disparar una llamada. abtop resuelve esto con
`tick_no_summaries()` — refresca todo el estado local sin tocar la quota del modelo.

### Solución

Añadir a `scripts/session-action-log.sh` y a los scripts de loops autónomos una
distinción explícita entre ticks ligeros y pesados:

```bash
# Tick ligero: lee estado, actualiza métricas, no llama a LLM
bash scripts/agent-tick.sh --mode light

# Tick pesado: puede llamar a LLM, compila, ejecuta tests
bash scripts/agent-tick.sh --mode heavy

# Estado del tick actual (para que el orquestador decida)
bash scripts/agent-tick.sh --status
# OUTPUT:
# TICK_MODE=light
# TICK_COST=low
# LAST_HEAVY_TICK=2026-06-10T21:00:00Z
# HEAVY_TICK_INTERVAL=300   # segundos entre ticks pesados
```

`code-improvement-loop.sh` y `overnight-sprint.sh` usan `agent-tick.sh --mode light`
para cada iteración de polling y `--mode heavy` solo cuando hay trabajo real que hacer.
El intervalo entre ticks pesados es configurable (`AGENT_HEAVY_TICK_INTERVAL`, default
300s = 5 min).

### Contrato

```bash
# light: solo lectura de estado local, nunca llama a LLM o ejecuta builds
# heavy: puede hacer cualquier operación
# --status: devuelve estado del último tick
# Exit: 0 siempre
```

### Tests `tests/test-se-219-s5-agent-tick.bats`

8 tests:
1. script existe y es ejecutable
2. `set -uo pipefail` en línea 2
3. `--mode light` completa sin llamadas a LLM (verificado por mock)
4. `--mode heavy` permite llamadas (no bloquea)
5. `--status` produce output con `TICK_MODE=` y `TICK_COST=`
6. `--mode invalid` → exit 2
7. `AGENT_HEAVY_TICK_INTERVAL` es respetado (no heavy tick < intervalo)
8. edge: sin estado previo → `--status` devuelve defaults, exit 0

### Criterios de aceptación

- [ ] `agent-tick.sh --mode light` nunca ejecuta builds ni llamadas LLM
- [ ] `AGENT_HEAVY_TICK_INTERVAL` configurable
- [ ] `overnight-sprint` y `code-improvement-loop` actualizados para usar el patrón
- [ ] Tests: 8/8, score SPEC-055 ≥ 80

---

## Orden de implementación recomendado

| Slice | Esfuerzo | Prioridad | Dep |
|---|---|---|---|
| S1 session-status --json | ~1h | P2 | session-action-log ✓ |
| S3 session-cleanup | ~1h | P2 | autonomous-safety ✓ |
| S4 profile-discover | ~1h | P2 | savia-env ✓ |
| S2 context-meter | ~2h | P2 | — |
| S5 agent-tick | ~2h | P2 | overnight-sprint ✓ |

**Total estimado**: ~7h. Todos independientes entre sí.

## Developer type

`agent-single` para S1, S3, S4 (contratos claros, sin ambigüedad).
`agent-single` para S2 (transformación de datos, thresholds configurables).
`human` para S5 (modifica loops autónomos existentes — riesgo de regresión).
