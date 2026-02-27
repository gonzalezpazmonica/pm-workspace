# Regla: Workflow PM — Convenciones, Cadencia y Comandos
# ── Referencia operativa completa ────────────────────────────────────────────

## 📅 Cadencia Scrum

| Ceremonia | Cuándo | Duración |
|---|---|---|
| Sprint Planning | Lunes inicio sprint, 10:00 | 4h max |
| Daily Standup | Cada día laborable, 09:15 | 15 min |
| Sprint Review | Viernes fin sprint, 15:00 | 1h |
| Retrospectiva | Viernes fin sprint, 16:30 | 1.5h |
| Refinement | Miércoles semana 1 del sprint, 11:00 | 2h |

## 📏 Convenciones

- **Branches:** `feature/#XXXX-descripcion`, `fix/#XXXX-descripcion` (el `#ID` enlaza el commit con la tarea en DevOps)
- **Commits:** `[AB#XXXX] Descripción corta en imperativo`
- **Sprints:** `Sprint YYYY-NN` (ej: `Sprint 2026-04`)
- **Informes:** `YYYYMMDD-tipo-proyecto.ext` (ej: `20260222-sprint-report-alpha.xlsx`)

## 📟 Comandos Disponibles

| Comando | Descripción |
|---|---|
| `/sprint:status` | Estado del sprint actual: progreso, burndown, alertas |
| `/sprint:plan` | Asistente de Sprint Planning: capacity + PBIs candidatos |
| `/sprint:review` | Resumen para Sprint Review: velocity, items completados |
| `/sprint:retro` | Plantilla de retrospectiva con datos del sprint |
| `/report:hours` | Informe de imputación de horas (Excel) |
| `/report:executive` | Informe ejecutivo multi-proyecto (PPT/Word) |
| `/report:capacity` | Estado de capacidades del equipo |
| `/team:workload` | Carga de trabajo por persona |
| `/board:flow` | Análisis del flujo: WIP, cuellos de botella, cycle time |
| `/kpi:dashboard` | Dashboard completo de KPIs del equipo |
| `/pbi:decompose {id}` | Descomponer un PBI en tasks con estimación y asignación |
| `/pbi:decompose-batch {ids}` | Descomponer varios PBIs optimizando la carga global |
| `/pbi:assign {pbi_id}` | (Re)asignar tasks existentes de un PBI |
| `/pbi:plan-sprint` | Planning completo: capacity + PBIs + descomposición + asignación |
| `/spec:generate {task_id}` | Generar Spec ejecutable desde una Task de Azure DevOps |
| `/spec:implement {spec_file}` | Implementar una Spec (lanza agente Claude o asigna humano) |
| `/spec:review {spec_file}` | Revisar calidad de Spec o validar implementación resultante |
| `/spec:status` | Dashboard de estado de todas las Specs del sprint |
| `/agent:run {spec_file}` | Lanzar agente Claude directamente sobre una Spec |
| `/pbi:jtbd {id}` | Generar documento Jobs to be Done para un PBI (discovery) |
| `/pbi:prd {id}` | Generar Product Requirements Document para un PBI (discovery) |
| `/pr:review [PR]` | Revisión multi-perspectiva de PR (BA, Dev, QA, Security, DevOps) |
| `/pr:pending` | PRs asignados al PM pendientes de revisión: estado, votos, comentarios, antigüedad |
| `/context:load` | Carga de contexto al iniciar sesión (proyecto, sprint, actividad) |
| `/changelog:update` | Actualizar CHANGELOG.md desde commits convencionales |
| `/evaluate:repo [URL]` | Auditoría de seguridad y calidad de un repo externo |
| `/team:onboarding {nombre}` | Guía de onboarding personalizada (Fases 1-2: contexto + código) |
| `/team:evaluate {nombre}` | Cuestionario interactivo de competencias → perfil en equipo.md |
| `/team:privacy-notice {nombre}` | Nota informativa RGPD obligatoria antes de evaluar competencias |
| `/infra:detect {proyecto} {env}` | Detectar infraestructura existente del proyecto en un entorno |
| `/infra:plan {proyecto} {env}` | Generar plan de infraestructura para un entorno |
| `/infra:estimate {proyecto}` | Estimar costes de infraestructura por entorno |
| `/infra:scale {recurso}` | Proponer escalado de un recurso (requiere aprobación humana) |
| `/infra:status {proyecto}` | Estado de la infraestructura actual del proyecto |
| `/env:setup {proyecto}` | Configurar entornos (DEV/PRE/PRO) para un proyecto |
| `/env:promote {proyecto} {origen} {destino}` | Promover deploy entre entornos (PRE→PRO requiere aprobación) |
| `/diagram:generate {proy}` | Generar diagrama de arquitectura/flujo → Draw.io, Miro o local |
| `/diagram:import {source}` | Importar diagrama → validar reglas negocio → crear Features/PBIs/Tasks |
| `/diagram:config` | Configurar credenciales Draw.io/Miro y verificar conexión |
| `/diagram:status` | Listar diagramas por proyecto y estado de sincronización |
| `/pipeline:status {--project p}` | Estado de pipelines: últimas builds, % éxito, duración, alertas |
| `/pipeline:run {--project p} {pipeline}` | Ejecutar pipeline con preview y confirmación previa |
| `/pipeline:logs {--project p} {--build id}` | Logs de una build: timeline, errores, warnings |
| `/pipeline:create {--project p} {--name n}` | Crear pipeline YAML desde template con preview |
| `/pipeline:artifacts {--project p} {--build id}` | Listar/descargar artefactos de una build |
| `/repos:list {--project p}` | Listar repositorios del proyecto en Azure DevOps |
| `/repos:branches {--project p} {--repo r}` | Gestión de branches: listar, crear, comparar |
| `/repos:pr-create {--project p} {--repo r}` | Crear PR en Azure Repos con work item linking |
| `/repos:pr-list {--project p}` | Listar PRs: pendientes, asignados al PM, por reviewer |
| `/repos:pr-review {--project p} {--pr id}` | Review multi-perspectiva de PR en Azure Repos |
| `/repos:search {--project p} {query}` | Buscar código en repositorios de Azure DevOps |
| `/notify:slack {canal} {msg}` | Enviar notificación o informe al canal de Slack del proyecto |
| `/slack:search {query}` | Buscar mensajes y decisiones en Slack como contexto |
| `/github:activity {repo}` | Analizar actividad GitHub: PRs, commits, contributors |
| `/github:issues {repo}` | Gestionar issues GitHub: buscar, crear, sincronizar con Azure DevOps |
| `/sentry:health {--project p}` | Métricas de salud técnica desde Sentry: errores, crash rate, performance |
| `/sentry:bugs {--project p}` | Crear PBIs (Bug) en Azure DevOps desde errores frecuentes en Sentry |
| `/gdrive:upload {file}` | Subir informes y documentos generados a Google Drive |
| `/linear:sync {--project p}` | Sincronizar issues Linear ↔ PBIs/Tasks Azure DevOps |
| `/jira:sync {--project p}` | Sincronizar issues Jira ↔ PBIs Azure DevOps (bidireccional) |
| `/confluence:publish {file}` | Publicar documentación/informes en Confluence |
| `/notion:sync {--project p}` | Sincronizar documentación del proyecto con Notion (import/export) |
| `/figma:extract {url}` | Extraer componentes UI, pantallas y design tokens desde Figma |
| `/help [filtro]` | Ayuda: catálogo de comandos + detección de primeros pasos pendientes |

