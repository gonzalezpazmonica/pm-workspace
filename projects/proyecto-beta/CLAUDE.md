# Proyecto Beta — Contexto Específico

> Lee este fichero ANTES de cualquier operación sobre Proyecto Beta.
> El contexto global está en `../../CLAUDE.md`.

---

## ⚙️ CONSTANTES DEL PROYECTO

```
# ── Identidad en Azure DevOps ─────────────────────────────────────────────────
PROJECT_AZDO_NAME         = "ProyectoBeta"
TEAM_NAME                 = "ProyectoBeta Team"
ITERATION_PATH_ROOT       = "ProyectoBeta\\Sprints"
BOARD_NAME                = "Stories"
AREA_PATH                 = "ProyectoBeta"

# ── Sprint Actual ──────────────────────────────────────────────────────────────
SPRINT_ACTUAL             = "Sprint 2026-04"
SPRINT_START              = "2026-03-02"
SPRINT_END                = "2026-03-13"
SPRINT_GOAL               = "Implementar el módulo de autenticación con Azure AD B2C y el alta de usuarios"

# ── Métricas históricas ────────────────────────────────────────────────────────
VELOCITY_MEDIA_SP         = 25
VELOCITY_ULTIMA_SP        = 23
SP_RATIO_HORAS            = 14.0
CYCLE_TIME_MEDIA_DIAS     = 4.0
CYCLE_TIME_P75_DIAS       = 6.0

# ── Repositorio de código ──────────────────────────────────────────────────────
REPO_NAME                 = "proyecto-beta"
REPO_URL                  = "https://dev.azure.com/MI-ORGANIZACION/ProyectoBeta/_git/proyecto-beta"
LOCAL_SOURCE_PATH         = "./source"
DEFAULT_BRANCH            = "develop"
MAIN_BRANCH               = "main"

# ── Stack tecnológico ──────────────────────────────────────────────────────────
BACKEND_FRAMEWORK         = ".NET 8 / ASP.NET Core Web API"
FRONTEND_FRAMEWORK        = "Blazor Server"
DATABASE                  = "Azure SQL"
ORM                       = "Entity Framework Core 8"
AUTH                      = "Azure Active Directory B2C"
CI_CD                     = "Azure Pipelines"
TEST_FRAMEWORK            = "xUnit"
COVERAGE_TOOL             = "Coverlet"

# ── Entornos ───────────────────────────────────────────────────────────────────
ENV_DEV_URL               = "https://beta-dev.empresa.com"
ENV_STAGING_URL           = "https://beta-staging.empresa.com"
ENV_PROD_URL              = "https://beta.empresa.com"

# ── Cliente ────────────────────────────────────────────────────────────────────
CLIENTE_NOMBRE            = "Cliente Beta Corp."
CLIENTE_PO_EMAIL          = "po@cliente-beta.com"
CLIENTE_CONTRATO          = "Precio fijo"
PRESUPUESTO_HORAS         = 1200
HORAS_CONSUMIDAS          = 320
```

---

## 📋 Descripción del Proyecto

**Qué es:** [Descripción del sistema — actualizar].

**Objetivo de negocio:** [Objetivo principal — actualizar].

**Alcance:** [Resumen del alcance — actualizar].

**Fecha de inicio:** 2026-02-02
**Fecha fin estimada:** 2026-07-31
**Versión actual en producción:** N/A (primer ciclo de desarrollo)

---

## 👥 Equipo

Ver composición completa en `equipo.md`.

| Rol | Persona | Email |
|-----|---------|-------|
| Project Manager | [Nombre] | pm@empresa.com |
| Product Owner | [Nombre cliente] | po@cliente-beta.com |
| Developer 1 | [Nombre] | dev@empresa.com |
| QA / Developer | [Nombre] | qa@empresa.com |

---

## 🏃 Sprint Actual

**Sprint:** Sprint 2026-04 (02/03/2026 → 13/03/2026)
**Sprint Goal:** Implementar el módulo de autenticación con Azure AD B2C y el alta de usuarios

**Estado:** 🟡 Inicio de sprint

Para ver el estado detallado ejecutar: `/sprint:status proyecto-beta`

---

## 📁 Estructura del Proyecto

```
projects/proyecto-beta/
├── CLAUDE.md               ← ESTE FICHERO
├── equipo.md               ← Composición del equipo
├── reglas-negocio.md       ← Reglas específicas de Beta
├── source/                 ← Código fuente (git clone aquí)
├── specs/                  ← Specs SDD del proyecto
│   ├── sdd-metrics.md
│   └── templates/
│       └── spec-template.md
└── sprints/
    └── sprint-2026-04/     ← Sprint actual
```

---

## 🎯 Configuración de Descomposición y Asignación de PBIs

> Leída por la skill `pbi-decomposition`. Ajustada para equipo pequeño (2 personas) y contrato precio fijo.

