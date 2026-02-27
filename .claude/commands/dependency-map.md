---
name: dependency-map
description: >
  Mapa de dependencias entre PBIs, Features y equipos.
  Alertas de bloqueo y grafo visual para sprint planning.
---

# Dependency Map

**Argumentos:** $ARGUMENTS

> Uso: `/dependency:map --project {p}` o `/dependency:map --project {p} --add`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--sprint` — Solo dependencias del sprint actual (defecto)
- `--release {nombre}` — Dependencias de una release completa
- `--add {from_id} --depends-on {to_id}` — Registrar dependencia
- `--remove {from_id} --depends-on {to_id}` — Eliminar dependencia
- `--cross-project` — Incluir dependencias con otros proyectos
- `--diagram` — Generar diagrama visual (Mermaid → Draw.io/Miro)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `.claude/skills/azure-devops-queries/SKILL.md` — WIQL para work items

## Pasos de ejecución

### Modo vista
1. **Obtener PBIs del sprint/release** — WIQL filtrado
2. **Leer relaciones** — Azure DevOps link types:
   - `System.LinkTypes.Dependency` (Predecessor/Successor)
   - `System.LinkTypes.Related`
   - Cross-project links
3. **Detectar bloqueos:**
   - Dependencia en estado New/Active → bloqueante
   - Dependencia asignada a otro equipo → cross-team
   - Dependencia circular → error crítico
4. **Presentar mapa:**

```
## Dependencias — {proyecto} — Sprint {n}

### Bloqueos activos (2)
- PBI #1234 "OAuth login" BLOQUEADO POR #1230 "API Gateway" (equipo Platform)
  → #1230 en estado Active, ETA: 3 días
- PBI #1240 "Payment flow" BLOQUEADO POR #1238 "DB migration" (mismo equipo)
  → #1238 en estado New, sin asignar ⚠️

### Grafo de dependencias
#1230 (Platform) → #1234 (Auth) → #1236 (Dashboard)
#1238 (DB) → #1240 (Payments) → #1242 (Reports)
#1235 (independiente)

### Resumen
Items con dependencias: 5/8 (62%)
Bloqueos activos: 2
Cross-team: 1
Ruta crítica: #1230 → #1234 → #1236 (estimado: 8 días)
```

### Modo `--diagram`
1. Generar Mermaid flowchart con dependencias
2. Usar `/diagram:generate` para publicar en Draw.io/Miro
3. Colorear: verde=resuelto, amarillo=en progreso, rojo=bloqueado

### Modo `--add`
1. Crear link de dependencia en Azure DevOps via MCP
2. Verificar que no crea ciclo
3. Confirmar con PM antes de crear

## Integración

- `/sprint:plan` → muestra dependencias al planificar
- `/project:release-plan` → usa mapa para ordenar releases
- `/board:flow` → detecta cuellos de botella por dependencias
- `/project:roadmap` → incluye dependencias en timeline

## Restricciones

- Crear/eliminar dependencias requiere confirmación del PM
- Dependencias circulares se reportan como error, no se crean
- Cross-project requiere acceso a ambos proyectos en Azure DevOps
