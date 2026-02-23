<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

🌐 [English version](README.en.md) · **Español**

# PM Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> Sistema de gestión de proyectos .NET con Scrum, impulsado por Claude Code como asistente de PM/Scrum Master con capacidad de delegar implementación técnica a agentes de IA.

---

## ¿Qué es esto?

Este workspace convierte a Claude Code en un **Project Manager / Scrum Master automatizado** para proyectos .NET en Azure DevOps. Su característica más avanzada es el **Spec-Driven Development (SDD)**: un proceso en el que las tareas técnicas se documentan como contratos ejecutables, y Claude puede implementarlas como agente de código.

**Gestión de sprints:** seguimiento de burndown, capacity del equipo, estado del board, KPIs, reportes automáticos de retrospectiva y review en Excel/PowerPoint.

**Descomposición de PBIs:** Claude analiza el backlog, descompone cada PBI en tasks con estimación en horas, detecta el balance de carga del equipo y propone asignaciones con un algoritmo de scoring (expertise × disponibilidad × balance × crecimiento).

**Spec-Driven Development:** las tasks se convierten en especificaciones ejecutables. Un "developer" puede ser un humano o un agente Claude. Claude puede implementar automáticamente Command Handlers, repositorios EF Core, unit tests y más, siguiendo la spec como contrato.

---

> **💬 EJEMPLO — Primeros cinco minutos con el workspace**
>
> _Escenario: Es lunes por la mañana. Abres Claude Code por primera vez desde la raíz de `pm-workspace/`._
>
> **Tú escribes:**
> ```
> ¿Qué proyectos tengo configurados y qué puedo hacer?
> ```
>
> **Claude responde:**
> ```
> Tengo configurados 2 proyectos activos:
>   • ProyectoAlpha  — equipo de 6 personas, sprint 2026-04 activo
>   • ProyectoBeta   — equipo de 4 personas, precio fijo, sprint 2026-04 activo
>
> Puedo ayudarte con:
>   Sprint      → /sprint:status, /sprint:plan, /sprint:review, /sprint:retro
>   Informes    → /report:hours, /report:executive, /report:capacity
>   Backlog     → /pbi:decompose, /pbi:plan-sprint, /pbi:assign
>   SDD (agentes) → /spec:generate, /agent:run, /spec:status
>
> ¿Por dónde quieres empezar? Si es lunes, te recomiendo /sprint:status
> para ver el estado actual del sprint antes de la Daily.
> ```
>
> **Tú escribes:**
> ```
> /sprint:status --project ProyectoAlpha
> ```
>
> **Claude responde:**
> ```
> ══════════════════════════════════════════
>   Sprint 2026-04 · ProyectoAlpha · Día 6/10
> ══════════════════════════════════════════
>
>   Burndown  ████████░░░░░░░░  40% completado  ⚠️ por debajo del plan
>   Objetivo sprint: Módulo de Pacientes v2
>
>   Items activos (In Progress): 4
>     AB#1021  Crear endpoint POST /patients  → Laura S.   [3/5h]
>     AB#1022  Unit tests PatientService      → 🤖 agente  [En ejecución]
>     AB#1023  Migración tabla Alergias       → Diego T.   [0/4h] ⚠️ sin avance
>     AB#1024  Swagger annotations            → 🤖 agente  [Terminado, en Review]
>
>   🔴 Alertas:
>     • AB#1023 lleva 2 días sin movimiento — ¿está bloqueado?
>     • Burndown al 40% en día 6 → riesgo de no completar el sprint goal
>     • WIP actual: 4 items (límite configurado: 5) ✅
>
>   Capacidad restante: 68h humanas + ~12h de agente disponibles
> ```

---

## Estructura del Workspace

```
pm-workspace/
├── CLAUDE.md                    ← Punto de entrada de Claude Code (constantes globales)
├── SETUP.md                     ← Guía de configuración paso a paso
├── README.md                    ← Este fichero
├── .gitignore
│
├── .claude/
│   ├── settings.local.json      ← Permisos de Claude Code
│   ├── .env                     ← Variables de entorno (NO commitear)
│   ├── mcp.json                 ← Configuración MCP opcional
│   │
│   ├── commands/                ← 19 slash commands
│   │   ├── sprint-status.md
│   │   ├── sprint-plan.md
│   │   ├── sprint-review.md
│   │   ├── sprint-retro.md
│   │   ├── report-hours.md
│   │   ├── report-executive.md
│   │   ├── report-capacity.md
│   │   ├── team-workload.md
│   │   ├── board-flow.md
│   │   ├── kpi-dashboard.md
│   │   ├── pbi-decompose.md
│   │   ├── pbi-decompose-batch.md
│   │   ├── pbi-assign.md
│   │   ├── pbi-plan-sprint.md
│   │   ├── spec-generate.md      ← SDD
│   │   ├── spec-implement.md     ← SDD
│   │   ├── spec-review.md        ← SDD
│   │   ├── spec-status.md        ← SDD
│   │   └── agent-run.md          ← SDD
│   │
│   └── skills/                  ← 6 skills personalizadas
│       ├── azure-devops-queries/
│       ├── sprint-management/
│       ├── capacity-planning/
│       ├── time-tracking-report/
│       ├── executive-reporting/
│       ├── pbi-decomposition/
│       │   └── references/
│       │       └── assignment-scoring.md
│       └── spec-driven-development/
│           ├── SKILL.md
│           └── references/
│               ├── spec-template.md         ← Plantilla de specs
│               ├── layer-assignment-matrix.md ← Qué va a agente vs humano
│               └── agent-team-patterns.md   ← Patrones de equipos de agentes
│
├── docs/
│   ├── reglas-scrum.md
│   ├── politica-estimacion.md
│   ├── kpis-equipo.md
│   ├── plantillas-informes.md
│   └── flujo-trabajo.md         ← Incluye sección 8: workflow SDD
│
├── projects/
│   ├── proyecto-alpha/
│   │   ├── CLAUDE.md            ← Constantes + config SDD del proyecto
│   │   ├── equipo.md            ← Equipo humano + agentes Claude como developers
│   │   ├── reglas-negocio.md
│   │   ├── source/              ← git clone del repo aquí
│   │   ├── sprints/
│   │   └── specs/               ← Specs SDD
│   │       ├── sdd-metrics.md
│   │       ├── templates/
│   │       └── sprint-YYYY-MM/
│   ├── proyecto-beta/
│   │   └── (misma estructura)
│   └── sala-reservas/           ← ⚗️ PROYECTO DE TEST (ver sección abajo)
│       ├── CLAUDE.md
│       ├── equipo.md            ← 4 devs + PM + agentes Claude
│       ├── reglas-negocio.md    ← 16 reglas de negocio documentadas
│       ├── sprints/
│       │   └── sprint-2026-04/
│       │       └── planning.md
│       ├── specs/
│       │   ├── sdd-metrics.md
│       │   └── sprint-2026-04/
│       │       ├── AB101-B3-create-sala-handler.spec.md
│       │       └── AB102-D1-unit-tests-salas.spec.md
│       └── test-data/           ← Mock JSON de Azure DevOps API
│           ├── mock-workitems.json
│           ├── mock-sprint.json
│           └── mock-capacities.json
│
├── scripts/
│   ├── azdevops-queries.sh      ← Bash: queries a Azure DevOps REST API
│   ├── capacity-calculator.py  ← Python: cálculo de capacity real
│   └── report-generator.js     ← Node.js: generación de informes Excel/PPT
│
└── output/
    ├── sprints/
    ├── reports/
    ├── executive/
    └── agent-runs/              ← Logs de ejecuciones de agentes Claude
```

---

## Configuración Inicial

### Requisitos previos

