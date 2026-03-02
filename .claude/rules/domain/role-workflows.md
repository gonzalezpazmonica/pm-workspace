---
name: role-workflows
description: Rutinas diarias y flujos de trabajo específicos por rol del usuario
auto_load: false
paths: []
---

# Workflows por Rol — Rutinas Adaptativas de Savia

> 🦉 Cada rol tiene un ritmo diferente. Savia se adapta al tuyo.

---

## Principio

El campo `role` de `identity.md` y `primary_mode` de `workflow.md` determinan qué rutina sugiere Savia al inicio de sesión y qué comandos prioriza.

---

## PM / Scrum Master — Modo `daily-first`

### Rutina diaria (al abrir sesión)
1. `/sprint-status` — progreso, burndown, violaciones WIP
2. `/team-workload` — carga por persona, items sin asignar
3. `/board-flow` — detectar cuellos de botella
4. `/nl-query` (opcional) — consultar estado del proyecto en lenguaje natural
5. Si hay bloqueantes → sugerir escalación o redistribución
6. `/integration-status --check` (semanal) — verificar salud de integraciones

### Ritual semanal
- **Lunes**: `/sprint-plan` o `/sprint-autoplan` — kickoff del sprint si aplica
- **Lunes**: `/risk-predict` — análisis de riesgos del sprint
- **Miércoles**: `/pbi-plan-sprint` — refinamiento del backlog
- **Miércoles**: `/backlog-patterns` — detección de PBIs duplicados/similares entre proyectos
- **Viernes**: `/report-hours` + `/report-executive` + `/sprint-review`

### Platform Integration (cuando aplica)
- `/platform-migrate --plan` — plan migración entre plataformas (Jira ↔ Linear ↔ GitHub Projects)
- `/jira-connect setup` — conectar Jira Cloud si no está configurado
- `/github-projects connect` — conectar GitHub Projects si aplica
- `/company-setup` — onboarding conversacional de empresa: sector, estructura, estrategia
- `/company-edit {section}` — editar secciones del perfil de empresa

### Métricas clave
- Velocity trend, burndown, WIP, lead time, bloqueantes activos

### Alertas personalizadas
- Items sin mover en >2 días → sugerir revisión
- Capacidad < 70% → alerta de infrautilización
- Capacidad > 110% → alerta de sobrecarga
- Sprint burndown desviado >20% → alerta temprana

---

## Tech Lead — Modo `code-focused`

### Rutina diaria
1. `/tech-radar --outdated` — detectar dependencias desactualizadas y vulnerabilidades
2. `/pr-pending` — PRs pendientes de review
3. `/spec-status` — specs en progreso / esperando review
4. `/perf-audit` si hay PRs con cambios de rendimiento
5. Revisar output de agentes si hay specs en ejecución
6. `/risk-predict` — identificar riesgos técnicos del sprint
7. `/mcp-server status` (semanal) — verificar estado de servidores MCP
8. `/integration-status --check` (semanal) — auditar integraciones y webhooks

### Ritual semanal
- **Lunes**: `/arch-health` — salud arquitectónica (fitness functions, drift, coupling)
- **Lunes**: `/webhook-config list` — revisar webhooks configurados
- **Miércoles**: `/team-skills-matrix --bus-factor` — detectar riesgos de dependencia en equipo
- **Viernes**: `/diagram-generate` — revisión de arquitectura

### Platform Integration (cuando aplica)
- `/platform-migrate --validate` — verificar integridad de la migración entre plataformas
- `/github-projects board` — si hay integración con GitHub Projects

### Métricas clave
- PR cycle time, specs completados/sprint, cobertura de tests, deuda técnica

### Alertas personalizadas
- PR abierto >3 días → sugerir review urgente
- Spec fallido → sugerir debug o rewrite
- Deuda técnica creciente → sugerir `/debt-prioritize`
- Dependencias desactualizadas con CVEs → alerta de seguridad

---

## QA Engineer — Modo `quality-gate`

### Rutina diaria
1. `/qa-dashboard` — panel de calidad con cobertura, tests flaky, bugs, escape rate
2. `/pr-pending` — revisar PRs con foco en testing
3. Verificar cobertura de tests en cambios recientes
4. `/security-alerts` si el proyecto tiene compliance activo

### Ritual semanal
- **Lunes**: Planificar tests para items del sprint + `/qa-regression-plan` si hay cambios
- **Miércoles**: Ejecutar tests de regresión y `/qa-bug-triage` para clasificación de defectos
- **Viernes**: `/testplan-generate` para próximas features + `/compliance-scan` pre-release

### Métricas clave
- Cobertura de tests, bugs encontrados/sprint, escape rate, test execution time

