---
globs: [".claude/commands/**", "output/**"]
---

# Regla: Context Health — Gestión proactiva del contexto
# ── Prevenir saturación que inutiliza los comandos ───────────────────────────

## Principio

> El contexto es un recurso finito. Si se agota, pm-workspace deja de funcionar.
> Cada decisión de diseño debe optimizar el uso de contexto.
> CLAUDE.md is NOT cached — re-sent at full price every turn. 150-line rule saves per-turn.

## 1. Patrón output-first (OBLIGATORIO en todos los comandos)

Los comandos NUNCA deben volcar información extensa en la conversación.

**Regla:** Si un resultado supera 30 líneas → guardar en fichero, mostrar resumen.

```
❌ MAL: Volcar 200 líneas de audit en la conversación
✅ BIEN: Guardar en output/audits/..., mostrar 10 líneas de resumen + ruta
```

Formato obligatorio para resultados extensos:
```
📊 Resumen (5-10 líneas máximo en conversación)
   Score global: 6.2/10 | 🔴 3 críticos | 🟡 5 mejorables | 🟢 4 correctos
   Top crítico: SQL injection en AuthController (3 sprints sin resolver)

📄 Detalle completo: output/audits/YYYYMMDD-audit-proyecto.md
💡 Siguiente paso: /project-release-plan --project proyecto
```

## 1b. Output Compression (SPEC-OUTPUT-COMPRESS)

Output bash >30 lineas: `scripts/output-compress.sh` (7 filtros). Hook async. 60-90% reduccion.

## 2. Uso de subagentes para tareas pesadas

Cuando un comando necesita análisis profundo (leer muchos ficheros, comparar
datos, generar informes largos), DEBE usar `Task` (subagente).

El subagente trabaja en contexto aislado y devuelve solo el resumen.
Esto evita que el análisis intermedio contamine el contexto principal.

**Comandos que DEBEN usar subagente:**
- `/project-audit` → subagente analiza repo, devuelve scores + hallazgos
- `/evaluate-repo` → subagente clona y analiza, devuelve puntuaciones
- `/legacy-assess` → subagente evalúa 6 dimensiones, devuelve scoring
- `/spec-generate` → subagente genera spec, guarda en fichero
- Cualquier comando que lea más de 5 ficheros internamente

## 3. Auto-compact post-comando — 4 ZONAS CALIBRADAS

> Basado en TurboQuant (arXiv:2504.19874) + Claude Code nativo ch18 performance: degradación gradual, no en acantilado. Claude Code protege buffer del 20-25%, umbral real ~75% (ver SPEC-AUTOCOMPACT-CALIBRATION).

### Zonas de contexto

| Zona | Rango | Acción | Calidad |
|------|-------|--------|---------|
| Verde | <50% | Sin acción | Óptima |
| Gradual | 50-70% | Sugerir /compact, no bloquear | >99% |
| Alerta | 70-85% | Bloquear operaciones pesadas | 95-99% |
| Crítica | >85% | Bloquear todo | <95% |

**Mensajes por zona:** Gradual → `💡 Contexto al XX% — /compact cuando puedas.` · Alerta → `⚠️ Contexto alto — sin operaciones pesadas.` · Crítica → `❌ Compacta ahora.`

### Regla principal
**TRAS CADA slash command** → terminar con `⚡ /compact` en el banner de finalización.

### Al compactar, SIEMPRE preservar
- Ficheros modificados en la sesión
- Scores de audits/evaluaciones (hallazgos críticos)
- Decisiones tomadas por el PM
- Estado del sprint/proyecto activo
- Errores encontrados y cómo se resolvieron
- Último comando ejecutado y su resultado

### REGLA INVIOLABLE: Integridad de pares tool [SPEC-088]
**NUNCA** eliminar un mensaje tool_use sin eliminar tambien su tool_result
correspondiente (y viceversa). La API rechaza pares rotos.
Al dropear mensajes, siempre eliminar pares completos.
Si un miembro del par esta en Tier C (descartar) y el otro en Tier A
(preservar), promover AMBOS al Tier del miembro preservado.

## 3b. Pre-compact extraction [SPEC-016]

ANTES de ejecutar /compact, Savia extrae y persiste informacion valiosa:

**Scan** — Identificar en el contexto actual:
- Correcciones del usuario ("no", "eso no", "cambia X por Y")
- Decisiones explicitas ("vamos con X", "usaremos Y", "descartamos Z")
- Descubrimientos ("resulta que X funciona asi", "el bug era por Y")
- Estado de trabajo ("estamos en paso 3 de 5", "falta X")

**Quality gate** — Descartar:
- Contenido < 50 caracteres (trivial)
- Saludos, confirmaciones simples (ok, si, vale)
- Info ya presente en auto-memory (dedup)
- Datos efimeros (linea de codigo, ruta temporal)

**Persist** — Guardar en destino correcto:
- Correcciones → auto-memory tipo `feedback`
- Decisiones → auto-memory tipo `project`
- Descubrimientos → auto-memory tipo `project`
- Estado de trabajo → incluir en compact summary (no persistir)

**Compact summary** — Al compactar, incluir siempre:
```
Session context: [N] items extracted to memory.
Current task: [descripcion breve]
Files modified: [lista]
Last command: [comando] → [resultado breve]
```

Max 5 items extraidos por compact. Si hay mas, priorizar correcciones > decisiones > descubrimientos.

## 3c. Proactive Budget Tracker [SPEC-086]

Verifica contexto ANTES de operaciones pesadas, no despues. Dual threshold + circuit breaker.

Script: `scripts/context-budget-check.sh [percentage]` (o env `CLAUDE_CONTEXT_USAGE_PCT`).

| Resultado | Umbral | Accion | Exit |
|-----------|--------|--------|------|
| NO_ACTION | <80% | Nada, reset failures | 0 |
| STANDARD_COMPACT | >=80% | /compact recomendado | 1 |
| EMERGENCY_COMPACT | >=95% | Trim tool results, drop oldest (sin LLM) | 2 |
| CIRCUIT_OPEN | 3+ fallos | No reintentar compact, escalar | 3 |

Circuit breaker: si 3 compactaciones consecutivas no bajan del umbral, para de reintentar. Se resetea cuando el contexto baja de 80%. Estado en `~/.savia/compact-failures`.

## 4. Sesiones enfocadas

Una tarea por sesion. Si el PM cambia de objetivo → `/clear` + `/context-load`.
Antipatrones: mezclar audit+implementacion, 10+ comandos sin compactar, informes extensos en chat.

## 5. Memoria persistente entre sesiones

Estado en disco (no en contexto): `projects/{p}/.context-index/PROJECT.ctx` como mapa, `debt-register.md`, `risk-register.md`, `retro-actions.md`, `output/audits/`, `output/dora/`. Comandos leen bajo demanda. `/context-load` muestra resumen al inicio.

## 6. Limites de carga bajo demanda

Max 3 ficheros `@` por comando. Skills: solo SKILL.md (references bajo demanda). Datos de comandos anteriores: leer de output, no recargar.
