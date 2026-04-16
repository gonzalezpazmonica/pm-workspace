# Sala Reservas — Proyecto de Test del PM-Workspace

> ⚠️ PROYECTO DE TEST — Creado para validar todas las funcionalidades del PM-Workspace.
> Los datos de Azure DevOps son ficticios. Consulta `test-data/` para los mocks.

---

## ⚙️ CONSTANTES DEL PROYECTO

```
# ── Identidad en Azure DevOps ─────────────────────────────────────────────────
PROJECT_AZDO_NAME         = "SalaReservas"                  # ← nombre exacto en Azure DevOps
TEAM_NAME                 = "SalaReservas Team"             # ← nombre exacto del equipo
ITERATION_PATH_ROOT       = "SalaReservas\\Sprints"         # ← ruta raíz de iteraciones
BOARD_NAME                = "Stories"
AREA_PATH                 = "SalaReservas"

# ── Sprint Actual ──────────────────────────────────────────────────────────────
SPRINT_ACTUAL             = "Sprint 2026-04"
SPRINT_START              = "2026-03-02"
SPRINT_END                = "2026-03-13"
SPRINT_GOAL               = "CRUD completo de Salas y Reservas con API REST funcional"

# ── Métricas históricas (sprints anteriores ficticios) ─────────────────────────
VELOCITY_MEDIA_SP         = 22                              # media últimos 3 sprints
VELOCITY_ULTIMA_SP        = 24
SP_RATIO_HORAS            = 8.0                             # horas/SP calibrado equipo
CYCLE_TIME_MEDIA_DIAS     = 2.8
CYCLE_TIME_P75_DIAS       = 4.0

# ── Repositorio de código ──────────────────────────────────────────────────────
REPO_NAME                 = "sala-reservas"
REPO_URL                  = "https://dev.azure.com/MI-ORGANIZACION/SalaReservas/_git/sala-reservas"
LOCAL_SOURCE_PATH         = "./source"
DEFAULT_BRANCH            = "develop"
MAIN_BRANCH               = "main"

# ── Stack tecnológico ──────────────────────────────────────────────────────────
BACKEND_FRAMEWORK         = ".NET 8 / ASP.NET Core Web API"
DATABASE                  = "SQL Server 2022 (LocalDB en dev)"
ORM                       = "Entity Framework Core 8"
AUTH                      = "Ninguna — nombre de empleado a mano"
CI_CD                     = "Azure Pipelines (YAML)"
TEST_FRAMEWORK            = "xUnit"
ARCH_PATTERN              = "Clean Architecture (Domain/Application/Infrastructure/API)"
CQRS                      = "MediatR 12"
VALIDATION                = "FluentValidation 11"
MAPPING                   = "AutoMapper 13"
COVERAGE_TOOL             = "Coverlet"

# ── Entornos ───────────────────────────────────────────────────────────────────
ENV_DEV_URL               = "https://localhost:5001"
ENV_STAGING_URL           = "https://sala-reservas-staging.empresa.com"
ENV_PROD_URL              = "https://sala-reservas.empresa.com"

# ── Cliente ────────────────────────────────────────────────────────────────────
CLIENTE_NOMBRE            = "Empresa Interna S.A."
CLIENTE_CONTRATO          = "T&M"
PRESUPUESTO_HORAS         = 500
HORAS_CONSUMIDAS          = 0                               # inicio del proyecto
```

---

## 📋 Descripción del Proyecto

**Qué es:** Aplicación web sencilla para reservar salas de reuniones. Sin sistema de login: el nombre del empleado se introduce manualmente al hacer una reserva.

**Entidades principales:**
- `Sala` — nombre, capacidad (personas), ubicación (planta/ala), disponible (bool)
- `Reserva` — sala, fecha, hora inicio, hora fin, nombre empleado, motivo

**Funcionalidades:**
- CRUD completo de Salas (listar, crear, editar, eliminar)
- CRUD completo de Reservas (listar por sala/fecha, reservar, cancelar)
- Validación de conflictos: una sala no puede tener dos reservas solapadas

**Objetivo de negocio:** Eliminar los conflictos de reservas que ocurren actualmente por email.

**Fecha de inicio:** 2026-03-02
**Fecha fin estimada:** 2026-04-10
**Versión actual en producción:** v0.0 (proyecto nuevo)

---

## 👥 Equipo

Ver composición completa en `equipo.md`.

