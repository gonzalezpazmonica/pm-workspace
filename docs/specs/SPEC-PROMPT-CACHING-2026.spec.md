# Spec: Prompt Caching 2026 Refresh — static/dynamic split + 1h TTL + workspace isolation

**Task ID:**        SPEC-PROMPT-CACHING-2026
**PBI padre:**      Cache hit rate optimization
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: platform.claude.com/docs/prompt-caching + aicheckerhub 2026 guide)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

pm-workspace tiene `prompt-caching.md` con un modelo 4-level. Sin embargo,
contiene 3 bugs que erosionan el cache hit rate real:

1. **Fecha dinamica en system prompt** — CLAUDE.md se inyecta con currentDate,
   rompiendo el prefijo cacheable CADA dia.
2. **TTL por defecto 5min** — sesiones SDD con dev-session slices pausan
   frecuentemente mas de 5min, perdiendo el cache.
3. **Cache isolation workspace-level** — Anthropic cambio Feb 2026 a isolation
   por workspace (no organizacion). pm-workspace no documenta ni verifica.

Ademas, el hit rate real NUNCA se ha medido (ver SPEC-CACHE-HIT-TRACKING).

**Objetivo:** refrescar la estrategia de prompt caching con 3 fixes concretos
y actualizar `prompt-caching.md` con las reglas 2026.

**Criterios de Aceptacion:**
- [ ] Fecha dinamica MOVIDA del system prompt al turno humano
- [ ] `cache_ttl: 1h` como opcion en commands largos
- [ ] Workspace isolation documentado + verificacion en session-init
- [ ] Regla "nunca datos dinamicos en system prompt" enforzada
- [ ] Hit rate real medible (integracion con SPEC-CACHE-HIT-TRACKING)
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Separacion static/dynamic

**Actual (roto):**
```
system: CLAUDE.md + currentDate + active-project
```

**Propuesto:**
```
system: CLAUDE.md (100% estatico, hash verificable)
[cache breakpoint]
user_turn_first: currentDate, active-project, any dynamic data
```

Regla: **"Nada dinamico en system prompt. Datos dinamicos van al primer
turno humano DESPUES del breakpoint."**

### 2.2 TTL 1h para sesiones largas

Claude API permite `cache_control: {type: "ephemeral", ttl: "1h"}` desde
Feb 2026. Coste: 2x write, 0.1x read. Util cuando pausas entre turnos
>5min pero revisitas el mismo prefijo.

pm-config anadir:
```
CACHE_TTL_DEFAULT           = "5m"
CACHE_TTL_LONG_SESSION      = "1h"
CACHE_TTL_1H_COMMANDS       = ["dev-session", "overnight-sprint", "project-audit"]
```

Los commands en la lista usan 1h automaticamente. Los demas 5min.

### 2.3 Workspace isolation verificacion

Anthropic Feb 2026: caches aislados por workspace.
session-init.sh debe verificar:

```bash
# Si el workspace cambio desde la ultima sesion, invalidar assumptions
CURRENT_WORKSPACE=$(pwd)
LAST_WORKSPACE=$(cat ~/.savia/cache-workspace 2>/dev/null)
if [[ "$CURRENT_WORKSPACE" != "$LAST_WORKSPACE" ]]; then
  echo "Workspace cambio: cache isolation activo"
  echo "$CURRENT_WORKSPACE" > ~/.savia/cache-workspace
fi
```

### 2.4 Fix de la fecha dinamica

Opciones:

**A. Mover al turno humano (preferida):**
- session-init.sh inyecta `# currentDate: YYYY-MM-DD` como primer turno user
- CLAUDE.md NO referencia fecha
- Cache hit del system prompt invariante dia a dia

**B. Aceptar MISS diario:**
- Fecha queda en system prompt
- Cache se rompe a diario
- Solo util si coste de invalidation es bajo

Eleccion: **A**. Ahorra ~un-reset-diario en cada sesion.

### 2.5 Regla enforced por hook

Crear hook `validate-system-prompt-static.sh`:

