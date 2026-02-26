<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

🌐 [English version](README.en.md) · **Español**

# PM-Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> Sistema de gestión de proyectos **multi-lenguaje** con Scrum, impulsado por Claude Code como asistente de PM/Scrum Master con capacidad de delegar implementación técnica a agentes de IA y gestionar infraestructura cloud.

> **🚀 ¿Primera vez aquí?** Consulta la [Guía de Adopción para Consultoras](docs/ADOPTION_GUIDE.md) — paso a paso desde el registro en Claude hasta la incorporación de proyectos y equipo.

---

## ¿Qué es esto?

Este workspace convierte a Claude Code en un **Project Manager / Scrum Master automatizado** para proyectos de **cualquier lenguaje** en Azure DevOps. Soporta 16 lenguajes (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) con convenciones, reglas y agentes especializados para cada uno.

**Gestión de sprints** — seguimiento de burndown, capacity del equipo, estado del board, KPIs, reportes automáticos en Excel/PowerPoint.

**Descomposición de PBIs** — analiza backlog, descompone PBIs en tasks con estimación, detecta balance de carga y propone asignaciones con scoring (expertise × disponibilidad × balance × crecimiento).

**Spec-Driven Development (SDD)** — las tasks se convierten en specs ejecutables. Un "developer" puede ser humano o agente Claude. Implementación automática de handlers, repositorios, unit tests en el lenguaje del proyecto.

**Infraestructura como Código** — gestión multi-cloud (Azure, AWS, GCP) con detección automática de recursos, creación al tier más bajo, y escalado solo con aprobación humana.

**Multi-entorno** — soporte para DEV/PRE/PRO (configurable) con protección de secrets — las connection strings nunca van al repositorio.

---

## Documentación

La documentación completa está organizada en secciones para facilitar la consulta:

### Empezar

| Sección | Descripción |
|---|---|
| [Introducción y ejemplo rápido](docs/readme/01-introduccion.md) | Primeros 5 minutos con el workspace |
| [Estructura del workspace](docs/readme/02-estructura.md) | Directorios, ficheros y organización |
| [Configuración inicial](docs/readme/03-configuracion.md) | PAT, constantes, dependencias, verificación |
| [Guía de adopción](docs/ADOPTION_GUIDE.md) | Paso a paso para consultoras |

### Uso diario

| Sección | Descripción |
|---|---|
| [Sprints e informes](docs/readme/04-uso-sprint-informes.md) | Gestión de sprint, reporting, workload, KPIs |
| [Spec-Driven Development](docs/readme/05-sdd.md) | SDD completo: specs, agentes, patrones de equipo |
| [Configuración avanzada](docs/readme/06-configuracion-avanzada.md) | Pesos de asignación, config SDD por proyecto |

### Infraestructura y despliegue

| Sección | Descripción |
|---|---|
| [Infraestructura del proyecto](docs/readme/07-infraestructura.md) | Definir compute, bases de datos, API gateways, storage |
| [Pipelines (PR y CI/CD)](docs/readme/08-pipelines.md) | Definir pipelines de validación y despliegue |

### Referencia

| Sección | Descripción |
|---|---|
| [Proyecto de test](docs/readme/09-proyecto-test.md) | `sala-reservas`: tests, datos mock, validación |
| [KPIs, reglas y roadmap](docs/readme/10-kpis-reglas.md) | Métricas, reglas críticas, plan de adopción |
| [Onboarding de nuevos miembros](docs/readme/11-onboarding.md) | Incorporación en 5 fases, evaluación de competencias, RGPD |
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | 37 comandos + 23 agentes especializados |
| [Cobertura y contribución](docs/readme/13-cobertura-contribucion.md) | Qué cubre, qué no, cómo contribuir |

### Otros documentos

| Documento | Descripción |
|---|---|
| [Best practices Claude Code](docs/best-practices-claude-code.md) | Buenas prácticas de uso |
| [Guía incorporación de lenguajes](docs/guia-incorporacion-lenguajes.md) | Cómo añadir soporte para nuevos lenguajes |
| [Reglas Scrum](docs/reglas-scrum.md) | Reglas de gestión Scrum del workspace |
| [Política de estimación](docs/politica-estimacion.md) | Criterios de estimación |
| [KPIs de equipo](docs/kpis-equipo.md) | Definición de KPIs |
| [Plantillas de informes](docs/plantillas-informes.md) | Templates para reporting |
| [Flujo de trabajo](docs/flujo-trabajo.md) | Workflow completo |

---

## Referencia rápida de comandos

### Sprint y Reporting
```
/sprint:status    /sprint:plan    /sprint:review    /sprint:retro
/report:hours     /report:executive    /report:capacity
/team:workload    /board:flow    /kpi:dashboard
```

### PBI y SDD
```
/pbi:decompose {id}    /pbi:plan-sprint    /pbi:assign {id}
/spec:generate {id}    /spec:review {file}    /agent:run {file}
/spec:status    /pbi:jtbd {id}    /pbi:prd {id}
```

### Infraestructura y Entornos
```
/infra:detect {proy} {env}    /infra:plan {proy} {env}    /infra:estimate {proy}
/infra:scale {recurso}        /infra:status {proy}
/env:setup {proy}             /env:promote {proy} {origen} {destino}
```

### Calidad y Equipo
```
/pr:review [PR]    /pr:pending    /context:load    /changelog:update    /evaluate:repo [URL]
/team:onboarding {nombre}    /team:evaluate {nombre}    /team:privacy-notice {nombre}
/help [filtro]
```

---

## Reglas Críticas

1. **NUNCA hardcodear el PAT** — siempre `$(cat $PAT_FILE)`
2. **Confirmar antes de escribir** en Azure DevOps — preguntar si modifica datos
3. **Leer CLAUDE.md del proyecto** antes de actuar sobre él
4. **SDD**: NUNCA lanzar agente sin Spec aprobada; Code Review SIEMPRE humano
5. **Secrets**: NUNCA connection strings, API keys o passwords en el repositorio
6. **Infraestructura**: NUNCA `terraform apply` en PRE/PRO sin aprobación humana; siempre tier mínimo
7. **Git**: NUNCA commit directo en `main` — siempre rama + PR

---

*PM-Workspace — Estrategia Claude Code + Azure DevOps para equipos multi-lenguaje/Scrum con soporte de infraestructura cloud*
