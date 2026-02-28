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

**Sistema de memoria inteligente** — reglas de lenguaje con auto-carga por tipo de fichero (`paths:` frontmatter), auto memory persistente por proyecto, soporte para proyectos externos vía symlinks y `--add-dir`. Memory store persistente (JSONL) con búsqueda, deduplicación por hash, topic_key para decisiones que evolucionan, filtrado de `<private>` tags, e inyección automática de contexto tras compactación. Skills y agentes usan progressive disclosure (`references/`) con metadata `context_cost` para optimizar el consumo de contexto.

**Hooks programáticos** — 12 hooks que refuerzan reglas críticas automáticamente: bloqueo de force push, detección de secrets, prevención de operaciones destructivas de infra, auto-lint tras edición, quality gates antes de finalizar, scope guard que detecta ficheros modificados fuera del alcance de la spec SDD, e inyección de memoria persistente tras compactación. Configurados en `.claude/settings.json`.

**Agentes con capacidades avanzadas** — cada subagente tiene memoria persistente (`memory: project`), skills precargados, modo de permisos apropiado, y los developer agents usan `isolation: worktree` para implementación paralela sin conflictos. Soporte experimental para Agent Teams (lead + teammates).

**Coordinación multi-agente** — sistema de agent-notes para memoria inter-agente persistente, TDD gate que bloquea implementación sin tests previos, security review pre-implementación (OWASP en la spec, no solo en el código), Architecture Decision Records (ADR) para decisiones trazables, y reglas de serialización de scope para sesiones paralelas seguras.

**Code Review automatizado** — hook pre-commit que analiza ficheros staged contra reglas de dominio (REJECT/REQUIRE/PREFER), con caché SHA256 que evita re-revisar ficheros sin cambios. Guardian angel integrado en el flujo de commit.

**Seguridad y compliance** — análisis SAST contra OWASP Top 10, auditoría de vulnerabilidades en dependencias, generación de SBOM (CycloneDX), escaneo de credenciales en historial git, y detección mejorada de leaks (AWS, GitHub, OpenAI, Azure, JWT).

**Validación y CI/CD** — plan gate que avisa si se implementa sin spec aprobada, validación de tamaño de ficheros (≤150 líneas), schema de frontmatter y settings.json, y pipeline CI con checks automáticos en cada PR.

**Analítica predictiva** — predicción de completitud de sprint con Monte Carlo, Value Stream Mapping con Lead Time E2E y Flow Efficiency, tendencia de velocity con detección de anomalías, y WIP aging con alertas. Métricas basadas en datos, no en sensaciones.

**Observabilidad de agentes** — trazas de ejecución con tokens consumidos, duración y resultado, estimación de costes por modelo (Opus/Sonnet/Haiku), y métricas de eficiencia (success rate, re-work, first-pass). Hook automático que registra cada invocación de subagente.

**Developer Experience** — encuestas DX Core 4 adaptadas, dashboard automatizado con feedback loops y cognitive load proxy, y análisis de friction points con recomendaciones accionables. Mide la experiencia del equipo, no solo la velocidad.

**Gobernanza IA y compliance** — model cards documentando agentes y modelos, evaluación de riesgo según EU AI Act (prohibido/alto/limitado/mínimo), logs de auditoría con trazabilidad completa, y reglas de gobernanza con checklist de compliance trimestral.

**Inteligencia de deuda técnica** — análisis automático de hotspots, coupling temporal y code smells, priorización por impacto de negocio con modelo de scoring (proximity × churn × velocity × risk), y presupuesto de deuda por sprint con proyección de impacto en velocity.

**Architecture Intelligence** — detección automática de patrones de arquitectura (Clean, Hexagonal, DDD, CQRS, MVC/MVVM, Microservices, Event-Driven) en repositorios de cualquier lenguaje, sugerencias de mejora priorizadas por impacto, recomendación de arquitectura para proyectos nuevos basada en requisitos, fitness functions para verificar integridad arquitectónica, y comparativas entre patrones para toma de decisiones. Catálogo de referencia con patrones específicos para los 16 lenguajes soportados.

**Modo emergencia (LLM local)** — plan de contingencia para operar sin conexión cloud. Scripts de setup automático de Ollama con detección de hardware (RAM/GPU), descarga de modelo recomendado (Qwen 2.5), y configuración transparente de Claude Code. Operaciones PM offline sin LLM (resumen git, snapshot del board, checklists Scrum). Documentación de emergencia paso a paso en español e inglés.

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
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | 117 comandos + 24 agentes especializados |
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
| [Sistema de memoria](docs/memory-system.md) | Auto-carga, auto memory, symlinks, `--add-dir` |
| [Agent Teams SDD](docs/agent-teams-sdd.md) | Implementación paralela con lead + teammates |
| [Agent Notes Protocol](docs/agent-notes-protocol.md) | Memoria inter-agente, handoffs, trazabilidad |
| [Guía de emergencia](docs/EMERGENCY.md) | Modo offline con LLM local, scripts de contingencia |

