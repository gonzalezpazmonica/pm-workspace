# Catálogo de Comandos PM-Workspace (37)

## 📅 Sprint y Reporting (10)

| Comando | Params | Descripción |
|---|---|---|
| `/sprint:status` | — | Burndown, progreso, alertas WIP, blockers |
| `/sprint:plan` | — | Planning: capacity real + PBIs candidatos |
| `/sprint:review` | — | Review: velocity, completados, demo |
| `/sprint:retro` | — | Retro con datos cuantitativos del sprint |
| `/report:hours` | — | Imputación de horas (Excel, 4 pestañas) |
| `/report:executive` | — | Multi-proyecto (PPT + Word, semáforos) |
| `/report:capacity` | — | Capacidades del equipo por persona |
| `/team:workload` | — | Carga por persona + alertas sobrecarga |
| `/board:flow` | — | Cycle time, WIP, cuellos de botella |
| `/kpi:dashboard` | — | Velocity, cycle time, lead time, bug escape rate |

## 📦 PBI y Discovery (6)

| Comando | Params | Descripción |
|---|---|---|
| `/pbi:decompose` | `{id}` | Descomponer PBI en tasks con estimación |
| `/pbi:decompose-batch` | `{ids}` (coma) | Descomponer varios PBIs a la vez |
| `/pbi:assign` | `{pbi_id}` | (Re)asignar tasks con scoring |
| `/pbi:plan-sprint` | — | Planning completo: capacity → PBIs → tasks → asignación |
| `/pbi:jtbd` | `{id}` | Jobs to be Done (discovery pre-técnico) |
| `/pbi:prd` | `{id}` | Product Requirements Document |

## ⚙️ SDD — Spec-Driven Development (5)

| Comando | Params | Descripción |
|---|---|---|
| `/spec:generate` | `{task_id}` | Spec ejecutable desde Task de Azure DevOps |
| `/spec:implement` | `{spec_file}` | Implementar Spec (agente Claude o humano) |
| `/spec:review` | `{spec_file}` | Revisar calidad o validar implementación |
| `/spec:status` | — | Dashboard de Specs del sprint |
| `/agent:run` | `{spec_file}` | Lanzar agente Claude sobre Spec |

## 🔍 Calidad y PRs (4)

| Comando | Params | Descripción |
|---|---|---|
| `/pr:review` | `[PR]` (opcional) | Revisión 5 perspectivas: BA, Dev, QA, Sec, DevOps |
| `/pr:pending` | `--project {p}` (opc.) | PRs del PM pendientes: votos, comentarios, antigüedad |
| `/evaluate:repo` | `[URL]` | Auditoría seguridad/calidad de repo externo |
| `/changelog:update` | — | CHANGELOG.md desde commits convencionales |

## 👥 Equipo y Onboarding (3)

| Comando | Params | Descripción |
|---|---|---|
| `/team:privacy-notice` | `{nombre}` `--project {p}` | Nota RGPD (obligatoria antes de evaluar) |
| `/team:onboarding` | `{nombre}` `--project {p}` | Guía: contexto + tour del código (Fases 1-2) |
| `/team:evaluate` | `{nombre}` `--project {p}` | Competencias → perfil expertise en equipo.md |

## 🏗️ Infraestructura y Entornos (7)

| Comando | Params | Descripción |
|---|---|---|
| `/infra:detect` | `{proy}` `{env}` | Detectar infra existente en un entorno |
| `/infra:plan` | `{proy}` `{env}` | Plan IaC (Terraform/CLI) para un entorno |
| `/infra:estimate` | `{proy}` | Costes mensuales estimados por entorno |
| `/infra:scale` | `{recurso}` | Proponer escalado (aprobación humana) |
| `/infra:status` | `{proy}` | Estado actual de la infra del proyecto |
| `/env:setup` | `{proy}` | Configurar entornos (DEV/PRE/PRO) |
| `/env:promote` | `{proy}` `{orig}` `{dest}` | Promover deploy (PRE→PRO = aprobación) |

## 🔧 Utilidades (2)

| Comando | Params | Descripción |
|---|---|---|
| `/context:load` | — | Inicializar sesión: CLAUDE.md, git, commits, tools |
| `/help` | `[filtro]` (opc.) | Esta ayuda. Filtros: sprint, pbi, sdd, pr, team, infra, --setup |

## Ejemplos rápidos por escenario

```
Empezar el día:       /context:load → /sprint:status → /pr:pending
Sprint Planning:      /sprint:plan → /pbi:plan-sprint
Revisar un PR:        /pr:review 42
Nuevo miembro:        /team:privacy-notice "Ana" --project Alpha → /team:onboarding "Ana" --project Alpha
Crear infraestructura:/infra:detect Alpha DEV → /infra:plan Alpha DEV → /infra:estimate Alpha
Generar informe:      /report:executive
```
