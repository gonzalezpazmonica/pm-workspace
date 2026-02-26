---
name: context-load
description: >
  Carga de contexto al inicio de una sesión de Claude Code. Lee el estado actual
  del workspace, el proyecto activo, el sprint en curso y la actividad reciente
  para arrancar la sesión con información completa.
---

# Carga de Contexto — Inicio de Sesión

> Ejecuta este comando al empezar una sesión nueva para que Claude tenga
> contexto completo sin que tengas que repetir información.

---

## Protocolo de carga (en orden)

### 1. Identificar el workspace

```bash
pwd
git branch --show-current
```

Verificar que estamos en la raíz del workspace (`~/claude/`).

### 2. Leer configuración global

Leer `CLAUDE.md` (raíz) — solo la sección de Proyectos Activos y Configuración Esencial.
Leer `CLAUDE.local.md` si existe — proyectos privados configurados.

### 3. Actividad reciente en Git

```bash
git log --oneline -10 --all --decorate
git branch -a | grep -v "remotes/origin/HEAD"
```

Resumir: últimos 5 commits, ramas activas (no mergeadas).

### 4. Estado del sprint (si Azure DevOps está disponible)

Solo si existe el PAT configurado:
```bash
test -f "$HOME/.azure/devops-pat" && echo "PAT disponible" || echo "PAT no configurado"
```

Si está disponible: ejecutar el equivalente de `/sprint:status` en modo resumido
(solo burndown y alertas, sin detalle por item).

Si no está disponible: indicar que Azure DevOps no está conectado y que los
comandos de sprint no funcionarán.

### 5. Proyecto activo (si hay rama de feature)

Si la rama actual sigue el patrón `feature/`, `fix/`, etc.:
- Detectar a qué proyecto pertenece (por el path o por el nombre de la rama)
- Leer su `CLAUDE.md` específico
- Resumir el estado de la tarea en curso

### 6. Verificar herramientas

```bash
claude --version 2>/dev/null || echo "Claude CLI: no disponible"
az --version 2>/dev/null | head -1 || echo "Azure CLI: no disponible"
dotnet --version 2>/dev/null || echo ".NET SDK: no disponible"
jq --version 2>/dev/null || echo "jq: no disponible"
```

---

## Formato del output

```
══════════════════════════════════════════════════
  PM-WORKSPACE · Sesión iniciada
══════════════════════════════════════════════════

  📁 Workspace: ~/claude/ (rama: main)
  🔧 Herramientas: Claude X.X ✅ | az CLI ✅ | .NET X ✅ | jq ✅

  📋 Proyectos activos: N
     • ProyectoAlpha — Sprint 2026-05 (día 4/10)
     • ProyectoBeta  — Sprint 2026-05 (día 4/10)

  📊 Sprint actual: [resumen de 1 línea del burndown]
     [alerta más importante si hay alguna]

  🌿 Ramas activas: N
     • feature/nueva-funcionalidad (3 commits adelante de main)
     • fix/capacity-edge-case (1 commit)

  📝 Últimos cambios:
     • feat(agents): add pr-review multi-perspective command
     • docs(readme): update command reference table
     • fix(rules): correct PAT reference in pm-config

══════════════════════════════════════════════════
  ¿Por dónde empezamos?
══════════════════════════════════════════════════
```

---

## Restricciones

- **Solo lectura** — este comando no modifica nada
- **Rápido** — no ejecutar queries pesadas a Azure DevOps; priorizar datos locales
- **Conciso** — el output debe leerse en 30 segundos o menos
- Si el PAT no está configurado, no mostrar error — simplemente indicar que AzDO no está disponible
