# time-tracking-report — Dominio

## Por que existe esta skill

Los informes de imputacion de horas son obligatorios en la mayoria de contratos con clientes y en la gestion interna de capacidad. Generarlos manualmente desde Azure DevOps consume horas de PM cada sprint. Esta skill automatiza la extraccion de horas de work items, la agrupacion por persona y actividad, el calculo de desviaciones y la exportacion a Excel/Word con formato corporativo.

## Conceptos de dominio

- **CompletedWork**: horas reales dedicadas a un work item, registradas en Azure DevOps por cada miembro del equipo
- **Desviacion**: diferencia entre horas estimadas (OriginalEstimate) y horas reales (CompletedWork + RemainingWork), expresada en horas y porcentaje
- **Agrupacion por actividad**: clasificacion del trabajo en categorias estandar (Development, Testing, Documentation, Meeting, Design, DevOps)
- **Timesheet corporativo**: informe con pestanas de resumen, detalle, actividad y comparativa, listo para entrega a cliente o direccion

## Reglas de negocio que implementa

- Convencion de informes: YYYYMMDD-tipo-proyecto.ext en output/
- Regla de PAT: NUNCA hardcodear, siempre $(cat $PAT_FILE)
- Regla de confirmacion: preguntar al usuario antes de subir a SharePoint
- Regla output-first: resultado en fichero, resumen en chat

## Relacion con otras skills

- **Upstream**: `azure-devops-queries` (extraccion de work items con horas via WIQL)
- **Upstream**: `capacity-planning` (datos de capacidad por persona contextualizan las desviaciones)
- **Downstream**: `executive-reporting` (el informe de horas alimenta el informe ejecutivo)
- **Paralelo**: `cost-management` (timesheets complementan el tracking de costes)

## Decisiones clave

- Excel como formato principal (no PDF): los clientes y directivos esperan poder filtrar y pivotar datos
- WIQL directo a Azure DevOps API en vez de az CLI: mas control sobre los campos extraidos
- Desviacion como (completado+restante)-estimado: refleja el impacto real, no solo el pasado
- Subida a SharePoint opcional y confirmada: no todos los proyectos usan SharePoint, y la subida es irreversible