- [Claude Code](https://docs.claude.ai/claude-code) instalado y autenticado (`claude --version`)
- [Azure CLI](https://docs.microsoft.com/es-es/cli/azure/install-azure-cli) con extensión `az devops`
- Node.js ≥ 18 (para scripts de reporting)
- Python ≥ 3.10 (para capacity calculator)
- `jq` instalado (`apt install jq` / `brew install jq`)

### Paso 1 — PAT de Azure DevOps

```bash
mkdir -p $HOME/.azure
echo -n "TU_PAT_AQUI" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat
```

El PAT necesita estos scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).

```bash
# Verificar conectividad
az devops configure --defaults organization=https://dev.azure.com/MI-ORGANIZACION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

### Paso 2 — Editar las constantes

Abre `CLAUDE.md` y actualiza la sección `⚙️ CONSTANTES DE CONFIGURACIÓN`. Repite en `projects/proyecto-alpha/CLAUDE.md` y `projects/proyecto-beta/CLAUDE.md` para los valores específicos de cada proyecto.

### Paso 3 — Instalar dependencias de scripts

```bash
cd scripts/
npm install
cd ..
```

### Paso 4 — Clonar el código fuente

```bash
# Para que SDD funcione, el código del proyecto debe estar disponible localmente
cd projects/proyecto-alpha/source
git clone https://dev.azure.com/TU-ORG/ProyectoAlpha/_git/proyecto-alpha .
cd ../../..
```

### Paso 5 — Verificar la conexión

```bash
chmod +x scripts/azdevops-queries.sh
./scripts/azdevops-queries.sh sprint ProyectoAlpha "ProyectoAlpha Team"
```

### Paso 6 — Abrir con Claude Code

```bash
# Desde la raíz de pm-workspace/
claude
```

Claude Code leerá `CLAUDE.md` automáticamente y tendrá acceso a todos los comandos y skills.

---

> **⚙️ EJEMPLO — Cómo queda el CLAUDE.md de un proyecto configurado**
>
> _Escenario: Tienes un proyecto llamado "GestiónClínica" en Azure DevOps, con equipo "GestiónClínica Team". Así quedan las constantes en `projects/gestion-clinica/CLAUDE.md`:_
>
> ```yaml
> PROJECT_NAME            = "GestiónClínica"
> PROJECT_TEAM            = "GestiónClínica Team"
> AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/miempresa"
> CURRENT_SPRINT_PATH     = "GestiónClínica\\Sprint 2026-04"
> VELOCITY_HISTORICA      = 38   # SP medios de los últimos 5 sprints
> SPRINT_DURATION_DAYS    = 10
> FOCUS_FACTOR            = 0.75
>
> # Equipo (nombres exactos como aparecen en Azure DevOps)
> TEAM_MEMBERS:
>   - nombre: "Carlos Mendoza"    role: "Tech Lead"   horas_dia: 6
>   - nombre: "Laura Sánchez"     role: "Full Stack"  horas_dia: 7.5
>   - nombre: "Diego Torres"      role: "Backend"     horas_dia: 7.5
>   - nombre: "Ana Morales"       role: "QA"          horas_dia: 7.5
>
> sdd_config:
>   token_budget_usd: 25
>   agentization_target: 0.60
> ```
>
> **A partir de aquí, Claude conoce tu organización, equipo y proyecto.**
> No tienes que repetir este contexto en cada conversación.

---

## Cómo Usar el Workspace

### Gestión de Sprint

Ejecuta estos comandos dentro de Claude Code:

| Comando | Descripción |
|---------|-------------|
| `/sprint:status` | Estado del sprint: burndown, items activos, alertas de WIP |
| `/sprint:plan` | Asistente de Sprint Planning: capacity + PBIs candidatos del backlog |
| `/sprint:review` | Resumen para Sprint Review: velocity, items completados, demostración |
| `/sprint:retro` | Plantilla de retrospectiva con datos del sprint |

---

> **💬 EJEMPLO — Lunes por la mañana antes de la Daily**
>
> _Escenario: Sprint en curso, día 4 de 10. Quieres saber si el equipo va bien antes de la reunión._
>
> **Tú escribes:**
> ```
> /sprint:status --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> ══════════════════════════════════════════════════
>   Sprint 2026-04 · GestiónClínica · Día 4/10
>   Objetivo: Módulo de Citas — CRUD completo + notificaciones
> ══════════════════════════════════════════════════
>
>   Burndown (SP)
>   Ideal:  ▓▓▓▓▓▓▓░░░░░░░░░░░░░  38 → 0
>   Real:   ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  38 → 23 completados  ⚠️
>   → Lleváis 15 SP completados, deberían ser 15.2 → ✅ en línea
>
>   En progreso (5 items):
>     AB#2041  POST /citas endpoint           Laura S.    [4/6h] ✅ en plazo
>     AB#2042  CitaValidator FluentValidation  🤖 agente   [terminado, en review]
>     AB#2043  Unit tests CitaService         🤖 agente   [en ejecución, 2h]
>     AB#2044  Migración tabla Citas          Carlos TL   [0/4h] 🔴 sin avance
>     AB#2045  GET /citas?fecha query         Diego T.    [2/4h] ✅
>
>   🔴 Requiere atención:
>     • AB#2044 — Carlos no ha registrado avance en 2 días.
>       Riesgo: si no avanza hoy, la migración puede bloquear a Laura y Diego.
>       Acción sugerida: preguntar en Daily si está bloqueado.
>
>   🟡 Avisos:
>     • 3 PBIs todavía en estado "New" sin descomponer → ¿planeas abordarlos este sprint?
>     • Ana (QA) tiene 0h imputadas esta semana — confirmar que está activa
>
>   Capacidad restante: ~72h humanas | ~18h agente
>   Estimación de cierre: 🟡 RIESGO MODERADO — depende de la migración
> ```
>
> **Tú escribes:**
> ```
> Dame el punto exacto para comentar en la Daily sobre AB#2044
> ```
>
> **Claude responde:**
> ```
> Para la Daily sobre AB#2044 (Migración tabla Citas):
>
> "Carlos, AB#2044 lleva 2 días sin avance. ¿Está bloqueado?
>  Esta migración desbloquea a Laura para hacer las queries de Citas
>  y a Diego para las relaciones EF Core. Si hay algún problema
>  con el schema, lo resolvemos ahora antes de que se convierta en cuello de botella."
>
> Si Carlos confirma un bloqueo, puedo ayudarte a:
>   a) Redefinir el scope de la migración para que sea más sencilla
>   b) Reasignar a alguien con más disponibilidad esta semana
>   c) Mover AB#2044 al siguiente sprint y adaptar las dependencias
> ```

---

> **💬 EJEMPLO — Sprint Planning completo**
>
> _Escenario: Es el viernes antes del nuevo sprint. Quieres preparar el planning._
>
> **Tú escribes:**
> ```
> /sprint:plan --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> ══════════════════════════════
>   Sprint Planning · 2026-05
>   GestiónClínica Team
> ══════════════════════════════
>
>   CAPACIDAD DEL SPRINT
>   ┌──────────────────┬───────┬──────────┬────────┬──────────────┐
>   │ Persona          │ Días  │ h/día    │ Factor │ Cap. Efectiva│
>   ├──────────────────┼───────┼──────────┼────────┼──────────────┤
>   │ Carlos TL        │  9    │  6.0h    │  0.75  │  40.5h       │
>   │ Laura Sánchez    │ 10    │  7.5h    │  0.75  │  56.3h       │
>   │ Diego Torres     │  9    │  7.5h    │  0.75  │  50.6h       │
>   │ Ana Morales (QA) │ 10    │  7.5h    │  0.75  │  56.3h       │
>   │ 🤖 Agente Claude │  —    │   —      │   —    │  ~35h est.   │
>   └──────────────────┴───────┴──────────┴────────┴──────────────┘
>   Total humano: 203.7h | Velocidad histórica: 38 SP
>
>   PBIs CANDIDATOS (ordenados por prioridad en backlog)
>   ┌──────┬────────────────────────────────────┬─────┬────────┐
>   │  ID  │ Título                             │ SP  │ h est. │
>   ├──────┼────────────────────────────────────┼─────┼────────┤
>   │ #301 │ Notificaciones de cita por email   │  8  │  38h   │
>   │ #302 │ Historial de citas por paciente    │  5  │  24h   │
>   │ #303 │ Panel de administración de salas   │  8  │  36h   │
>   │ #304 │ Exportar agenda a PDF              │  3  │  14h   │
>   │ #305 │ API paginación en listados         │  2  │   8h   │ ← límite capacity
>   └──────┴────────────────────────────────────┴─────┴────────┘
>   Propuesta: #301 + #302 + #304 + #305 = 18 SP / 84h ✅ dentro de capacity
>   (El #303 queda fuera — 36h excede la capacidad restante)
>
>   ¿Procedo a descomponer estos 4 PBIs en tasks con asignaciones?
> ```
>
> **Tú escribes:**
> ```
> Sí, descompón los 4 PBIs y asigna
> ```
>
> **Claude responde:**
> ```
> Descomponiendo los 4 PBIs... [consulta Azure DevOps]
>
> PBI #301 — Notificaciones de cita por email (8 SP)
>   B1  Entidad NotificacionEmail + reglas de dominio   4h  Carlos TL   human
>   B2  IEmailNotificationService interface             2h  Carlos TL   human
>   B3  SendCitaConfirmationCommandHandler              4h  🤖 agente   agent:single
>   B4  EmailTemplateService (Infrastructure)          3h  🤖 agente   agent:single
>   C1  Unit tests del command handler                 2h  🤖 agente   agent:single
>   D1  EmailController endpoints                      3h  🤖 agente   agent:single
>   D2  Integration test (Mailtrap sandbox)            4h  Diego T.    human
>   E1  Code Review                                    2h  Carlos TL   human
>
> [...PBIs #302, #304, #305 igualmente descompuestos...]
>
> Resumen de asignación:
>   Carlos TL:  22h (54% capacity) ✅
>   Laura S.:   18h (32% capacity) 🟡 tiene margen, ¿añadir #303 parcialmente?
>   Diego T.:   24h (47% capacity) ✅
>   Ana QA:     20h (35% capacity) ✅
>   🤖 Agente:  28h estimadas ($18 USD est.)
>
> ¿Creo las tasks en Azure DevOps con estas asignaciones?
> ```

---

### Informes

| Comando | Descripción |
|---------|-------------|
| `/report:hours` | Informe de imputación de horas (Excel, 4 pestañas) |
| `/report:executive` | Informe ejecutivo multi-proyecto (Word + PPT con semáforos) |
| `/report:capacity` | Estado de capacidades del equipo esta semana |
| `/team:workload` | Mapa de carga de trabajo por persona |
| `/kpi:dashboard` | Dashboard completo: velocity, cycle time, lead time, bug escape rate |

---

> **💬 EJEMPLO — Informe de horas al cierre del sprint**
>
> _Escenario: Último día del sprint. El cliente pide el informe de imputación._
>
> **Tú escribes:**
> ```
> /report:hours --project GestiónClínica --sprint 2026-04
> ```
>
> **Claude responde:**
> ```
> Generando informe de horas para Sprint 2026-04...
> [Consultando Azure DevOps Work Items y time tracking]
> [Consultando capacidades e imputaciones del sprint]
>
> ✅ Informe generado: output/reports/GestionClinica-horas-2026-04.xlsx
>
> Resumen ejecutivo:
>   Horas planificadas:  203.7h
>   Horas imputadas:     198.3h (97.3%)
>   Horas de agente:      31.5h (equivalente real: ~$19.80 USD)
>
>   Por persona:
>     Carlos TL   → 39.0h / 40.5h (96%) ✅
>     Laura S.    → 54.5h / 56.3h (97%) ✅
>     Diego T.    → 52.0h / 50.6h (103%) ⚠️ +2.4h sobre capacity
>     Ana QA      → 52.8h / 56.3h (94%) ✅
>
>   Items completados: 9/11 (18/20 SP — velocity 18 vs histórico 38 🔴)
>   Items arrastrados al siguiente sprint: AB#2044, AB#2051
>
> El Excel tiene 4 pestañas: Resumen, Detalle por persona, Detalle por PBI, Agentes.
> ```
>
> **Nota:** El fichero `.xlsx` se puede entregar directamente al cliente o al PMO.

---

> **💬 EJEMPLO — Ver la carga real del equipo esta semana**
>
> _Escenario: Miércoles. Sospechas que alguien está sobrecargado._
>
> **Tú escribes:**
> ```
> /team:workload --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> Carga del equipo — semana actual (lun 17/03 – vie 21/03)
>
>   Carlos TL    ██████████░░░░░  68%  [ 20.4h / 30h disponibles ]  🟢
>   Laura S.     █████████████░░  87%  [ 32.8h / 37.5h ]            🟡 alta
>   Diego T.     ████████████████ 100% [ 37.5h / 37.5h ]            🔴 sin margen
>   Ana QA       ████████░░░░░░░  55%  [ 20.6h / 37.5h ]            🟢 tiene margen
>   🤖 Agente    ███████░░░░░░░░  48%  [ 3 specs en cola ]          🟢
>
>   ⚠️  Diego Torres está al 100% — no absorbe incidencias ni bugs inesperados.
>   💡 Ana tiene 16.9h disponibles esta semana. Si hay tareas pendientes
>      de QA o documentación, ahora es el momento de asignárselas.
> ```

---

### Descomposición de PBIs

El proceso estándar para preparar un sprint:

1. `/pbi:decompose {id}` — Claude analiza el PBI, sus criterios de aceptación y el contexto del equipo, y propone la tabla de tasks.
2. Claude pregunta si crear las tasks en Azure DevOps.
3. Confirmas y Claude las crea vía REST API.

Para preparar el sprint completo de una vez: `/pbi:plan-sprint` hace todo el ciclo automáticamente (capacity → selección de PBIs → descomposición → asignación → creación en AzDO).

**Algoritmo de scoring de asignación:**
```
score = expertise × 0.40 + disponibilidad × 0.30 + balance × 0.20 + crecimiento × 0.10
```
Los pesos son configurables por proyecto en `projects/{proyecto}/CLAUDE.md`.

---

> **💬 EJEMPLO — Descomponer un PBI con criterios de aceptación**
>
> _Escenario: Tienes el PBI AB#302 "Historial de citas por paciente" con 3 criterios de aceptación definidos en Azure DevOps._
>
> **Tú escribes:**
> ```
> /pbi:decompose 302 --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> Analizando AB#302 — "Historial de citas por paciente" (5 SP)
>
> Criterios de aceptación detectados:
>   ✓ El médico puede filtrar por rango de fechas (inicio–fin)
>   ✓ Se muestran máx. 50 resultados con paginación (cursor-based)
>   ✓ Incluye estado de cada cita: Confirmada / Cancelada / Realizada
>
> Stack detectado: .NET 8 / Clean Arch / CQRS / EF Core / xUnit
>
> PROPUESTA DE TASKS:
> ┌────┬──────────────────────────────────────────┬──────┬──────┬──────────────┬───────────────┐
> │ #  │ Task                                     │ Horas│ Act. │ Asignado a   │ Developer Type│
> ├────┼──────────────────────────────────────────┼──────┼──────┼──────────────┼───────────────┤
> │ B1 │ Diseño query HistorialCitasQuery + DTO   │  3h  │ Dev  │ Carlos TL    │ human         │
> │ B2 │ EF Core: IHistorialCitasRepository       │  2h  │ Dev  │ Diego T.     │ human         │
> │ B3 │ GetHistorialCitasQueryHandler            │  4h  │ Dev  │ 🤖 agente    │ agent:single  │
> │ C1 │ HistorialCitasController (GET endpoint)  │  3h  │ Dev  │ 🤖 agente    │ agent:single  │
> │ C2 │ Paginación cursor-based (middleware)     │  3h  │ Dev  │ Laura S.     │ human         │
> │ D1 │ Unit tests del QueryHandler              │  2h  │ Dev  │ 🤖 agente    │ agent:single  │
> │ D2 │ Integration test end-to-end              │  3h  │ QA   │ Ana Morales  │ human         │
> │ E1 │ Code Review                              │  2h  │ Rev  │ Carlos TL    │ human         │
> └────┴──────────────────────────────────────────┴──────┴──────┴──────────────┴───────────────┘
> Total: 22h | Agente: 9h ($5.40 USD est.) | Humano: 13h
>
> Nota: La paginación cursor-based (C2) es un patrón nuevo en este proyecto
> → asignada a Laura (Full Stack, más flexible) en lugar de al agente.
>
> ¿Creo estas Tasks en Azure DevOps? (S/N o ajusta lo que necesites)
> ```
>
> **Tú escribes:**
> ```
> Cambia C2 al agente también, Laura ya tiene mucha carga. Crea las tasks.
> ```
>
> **Claude responde:**
> ```
> Ajustado: C2 → agent:single (añadiré en la spec el patrón de paginación de referencia).
>
> Creando 8 tasks en Azure DevOps para AB#302...
>   ✅ AB#302-B1 creada → asignada a Carlos Mendoza
>   ✅ AB#302-B2 creada → asignada a Diego Torres
>   ✅ AB#302-B3 creada → asignada a claude-agent (tag: spec-driven)
>   ✅ AB#302-C1 creada → asignada a claude-agent (tag: spec-driven)
>   ✅ AB#302-C2 creada → asignada a claude-agent (tag: spec-driven)
>   ✅ AB#302-D1 creada → asignada a claude-agent-fast (tag: spec-driven)
>   ✅ AB#302-D2 creada → asignada a Ana Morales
>   ✅ AB#302-E1 creada → asignada a Carlos Mendoza
>
> 8 tasks creadas. Las tasks de agente (B3, C1, C2, D1) ya tienen el tag
> "spec-driven" y están listas para /spec:generate cuando quieras.
> ```

---

## Spec-Driven Development (SDD)

El SDD es la característica más avanzada del workspace. Permite que las tasks técnicas sean implementadas por un desarrollador humano **o por un agente Claude**, dependiendo del tipo de tarea.

Una Spec es un contrato que describe exactamente qué implementar. Si el contrato es suficientemente claro, un agente puede implementarlo sin intervención humana.

### Tipos de developer

| Tipo | Quién implementa | Cuándo |
|------|-----------------|--------|
| `human` | Desarrollador del equipo | Lógica de dominio, migraciones, integraciones externas, Code Review |
| `agent:single` | Un agente Claude | Command Handlers, Repositories EF Core, Validators, Unit Tests, DTOs |
| `agent:team` | Implementador + Tester en paralelo | Tasks ≥ 6h con código producción + tests |

### Flujo de trabajo SDD

```
1. /pbi:decompose → propuesta de tasks con columna "Developer Type"
2. /spec:generate {task_id} → genera el fichero .spec.md desde Azure DevOps
3. /spec:review {spec_file} → valida la spec (calidad, completitud)
4. Si developer_type = agent:
     /agent:run {spec_file} → agente implementa la spec
   Si developer_type = human:
     Asignar al desarrollador
5. /spec:review {spec_file} --check-impl → pre-check del código generado
6. Code Review (E1) → SIEMPRE humano (Tech Lead)
7. PR → merge → Task: Done
```

### La plantilla de Spec

Cada Spec (`.spec.md`) tiene 9 secciones que eliminan la ambigüedad:

1. **Cabecera** — Task ID, developer_type, estimación, asignado a
2. **Contexto y Objetivo** — por qué existe la task, criterios de aceptación relevantes
3. **Contrato Técnico** — firma exacta de clases/métodos, DTOs con tipos y restricciones, dependencias a inyectar
4. **Reglas de Negocio** — tabla con cada regla, su excepción y código HTTP
5. **Test Scenarios** — Given/When/Then para happy path, errores y edge cases
6. **Ficheros a Crear/Modificar** — lista exacta de rutas (el agente no puede salirse de esta lista)
7. **Código de Referencia** — ejemplo del mismo patrón en el proyecto
8. **Estado de Implementación** — log del agente, blockers
9. **Checklist Pre-Entrega** — verificación antes de pasar a Code Review

### Qué tasks puede hacer un agente (por defecto)

La matrix completa está en `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`. El resumen para proyectos .NET Clean Architecture:

**El agente puede hacer:** Application Layer (Command Handlers, Query Handlers, Validators FluentValidation, AutoMapper Profiles, DTOs), Infrastructure (Repositorios EF Core, Entity Configurations Fluent API), API (Controllers CRUD, Swagger annotations), Tests (Unit Tests de Application cuando los escenarios están en la Spec).

**Siempre humano:** Domain Layer (nuevas entidades raíz de agregado, Domain Services, lógica de negocio compleja), Migraciones de base de datos, Configuración de autenticación/autorización, Integraciones con sistemas externos, Code Review (E1) — sin excepciones.

---

> **💬 EJEMPLO — Flujo SDD completo: de task a código en producción**
>
> _Escenario: La task AB#302-B3 "GetHistorialCitasQueryHandler" está lista para que el agente la implemente._
>
> **Paso 1 — Generar la spec**
>
> **Tú escribes:**
> ```
> /spec:generate 302-B3 --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> Leyendo AB#302 (PBI padre) y AB#302-B3 (Task)...
> Analizando código existente en projects/gestion-clinica/source/...
> → Módulo: Citas / Capa: Application / Tipo: QueryHandler
> → Developer type: agent:single (patrón repetible, interfaces definidas)
>
> Spec generada:
>   projects/gestion-clinica/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
>
> Vista previa de la sección más crítica (Contrato Técnico):
> ┌─────────────────────────────────────────────────────────────────┐
> │  public sealed class GetHistorialCitasQuery                     │
> │      : IRequest<PagedResult<HistorialCitaDto>>                  │
> │  {                                                              │
> │      public Guid PacienteId { get; init; }                      │
> │      public DateOnly FechaInicio { get; init; }                 │
> │      public DateOnly FechaFin { get; init; }                    │
> │      public string? Cursor { get; init; }   // paginación       │
> │      public int PageSize { get; init; } = 20;                   │
> │  }                                                              │
> └─────────────────────────────────────────────────────────────────┘
>
> ¿Revisas la spec antes de implementar? → /spec:review AB302-B3-...
> ```
>
> **Paso 2 — Validar la spec**
>
> **Tú escribes:**
> ```
> /spec:review AB302-B3-get-historial-citas-handler.spec.md
> ```
>
> **Claude responde:**
> ```
> Revisando calidad de la spec...
>
> ✅ Cabecera completa (Task ID, developer_type, estimación, asignado)
> ✅ Contrato técnico definido (interfaces, DTOs, dependencias)
> ✅ Reglas de negocio documentadas: 4 reglas con excepciones y HTTP codes
> ✅ Test scenarios: 6 escenarios (happy path + fechas inválidas + paciente no encontrado)
> ✅ Ficheros a crear listados: 3 ficheros en rutas exactas
> ✅ Código de referencia incluido (GetCitasDelDíaQueryHandler como patrón)
>
> ══════════════════════
>   ✅ SPEC LISTA
>   Puedes ejecutar /agent:run
> ══════════════════════
> ```
>
> **Paso 3 — Lanzar el agente**
>
> **Tú escribes:**
> ```
> /agent:run projects/gestion-clinica/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
> ```
>
> **Claude responde:**
> ```
> Lanzando agente claude-opus-4-5 sobre AB302-B3...
> Log en tiempo real: output/agent-runs/20260519-094512-AB302-B3-single.log
>
> [09:45:14] Agente iniciado — leyendo spec y contexto del proyecto
> [09:45:31] Creando GetHistorialCitasQuery.cs
> [09:45:44] Creando GetHistorialCitasQueryHandler.cs
> [09:46:02] Creando HistorialCitaDto.cs + AutoMapper profile
> [09:46:18] Ejecutando dotnet build... ✅ 0 errores
> [09:46:35] Ejecutando dotnet test --filter "GetHistorial"... 6/6 ✅
> [09:46:41] Agente finalizado.
>
> ══════════════════════════════════════════════
>   ✅ IMPLEMENTACIÓN COMPLETADA
>   Build: OK | Tests: 6/6 | Duración: 87s
>   Coste estimado: ~$0.62 USD
> ══════════════════════════════════════════════
>
> Ficheros creados:
>   + Application/Citas/Queries/GetHistorialCitas/GetHistorialCitasQuery.cs
>   + Application/Citas/Queries/GetHistorialCitas/GetHistorialCitasQueryHandler.cs
>   + Application/Citas/Queries/GetHistorialCitas/HistorialCitaDto.cs
>
> ⚠️  IMPORTANTE: Code Review (E1) es obligatorio antes del merge.
>    Asigna AB#302-E1 a Carlos TL para revisión.
>
> ¿Actualizo la Task AB#302-B3 en Azure DevOps a estado "In Review"?
> ```
>
> **Tú escribes:**
> ```
> Sí, actualiza el estado
> ```
>
> **Claude responde:**
> ```
> ✅ AB#302-B3 actualizada en Azure DevOps:
>    Estado: In Review
>    Tags añadidos: spec-driven; agent-implemented
>    Comentario: "Implementado por claude-opus-4-5. Build OK, 6/6 tests. Pendiente Code Review."
> ```

---

> **💬 EJEMPLO — Dashboard de specs del sprint**
>
> _Escenario: Quieres ver el estado de todas las tasks SDD del sprint de un vistazo._
>
> **Tú escribes:**
> ```
> /spec:status --project GestiónClínica
> ```
>
> **Claude responde:**
> ```
> ══════════════════════════════════════════════════════════════════
>   SDD Status · GestiónClínica · Sprint 2026-05
> ══════════════════════════════════════════════════════════════════
>
>   Task                             Spec         Dev Type     Estado   h    Asignado
>   ─────────────────────────────────────────────────────────────────────────────────
>   AB#302-B3 GetHistorialCitas      ✅ lista      agent:single  ✅ done  4h   agente
>   AB#302-C1 HistorialController    ✅ lista      agent:single  🔄 impl  3h   agente
>   AB#302-C2 Paginación cursor      ✅ lista      agent:single  ⏳ cola  3h   agente
>   AB#302-D1 Unit tests handler     ✅ lista      agent:single  ⏳ cola  2h   agente
>   AB#301-B3 SendConfirmationCmd    ⚠️ incompleta agent:single  🚫 bloq  4h   agente
>   AB#301-D1 EmailTemplateService   ⏳ pendiente  agent:single  ⏳ cola  3h   agente
>
>   Resumen:
>     Completadas: 1 | En curso: 1 | En cola: 3 | Bloqueadas: 1
>     Horas de agente ahorradas (completadas): 4h (~$2.48 USD)
>     Horas de agente estimadas (total sprint): 19h (~$11.78 USD est.)
>
>   ⚠️  AB#301-B3 bloqueada:
>      La spec tiene una sección de Contrato Técnico incompleta —
>      falta la firma de IEmailService. Ejecuta /spec:review AB301-B3-...
>      para ver qué falta exactamente.
> ```

---

### Patrones de equipos de agentes

Para tasks grandes, puedes usar un equipo de agentes en paralelo:

```bash
/agent:run {spec_file} --team
# Lanza: Implementador (opus) + Tester (haiku) en paralelo
# Tiempo: ~50% menos que secuencial
# Coste: ~$0.80-1.80 por spec
```

Los patrones disponibles están documentados en `references/agent-team-patterns.md`:

- `single` — 1 agente (tasks ≤ 6h)
- `impl-test` — Implementador + Tester en paralelo
- `impl-test-review` — añade un Reviewer tras la fase paralela
- `full-stack` — 4 agentes por capa (API, Application, Infrastructure, Tests)
- `parallel-handlers` — N agentes para N specs simultáneas

---

> **💬 EJEMPLO — Lanzar un equipo de agentes para una task grande**
>
> _Escenario: La task AB#301-B3 "SendCitaConfirmationCommandHandler" es compleja (6h), tiene código de producción y necesita tests. Usas el patrón `impl-test`._
>
> **Tú escribes:**
> ```
> /agent:run projects/gestion-clinica/specs/sprint-2026-05/AB301-B3-send-confirmation-cmd.spec.md --team
> ```
>
> **Claude responde:**
> ```
> Patrón seleccionado: impl-test (código producción + tests en paralelo)
>   Agente 1 — Implementador: claude-opus-4-5  (handler + service)
>   Agente 2 — Tester:        claude-haiku-4-5 (unit tests + mocks)
>
> Coste estimado: ~$1.40 USD
> ¿Confirmas el lanzamiento?
> ```
>
> **Tú escribes:**
> ```
> Sí
> ```
>
> **Claude responde:**
> ```
> Lanzando 2 agentes en paralelo...
>
> [Agente 1] 09:51:03 → Implementando SendCitaConfirmationCommandHandler...
> [Agente 2] 09:51:04 → Generando unit tests para SendCitaConfirmationCommand...
>
> [Agente 1] 09:52:41 → Handler + EmailTemplateService completos. Build OK.
> [Agente 2] 09:52:58 → 9 unit tests generados. Esperando implementación para ejecutar.
>
> [Sincronizando] → Ejecutando dotnet test... 9/9 ✅
>
> ══════════════════════════════════════════════
>   ✅ EQUIPO COMPLETADO
>   Duración total: 118s (vs ~210s secuencial)
>   Build: OK | Tests: 9/9
>   Coste real: $1.22 USD
> ══════════════════════════════════════════════
> ```

---

## Configuración Avanzada por Proyecto

Cada proyecto tiene su `CLAUDE.md` con configuración propia que adapta el comportamiento de Claude a las particularidades del equipo y el contrato.

### Pesos de asignación (pbi-decomposition)

```yaml
# En projects/{proyecto}/CLAUDE.md
assignment_weights:
  expertise:    0.40   # Priorizar quien mejor conoce el módulo
  availability: 0.30   # Priorizar quien tiene más horas libres
  balance:      0.20   # Distribuir carga equitativamente
  growth:       0.10   # Dar oportunidades de aprendizaje
```

En proyectos de precio fijo, se puede ajustar: más peso en expertise y disponibilidad, `growth: 0.00` para no arriesgar el presupuesto.

### Configuración SDD

```yaml
# En projects/{proyecto}/CLAUDE.md
sdd_config:
  model_agent: "claude-opus-4-5-20251101"
  model_fast:  "claude-haiku-4-5-20251001"
  token_budget_usd: 30          # Presupuesto mensual en tokens
  max_parallel_agents: 5

  # Sobreescribir la matrix global para este proyecto
  layer_overrides:
    - layer: "Authentication"
      force: "human"
      reason: "Módulo de seguridad — siempre revisión humana"
```

### Agregar un proyecto nuevo

1. Copia `projects/proyecto-alpha/` a `projects/tu-proyecto/`
2. Edita `projects/tu-proyecto/CLAUDE.md` con las constantes del nuevo proyecto
3. Añade el proyecto al `CLAUDE.md` raíz (sección `📋 Proyectos Activos`)
4. Clona el repo en `projects/tu-proyecto/source/`

---

> **⚙️ EJEMPLO — Proyecto de precio fijo con SDD conservador**
>
> _Escenario: "ProyectoBeta" es un contrato cerrado. Quieres maximizar la velocidad del equipo senior y usar agentes solo en lo muy seguro, sin riesgo presupuestario._
>
> ```yaml
> # projects/proyecto-beta/CLAUDE.md
>
> PROJECT_TYPE = "precio-fijo"
>
> assignment_weights:
>   expertise:    0.55   # ← sube: siempre el mejor para cada task
>   availability: 0.35   # ← sube: no sobrecargar en precio fijo
>   balance:      0.10
>   growth:       0.00   # ← baja a 0: no arriesgar horas de aprendizaje
>
> sdd_config:
>   agentization_target: 0.40    # ← meta conservadora: solo 40% agentizado
>   require_tech_lead_approval: true  # ← Carlos revisa CADA spec antes de lanzar agente
>   cost_alert_per_spec_usd: 1.50     # ← alerta si una spec supera $1.50
>   token_budget_usd: 15              # ← presupuesto mensual ajustado
>
>   layer_overrides:
>     - layer: "Domain"       force: "human"  reason: "precio fijo — 0 riesgo"
>     - layer: "Integration"  force: "human"  reason: "APIs externas del cliente"
>     - layer: "Migration"    force: "human"  reason: "cambios irreversibles en BBDD"
> ```
>
> **Con esta configuración, Claude sabrá automáticamente:**
> - Proponer solo las tasks más seguras al agente (validators, unit tests, DTOs)
> - Pedir aprobación del Tech Lead antes de lanzar cualquier agente
> - Avisar si el coste estimado de una spec supera $1.50
> - Asignar siempre al miembro con más expertise en el módulo (expertise: 0.55)

---

## Proyecto de Test — `sala-reservas`

El workspace incluye un **proyecto de test completo** (`projects/sala-reservas/`) que permite verificar todas las funcionalidades sin necesidad de conectarse a Azure DevOps real. Usa datos simulados (mock JSON) que imitan fielmente la estructura de la API de Azure DevOps.

### Qué es sala-reservas

Una aplicación sencilla de reserva de salas de reuniones: CRUD de salas (Sala) y CRUD de reservas por fecha (Reserva), sin login — el empleado introduce su nombre manualmente. Tecnología: .NET 8, Clean Architecture, CQRS/MediatR, EF Core.

**Equipo simulado:** 4 desarrolladores humanos (Tech Lead, Full Stack, Backend, QA) + 1 PM + equipo de agentes Claude.

El proyecto incluye dos specs SDD completas que sirven como referencia para testear el flujo de Spec-Driven Development:
- `AB101-B3-create-sala-handler.spec.md` — Command Handlers para el CRUD de Salas (agente opus)
- `AB102-D1-unit-tests-salas.spec.md` — 15 unit tests con xUnit + Moq (agente haiku)

### Ejecutar los tests del workspace

El script `scripts/test-workspace.sh` valida que el workspace esté correctamente configurado. Ejecuta 96 pruebas agrupadas en 9 categorías.

#### Modo mock (sin Azure DevOps) — recomendado para empezar

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
```

Resultado esperado: **≥ 93/96 tests pasan**. Los fallos en modo mock son esperados y no indican problemas en el workspace:
- `az` (Azure CLI) no instalado en el entorno de test
- `node_modules` no existe — ejecuta `cd scripts && npm install` para instalar dependencias Node

#### Modo real (con Azure DevOps configurado)

```bash
./scripts/test-workspace.sh --real
```

Requiere: PAT configurado, `az devops` instalado, constantes correctas en `CLAUDE.md`.

#### Ejecutar una categoría específica

```bash
./scripts/test-workspace.sh --only structure    # Solo estructura de ficheros
./scripts/test-workspace.sh --only sdd          # Solo validación SDD
./scripts/test-workspace.sh --only capacity     # Solo capacity y fórmulas
./scripts/test-workspace.sh --only sprint       # Solo datos del sprint
./scripts/test-workspace.sh --only imputacion   # Solo imputaciones de horas
./scripts/test-workspace.sh --only report       # Solo generación de informes
./scripts/test-workspace.sh --only backlog      # Solo backlog y scoring
```

#### Ver output detallado

```bash
./scripts/test-workspace.sh --mock --verbose
```

### Categorías de tests y qué validan

| Categoría | Tests | Qué verifica |
|-----------|-------|--------------|
| `prereqs` | 5 | Herramientas instaladas (jq, python3, node, az, claude CLI) |
| `structure` | 18 | Existencia de todos los ficheros del workspace |
| `connection` | 8 | Conectividad con Azure DevOps (solo `--real`) |
| `capacity` | 12 | Fórmulas de capacity, algoritmo de scoring de asignación |
| `sprint` | 14 | Datos del sprint, burndown, mock JSON válido |
| `imputacion` | 10 | Imputaciones de horas, registro de agentes |
| `sdd` | 15 | Specs, layer matrix, patrones de agente, algoritmo de conflictos |
| `report` | 8 | Generación de informes Excel/PPT |
| `backlog` | 6 | Backlog query, descomposición, scoring de asignación |

### Informe de resultados

Al terminar, el script genera automáticamente un informe Markdown en `output/test-report-YYYYMMDD-HHMMSS.md` con el resumen de resultados, los tests fallidos con la causa y las instrucciones de corrección.

### Estructura de los datos mock

Los ficheros en `projects/sala-reservas/test-data/` simulan respuestas reales de la API de Azure DevOps:

| Fichero | API simulada | Contenido |
|---------|-------------|-----------|
| `mock-workitems.json` | `GET /_apis/wit/wiql` | 3 PBIs + 12 Tasks con estados, asignaciones y tags SDD |
| `mock-sprint.json` | `GET /_apis/work/teamsettings/iterations` | Sprint 2026-04 con burndown de 10 días, velocity histórico |
| `mock-capacities.json` | `GET /_apis/work/teamsettings/iterations/{id}/capacities` | Capacidades de 5 miembros + imputaciones semana 1 |

---

## Métricas y KPIs Trackeados

| KPI | Descripción | Umbral OK |
|-----|-------------|-----------|
| Velocity | Story Points completados por sprint | > media últimos 5 sprints |
| Burndown | Progreso vs plan del sprint | Dentro del rango ±15% |
| Cycle Time | Días desde "Active" hasta "Done" | < 5 días (P75) |
| Lead Time | Días desde "New" hasta "Done" | < 12 días (P75) |
| Capacity Utilization | % de capacity usada | 70-90% (🟢), >95% (🔴) |
| Sprint Goal Hit Rate | % de sprints que cumplen el objetivo | > 75% |
| Bug Escape Rate | Bugs en producción / total completado | < 5% |
| SDD Agentización | % de tasks técnicas implementadas por agente | Objetivo: > 60% |

---

## Reglas Críticas

1. **El PAT nunca se hardcodea** — siempre `$(cat $AZURE_DEVOPS_PAT_FILE)`
2. **Filtrar siempre por IterationPath** en queries WIQL, salvo petición explícita
3. **Confirmar antes de escribir** en Azure DevOps — Claude pregunta antes de modificar datos
4. **Leer el CLAUDE.md del proyecto** antes de actuar sobre él
5. **La Spec es el contrato** — no se implementa sin spec aprobada (ni humanos ni agentes)
6. **El Code Review (E1) es siempre humano** — sin excepciones, nunca a un agente
7. **"Si el agente falla, la Spec no era suficientemente buena"** — mejorar la spec, no saltarse el proceso
8. **Budget de tokens** — respetar el límite configurado por proyecto antes de lanzar agent:team

---

## Roadmap de Adopción

| Semanas | Fase | Objetivo |
|---------|------|----------|
| 1-2 | Configuración | Conectar con Azure DevOps, probar `/sprint:status` |
| 3-4 | Gestión básica | Iterar con `/sprint:plan`, `/team:workload`, ajustar constantes |
| 5-6 | Reporting | Activar `/report:hours` y `/report:executive` con datos reales |
| 7-8 | SDD piloto | Generar primeras specs, probar agente con 1-2 tasks de Application Layer |
| 9+ | SDD a escala | Objetivo: 60%+ de tasks técnicas repetitivas implementadas por agentes |

---

## Referencia Rápida de Comandos

### Sprint y Reporting
```
/sprint:status [--project]        Estado del sprint con alertas
/sprint:plan [--project]          Asistente de Sprint Planning
/sprint:review [--project]        Resumen para Sprint Review
/sprint:retro [--project]         Retrospectiva con datos
/report:hours [--project]         Informe de horas (Excel)
/report:executive                 Informe multi-proyecto (PPT/Word)
/report:capacity [--project]      Estado de capacidades
/team:workload [--project]        Carga por persona
/board:flow [--project]           Cycle time y cuellos de botella
/kpi:dashboard [--project]        Dashboard KPIs completo
```

### PBI Decomposition
```
/pbi:decompose {id}               Descomponer un PBI en tasks
/pbi:decompose-batch {id1,id2}    Descomponer varios PBIs
/pbi:assign {pbi_id}              (Re)asignar tasks de un PBI
/pbi:plan-sprint                  Planning completo del sprint
```

### Spec-Driven Development
```
/spec:generate {task_id}          Generar Spec desde Task de Azure DevOps
/spec:implement {spec_file}       Implementar Spec (agente o humano)
/spec:review {spec_file}          Revisar calidad de Spec o implementación
/spec:status [--project]          Dashboard de Specs del sprint
/agent:run {spec_file} [--team]   Lanzar agente Claude sobre una Spec
```

---

## Soporte

Para ajustar el comportamiento de Claude, edita los ficheros en `.claude/skills/` (cada skill tiene su `SKILL.md`) o añade nuevos slash commands en `.claude/commands/`.

Las métricas de uso de SDD se registran automáticamente en `projects/{proyecto}/specs/sdd-metrics.md` al ejecutar `/spec:review --check-impl`.

---

## Musts en gestión de proyectos .NET — cobertura de este workspace

Esta sección responde a una pregunta clave para cualquier PM que evalúe adoptar esta herramienta: ¿qué cubre, qué no cubre y qué no puede cubrirse por definición?

### ✅ Contemplado y simplificado

Las siguientes responsabilidades clásicas del PM/Scrum Master quedan automatizadas o notablemente reducidas en carga:

| Must | Cobertura | Simplificación |
|------|-----------|----------------|
| Sprint Planning (capacity + selección de PBIs) | `/sprint:plan` | Alta — calcula capacity real, propone PBIs hasta llenarla y descompone en tasks con un solo comando |
| Descomposición de PBIs en tasks | `/pbi:decompose`, `/pbi:decompose-batch` | Alta — genera tabla de tasks con estimación, actividad y asignación. Elimina la reunión de refinamiento de tareas |
| Asignación de trabajo (balanceo de carga) | `/pbi:assign` + scoring algorithm | Alta — el algoritmo expertise×disponibilidad×balance elimina la intuición subjetiva y garantiza reparto equitativo |
| Seguimiento del burndown | `/sprint:status` | Alta — burndown automático en cualquier momento, con desviación respecto al ideal y proyección de cierre |
| Control de capacity del equipo | `/report:capacity`, `/team:workload` | Alta — detecta sobrecarga individual y días libres sin necesidad de hojas de cálculo manuales |
| Alertas de WIP y bloqueos | `/sprint:status` | Alta — alertas automáticas de items sin avance, personas al 100% y WIP sobre el límite |
| Preparación de la Daily | `/sprint:status` | Media — proporciona el estado exacto y sugiere los puntos a tratar, pero la Daily es humana |
| Informe de imputación de horas | `/report:hours` | Alta — Excel con 4 pestañas generado automáticamente desde Azure DevOps, sin edición manual |
| Informe ejecutivo multi-proyecto | `/report:executive` | Alta — PPT/Word con semáforos de estado, listo para enviar a dirección |
| Velocity y KPIs de equipo | `/kpi:dashboard` | Alta — velocity, cycle time, lead time, bug escape rate calculados con datos reales de AzDO |
| Sprint Review (preparación) | `/sprint:review` | Media — genera el resumen de items completados y velocity, pero la demo la hace el equipo |
| Sprint Retrospectiva (datos) | `/sprint:retro` | Media — proporciona los datos cuantitativos del sprint (qué fue bien, qué no), pero la dinámica es humana |
| Implementación de tasks repetibles (.NET) | SDD + `/agent:run` | Muy alta — Command Handlers, Repositories, Validators, Unit Tests implementados sin intervención humana |
| Control de calidad de specs | `/spec:review` | Alta — valida automáticamente que una spec tenga el nivel de detalle suficiente antes de implementar |

### 🔮 No contemplado actualmente — candidatos para el futuro

Áreas que serían naturalmente automatizables con Claude y que representan una evolución lógica del workspace:

**Gestión del backlog y refinement:** actualmente Claude descompone PBIs que ya existen, pero no asiste en la creación de nuevos PBIs desde cero (desde notas de cliente, emails, tickets de soporte). Un skill de `backlog:capture` que convierta inputs desestructurados en PBIs bien formados con criterios de aceptación sería un paso natural.

**Gestión de riesgos (risk log):** el workspace detecta alertas de WIP y burndown, pero no mantiene un registro estructurado de riesgos con probabilidad, impacto y plan de mitigación. Un skill de `risk:log` que actualice el registro en cada `/sprint:status` y escale riesgos críticos al PM sería valioso.

**Release notes automáticas:** al cierre del sprint, Claude tiene toda la información para generar las release notes desde los items completados y los commits. No está implementado, pero sería un `/sprint:release-notes` directo.

**Gestión de deuda técnica:** el workspace no rastrea ni prioriza la deuda técnica. Un skill que analice el backlog en busca de items marcados como "refactor" o "tech-debt" y los proponga para sprints de mantenimiento sería un añadido útil.

**Onboarding de nuevos miembros:** cuando llega alguien nuevo al equipo, Claude podría generar automáticamente una guía de incorporación personalizada (setup del entorno, módulos del proyecto, convenciones de código) desde los ficheros del workspace.

**Integración con pull requests:** el workspace gestiona tasks en AzDO pero no hace seguimiento del estado de los PRs asociados (reviewers, comentarios pendientes, tiempo en revisión). Una integración con la API de Git de Azure DevOps completaría el ciclo.

**Seguimiento de bugs en producción:** el bug escape rate se calcula, pero no hay un flujo automatizado para priorizar bugs entrantes, relacionarlos con el sprint en curso y proponer si impactan en el sprint goal actual.

**Estimación asistida de PBIs nuevos:** Claude podría estimar en Story Points un PBI nuevo basándose en el histórico de PBIs similares completados (análisis semántico de títulos y criterios de aceptación), reduciendo la dependencia del Planning Poker para items sencillos.

### 🚫 Fuera del alcance de la automatización — siempre humano

Estas responsabilidades no pueden ni deben delegarse a un agente por razones estructurales: requieren juicio contextual, responsabilidad formal, relación humana o decisión estratégica que no puede codificarse en una spec ni en un prompt.

**Decisiones de arquitectura** — Elegir entre microservicios y monolito, decidir si adoptar Event Sourcing, evaluar si cambiar de ORM o de cloud provider. Estas decisiones tienen implicaciones de años y requieren comprensión del negocio, el equipo y el contexto que ningún agente tiene. Claude puede informar y analizar opciones, pero no puede ni debe decidir.

**Code Review real** — El Code Review (E1 en el flujo SDD) es inviolablemente humano. Un agente puede hacer un pre-check de compilación y tests, pero la revisión de calidad, legibilidad, coherencia arquitectónica y detección de problemas sutiles de seguridad o rendimiento requiere un desarrollador senior con contexto del sistema.

**Gestión de personas** — Evaluaciones de rendimiento, conversaciones difíciles sobre productividad, decisiones de promoción, gestión de conflictos entre miembros del equipo, contratación y despido. Ningún dato de burndown ni de capacity reemplaza el juicio humano en estas situaciones.

**Negociación con el cliente o stakeholders** — El workspace genera informes y proporciona datos, pero la negociación de scope, la gestión de expectativas y la comunicación de malas noticias (un sprint que no se cierra, un bug crítico en producción) requieren presencia, empatía y autoridad de un PM real.

**Decisiones de seguridad y compliance** — Revisar que el código cumple con GDPR, evaluar el alcance de una brecha de seguridad, decidir si un módulo necesita penetration testing, obtener certificaciones de calidad. Estas decisiones conllevan responsabilidad legal que no puede recaer en un agente.

**Migraciones de base de datos en producción** — El workspace excluye explícitamente las migraciones del scope de los agentes. La reversibilidad, el rollback plan y la ventana de mantenimiento de una migración en producción deben estar en manos de un desarrollador que entienda el estado real de los datos.

**Aceptación y UAT (User Acceptance Testing)** — Los tests unitarios e de integración pueden automatizarse. La validación de que el software resuelve el problema real del usuario final, no. El UAT requiere usuarios reales, contexto de negocio y criterio que va más allá de un escenario Given/When/Then.

**Gestión de incidencias en producción (P0/P1)** — Cuando algo falla en producción, el triage, la comunicación de crisis, la decisión de hacer rollback y la coordinación entre equipos requieren un humano disponible, con autoridad y con contexto completo del sistema en producción.

**Definición de la visión y el roadmap del producto** — El workspace gestiona sprints, no estrategia de producto. Qué construir, por qué y en qué orden es una decisión de negocio que pertenece al Product Owner, al CEO o al cliente, no a un sistema de automatización.

---

## Cómo contribuir

Este proyecto está diseñado para crecer con las aportaciones de la comunidad. Si usas el workspace en un proyecto real y encuentras una mejora, un comando nuevo o una skill que falta, tu contribución es bienvenida.

### Qué tipos de contribución aceptamos

**Nuevos slash commands** (`.claude/commands/`) — el área de mayor impacto inmediato. Si has automatizado una conversación con Claude que resuelve un problema de PM no cubierto, empaquétala como comando y compártela. Ejemplos de alto interés: `risk:log`, `sprint:release-notes`, `backlog:capture`, `pr:status`.

**Nuevas skills** (`.claude/skills/`) — skills que amplíen el comportamiento de Claude en áreas nuevas (gestión de deuda técnica, integración con Jira, soporte para metodologías Kanban o SAFe, stacks distintos de .NET).

**Ampliaciones del proyecto de test** (`projects/sala-reservas/`) — nuevos ficheros mock, nuevas specs de ejemplo, nuevas categorías en `test-workspace.sh`.

**Correcciones y mejoras de documentación** — aclaraciones en los SKILL.md, ejemplos adicionales en el README, traducciones.

**Bug fixes en scripts** (`scripts/`) — mejoras en `azdevops-queries.sh`, `capacity-calculator.py` o `report-generator.js`.

### Flujo de contribución

```
1. Fork del repositorio en GitHub
2. Crea una rama con nombre descriptivo
3. Desarrolla y documenta tu contribución
4. Ejecuta el test suite (debe pasar ≥ 93/96 en modo mock)
5. Abre un Pull Request siguiendo la plantilla
```

**Paso 1 — Fork y rama**

```bash
# Desde tu cuenta de GitHub, haz fork del repositorio
# Luego clona tu fork y crea tu rama de trabajo:

git clone https://github.com/TU-USUARIO/pm-workspace.git
cd pm-workspace
git checkout -b feature/sprint-release-notes
# o para fixes: git checkout -b fix/capacity-formula-edge-case
```

Convención de nombres de ramas:
- `feature/` — nueva funcionalidad (comando, skill, integración)
- `fix/` — corrección de un bug
- `docs/` — solo documentación
- `test/` — mejoras al test suite o datos mock
- `refactor/` — reorganización sin cambio de comportamiento

**Paso 2 — Desarrolla tu contribución**

Si añades un slash command nuevo, sigue la estructura de los existentes en `.claude/commands/`. Cada comando debe incluir:
- Descripción del propósito en las primeras líneas
- Pasos numerados del proceso que Claude debe seguir
- Manejo del caso de error más común
- Al menos un ejemplo de uso en el propio fichero

Si añades una skill nueva, incluye un `SKILL.md` con la descripción, cuándo se usa, parámetros de configuración y referencias a documentación relevante.

**Paso 3 — Verifica que los tests siguen pasando**

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock

# Resultado esperado: ≥ 93/96 PASSED
# Si tu contribución añade nuevos ficheros, añade también sus tests
# en la suite correspondiente de scripts/test-workspace.sh
```

**Paso 4 — Abre el Pull Request**

Usa esta plantilla para el cuerpo del PR:

```markdown
## ¿Qué añade o corrige este PR?
[Descripción en 2-3 frases]

## Tipo de contribución
- [ ] Nuevo slash command
- [ ] Nueva skill
- [ ] Fix de bug
- [ ] Mejora de documentación
- [ ] Ampliación del test suite
- [ ] Otro: ___

## Archivos modificados / creados
- `.claude/commands/nombre-comando.md` — [qué hace]
- `docs/` — [si aplica]

## Tests
- [ ] `./scripts/test-workspace.sh --mock` pasa ≥ 93/96
- [ ] He añadido tests para los nuevos ficheros (si aplica)

## Checklist
- [ ] El comando/skill sigue las convenciones de estilo de los existentes
- [ ] He probado la conversación con Claude manualmente al menos una vez
- [ ] No incluyo datos reales de proyectos, clientes ni PATs
```

### Criterios de aceptación de un PR

Un PR se acepta si cumple todos estos criterios y al menos uno de los mantenedores hace review:

El test suite sigue pasando en modo mock (≥ 93/96). El nuevo comando o skill tiene un nombre consistente con los existentes (kebab-case, namespace con `:` o `-`). No incluye credenciales, PATs, URLs internas ni datos reales de ningún proyecto. Si añade un fichero nuevo que debería existir en todos los proyectos (como `sdd-metrics.md`), también añade el test correspondiente en `test-workspace.sh`. La documentación inline en el fichero es suficiente para que otro PM entienda para qué sirve sin leer el código.

### Reportar un bug o proponer una feature

Abre un Issue en GitHub con uno de estos prefijos en el título:

```
[BUG]     /sprint:status no muestra alertas cuando WIP = 0
[FEATURE] Añadir soporte para metodología Kanban
[DOCS]    El ejemplo de SDD en el README no refleja el comportamiento actual
[QUESTION] ¿Cómo configurar el workspace para proyectos con múltiples repos?
```

Incluye siempre: versión de Claude Code usada (`claude --version`), qué comando o skill está involucrado, qué comportamiento esperabas y qué obtienes, y si es reproducible con el proyecto de test `sala-reservas` en modo mock.

### Código de conducta

Las contribuciones deben ser respetuosas, técnicamente sólidas y orientadas a resolver problemas reales de gestión de proyectos. Se valoran especialmente las contribuciones que vienen acompañadas de un caso de uso real (anonimizado), ya que demuestran que la funcionalidad resuelve una necesidad genuina.

---

*PM Workspace — Estrategia Claude Code + Azure DevOps para equipos .NET/Scrum*
