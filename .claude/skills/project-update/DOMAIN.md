# Domain — Project Update

## Por qué existe esta skill

Los proyectos activos acumulan cambios (commits, PRs, issues, documentos) que deben consolidarse periódicamente en un informe de estado. Sin automatización, el PM dedica horas a recopilar esta información manualmente. Esta skill orquesta la actualización integral del proyecto activo en un único paso determinista.

## Conceptos de dominio

- **Project snapshot**: estado completo del proyecto en un momento dado (commits, PRs, issues, docs)
- **Delta report**: diferencia entre el snapshot anterior y el actual
- **Refresh pipeline**: secuencia de pasos determinista que actualiza todos los artefactos del proyecto
- **Staleness threshold**: tiempo máximo que un artefacto puede estar sin actualizar antes de marcarse como stale

## Reglas de negocio

- Solo se actualiza el proyecto activo (detectado vía `project-context.sh detect`)
- Los snapshots se guardan en `projects/{nombre}/snapshots/`
- Si el proyecto no ha cambiado desde el último snapshot, se reporta "no changes"
