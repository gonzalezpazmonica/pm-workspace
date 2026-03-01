---
name: context-load
description: >
  Carga de contexto al inicio de sesión. Lee estado del workspace, decisiones
  recientes, último session save y actividad Git para arrancar con el big picture.
---

# Carga de Contexto — Inicio de Sesión

> Ejecuta al empezar una sesión nueva para tener contexto completo.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Memory** del context-map):
   - `profiles/users/{slug}/identity.md`
3. Usar slug para aislar memorias por usuario
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /context-load — Cargando contexto de sesión
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 3. Detección de stack

Leer `CLAUDE.local.md` → campo `AZURE_DEVOPS_ENABLED`.
Mostrar: `📦 Stack: {GitHub-only|Azure DevOps}`

## 4. Protocolo de carga (con progreso)

```
📋 Paso 1/5 — Workspace y rama...
```
```bash
pwd && git branch --show-current
```
Verificar raíz (`~/claude/`).

```
📋 Paso 2/5 — Memoria persistente y sesión anterior...
```
**Memory store** (`output/.memory-store.jsonl`):
- Si existe → ejecutar `bash scripts/memory-store.sh context --limit 10`
- Mostrar últimas decisiones, bugs y patrones agrupados por tipo
- Si no existe → buscar `decision-log.md` como fallback (formato legacy)

**Último session save** (`output/sessions/` → fichero más reciente):
- Si existe → leer y mostrar: objetivo, pendientes, contexto para esta sesión
- Si no existe → `ℹ️ Sin sesiones anteriores guardadas`

```
📋 Paso 3/6 — Estado de proyectos...
```
Leer `CLAUDE.local.md` → tabla de proyectos activos.
Para cada proyecto, comprobar si existe y mostrar 1 línea de estado:
- Último audit: `output/audits/*-{proyecto}.md` → score si existe
- Deuda: `projects/{p}/debt-register.md` → items abiertos si existe
- Riesgos: `projects/{p}/risk-register.md` → riesgos críticos si existe

```
📋 Paso 4/6 — ADRs activos...
```
Para cada proyecto activo, buscar ADRs con `status: accepted`:
```bash
grep -l "status: accepted" projects/*/adrs/*.md 2>/dev/null
```
- Si existen → leer título y fecha de cada ADR activo, mostrar resumen (máx. 5 ADRs más recientes)
- Si no existen → `ℹ️ Sin ADRs activos`
- Formato: `🏛️ ADR-001: {título} ({fecha}) — {proyecto}`

**Propósito**: Prevenir deriva arquitectónica a largo plazo al recordar decisiones activas al inicio de cada sesión.

```
📋 Paso 5/6 — Actividad Git reciente...
```
```bash
git log --oneline -5 --decorate
```
Ramas activas no mergeadas (si hay).

```
📋 Paso 6/6 — Herramientas disponibles...
```
Solo si stack = Azure DevOps: verificar `az`, PAT.
Siempre: `claude --version`, `git --version`.

## 4. Mostrar resultado

```
══════════════════════════════════════════════════
  PM-WORKSPACE · Sesión iniciada
══════════════════════════════════════════════════

  📦 Stack: {GitHub-only|Azure DevOps}
  📁 Workspace: ~/claude/ (rama: {branch})

  📋 Decisiones recientes:
     • {decisión más reciente}
     • {decisión 2}
     • {decisión 3}

  ⏳ Pendiente (de última sesión):
     • {tarea pendiente 1}
     • {tarea pendiente 2}

  📁 Proyectos activos: N
     • {proyecto1} — audit: X/10 | deuda: N items | riesgos: N
     • {proyecto2} — sin audit previo

  🏛️ ADRs activos: N
     • ADR-001: {título} ({fecha}) — {proyecto}
     • ADR-002: {título} ({fecha}) — {proyecto}

  📝 Últimos cambios:
     • {commit 1}
     • {commit 2}

══════════════════════════════════════════════════
```

Si no hay decisiones ni sesiones previas, mostrar solo proyectos + git.
Si no hay proyectos → sugerir `/help --setup`.

## 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /context-load — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 {N} proyectos | 🏛️ {N} ADRs activos | 📋 {N} decisiones recientes | ⏳ {N} pendientes
💡 ¿Por dónde empezamos?
```

## Restricciones

- **Solo lectura** — no modifica nada
- **Conciso** — output legible en 30 segundos, NO cargar ficheros completos
- Si no hay PAT / Azure DevOps → no error, solo omitir esos datos
- Leer solo las primeras líneas de cada fichero de estado (no cargar completos)
- **NO ejecutar otros comandos** como dependencia (/sprint-status, etc.)
