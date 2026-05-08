---
spec_id: SE-093
title: Zero project leakage enforcement — context isolation by project
status: APPROVED
approved_by: operator (2026-05-07)
priority: CRITICAL
effort: M
estimated_time: 60 min
depends_on: SPEC-127 (provider-agnostic env)
---

# SE-093 — Zero Project Leakage: aislamiento de contexto por proyecto

## Problema

OpenCode carga el workspace completo (todos los proyectos en `projects/`, todas las reglas, docs, specs). Cuando un agente o SaviaClaw responde, el LLM mezcla información de proyectos distintos. Ejemplos reales detectados:

- SaviaClaw Talk menciona "Savia Web" cuando se le pregunta por pm-workspace
- Un comando `/sprint-status` devuelve datos del proyecto equivocado si hay múltiples configurados
- Agentes que leen specs de un proyecto y las aplican a otro

Esto es una fuga de contexto que viola el aislamiento entre proyectos y genera respuestas incorrectas.

## Solución

Implementar un mecanismo de aislamiento por proyecto que:
1. Detecta qué proyecto está activo en cada turno
2. Filtra el contexto cargado al proyecto activo
3. Bloquea referencias cruzadas entre proyectos
4. Mantiene compatibilidad con comandos cross-project cuando se solicitan explícitamente

## Alcance

### Slice 1: Detección de proyecto activo — ~15 min

Script `scripts/project-context.sh`:
- `project-context.sh detect` — detecta el proyecto activo desde el prompt del usuario
- `project-context.sh set <project>` — establece proyecto activo manualmente
- `project-context.sh list` — lista proyectos disponibles
- `project-context.sh filter <file>` — filtra líneas de un fichero para mantener solo las del proyecto activo

Heurísticas de detección:
1. El usuario menciona el nombre del proyecto explícitamente
2. Se está ejecutando un comando con scope de proyecto (`/sprint-status <proyecto>`)
3. El contexto actual referencia ficheros en `projects/<nombre>/`
4. Fallback: último proyecto activo (guardado en `.savia/active-project`)

### Slice 2: Hook de aislamiento — ~20 min

Hook `project-isolation-gate.sh` (PreToolUse):
- Detecta el proyecto activo al inicio de cada turno
- Si se detecta un proyecto, inyecta en contexto: `PROJECT ACTIVE: <nombre>`
- Si el agente referencia ficheros de otro proyecto, emite WARNING
- Nunca bloquea — solo advierte

### Slice 3: Filtro de contexto — ~15 min

Modificar `opencode.json` para cargar contexto específico del proyecto activo:
- Si proyecto activo = `trazabios`, cargar `projects/trazabios/CLAUDE.md` pero NO `projects/alpha/CLAUDE.md`
- Reglas de dominio y skills se cargan siempre (son compartidas)
- Documentación de proyecto se carga solo si pertenece al proyecto activo

### Slice 4: Comando de cambio de proyecto — ~10 min

Comando `/project-switch <nombre>`:
- Cambia el proyecto activo
- Muestra resumen del proyecto (último sprint, estado, issues abiertos)
- Guarda en `.savia/active-project`

## Diseño técnico

### `scripts/project-context.sh`

```bash
# project-context.sh — Project isolation for Savia
ACTIVE_FILE="${SAVIA_WORKSPACE_DIR:-$HOME/savia}/.savia/active-project"

detect_active_project() {
  # 1. Explicit override
  [[ -n "${SAVIA_ACTIVE_PROJECT:-}" ]] && { echo "$SAVIA_ACTIVE_PROJECT"; return 0; }
  # 2. Saved state
  [[ -f "$ACTIVE_FILE" ]] && { cat "$ACTIVE_FILE"; return 0; }
  # 3. No project active
  echo ""
}
```

### Hook `project-isolation-gate.sh`

```bash
# PreToolUse hook — warns on cross-project references
ACTIVE=$(bash scripts/project-context.sh detect 2>/dev/null)
[[ -z "$ACTIVE" ]] && exit 0

# Check if tool input references files from other projects
INPUT=$(cat /dev/stdin 2>/dev/null || echo "")
for proj_dir in projects/*/; do
  pname=$(basename "$proj_dir")
  [[ "$pname" == "$ACTIVE" ]] && continue
  if echo "$INPUT" | grep -q "projects/$pname/"; then
    echo "WARNING: Cross-project reference detected: $pname (active: $ACTIVE)" >&2
  fi
done
exit 0
```

## Acceptance Criteria

### AC-1: Detección de proyecto
- `project-context.sh detect` devuelve el proyecto activo o vacío
- `/project-switch alpha` cambia el proyecto activo
- Tras cambiar, `project-context.sh detect` devuelve el nuevo proyecto

### AC-2: Hook de aislamiento
- Si se referencia `projects/alpha/` y el proyecto activo es `beta`, el hook emite WARNING
- El hook nunca bloquea (exit 0 siempre)
- El warning aparece en stderr

### AC-3: Contexto cargado por proyecto
- Con proyecto activo, el contexto inyecta `PROJECT ACTIVE: <nombre>` al inicio
- Los CLAUDE.md de otros proyectos no se cargan
- Las reglas de dominio y skills se cargan siempre

### AC-4: Sin regresión
- Sin proyecto activo, todo el contexto se carga normalmente
- Comandos cross-project explícitos (`/sprint-status otro-proyecto`) funcionan
- Tests existentes pasan sin cambios

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Falsos positivos en detección de proyecto | Solo WARNING, nunca bloqueo |
| Proyecto activo incorrecto | Comando `/project-switch` para corrección manual |
| Contexto insuficiente tras filtrar | Reglas de dominio y skills siempre disponibles |

## Referencias

- docs/rules/domain/zero-project-leakage.md — regla canónica
- docs/rules/domain/context-placement-confirmation.md — N1-N4b levels
- SaviaClaw Talk: bug de mezcla de proyectos detectado 2026-05-07
