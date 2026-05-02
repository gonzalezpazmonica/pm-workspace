# Spec: PM Backend Integration — Azure DevOps / Jira Bridge

**Task ID:**        SPEC-SE-092-PM-BACKEND
**PBI padre:**      Era 196 — Production PM Operations
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (gap analysis)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~90 min
**Estado:**         Pendiente
**Prioridad:**      CRITICA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      25

---

## 1. Problema

Savia tiene 535+ comandos, identidad de PM, reglas de scrum, y un roadmap de 20+ specs.
Pero no puede tocar un backlog real. Los comandos `/sprint-status`, `/capacity-plan`,
`/velocity-trend`, `/daily-standup` son shells vacios — no hay backend que los alimente.

`init-pm.sh` declara Azure DevOps como "opcional bajo demanda" pero no hay NINGUN script
que:
- Autentique contra Azure DevOps (PAT → WIQL queries)
- Mapee work items (PBIs, Tasks, Bugs) al sistema de specs de Savia
- Sincronice estados entre Azure DevOps y el roadmap de Savia
- Genere informes reales en `output/` con datos del backlog

Sin esto, Savia es una PM de mentira. Sabe hablar de scrum pero no puede ejecutarlo.

## 2. Requisitos

- **REQ-01** `scripts/azure-devops-bridge.sh`: wrapper autenticado contra Azure DevOps.
  Lee `AZURE_DEVOPS_ORG_URL` y `$AZURE_DEVOPS_PAT_FILE` del entorno.
  - `ado query "<WIQL>"` → JSON con work items
  - `ado workitem <id>` → detalle completo
  - `ado update <id> --field value` → actualizar campo
  - `ado sprints` → sprints del proyecto actual
  - `ado capacity` → capacidad por team member

- **REQ-02** Conectar comandos existentes a datos reales:
  - `/sprint-status` → `ado query "SELECT * FROM WorkItems WHERE [System.IterationPath] = @currentIteration"`
  - `/capacity-plan` → `ado capacity` + calculo horas/desarrollador
  - `/velocity-trend` → historico de sprints cerrados + puntos entregados
  - `/daily-standup` → work items con cambios en las ultimas 24h

- **REQ-03** Formato de salida unificado: todos los comandos PM producen informe
  en `output/YYYYMMDD-tipo-proyecto.ext` (Rule #5).

- **REQ-04** Sin credenciales → graceful degradation. Si `AZURE_DEVOPS_ORG_URL`
  contiene placeholder ("MI-ORGANIZACIÓN"), los comandos informan "Azure DevOps
  not configured" en lugar de fallar.

- **REQ-05** Mapeo spec ↔ work item: Savia puede asociar un SPEC-XXX a un PBI
  de Azure DevOps y sincronizar estados (Approved → Active, Implemented → Closed).

---

## 3. Ficheros

| Fichero | Accion |
|---------|--------|
| `scripts/azure-devops-bridge.sh` | CREAR |
| `docs/rules/domain/azure-devops-integration.md` | CREAR |

---

## 4. Criterios de Aceptacion

- **AC-01** `ado query` retorna work items reales (no mocks).
- **AC-02** `/sprint-status` produce `output/YYYYMMDD-sprintstatus-{project}.md` con datos reales.
- **AC-03** Sin PAT configurado, comandos no fallan — informan "not configured".
- **AC-04** No hardcodea PAT en ningun archivo (Rule #1).