```yaml
# Pesos del algoritmo de scoring
# Equipo reducido: priorizar expertise y disponibilidad sobre crecimiento
# En precio fijo el riesgo de asignar a alguien sin experiencia es mayor
assignment_weights:
  expertise:     0.50   # Más peso a quien conoce el módulo (presupuesto ajustado)
  availability:  0.35   # Disponibilidad crítica con solo 2 personas
  balance:       0.15   # Equilibrio menos prioritario (equipo pequeño, natural)
  growth:        0.00   # Sin cross-training en sprints normales (riesgo en precio fijo)

# Para sprints holgados (si el buffer lo permite):
# expertise: 0.35, availability: 0.30, balance: 0.15, growth: 0.20

# Límites de descomposición
task_max_hours:         8
task_min_hours:         1
pbi_max_sp_sin_decomp:  8    # Más estricto que Alpha: equipo pequeño, menos margen

# Patrones arquitectónicos del proyecto
architecture_patterns:
  - "N-Layer simple"         # Sin Clean Architecture completa (equipo pequeño)
  - "Blazor Server"          # Componentes Blazor + code-behind
  - "EF Core Migrations"
  - "Azure SQL"

# Cobertura mínima de tests
test_coverage_min: 80   # %

# Code review: con equipo de 2, ambos se revisan mutuamente
# La skill NO asignará code review a quien implementó la task
tech_lead_alias: "laura.martinez@empresa.com"   # desarrolladora más senior

# Restricción especial por precio fijo:
# Si la estimación total de tasks excede el presupuesto restante → alertar antes de crear
budget_alert: true
```

---

## 🤖 Configuración Spec-Driven Development (SDD)

> Leída por la skill `spec-driven-development`.
> En Beta (precio fijo, equipo de 2), la agentización es prioritaria para proteger márgenes.

```yaml
sdd_config:
  # Modelos
  model_agent: "claude-opus-4-5-20251101"
  model_fast: "claude-haiku-4-5-20251001"

  # Directorio de specs
  specs_dir: "projects/proyecto-beta/specs"

  # Política de agentización: más agresiva que Alpha por precio fijo
  agentization_target: 0.70   # Objetivo: 70% de tasks técnicas por agente

  # Overrides (más restrictivos que Alpha en algunas áreas)
  layer_overrides:
    # Azure AD B2C: siempre humano en Beta (más complejo que Azure AD standard de Alpha)
    - layer: "Authentication / Azure B2C"
      force: "human"
      reason: "Azure AD B2C tiene configuración específica del tenant; Laura es la experta"

    # Blazor Server: agente solo si hay componentes de referencia
    - layer: "Blazor Components"
      task_type: "Nuevo componente sin referencia"
      force: "human"
      reason: "Sin componente de referencia en el código, el agente genera estructuras inconsistentes"
    - layer: "Blazor Components"
      task_type: "Componente basado en patrón existente"
      default: "agent:single"
      reason: "Si hay componente similar, el agente puede replicar el patrón"

    # Migraciones: siempre humano (precio fijo → riesgo de datos crítico)
    - layer: "Infrastructure / Migrations"
      force: "human"
      reason: "Precio fijo: un error de migración puede costar días de rollback"

  # En Beta (N-Layer simple, no Clean Architecture completa), adaptar los tipos de task
  default_agent_tasks:
    - "Service Method (CRUD)"          # Application/Services → agent:single
    - "Repository Method EF Core"      # Data layer → agent:single
    - "DTO / ViewModel"                # Cualquier capa → agent:single (haiku)
    - "Unit Tests Services"            # Tests → agent:single (haiku)
    - "Blazor Code-Behind (CRUD)"      # Presentación → agent:single si hay referencia

  default_human_tasks:
    - "Business Logic compleja"        # Siempre humano
    - "Authentication / Azure B2C"     # Siempre humano (seguridad)
    - "EF Core Migration"              # Siempre humano (precio fijo)
    - "Code Review (E1)"               # Siempre humano
    - "Nuevo patrón sin referencia"    # Primera vez → humano

  # Presupuesto de tokens (más ajustado que Alpha por precio fijo)
  token_budget_usd: 20          # $20/sprint máximo
  max_parallel_agents: 3        # Máximo 3 agentes en paralelo (equipo pequeño de supervisión)
  require_tech_lead_approval: true   # Laura debe aprobar antes de lanzar agent:team (riesgo precio fijo)
  cost_alert_per_spec_usd: 2.00     # Alertar si una spec supera $2 en tokens
```

---

## ⚠️ Notas Importantes

- Proyecto en precio fijo — cualquier cambio de alcance requiere Change Request formal
- El presupuesto es ajustado: monitorizar semanalmente las horas consumidas
- El cliente tiene poca experiencia con Scrum — dedicar tiempo a explicar las ceremonias