| Rol | Persona | Email |
|-----|---------|-------|
| PM / Scrum Master | Sofía Reyes | sofia.reyes@empresa.com |
| Tech Lead / Senior Dev | Carlos Mendoza | carlos.mendoza@empresa.com |
| Developer Full Stack | Laura Sánchez | laura.sanchez@empresa.com |
| Developer Backend | Diego Torres | diego.torres@empresa.com |
| QA Engineer | Ana Morales | ana.morales@empresa.com |
| Developer Virtual | Claude Agent Team | dev:agent (tag AzDO) |

---

## 🏃 Sprint Actual

**Sprint:** Sprint 2026-04 (02/03/2026 → 13/03/2026)
**Sprint Goal:** CRUD completo de Salas y Reservas con API REST funcional

**PBIs comprometidos:**
- AB#001 — Gestión de Salas (CRUD) — 3 SP
- AB#002 — Gestión de Reservas (CRUD) — 5 SP
- AB#003 — Validación de conflictos de reservas — 3 SP

**Capacity del sprint:** 198h (ver equipo.md)

Para ver el estado: `/sprint-status sala-reservas`

---

## 📁 Estructura del Proyecto

```
projects/sala-reservas/
├── CLAUDE.md                    ← ESTE FICHERO
├── equipo.md                    ← Composición del equipo
├── reglas-negocio.md            ← Reglas de negocio de la app
├── source/                      ← Código fuente (git clone aquí)
│   └── [estructura .NET Clean Architecture]
├── sprints/
│   └── sprint-2026-04/
│       └── planning.md          ← Planning detallado del sprint
├── specs/
│   ├── sdd-metrics.md           ← Métricas SDD
│   └── sprint-2026-04/          ← Specs del sprint actual
│       ├── AB101-B3-create-sala-handler.spec.md
│       └── AB102-D1-unit-tests-salas.spec.md
└── test-data/                   ← Datos mock para tests sin Azure DevOps real
    ├── mock-sprint.json
    ├── mock-workitems.json
    └── mock-capacities.json
```

---

## 🔗 Links Rápidos (ficticios — solo para test)

- Azure DevOps: `https://dev.azure.com/MI-ORGANIZACION/SalaReservas`
- Board: `https://dev.azure.com/MI-ORGANIZACION/SalaReservas/_boards`
- Repo: `https://dev.azure.com/MI-ORGANIZACION/SalaReservas/_git/sala-reservas`

---

## 🎯 Configuración de Descomposición y Asignación de PBIs

```yaml
# Pesos del algoritmo de scoring
assignment_weights:
  expertise:     0.40
  availability:  0.30
  balance:       0.20
  growth:        0.10

task_max_hours:         8
task_min_hours:         1
pbi_max_sp_sin_decomp:  8

architecture_patterns:
  - "Clean Architecture"
  - "CQRS con MediatR"
  - "Repository Pattern"
  - "FluentValidation"
  - "EF Core Migrations"

test_coverage_min: 80
tech_lead_alias: "carlos.mendoza@empresa.com"
```

---

## 🤖 Configuración Spec-Driven Development (SDD)

```yaml
sdd_config:
  model_agent: "claude-opus-4-7"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  specs_dir: "projects/sala-reservas/specs"
  agentization_target: 0.65    # 65% de tasks técnicas por agente

  # Para este proyecto de test, los agentes se usan para todo excepto Domain
  layer_overrides:
    - layer: "Domain"
      task_type: "Entidad raíz o Domain Service"
      force: "human"
      reason: "Domain Layer siempre humano"
    - layer: "Infrastructure / Migrations"
      force: "human"
      reason: "Migraciones revisadas por Carlos TL"

  default_agent_tasks:
    - "Command Handler (CRUD)"
    - "Query Handler"
    - "FluentValidation Validator"
    - "AutoMapper Profile"
    - "DTO / Request / Response"
    - "Repository EF Core"
    - "Entity Configuration EF Core"
    - "Controller CRUD"
    - "Unit Tests Application"

  default_human_tasks:
    - "Entidad de Dominio"
    - "Domain Service (ValidarConflicto)"
    - "EF Core Migration"
    - "Integration Tests"
    - "Code Review (E1)"

  token_budget_usd: 15           # Presupuesto reducido (proyecto pequeño)
  max_parallel_agents: 3
  require_tech_lead_approval: false
```

---

## ⚠️ Notas del Proyecto de Test

- Este proyecto existe para validar el PM-Workspace sin necesidad de Azure DevOps real
- Los datos de `test-data/` simulan respuestas reales de la API de Azure DevOps
- Las specs en `specs/sprint-2026-04/` son specs completas y ejecutables para testear SDD
- El script `scripts/test-workspace.sh --mock` usa estos datos y no necesita conectividad
