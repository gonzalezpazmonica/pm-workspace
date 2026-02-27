---
name: memory-sync
description: Sincroniza insights del sprint en los topic files de auto memory
---

# /memory-sync — Sincronización de Memoria por Proyecto

## Descripción

Consolida los insights, decisiones y aprendizajes de la sesión actual en los topic files de auto memory del proyecto activo.

## Prerequisitos

- Proyecto activo identificado (leer `CLAUDE.md` del proyecto o preguntar)
- Directorio de auto memory existente en `~/.claude/projects/<project>/memory/`

## Procedimiento

### 1. Identificar proyecto y directorio de memoria

```bash
# El directorio se deriva del git root
MEMORY_DIR="$HOME/.claude/projects/$(basename $(git rev-parse --show-toplevel 2>/dev/null || echo $PWD))/memory"
```

Si no existe, crear la estructura:
```
memory/
├── MEMORY.md
├── sprint-history.md
├── architecture.md
├── debugging.md
├── team-patterns.md
└── devops-notes.md
```

### 2. Recopilar información de la sesión

Revisar en contexto:
- Decisiones arquitectónicas tomadas
- Bugs resueltos y sus soluciones
- Cambios en convenciones o patrones del equipo
- Configuraciones de entorno descubiertas
- Impedimentos encontrados y resoluciones
- Velocidad y métricas del sprint si están disponibles

### 3. Actualizar topic files

Distribuir la información en los ficheros apropiados:

| Información | Topic file |
|---|---|
| Decisiones de diseño, patrones elegidos | `architecture.md` |
| Bugs, errores, soluciones | `debugging.md` |
| Velocidad, burndown, impedimentos | `sprint-history.md` |
| Preferencias del equipo, convenciones | `team-patterns.md` |
| Pipelines, entornos, config | `devops-notes.md` |

### 4. Actualizar MEMORY.md (índice)

Mantener MEMORY.md como índice conciso (≤ 200 líneas):
- Una línea por insight clave
- Referencias a topic files para detalles
- Fecha de última actualización

Formato del índice:
```markdown
# Memory — {Proyecto}
> Última sync: YYYY-MM-DD

## Resumen
- [Breve] descripción del proyecto y stack
- Sprint actual: Sprint N (fecha inicio — fecha fin)

## Topic Files
- `sprint-history.md` — Velocidad promedio, impedimentos recurrentes
- `architecture.md` — Decisiones clave, ADRs informales
- `debugging.md` — Problemas resueltos y workarounds
- `team-patterns.md` — Convenciones del equipo, preferencias
- `devops-notes.md` — Config de CI/CD, entornos, secretos

## Insights Recientes
- {línea 1}
- {línea 2}
- ...
```

### 5. Banner de resultado

```
════════════════════════════════════════════════════════
  /memory-sync — {Proyecto}
  ✅ Sincronización completada
  📁 {N} topic files actualizados
  📝 MEMORY.md: {líneas}/200 líneas usadas
  📅 Última sync: {fecha}
════════════════════════════════════════════════════════
```

⚡ /compact
