---
name: session-save
description: >
  Guarda decisiones, resultados y pendientes de la sesión actual antes de /clear.
  Persiste el conocimiento entre sesiones para que /context-load lo recupere.
---

# Session Save — Persistencia entre sesiones

**Argumentos:** $ARGUMENTS

> Ejecuta ANTES de `/clear` o al terminar una sesión para no perder contexto.

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /session-save — Guardando estado de sesión
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Recopilar información de la sesión

Revisar la conversación actual y extraer:

### 2a. Decisiones tomadas
Cualquier cosa que el PM haya decidido, aprobado o rechazado:
- Cambios de arquitectura, tecnología, priorización
- Aprobaciones de PRs, specs, planes
- Rechazos o postponements con motivo
- Criterios definidos para futuras decisiones

### 2b. Resultados de comandos
Scores, hallazgos y métricas producidos en la sesión:
- Audit scores y hallazgos críticos
- Evaluaciones de repos
- Métricas DORA / KPIs
- Deuda técnica detectada

### 2c. Ficheros modificados
Lista de ficheros creados o editados en la sesión (del git status/log).

### 2d. Tareas pendientes
Lo que quedó sin hacer o se identificó como siguiente paso.

### 2e. Contexto relevante
Cualquier información que la próxima sesión necesite para no empezar de cero.

## 3. Guardar en dos destinos

### 3a. Session log (historial)

Guardar en: `output/sessions/YYYYMMDD-HHMM-session.md`

Formato:
```markdown
# Sesión YYYY-MM-DD HH:MM

## Objetivo
{qué se hizo en esta sesión — 1 línea}

## Decisiones
- {decisión 1}
- {decisión 2}

## Resultados
- {resultado 1: score, métrica, hallazgo}

## Ficheros modificados
- {fichero 1}
- {fichero 2}

## Pendiente
- {tarea 1}
- {tarea 2}

## Contexto para próxima sesión
{lo que necesita saber quien continúe}
```

### 3b. Decision log (acumulativo, privado)

Fichero: `decision-log.md` (raíz del workspace, git-ignorado)

**Si no existe** → crearlo con cabecera:
```markdown
# Decision Log — PM-Workspace
# ── FICHERO PRIVADO — git-ignorado ──────────────────────────────

> Registro acumulativo de decisiones del PM. Cargado por /context-load.
> Mantener máximo 50 entradas. Al superar → archivar antiguas al final.

---
```

**Añadir al inicio** (después de la cabecera, antes de entradas anteriores):
```markdown
### YYYY-MM-DD — {objetivo de la sesión}
- {decisión 1}
- {decisión 2}
```

Solo decisiones — no resultados ni ficheros (eso está en el session log).

## 4. Mostrar resumen en chat

```
📋 Sesión guardada:
   📝 Decisiones: N
   📊 Resultados: N
   📁 Ficheros modificados: N
   ⏳ Pendientes: N
```

## 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /session-save — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Log: output/sessions/YYYYMMDD-HHMM-session.md
📋 Decision log actualizado: decision-log.md
💡 Ahora puedes ejecutar /clear con tranquilidad
```

## Restricciones

- Solo lectura de la conversación + escritura en los 2 ficheros indicados
- **NO modificar** ningún otro fichero
- **NO ejecutar** ningún otro comando
- Si no hay decisiones → guardar igualmente con "Sin decisiones en esta sesión"
- El decision-log.md es PRIVADO — nunca subirlo al repo
