# Capability Groups — Mapa de Comandos

> Agrupación semántica de los 360+ comandos de pm-workspace para reducir tool overload.
> Referencia: `docs/rules/domain/tool-discovery.md`

---

## ¿Por qué grupos?

El AI Engineering Guidebook (2025) documenta que más herramientas no significa
mejores resultados. Al agrupar comandos por capacidad, los agentes y el
NL-resolver pueden buscar en un subconjunto relevante en vez de recorrer el
catálogo completo.

---

## Grupos y sus comandos principales

### 1. Sprint Management (`sprint`)
Sprint planning, dailys, velocidad, burndown.
Comandos clave: `sprint-plan`, `sprint-review`, `sprint-retro`, `daily-generate`, `velocity-trend`

### 2. Project Lifecycle (`project`)
Onboarding, auditoría, releases, health checks.
Comandos clave: `project-audit`, `project-release-plan`, `project-onboard`, `project-health`

### 3. Backlog Management (`backlog`)
PBIs, priorización, refinamiento, decomposición.
Comandos clave: `pbi-create`, `pbi-refine`, `backlog-prioritize`, `backlog-groom`

### 4. Architecture & Design (`architecture`)
Revisiones, ADRs, diagramas, patrones.
Comandos clave: `arch-review`, `adr-create`, `diagram-generate`, `diagram-import`

### 5. Technical Debt (`debt`)
Tracking, análisis, priorización, presupuesto de deuda.
Comandos clave: `debt-track`, `debt-analyze`, `debt-prioritize`, `legacy-assess`

### 6. Security & Compliance (`security`)
Seguridad, accesibilidad, AEPD, regulatory.
Comandos clave: `security-review`, `a11y-audit`, `aepd-compliance`, `regulatory-check`

### 7. Testing (`testing`)
Test execution, coverage, visual regression, spec verification.
Comandos clave: `test-run`, `spec-verify-ui`, `visual-regression`, `coverage-report`

### 8. DevOps & Infrastructure (`devops`)
Pipelines, deploys, infra as code, environments.
Comandos clave: `pipeline-status`, `deploy-check`, `infra-plan`, `env-setup`

### 9. Reporting & Metrics (`reporting`)
Informes ejecutivos, DORA, dashboards.
Comandos clave: `report-sprint`, `executive-report`, `dora-metrics`, `kpi-dashboard`

### 10. Risk Management (`risk`)
Riesgos, incidentes, postmortems.
Comandos clave: `risk-log`, `risk-matrix`, `incident-postmortem`

### 11. Team & Wellbeing (`team`)
Health checks, capacity, onboarding, bienestar.
Comandos clave: `team-health`, `capacity-plan`, `team-onboard`, `wellbeing-check`

### 12. Memory & Context (`memory`)
Memoria persistente, contexto, NL queries.
Comandos clave: `memory-recall`, `memory-stats`, `context-load`, `nl-query`, `entity-recall`

### 13. AI Governance (`ai-governance`)
Exposición IA, adopción, trazabilidad de agentes.
Comandos clave: `ai-exposure-audit`, `ai-confidence`, `agent-trace`, `adoption-assess`

### 14. Communication (`communication`)
Mensajería, voice inbox, comunidad.
Comandos clave: `msg-send`, `voice-inbox`, `community-engage`

### 15. Spec-Driven Development (`spec-driven`)
Generación de specs, SDD flow, implementación.
Comandos clave: `spec-generate`, `sdd-status`, `implement-spec`, `eval-output`

---

## Cómo usar

Para el PM: `/help --group sprint` muestra solo los comandos del grupo sprint.
Para agentes: el orquestador carga solo los comandos del grupo asignado.
Para NL-resolver: primero identifica grupo, luego busca dentro del grupo.