---

## Referencia rápida de comandos

> 125 comandos · 24 agentes · 16 skills — referencia completa en [docs/readme/12-comandos-agentes.md](docs/readme/12-comandos-agentes.md)

### Inteligencia de Deuda Técnica
```
/debt-analyze    /debt-prioritize    /debt-budget
```

### Gobernanza IA
```
/ai-model-card    /ai-risk-assessment    /ai-audit-log
```

### Sprint y Reporting
```
/sprint-status    /sprint-plan    /sprint-review    /sprint-retro
/sprint-release-notes    /report-hours    /report-executive    /report-capacity
/team-workload    /board-flow    /kpi-dashboard    /kpi-dora
/sprint-forecast    /flow-metrics    /velocity-trend
```

### PBI y SDD
```
/pbi-decompose {id}    /pbi-decompose-batch {ids}    /pbi-assign {id}
/pbi-plan-sprint    /pbi-jtbd {id}    /pbi-prd {id}
/spec-generate {id}    /spec-explore {id}    /spec-design {spec}
/spec-implement {spec}    /spec-review {file}    /spec-verify {spec}
/spec-status    /agent-run {file}
```

### Repositorios, PRs y Pipelines
```
/repos-list    /repos-branches {repo}    /repos-search {query}
/repos-pr-create    /repos-pr-list    /repos-pr-review {pr}
/pr-review [PR]    /pr-pending
/pipeline-status    /pipeline-run {pipe}    /pipeline-logs {id}
/pipeline-artifacts {id}    /pipeline-create {repo}
```

### Infraestructura y Entornos
```
/infra-detect {proy} {env}    /infra-plan {proy} {env}    /infra-estimate {proy}
/infra-scale {recurso}    /infra-status {proy}
/env-setup {proy}    /env-promote {proy} {origen} {destino}
```

### Proyectos y Planificación
```
/project-kickoff {nombre}    /project-assign {nombre}    /project-audit {nombre}
/project-roadmap {nombre}    /project-release-plan {nombre}
/epic-plan {proy}    /backlog-capture    /retro-actions
```

### Memoria y Contexto
```
/memory-sync    /memory-save    /memory-search    /memory-context
/context-load    /session-save    /help [filtro]
```

### Seguridad y Auditoría
```
/security-review {spec}    /security-audit    /security-alerts
/credential-scan    /dependencies-audit    /sbom-generate
```

### Calidad y Validación
```
/changelog-update    /evaluate-repo [URL]    /validate-filesize
/validate-schema    /review-cache-stats    /review-cache-clear
/testplan-status    /testplan-results {id}
```

### Developer Experience
```
/dx-survey    /dx-dashboard    /dx-recommendations
```

### Observabilidad de Agentes
```
/agent-trace    /agent-cost    /agent-efficiency
```

### Equipo y Onboarding
```
/team-onboarding {nombre}    /team-evaluate {nombre}    /team-privacy-notice {nombre}
```

### Architecture Intelligence
```
/arch-detect {repo|path}    /arch-suggest {repo|path}    /arch-recommend {reqs}
/arch-fitness {repo|path}    /arch-compare {patrón1} {patrón2}
```

### Arquitectura y Diagramas
```
/adr-create {proy} {título}    /agent-notes-archive {proy}
/diagram-generate {proy}    /diagram-import {fichero}
/diagram-config    /diagram-status
/debt-track    /dependency-map    /legacy-assess    /risk-log
```

### Emergencia
```
/emergency-plan [--model MODEL]    /emergency-mode {setup|status|activate|deactivate|test}
```

### Integraciones Externas
```
/jira-sync    /linear-sync    /notion-sync    /confluence-publish
/wiki-publish    /wiki-sync    /slack-search    /notify-slack
/notify-whatsapp    /whatsapp-search    /notify-nctalk    /nctalk-search
/figma-extract    /gdrive-upload    /github-activity    /github-issues
/sentry-bugs    /sentry-health    /inbox-check    /inbox-start
/worktree-setup {spec}
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
8. **Comandos**: validar con `scripts/validate-commands.sh` antes de commit
9. **Paralelo**: verificar solapamiento de scope antes de lanzar Agent Teams; serializar si hay conflicto

---

*PM-Workspace — Estrategia Claude Code + Azure DevOps para equipos multi-lenguaje/Scrum con soporte de infraestructura cloud*
