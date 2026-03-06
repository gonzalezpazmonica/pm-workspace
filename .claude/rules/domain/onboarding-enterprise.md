---
name: onboarding-enterprise
description: "Enterprise onboarding at scale — 4-phase workflow, batch CSV import, per-role checklists, knowledge transfer"
auto_load: false
paths: [".claude/commands/onboard-enterprise*", ".claude/skills/enterprise-onboarding/*"]
---

# Regla: Onboarding Empresarial a Escala

> Basado en: ADKAR framework (Hiatt, 2006), modelos de integración de talento (Ostroff & Kozlowski, 2007)
> Complementa: @.claude/rules/domain/role-workflows.md, @.claude/rules/domain/team-structure.md

**Principio fundamental**: El onboarding no es un evento, es un proceso de 30 días que acelera el tiempo-a-productividad reduciendo fricción.

## Modelo de 4 fases

### Fase 0 — Pre-llegada (HR + IT setup)
- Email, MFA, Azure AD, GitHub access
- Onboarding pack preparado
- Buddy asignado

### Fase 1 — Día 1 (Instalación + intro)
Dev: clonar repos, IDE, debugging (2h)
QA: TestContainers, test frameworks (2h)
PM: Azure DevOps, Jira/Notion (1.5h)
Tech Lead: Architecture overview, decision-log (1h)

### Fase 2 — Semana 1 (Primeras tareas + mentoría)
- 2h/día pair programming con buddy
- Daily standups
- Primer PBI completado
- Primer PR reviewed + merged

### Fase 3 — Mes 1 (Autonomía)
- T+2: first commit
- T+5: first PR merged
- T+15: tarea sin buddy
- T+30: 1h/week mentoría
- Éxito: 80% velocidad esperada

## CSV de importación

```csv
name,email,role,team,projects,start_date
Alejandra García,agarcia@empresa.com,Developer,backend,api-v3;auth-service,2026-03-10
Carlos López,clopez@empresa.com,QA,quality,api-v3;auth-service,2026-03-10
María Sánchez,msanchez@empresa.com,PM,product,erp-migration,2026-03-12
```

Schema: name, email, role, team, projects (semicolon-separated), start_date (ISO 8601).

## Checklists por rol

### Developer

- [ ] Repos clonados (main branch + test branch)
- [ ] IDE configurado + debugging funciona
- [ ] Ejecutar primer test (`npm test` o `dotnet test`)
- [ ] Crear rama de feature con naming conventions
- [ ] Hacer primer commit + push
- [ ] Crear primer PR (draft OK)
- [ ] Code review feedback absorbido + rebase realizado
- [ ] Primer PR merged

**Duración Fase 1**: 2h | Fase 2: 1 semana | Autonomía: T+15

### QA

- [ ] Acceso a test environments (DEV, PRE)
- [ ] Test frameworks instalados (TestContainers, Selenium, etc.)
- [ ] Entender estructura de tests existentes
- [ ] Escribir primer test (unitario o integración)
- [ ] Ejecutar suite de tests completa sin errores
- [ ] Documentar casos de prueba para feature actual
- [ ] Ejecutar regression testing en cambio reciente

**Duración Fase 1**: 2h | Fase 2: 1 semana | Autonomía: T+10

### PM

- [ ] Azure DevOps workspace configurado
- [ ] Entender estructura de sprints, proyectos, areas
- [ ] Leer decision-log y últimas 3 retros
- [ ] Entender team-structure.md del equipo
- [ ] Asistir a 3 standups + entender flujo
- [ ] Editar primer PBI (titulo, AC, estimación)
- [ ] Aprobación de spec completada durante onboarding

**Duración Fase 1**: 1.5h | Fase 2: 2 semanas | Autonomía: T+21

### Tech Lead

- [ ] Architecture overview asimilado
- [ ] Decision log completamente leído
- [ ] Entender ADRs actuales
- [ ] Completar EIPD + tech architecture review si nueva feature
- [ ] Revisar primer PR de equipo (no necesariamente de onboarding)
- [ ] Definir tech spike si es necesario

**Duración Fase 1**: 1h | Fase 2: 1 semana | Autonomía: T+7

## Plantilla de Knowledge Transfer

Generar antes de T+0 para cada nuevo team member:

```markdown
# Knowledge Transfer — {nombre}

## Proyecto: {nombre-proyecto}

### Stack
- Backend: {lenguaje, framework}
- DB: {engine, schema overview}
- DevOps: {cloud, CI/CD}
- Testing: {frameworks, coverage target}

### Decision Log Highlights
- [{fecha}] {titulo} → {enlace decision-log.md}
- [{fecha}] {titulo}

### Primeras tareas asignadas
1. {tarea 1} (tiempo estimado: {h}h) — {buddy asignado}
2. {tarea 2} — {buddy}

### Referencias clave
- docs/architecture.md
- .claude/rules/domain/team-structure.md
- decision-log.md
```

## Métricas de éxito

| Métrica | Umbral | Acción si falla |
|---|---|---|
| Time-to-first-commit | < 2 días | Revisar impedimentos (acceso, onboarding pack) |
| Time-to-first-PR | < 5 días | Asignar segundo buddy si primer buddy no disponible |
| Completion-rate (Fase 2) | ≥ 90% tareas | Reassess workload; reducir carga si needed |
| Satisfaction survey (T+30) | ≥ 4/5 | One-on-one retro para mejorar proceso |
| Retention (T+90) | 100% | Indicador de healthy onboarding |

## Integración

| Comando | Uso |
|---|---|
| `/onboard-enterprise import` | Cargar CSV, crear perfiles, generar checklists |
| `/onboard-enterprise checklist {persona}` | Mostrar checklist personalizado |
| `/onboard-enterprise progress {persona}` | Trackear progreso en Fase 1/2/3 |
| `/onboard-enterprise knowledge-transfer` | Generar KT doc desde decision-log + specs |
| `/team-orchestrator assign {persona} {team}` | Integración: asignar a equipo tras onboarding |
