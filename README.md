<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

🌐 [English version](README.en.md) · **Español**

# PM-Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> 🦉 **Soy Savia**, la buhita de pm-workspace. Me encargo de que tus proyectos fluyan: gestiono sprints, backlog, informes, agentes de código e infraestructura cloud — todo desde Claude Code, en **cualquier lenguaje**, con Scrum y Azure DevOps.

> **🚀 ¿Primera vez aquí?** Consulta la [Guía de Adopción para Consultoras](docs/ADOPTION_GUIDE.md) — paso a paso desde el registro en Claude hasta la incorporación de proyectos y equipo.

---

## ¿Quién soy?

Soy Savia — tu PM / Scrum Master automatizada para proyectos en Azure DevOps. Cuando me instalas, lo primero que hago es presentarme y conocerte: tu nombre, tu rol, cómo trabajas, qué herramientas usas. Me adapto a ti, no al revés.

Trabajo con 16 lenguajes (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) y tengo convenciones, reglas y agentes especializados para cada uno.

**Gestión de sprints** — Llevo el control del burndown, la capacity del equipo, el estado del board, los KPIs, y genero informes automáticos en Excel y PowerPoint.

**Descomposición de PBIs** — Analizo el backlog, descompongo PBIs en tasks con estimación, detecto problemas de carga y propongo asignaciones con scoring (expertise × disponibilidad × balance × crecimiento).

**Spec-Driven Development (SDD)** — Las tasks se convierten en specs ejecutables. Un "developer" puede ser humano o agente Claude. Implemento handlers, repositorios y unit tests en el lenguaje del proyecto.

**Infraestructura como Código** — Gestiono multi-cloud (Azure, AWS, GCP) con detección automática de recursos, creación al tier más bajo, y escalado solo con tu aprobación.

**Multi-entorno** — Soporte para DEV/PRE/PRO (configurable) con protección de secrets — las connection strings nunca van al repositorio.

**Sistema de memoria inteligente** — Tengo reglas de lenguaje con auto-carga por tipo de fichero, auto memory persistente por proyecto, soporte para proyectos externos vía symlinks y `--add-dir`. Mi memory store (JSONL) tiene búsqueda, deduplicación por hash, topic_key para decisiones que evolucionan, filtrado de `<private>` tags, e inyección automática de contexto tras compactación. Mis skills y agentes usan progressive disclosure con metadata `context_cost` para optimizar el consumo de contexto.

**Hooks programáticos** — 12 hooks que refuerzan reglas críticas automáticamente: bloqueo de force push, detección de secrets, prevención de operaciones destructivas de infra, auto-lint tras edición, quality gates antes de finalizar, scope guard que detecta ficheros modificados fuera del alcance de la spec SDD, e inyección de memoria persistente tras compactación.

**Agentes con capacidades avanzadas** — Cada subagente tiene memoria persistente, skills precargados, modo de permisos apropiado, y los developer agents usan `isolation: worktree` para implementación paralela sin conflictos. Soporte experimental para Agent Teams (lead + teammates).

**Coordinación multi-agente** — Sistema de agent-notes para memoria inter-agente persistente, TDD gate que bloquea implementación sin tests previos, security review pre-implementación (OWASP en la spec, no solo en el código), Architecture Decision Records (ADR) para decisiones trazables, y reglas de serialización de scope para sesiones paralelas seguras.

**Code Review automatizado** — Hook pre-commit que analiza ficheros staged contra reglas de dominio (REJECT/REQUIRE/PREFER), con caché SHA256 que evita re-revisar ficheros sin cambios. Guardian angel integrado en el flujo de commit.

**Seguridad y compliance** — Análisis SAST contra OWASP Top 10, auditoría de vulnerabilidades en dependencias, generación de SBOM (CycloneDX), escaneo de credenciales en historial git, y detección mejorada de leaks (AWS, GitHub, OpenAI, Azure, JWT).

**Validación de Azure DevOps** — Cuando conectas un proyecto, audito automáticamente la configuración contra mi "Agile ideal": process template, tipos de work item, estados, campos, jerarquía de backlog e iteraciones. Si hay incompatibilidades, genero un plan de remediación para que tú lo apruebes.

**Validación y CI/CD** — Plan gate que avisa si se implementa sin spec aprobada, validación de tamaño de ficheros (≤150 líneas), schema de frontmatter y settings.json, y pipeline CI con checks automáticos en cada PR.

**Analítica predictiva** — Predicción de completitud de sprint con Monte Carlo, Value Stream Mapping con Lead Time E2E y Flow Efficiency, tendencia de velocity con detección de anomalías, y WIP aging con alertas. Métricas basadas en datos, no en sensaciones.

**Observabilidad de agentes** — Trazas de ejecución con tokens consumidos, duración y resultado, estimación de costes por modelo (Opus/Sonnet/Haiku), y métricas de eficiencia (success rate, re-work, first-pass). Hook automático que registra cada invocación de subagente.

**Developer Experience** — Encuestas DX Core 4 adaptadas, dashboard automatizado con feedback loops y cognitive load proxy, y análisis de friction points con recomendaciones accionables. Mido la experiencia del equipo, no solo la velocidad.

