# Domain — Weekly Report

## Por qué existe esta skill

Los informes semanales son el pulso del proyecto. Consolidan sprint status, actividad git, PRs abiertos y capacidad del equipo en un solo documento. Sin automatización, el PM invierte 30-60 minutos cada semana en compilarlos manualmente. Esta skill reduce ese tiempo a segundos.

## Conceptos de dominio

- **Weekly cadence**: ciclo semanal de reporting (lunes a viernes)
- **Report template**: plantilla Jinja2 con variables que se rellenan desde datos reales
- **Multi-source consolidation**: agregación de datos desde Azure DevOps, git, y documentación del proyecto
- **Scheduled generation**: generación automática vía cron (semanal, lunes 09:00)

## Reglas de negocio

- El informe cubre de lunes a viernes de la semana actual
- Si no hay proyecto activo, se muestra error con instrucciones
- Los datos de ADO requieren PAT configurado; sin él se muestra "sin conexión a Azure DevOps"
