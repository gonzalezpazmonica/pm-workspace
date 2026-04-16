# Proyecto Alpha — Contexto Específico

> Lee este fichero ANTES de cualquier operación sobre Proyecto Alpha.
> El contexto global está en `../../CLAUDE.md`.

---

## ⚙️ CONSTANTES DEL PROYECTO

```
# ── Identidad en Azure DevOps ─────────────────────────────────────────────────
PROJECT_AZDO_NAME         = "ProyectoAlpha"                  # ← nombre exacto en Azure DevOps
TEAM_NAME                 = "ProyectoAlpha Team"             # ← nombre exacto del equipo
ITERATION_PATH_ROOT       = "ProyectoAlpha\\Sprints"         # ← ruta raíz de iteraciones
BOARD_NAME                = "Stories"                        # ← nombre del board principal
AREA_PATH                 = "ProyectoAlpha"                  # ← área path (puede tener subnodos)

# ── Sprint Actual ──────────────────────────────────────────────────────────────
SPRINT_ACTUAL             = "Sprint 2026-04"                 # ← actualizar cada sprint
SPRINT_START              = "2026-03-02"                     # ← YYYY-MM-DD
SPRINT_END                = "2026-03-13"                     # ← YYYY-MM-DD
SPRINT_GOAL               = "Completar el módulo de autenticación SSO y el dashboard de usuario"

# ── Métricas históricas ────────────────────────────────────────────────────────
VELOCITY_MEDIA_SP         = 32                               # media últimos 5 sprints
VELOCITY_ULTIMA_SP        = 30                               # velocity sprint anterior
SP_RATIO_HORAS            = 16.0                             # horas/SP (recalcular cada 5 sprints)
CYCLE_TIME_MEDIA_DIAS     = 3.5                              # días (P50)
CYCLE_TIME_P75_DIAS       = 5.2                              # días

# ── Repositorio de código ──────────────────────────────────────────────────────
REPO_NAME                 = "proyecto-alpha"                 # nombre del repo en Azure DevOps
REPO_URL                  = "https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_git/proyecto-alpha"
LOCAL_SOURCE_PATH         = "./source"                       # código fuente clonado aquí
DEFAULT_BRANCH            = "develop"
MAIN_BRANCH               = "main"

# ── Stack tecnológico ──────────────────────────────────────────────────────────
BACKEND_FRAMEWORK         = ".NET 8 / ASP.NET Core Web API"
FRONTEND_FRAMEWORK        = "Angular 17"
DATABASE                  = "SQL Server 2022"
ORM                       = "Entity Framework Core 8"
AUTH                      = "Azure Active Directory / MSAL"
CI_CD                     = "Azure Pipelines"
TEST_FRAMEWORK            = "xUnit / NUnit"
COVERAGE_TOOL             = "Coverlet"
CODE_ANALYSIS             = "SonarQube"

# ── Entornos ───────────────────────────────────────────────────────────────────
ENV_DEV_URL               = "https://alpha-dev.empresa.com"
ENV_STAGING_URL           = "https://alpha-staging.empresa.com"
ENV_PROD_URL              = "https://alpha.empresa.com"

# ── Cliente ────────────────────────────────────────────────────────────────────
CLIENTE_NOMBRE            = "Cliente Alpha S.A."             # ← actualizar
CLIENTE_PO_EMAIL          = "po@cliente-alpha.com"           # ← actualizar
CLIENTE_CONTRATO          = "T&M / Precio fijo"              # ← tipo de contrato
PRESUPUESTO_HORAS         = 2000                             # horas totales contratadas
HORAS_CONSUMIDAS          = 850                              # actualizar mensualmente
```

---

## 📋 Descripción del Proyecto

**Qué es:** Sistema de gestión de [descripción del sistema — actualizar].

**Objetivo de negocio:** [objetivo principal del proyecto — actualizar].

**Alcance:** [resumen del alcance — actualizar].

**Fecha de inicio:** 2026-01-05
**Fecha fin estimada:** 2026-06-30
**Versión actual en producción:** v1.1.0

---

## 👥 Equipo

Ver composición completa en `equipo.md`.

| Rol | Persona | Email |
|-----|---------|-------|
| Project Manager | [Nombre] | pm@empresa.com |
| Product Owner | [Nombre cliente] | po@cliente.com |
| Scrum Master | [Nombre] | sm@empresa.com |
| Tech Lead | [Nombre] | techlead@empresa.com |
| Developer 1 | [Nombre] | dev1@empresa.com |
| Developer 2 | [Nombre] | dev2@empresa.com |
| QA Engineer | [Nombre] | qa@empresa.com |

---

## 🏃 Sprint Actual

**Sprint:** Sprint 2026-04 (02/03/2026 → 13/03/2026)
**Sprint Goal:** Completar el módulo de autenticación SSO y el dashboard de usuario

**Estado:** 🟢 En buen camino

Para ver el estado detallado ejecutar: `/sprint-status proyecto-alpha`

---

## 📁 Estructura del Proyecto

```
projects/proyecto-alpha/
├── CLAUDE.md               ← ESTE FICHERO
├── equipo.md               ← Composición y disponibilidad del equipo
├── reglas-negocio.md       ← Reglas de negocio específicas de Alpha
├── source/                 ← Código fuente (git clone aquí)
│   └── [repo clonado]
├── specs/                  ← Specs SDD del proyecto
│   ├── sdd-metrics.md
│   └── templates/
│       └── spec-template.md
└── sprints/                ← Historial de sprints
    ├── sprint-2026-01/
    │   ├── planning.md
    │   ├── review.md
    │   └── retro-actions.md
    ├── sprint-2026-02/
    ├── sprint-2026-03/
    └── sprint-2026-04/     ← Sprint actual
        └── planning.md
```