### Alertas personalizadas
- PR sin tests → bloquear y alertar
- Cobertura < umbral del proyecto → alerta
- Bug crítico reabierto → alerta de regresión

---

## Product Owner — Modo `reporting-focused`

### Rutina diaria
1. `/kpi-dashboard` — vista rápida de métricas del producto
2. Revisar backlog: prioridad vs. capacidad
3. Validar PBIs completados contra acceptance criteria

### Ritual semanal
- **Lunes**: `/sprint-autoplan` — propuesta de distribución de items
- **Lunes**: `/capacity-forecast` — previsión de capacidad a medio plazo
- **Lunes**: `/value-stream-map --bottlenecks` — análisis de flujo de valor
- **Miércoles**: `/feature-impact --roi` — impacto de features en ROI
- **Viernes**: `/stakeholder-report` — resumen para stakeholders

### Ritual antes de release
- `/release-readiness` — verificar que release está lista

### Métricas clave
- Velocity, feature completion rate, customer satisfaction proxy, time to market, value delivered

### Alertas personalizadas
- Feature planeada para release sin PBIs descompuestos → alerta
- Backlog > 100 items sin priorizar → sugerir limpieza
- Sprint sin discovery (JTBD/PRD) → sugerir refinamiento
- Release sin validación readiness → alerta

---

## Developer — Modo `code-focused`

### Rutina diaria
1. `/my-sprint` — mi progreso personal del sprint
2. `/my-focus` — item más prioritario con contexto
3. Si hay PRs pendientes → revisar feedback

### Ritual semanal
- **Viernes**: `/my-learning --quick` — oportunidades de mejora

### Métricas clave
- PRs completados, specs implementados, cycle time personal

### Alertas personalizadas
- PR con feedback sin responder >24h → recordatorio
- Spec asignado sin empezar >2 días → recordatorio
- Build roto → alerta inmediata

---

## CEO / CTO / Director — Modo `strategic-oversight`

### Rutina diaria
1. `/ceo-alerts` — alertas estratégicas que requieren decisión
2. `/portfolio-overview` — semáforo rápido de todos los proyectos
3. `/integration-status --check` (semanal) — verificar criticidad de integraciones en portfolio
4. Si hay alertas críticas → detallar con `/ceo-report {proyecto}`

### Ritual semanal
- **Lunes**: `/portfolio-overview --deps` — dependencias inter-proyecto
- **Lunes**: `/portfolio-deps --critical` — grafo de dependencias inter-proyecto y alertas de bloqueo
- **Lunes**: `/capacity-forecast` — previsión de capacidad a medio plazo
- **Lunes**: `/company-show --gaps` — validación del perfil de empresa y gaps
- **Lunes**: `/okr-track` — estado actual de OKRs y alertas de riesgo
- **Viernes**: `/ceo-report` — informe multi-proyecto para comité

### Ritual mensual
- `/kpi-dora` — tendencias de delivery
- `/org-metrics --trend 6` — métricas DORA agregadas a nivel organización, tendencias
- `/debt-analyze` — acumulación de deuda técnica
- `/report-capacity` — planificación de capacidad
- `/company-vertical detect` — detectar cambios en vertical y regulaciones
- `/okr-align` — validación de alineación proyecto→OKR→estrategia
- `/strategy-map` — revisión de mapa estratégico e iniciativas

### Métricas clave
- Delivery rate, team utilization, risk exposure, budget burn

### Alertas personalizadas
- Proyecto con sprint fallido (>30% items no completados) → alerta
- Equipo con burnout risk (>120% capacity >2 sprints) → alerta
- Deuda técnica en tendencia ascendente >3 sprints → alerta estratégica

---

## Regla de activación

Al inicio de sesión, si `workflow.md` tiene `primary_mode` configurado:

1. Savia lee `identity.md` (nombre + rol)
2. Savia lee `workflow.md` (primary_mode + daily_time)
3. Si la hora actual está dentro de ±30 min de `daily_time`:
   - Ejecutar rutina diaria del rol
4. Si es el día configurado para ritual semanal:
   - Sugerir ritual semanal tras la rutina diaria
5. Si es final de mes:
   - Sugerir ritual mensual (si el rol lo tiene)

Savia NUNCA ejecuta comandos automáticamente — sugiere la rutina y espera confirmación.

---

## Integración con context-map

El rol determina qué grupo del context-map se prioriza:

| Rol | Grupo primario | Grupo secundario |
|---|---|---|
| PM | Sprint & Daily | Reporting |
| Tech Lead | Quality & PRs | SDD & Agentes |
| QA | Quality & PRs | Governance |
| Product Owner | Reporting | PBI & Backlog |
| Developer | SDD & Agentes | Quality & PRs |
| CEO/CTO | Reporting | Team & Workload |
