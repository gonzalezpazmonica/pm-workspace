# Dominio: Google Sheets Tracker

## Contexto
El dominio de Google Sheets Tracker proporciona una alternativa ligera para la gestión visual de tareas y métricas, permitiendo que roles no técnicos (POs, stakeholders) trabajen con datos de proyecto sin necesidad de acceso a Azure DevOps.

## Límites de Responsabilidad
- **Lectura de datos** — Acceso filtrado a tareas, métricas y riesgos
- **Escritura de cambios de estado** — Actualizaciones de status que se sincronizan bidireccionalamente
- **Reportería** — Generación de vistas de métricas e informes
- **No gestiona** — Creación de nuevas PBIs, cambios profundos de arquitectura, o acceso administrativo

## Entidades Clave
1. **Tasks** — Conjunto de trabajo planificado en el sprint
2. **Metrics** — Indicadores de rendimiento del sprint
3. **Risks** — Impedimentos y riesgos identificados

## Relaciones de Integración
- Sincronización bidireccional con Azure DevOps
- MCP: google-sheets para operaciones de lectura/escritura
- Validación de datos y reglas de negocio

## Normativas de Datos
- Todas las celdas tienen validación de datos
- Historial de cambios auditado
- Permisos granulares por rol