---

## 🔗 Links Rápidos

- Azure DevOps: `https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha`
- Board: `https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_boards/board/t/ProyectoAlpha%20Team/Stories`
- Sprints: `https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_sprints/taskboard/ProyectoAlpha%20Team/ProyectoAlpha/Sprints`
- Repo: `https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_git/proyecto-alpha`
- Pipeline CI: `https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_build`

---

## 🎯 Configuración de Descomposición y Asignación de PBIs

> Leída por la skill `pbi-decomposition` para personalizar el comportamiento de asignación en este proyecto.

```yaml
# Pesos del algoritmo de scoring (deben sumar 1.0)
assignment_weights:
  expertise:     0.40   # Priorizar quien mejor conoce el módulo
  availability:  0.30   # Priorizar quien tiene más horas libres
  balance:       0.20   # Distribuir carga equitativamente
  growth:        0.10   # Dar oportunidades de aprendizaje

# Límites de descomposición
task_max_hours:         8    # Una task no puede superar 8h
task_min_hours:         1    # No crear micro-tasks de menos de 1h
pbi_max_sp_sin_decomp:  13   # PBIs > 13 SP deben descomponerse

# Patrones arquitectónicos del proyecto (adaptan las categorías de tasks)
architecture_patterns:
  - "Clean Architecture"     # Domain / Application / Infrastructure / API separados
  - "CQRS con MediatR"       # Commands y Queries con IRequestHandler
  - "Repository Pattern"     # IRepository<T> por entidad
  - "FluentValidation"       # Validators en capa Application
  - "EF Core Migrations"     # Migraciones con EF Core

# Cobertura mínima de tests
test_coverage_min: 80   # % (de docs/reglas-negocio.md)

# Code review: quién es Tech Lead (reviewer prioritario para cambios arquitectónicos)
tech_lead_alias: "juan.garcia@empresa.com"
```

---

## 🤖 Configuración Spec-Driven Development (SDD)

> Leída por la skill `spec-driven-development` para determinar el `developer_type` de cada task.
> Sobreescribe la matrix global en `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`.

```yaml
sdd_config:
  # Modelo de agentes para este proyecto
  model_agent: "claude-opus-4-7"            # Para código de producción complejo
  model_mid:   "claude-sonnet-4-6"          # Para tareas medianas y balanceadas
  model_fast:  "claude-haiku-4-5-20251001"  # Para tests, DTOs, validators

  # Directorio de specs de este proyecto
  specs_dir: "projects/proyecto-alpha/specs"

  # Overrides de la matrix global (solo lo que difiere del default)
  layer_overrides:
    # Angular (Frontend) siempre humano — los agentes no tienen contexto suficiente de UI/UX
    - layer: "Frontend / Angular"
      force: "human"
      reason: "Los componentes Angular requieren decisiones de UX que no están en las Specs técnicas"

    # Domain Layer: solo Value Objects simples pueden ser de agente
    - layer: "Domain"
      task_type: "Domain Entity (nuevo agregado)"
      force: "human"
      reason: "Las decisiones de identidad de agregado y encapsulación son de arquitectura — siempre humano"

  # Tipos de task por defecto para este proyecto (basado en el stack)
  default_agent_tasks:
    - "Command Handler (CRUD)"         # Application layer → agent-single
    - "Query Handler"                  # Application layer → agent-single
    - "FluentValidation Validator"     # Application layer → agent-single
    - "AutoMapper Profile"             # Application layer → agent-single
    - "DTO / Request / Response"       # Cualquier capa → agent-single (haiku)
    - "Repository EF Core"             # Infrastructure → agent-single
    - "Entity Configuration EF Core"   # Infrastructure → agent-single
    - "Controller CRUD"                # API layer → agent-single
    - "Unit Tests Application"         # Tests → agent-single (haiku)

  default_human_tasks:
    - "Domain Entity (nuevo agregado)" # Domain → human
    - "Domain Service"                 # Domain → human
    - "Pipeline Behavior"              # Application → human
    - "Migration EF Core"              # Infrastructure → human (riesgo datos)
    - "External HTTP Client"           # Infrastructure → human
    - "Middleware"                     # API → human
    - "Authentication/Authorization"   # API → human
    - "Code Review (E1)"               # Siempre → human

  # Módulos con restricciones especiales
  module_overrides:
    - module: "Authentication"
      force: "human"
      reason: "Módulo de autenticación Azure AD — seguridad siempre revisión humana"
    - module: "Reporting"
      force: "human"
      reason: "Los informes Word/PDF tienen lógica de presentación específica del cliente"

  # Presupuesto de tokens por sprint
  token_budget_usd: 30          # $30/sprint máximo en tokens Claude
  max_parallel_agents: 5        # Máximo 5 agentes en paralelo
  require_tech_lead_approval: false  # No requiere aprobación extra (Tech Lead ya aprobó la Spec)
```

---

## ⚠️ Notas y Decisiones Importantes

> Añadir aquí decisiones técnicas o de negocio importantes que el agente debe conocer.

- **[Fecha]** — [Decisión o nota relevante]
- El cliente solicita informes en español, formato Word
- Los deploys a producción se hacen los miércoles antes de las 10:00
- El entorno de staging se reinicia cada domingo a las 03:00 (puede perder datos de test)