**Gobernanza IA y compliance** — Model cards documentando agentes y modelos, evaluación de riesgo según EU AI Act, logs de auditoría con trazabilidad completa, y reglas de gobernanza con checklist de compliance trimestral.

**Inteligencia de deuda técnica** — Análisis automático de hotspots, coupling temporal y code smells, priorización por impacto de negocio con modelo de scoring, y presupuesto de deuda por sprint con proyección de impacto en velocity.

**Architecture Intelligence** — Detecto patrones de arquitectura (Clean, Hexagonal, DDD, CQRS, MVC/MVVM, Microservices, Event-Driven) en repositorios de cualquier lenguaje, sugiero mejoras priorizadas por impacto, recomiendo arquitectura para proyectos nuevos, verifico integridad con fitness functions, y comparo patrones para toma de decisiones.

**Modo emergencia (LLM local)** — Plan de contingencia para operar sin conexión cloud. Scripts de setup automático de Ollama con detección de hardware, descarga de modelo recomendado (Qwen 2.5), y configuración transparente de Claude Code. Operaciones PM offline sin LLM. Documentación de emergencia en español e inglés.

**Inteligencia de Compliance Regulatorio** — Escaneo automatizado de cumplimiento normativo en 12 sectores regulados. Algoritmo de auto-detección de sector en 5 fases calibradas. Detecto violaciones HIPAA/PCI, fallos de retención, auditoría incompleta, cifrado débil, acceso mal configurado. Auto-fix con re-verificación post-aplicación.

**Auditoría de Rendimiento** — Análisis estático de rendimiento sin ejecución de código. Detecto funciones pesadas por complejidad ciclomática + cognitiva, anti-patrones de async por lenguaje, hotspots con estimación de O() y N+1 queries. Workflow test-first: creo characterization tests antes de optimizar.

**Perfiles de usuario y modo agente** — Cuando llegas por primera vez, me presento y te conozco en una conversación natural. Guardo tu perfil fragmentado (identidad, workflow, herramientas, proyectos, preferencias, tono) y cargo solo lo necesario en cada operación. También hablo con agentes externos (OpenClaw y similares) en modo máquina-a-máquina: output estructurado YAML/JSON, sin narrativa, solo datos y códigos de estado.

**Comunidad y colaboración** — Te animo a contribuir mejoras, reportar bugs o proponer ideas. Con `/contribute` puedes crear PRs directamente al repositorio, y con `/feedback` abrir issues. Antes de enviar cualquier cosa, valido que no haya datos privados (PATs, emails corporativos, nombres de proyecto, IPs) — tu privacidad es lo primero.

**Backup cifrado en la nube** — Con `/backup` cifro tus perfiles, configuraciones y PATs con AES-256-CBC (PBKDF2, 100k iteraciones) antes de subirlos a NextCloud o Google Drive. Rotación automática de 7 backups. Si pierdes tu máquina, un solo comando restaura todo tras un clone fresco.

**Rutina diaria adaptativa** — Con `/daily-routine` te propongo la rutina del día según tu rol (PM, Tech Lead, QA, Product Owner, Developer, CEO/CTO). Cada rol ve los comandos más relevantes en el orden correcto. También puedes usar `/health-dashboard` para ver un dashboard de salud del proyecto adaptado a tu perspectiva, con scoring compuesto y alertas priorizadas.

**Optimización de contexto** — Con `/context-optimize` analizo cómo usas pm-workspace y te sugiero optimizaciones al context-map. Con `/context-age` comprimo y archivo decisiones antiguas aplicando envejecimiento semántico (episódico → comprimido → archivado). Con `/context-benchmark` verifico empíricamente que la información crítica está bien posicionada en el contexto. Con `/hub-audit` audito la topología de dependencias entre reglas, comandos y agentes para detectar hubs críticos y reglas huérfanas.

**Informes ejecutivos** — Con `/ceo-report` genero informes multi-proyecto para dirección con semáforo de portfolio, métricas clave y recomendaciones. Con `/ceo-alerts` filtro solo las alertas que requieren decisión de nivel directivo. Con `/portfolio-overview` muestro una vista bird's-eye de todos los proyectos con dependencias.

**Toolkit QA** — Con `/qa-dashboard` tengo un panel de calidad con cobertura, tests flaky, bugs y escape rate. Con `/qa-regression-plan` analizo el impacto de cambios y recomiendo qué tests ejecutar. Con `/qa-bug-triage` ayudo a clasificar bugs por severidad y detectar duplicados. Con `/testplan-generate` genero planes de pruebas desde specs SDD o PBIs.

**Productividad del desarrollador** — Con `/my-sprint` muestro tu vista personal del sprint con items asignados y cycle time. Con `/my-focus` identifico tu item más prioritario y cargo todo su contexto. Con `/my-learning` detecto oportunidades de mejora analizando tu código. Con `/code-patterns` documento los patterns del proyecto con ejemplos reales.

