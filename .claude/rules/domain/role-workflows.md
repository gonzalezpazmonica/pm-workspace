---
name: role-workflows
description: Rutinas diarias y flujos de trabajo específicos por rol del usuario
auto_load: false
paths: []
---

# Workflows por Rol — Rutinas Adaptativas de Savia

El campo `role` de `identity.md` y `primary_mode` de `workflow.md` determinan qué rutina sugiere Savia al inicio de sesión.

---

## PM / Scrum Master — Modo `daily-first`

**Diaria**: `/sprint-status` → `/team-workload` → `/board-flow` → `/nl-query` (opt) → si bloqueantes: sugerir escalación. Semanal: `/integration-status --check`.

**Semanal**: Lun: `/sprint-plan` o `/sprint-autoplan`, `/risk-predict`. Mié: `/pbi-plan-sprint`, `/backlog-patterns`, `/backlog-groom`, `/backlog-prioritize`. Vie: `/report-hours` + `/report-executive` + `/sprint-review`.

**Post-Release**: `/outcome-track`, `/stakeholder-align`.

**Wellbeing (SPACE)**: `/burnout-radar --team|--individual {name}`, `/workload-balance --show|--suggest`, `/sustainable-pace --calculate|--forecast`, `/team-sentiment --collect|--trends`.

**Playbooks**: `/playbook-create`, `/playbook-reflect`, `/playbook-evolve`, `/playbook-library --search`.

**Alertas**: Items sin mover >2d → revisión. Capacidad <70% → infrautilización. >110% → sobrecarga. Burndown desviado >20% → alerta temprana.

**Métricas**: Velocity trend, burndown, WIP, lead time, bloqueantes activos.

---

## Tech Lead — Modo `code-focused`

**Diaria**: `/tech-radar --outdated` → `/pr-pending` → `/spec-status` → `/perf-audit` si hay PRs de rendimiento → revisar output de agentes → `/risk-predict`. Semanal: `/mcp-server status`, `/integration-status --check`.

**Semanal**: Lun: `/arch-health`, `/webhook-config list`. Mié: `/team-skills-matrix --bus-factor`. Vie: `/diagram-generate`.

**Alertas**: PR abierto >3d → review urgente. Spec fallido → debug/rewrite. Deuda técnica creciente → `/debt-prioritize`. CVEs → alerta seguridad.

**Métricas**: PR cycle time, specs/sprint, cobertura tests, deuda técnica.

---

## QA Engineer — Modo `quality-gate`

**Diaria**: `/qa-dashboard` → `/pr-pending` (foco testing) → verificar cobertura → `/security-alerts` si compliance activo.

**Semanal**: Lun: planificar tests + `/qa-regression-plan`. Mié: regresión + `/qa-bug-triage`. Vie: `/testplan-generate` + `/compliance-scan`.

**A11y**: `/a11y-audit`, `/a11y-fix`, `/a11y-report`, `/a11y-monitor`.

**Alertas**: PR sin tests → bloquear. Cobertura < umbral → alerta. Bug crítico reabierto → regresión.

**Métricas**: Cobertura tests, bugs/sprint, escape rate, test execution time.

---

## Product Owner — Modo `reporting-focused`

**Diaria**: `/kpi-dashboard` → revisar backlog prioridad vs capacidad → validar PBIs contra acceptance criteria.

**Semanal**: Lun: `/sprint-autoplan`, `/capacity-forecast`, `/value-stream-map --bottlenecks`. Mié: `/feature-impact --roi`. Vie: `/stakeholder-report`.

**Pre-Release**: `/release-readiness`.

**Alertas**: Feature sin PBIs descompuestos → alerta. Backlog >100 items sin priorizar → limpieza. Sprint sin discovery → refinamiento. Release sin readiness → alerta.

**Métricas**: Velocity, feature completion rate, satisfaction proxy, time to market.

---

## Developer — Modo `code-focused`

**Diaria**: `/my-sprint` → `/my-focus` → revisar feedback PRs.

**Semanal**: Vie: `/my-learning --quick`.

**Alertas**: PR con feedback sin responder >24h → recordatorio. Spec sin empezar >2d → recordatorio. Build roto → alerta inmediata.

**Métricas**: PRs completados, specs implementados, cycle time personal.

---

## CEO / CTO / Director — Modo `strategic-oversight`

**Diaria**: `/ceo-alerts` → `/portfolio-overview` → si alertas críticas: `/ceo-report {proyecto}`. Semanal: `/integration-status --check`.

**Semanal**: Lun: `/portfolio-overview --deps`, `/portfolio-deps --critical`, `/capacity-forecast`, `/company-show --gaps`, `/okr-track`. Vie: `/ceo-report`.

**Mensual**: `/kpi-dora`, `/org-metrics --trend 6`, `/debt-analyze`, `/report-capacity`, `/company-vertical detect`, `/okr-align`, `/strategy-map`, `/governance-audit`, `/governance-report`, `/governance-certify`, `/cache-strategy`, `/cache-analytics`, `/cache-warm`. Verticales si aplican: `/vertical-healthcare`, `/vertical-finance`, `/vertical-legal`, `/vertical-education`.

**Alertas**: Sprint fallido (>30% incompleto) → alerta. Burnout risk (>120% capacity >2 sprints) → alerta. Deuda técnica ascendente >3 sprints → alerta estratégica.

**Métricas**: Delivery rate, team utilization, risk exposure, budget burn.

---

## Bloques compartidos (todos los roles)

**Context Engineering**: `/context-budget --show|--optimize`, `/context-profile --compare|--analyze`, `/context-compress --preview`, `/context-defer --status`.

**Memory**: `/memory-compress --preview`, `/memory-importance --scan`, `/memory-graph --build`.

**Platform**: `/cache-strategy --show`, `/cache-invalidate --selective`, `/platform-migrate --plan|--validate`, `/jira-connect setup`, `/github-projects connect|board`, `/company-setup`, `/company-edit {section}`.

---

## Regla de activación

Al inicio de sesión, si `workflow.md` tiene `primary_mode`:
1. Leer `identity.md` (nombre + rol) y `workflow.md` (primary_mode + daily_time)
2. Si hora actual ±30 min de `daily_time` → ejecutar rutina diaria del rol
3. Si día de ritual semanal → sugerir tras rutina diaria
4. Si final de mes → sugerir ritual mensual (si el rol lo tiene)

Savia NUNCA ejecuta automáticamente — sugiere y espera confirmación.

## Integración con context-map

| Rol | Grupo primario | Grupo secundario |
|---|---|---|
| PM | Sprint & Daily | Reporting |
| Tech Lead | Quality & PRs | SDD & Agentes |
| QA | Quality & PRs | Governance |
| Product Owner | Reporting | PBI & Backlog |
| Developer | SDD & Agentes | Quality & PRs |
| CEO/CTO | Reporting | Team & Workload |
