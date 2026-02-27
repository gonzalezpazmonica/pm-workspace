---
name: context-load
description: >
  Carga de contexto al inicio de una sesión de Claude Code. Lee el estado actual
  del workspace, el proyecto activo, el sprint en curso y la actividad reciente
  para arrancar la sesión con información completa.
---

# Carga de Contexto — Inicio de Sesión

Aplica siempre @.claude/rules/command-ux-feedback.md

> Ejecuta este comando al empezar una sesión nueva para tener contexto completo.

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /context:load — Cargando contexto de sesión
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Protocolo de carga (con progreso)

```
📋 Paso 1/5 — Identificando workspace y rama...
```
```bash
pwd
git branch --show-current
```
Verificar que estamos en la raíz (`~/claude/`).

```
📋 Paso 2/5 — Leyendo configuración global...
```
Leer `CLAUDE.md` (raíz) — Proyectos Activos y Config Esencial.
Leer `CLAUDE.local.md` si existe — proyectos privados.

```
📋 Paso 3/5 — Analizando actividad Git reciente...
```
```bash
git log --oneline -10 --all --decorate
git branch -a | grep -v "remotes/origin/HEAD"
```
Resumir: últimos 5 commits, ramas activas no mergeadas.

```
📋 Paso 4/5 — Consultando estado del sprint...
```
Solo si PAT configurado:
- Ejecutar `/sprint:status` en modo resumido (solo burndown y alertas)
- Si no hay PAT → "⚠️ Azure DevOps no conectado — sprint no disponible"

```
📋 Paso 5/5 — Verificando herramientas disponibles...
```
```bash
claude --version 2>/dev/null || echo "no disponible"
az --version 2>/dev/null | head -1 || echo "no disponible"
dotnet --version 2>/dev/null || echo "no disponible"
jq --version 2>/dev/null || echo "no disponible"
```

## 3. Proyecto activo (detección automática)

Si la rama sigue `feature/`, `fix/`, etc.:
- Detectar proyecto por path o nombre de rama
- Leer su CLAUDE.md específico
- Resumir tarea en curso

## 4. Mostrar resultado

```
══════════════════════════════════════════════════
  PM-WORKSPACE · Sesión iniciada
══════════════════════════════════════════════════

  📁 Workspace: ~/claude/ (rama: main)
  🔧 Herramientas: Claude X.X ✅ | az CLI ✅ | .NET X ✅ | jq ✅

  📋 Proyectos activos: N
     • ProyectoAlpha — Sprint 2026-05 (día 4/10)
     • ProyectoBeta  — Sprint 2026-05 (día 4/10)

  📊 Sprint actual: [resumen 1 línea del burndown]
     [alerta más importante si hay]

  🌿 Ramas activas: N
     • feature/nueva-funcionalidad (3 commits adelante)
     • fix/capacity-edge-case (1 commit)

  📝 Últimos cambios:
     • feat(agents): add pr-review command
     • docs(readme): update command reference
     • fix(rules): correct PAT reference

══════════════════════════════════════════════════
```

## 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /context:load — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 {N} proyectos | 🌿 {N} ramas | 🔧 {N}/{M} herramientas OK
💡 ¿Por dónde empezamos?
```

## Restricciones

- **Solo lectura** — no modifica nada
- **Rápido** — no queries pesadas a Azure DevOps; datos locales primero
- **Conciso** — output legible en 30 segundos o menos
- Si PAT no configurado → no error, solo aviso
