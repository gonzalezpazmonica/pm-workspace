---
name: agent-notes-archive
description: >
  Archiva agent-notes de sprints cerrados. Mueve las notas completadas a
  agent-notes/archive/{sprint}/ para mantener el directorio principal limpio.
allowed-tools:
  - Read
  - Bash
  - Glob
tier: extended
---

# /agent-notes-archive {proyecto} [sprint]

## Prerequisitos

1. Verificar que `projects/{proyecto}/agent-notes/` existe
2. Si no se especifica sprint, usar el sprint actual (obtener de Azure DevOps)

## Ejecución

1. 🏁 Banner inicio: `══ /agent-notes-archive — {proyecto} ══`
2. Listar agent-notes con status: completed o superseded
3. Crear directorio `projects/{proyecto}/agent-notes/archive/{sprint}/`
4. Mover notas completadas al directorio de archivo
5. Mostrar resumen: N notas archivadas, N notas activas restantes
6. ✅ Banner fin

## Reglas

- Solo archivar notas con `status: completed` o `status: superseded`
- Notas con `status: draft` o `status: in-progress` NO se archivan
- Confirmar con el PM antes de archivar si hay más de 10 notas