```bash
# Verifica que CLAUDE.md no contiene:
# - Fechas (YYYY-MM-DD)
# - Timestamps
# - Paths absolutos con $HOME
# - Conteos dinamicos (output de scripts)
# Si encuentra algo dinamico: WARNING (no blocker)
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| CACHE-01 | System prompt 100% estatico (hash verificable) | Cache miss constante |
| CACHE-02 | Datos dinamicos al primer turno humano | Misma que CACHE-01 |
| CACHE-03 | 1h TTL para commands en CACHE_TTL_1H_COMMANDS | Sin justificar coste |
| CACHE-04 | Workspace change detectado y registrado | Cache confusion |
| CACHE-05 | Zero cambios de system prompt mid-sesion | Invalidation total |
| CACHE-06 | Hit rate medido y publicado (via SPEC-CACHE-HIT-TRACKING) | Sin validacion empirica |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | Zero nuevas |
| Compatibilidad | Backward: commands que no usan 1h siguen en 5min |
| Testing | Hash del system prompt verificable por script |
| Observabilidad | Hit rate reportado en session-end |
| Coste | 1h TTL tiene 2x write — solo en commands que lo justifican |

---

## 5. Test Scenarios

### System prompt estatico

```
GIVEN   CLAUDE.md con fecha dinamica
WHEN    bash scripts/validate-system-prompt-static.sh
THEN    WARNING con linea de la fecha
AND     sugerencia de mover al turno humano
```

### System prompt post-fix

```
GIVEN   CLAUDE.md sin referencias dinamicas
WHEN    validacion corre
THEN    exit 0
AND     hash SHA256 del system prompt reproducible
```

### Cache TTL 1h para dev-session

```
GIVEN   /dev-session start en lista CACHE_TTL_1H_COMMANDS
WHEN    ejecutado
THEN    API call usa cache_control ttl=1h
AND     registrado en agent-trace
```

### Workspace change detection

```
GIVEN   usuario cambia de pm-workspace a otro repo
WHEN    session-init corre
THEN    detecta cambio, log "cache isolation activo"
AND     ~/.savia/cache-workspace actualizado
```

### Regla sin cambios mid-sesion

```
GIVEN   sesion iniciada
WHEN    un hook intenta modificar CLAUDE.md mid-sesion
THEN    cambio bloqueado por hook-config-snapshot (SPEC-HOOK-CONFIG-SNAPSHOT)
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Modificar | .claude/rules/domain/prompt-caching.md | Reglas 2026, static/dynamic |
| Modificar | CLAUDE.md | Quitar cualquier dato dinamico |
| Modificar | .claude/hooks/session-init.sh | Inyectar fecha en turno humano |
| Crear | .claude/hooks/validate-system-prompt-static.sh | Validador |
| Modificar | .claude/rules/domain/pm-config.md | Constantes CACHE_TTL_* |
| Crear | tests/test-prompt-caching-2026.bats | Suite BATS |
| Modificar | .claude/commands/dev-session.md | Marcar como ttl=1h |
| Modificar | .claude/commands/overnight-sprint.md | Marcar como ttl=1h |
| Modificar | .claude/commands/project-audit.md | Marcar como ttl=1h |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Hit rate de system prompt | >=95% | SPEC-CACHE-HIT-TRACKING |
| Reduccion tokens input | >=30% en sesiones largas | Benchmark antes/despues |
| Zero cache invalidation por fecha | 0 | Log del proxy o API |
| Workspace change detectado | 100% | session-init log |

---

## Checklist Pre-Entrega

- [ ] prompt-caching.md actualizado a 2026
- [ ] CLAUDE.md sin datos dinamicos (hash reproducible)
- [ ] session-init inyecta fecha en turno humano
- [ ] validate-system-prompt-static.sh operativo
- [ ] CACHE_TTL_* en pm-config
- [ ] 3 commands marcados como ttl=1h
- [ ] Hit rate medido y publicado
- [ ] Tests BATS >=80 score