**Inteligencia para Tech Lead** — Con `\`/tech-radar\`` mapeo el stack tecnológico con categorización adopt/trial/hold/retire. Con `\`/team-skills-matrix\`` construyo la matriz de competencias del equipo con bus factor y sugerencias de pair programming. Con `\`/arch-health\`` mido la salud arquitectónica con fitness functions, drift detection y métricas de acoplamiento. Con `\`/incident-postmortem\`` estructuro postmortems blameless con timeline y root cause analysis.

**Product Owner Analytics** — Con `/value-stream-map` mapeo el flujo de valor end-to-end detectando cuellos de botella. Con `/feature-impact` analizo el impacto de features en ROI, engagement y carga técnica. Con `/stakeholder-report` genero reportes ejecutivos para stakeholders con métricas de entrega y alineación de objetivos. Con `/release-readiness` verifico que una release está lista: capacidad técnica, riesgos mitigados, comunicación preparada.

**Detección de verticales** — Detecto automáticamente si tu proyecto pertenece a un sector no-software (sanidad, legal, industrial, agrícola, educación, finanzas...) usando un algoritmo de 5 fases con scoring calibrado. Si el score es suficiente, te propongo crear extensiones especializadas con reglas, flujos y entidades de dominio para tu sector.

---

## Documentación

He organizado toda la documentación en secciones para que encuentres rápido lo que necesitas:

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
| [Comandos y agentes](docs/readme/12-comandos-agentes.md) | 135 comandos + 24 agentes especializados |
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

> 181 comandos · 24 agentes · 20 skills — referencia completa en [docs/readme/12-comandos-agentes.md](docs/readme/12-comandos-agentes.md)

### Perfil de Usuario, Actualización y Comunidad
```
/profile-setup    /profile-edit    /profile-switch    /profile-show
/update {check|install|auto-on|auto-off|status}
/contribute {pr|idea|bug|status}    /feedback {bug|idea|improve|list|search}
/vertical-propose {nombre}
/review-community {pending|review|merge|release|summary}
/backup {now|restore|auto-on|auto-off|status}
/daily-routine    /health-dashboard {proyecto|all|trend}
/context-optimize {stats|reset|apply}
/context-age {status|apply}    /context-benchmark {quick|history}
/hub-audit {quick|update}
/ceo-report {proyecto|--format md|pdf|pptx}
/ceo-alerts {proyecto|--history}    /portfolio-overview {--compact|--deps}
/qa-dashboard {proyecto|--trend}    /qa-regression-plan {branch|--pr}
/qa-bug-triage {bug-id|--backlog}    /testplan-generate {spec|--pbi|--sprint}

### Productividad del Desarrollador
```
/my-sprint {--all|--history}    /my-focus {--next|--list}
/my-learning {--quick|--topic}    /code-patterns {pattern|--new}
```

### Inteligencia para Tech Lead
```
/tech-radar {proyecto|--outdated}    /team-skills-matrix {--bus-factor|--pairs}
/arch-health {--drift|--coupling}    /incident-postmortem {desc|--from-alert|--list}
```

### Product Owner Analytics
```
/value-stream-map {--bottlenecks}    /feature-impact {--roi}
/stakeholder-report    /release-readiness
```

### Cross-Project Intelligence
```
/portfolio-deps {--critical}    /backlog-patterns
/org-metrics {--trend 6}    /cross-project-search {query}
```

### AI-Powered Planning
```
/sprint-autoplan {--conservative}    /risk-predict {--sprint N}
/meeting-summarize {--type daily}    /capacity-forecast {--sprints 6}
```

### Integration Hub
```
/mcp-server {start|stop}    /nl-query {pregunta}
/webhook-config {add|list}    /integration-status {--check}
```

### Multi-Platform
```
/jira-connect {setup|sync|map}    /github-projects {connect|board}
/linear-sync {setup|pull|push}    /platform-migrate {plan|execute}
```

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
/testplan-status    /testplan-results {id}    /devops-validate {proy}
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

### Inteligencia de Compliance Regulatorio
```
/compliance-scan {repo|path}       /compliance-fix {repo|path}       /compliance-report {repo|path}
```

### Auditoría de Rendimiento
```
/perf-audit {path}                 /perf-fix {PA-NNN}                 /perf-report {path}
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

Estas son las reglas que nunca se saltan — ni yo misma:

1. **NUNCA hardcodear el PAT** — siempre `$(cat $PAT_FILE)`
2. **Confirmar antes de escribir** en Azure DevOps — pregunto antes de modificar datos
3. **Leer CLAUDE.md del proyecto** antes de actuar sobre él
4. **SDD**: NUNCA lanzar agente sin Spec aprobada; Code Review SIEMPRE humano
5. **Secrets**: NUNCA connection strings, API keys o passwords en el repositorio
6. **Infraestructura**: NUNCA `terraform apply` en PRE/PRO sin aprobación humana; siempre tier mínimo
7. **Git**: NUNCA commit directo en `main` — siempre rama + PR
8. **Comandos**: validar con `scripts/validate-commands.sh` antes de commit
9. **Paralelo**: verificar solapamiento de scope antes de lanzar Agent Teams; serializar si hay conflicto

---

*🦉 Savia — PM-Workspace, tu PM automatizada con Claude Code + Azure DevOps para equipos multi-lenguaje/Scrum*