## 🔗 Referencias

- Reglas Scrum: `docs/reglas-scrum.md`
- KPIs: `docs/kpis-equipo.md`
- Plantillas: `docs/plantillas-informes.md`
- Política estimación: `docs/politica-estimacion.md`
- Queries WIQL: `.claude/skills/azure-devops-queries/references/wiql-patterns.md`
- Product Discovery: `.claude/skills/product-discovery/SKILL.md`
- Scoring asignación: `.claude/skills/pbi-decomposition/references/assignment-scoring.md`
- SDD Template: `.claude/skills/spec-driven-development/references/spec-template.md`
- SDD Layer Matrix: `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`
- SDD Agent Patterns: `.claude/skills/spec-driven-development/references/agent-team-patterns.md`
- Team Onboarding: `.claude/skills/team-onboarding/SKILL.md`
- Multi-entorno: `.claude/rules/environment-config.md`
- Confidencialidad: `.claude/rules/confidentiality-config.md`
- Infrastructure as Code: `.claude/rules/infrastructure-as-code.md`
- Conectores Claude: `.claude/rules/connectors-config.md`
- Diagram Generation: `.claude/skills/diagram-generation/SKILL.md`
- Diagram Import: `.claude/skills/diagram-import/SKILL.md`
- Diagram Config: `.claude/rules/diagram-config.md`
- Azure Pipelines: `.claude/skills/azure-pipelines/SKILL.md`
- Azure Repos Config: `.claude/rules/azure-repos-config.md`
- Azure DevOps API v7.1: https://learn.microsoft.com/en-us/rest/api/azure/devops/
