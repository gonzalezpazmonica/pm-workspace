# Referencia Rápida de Comandos

## Sprint y Reporting (15 comandos)
```
/sprint-status [--project]        Estado del sprint con alertas
/sprint-plan [--project]          Asistente de Sprint Planning
/sprint-review [--project]        Resumen para Sprint Review
/sprint-retro [--project]         Retrospectiva con datos
/sprint-release-notes [--project] Generar release notes del sprint
/report-hours [--project]         Informe de horas (Excel)
/report-executive                 Informe multi-proyecto (PPT/Word)
/report-capacity [--project]      Estado de capacidades del equipo
/team-workload [--project]        Carga por persona
/board-flow [--project]           Cycle time y cuellos de botella
/kpi-dashboard [--project]        Dashboard KPIs completo
/kpi-dora [--project]             Métricas DORA (deploy freq, lead time, MTTR, change fail)
/sprint-forecast [--project]      Predicción de completitud con Monte Carlo
/flow-metrics [--project]         Value Stream dashboard (Lead Time, Flow Efficiency, WIP)
/velocity-trend [--project]       Tendencia de velocity y detección de anomalías
```

## Gobernanza IA (3 comandos)
```
/ai-model-card [--project]        Model card de agentes IA del proyecto
/ai-risk-assessment [--project]   Evaluación de riesgo EU AI Act
/ai-audit-log [--project]         Log de auditoría de ejecuciones IA
```

## PBI y Decomposition (6 comandos)
```
/pbi-decompose {id}               Descomponer un PBI en tasks
/pbi-decompose-batch {id1,id2}    Descomponer varios PBIs
/pbi-assign {pbi_id}              (Re)asignar tasks de un PBI
/pbi-plan-sprint                  Planning completo del sprint
/pbi-jtbd {id}                    Generar JTBD (Jobs to be Done)
/pbi-prd {id}                     Generar PRD (Product Requirements)
```

## Spec-Driven Development (8 comandos)
```
/spec-generate {task_id}          Generar Spec desde Task de Azure DevOps
/spec-explore {id}                Exploración pre-spec del codebase
/spec-design {spec}               Diseño técnico a partir de spec
/spec-implement {spec_file}       Implementar Spec (agente o humano)
/spec-review {spec_file}          Revisar calidad de Spec o implementación
/spec-verify {spec}               Verificar implementación vs spec (Given/When/Then)
/spec-status [--project]          Dashboard de Specs del sprint
/agent-run {spec_file} [--team]   Lanzar agente Claude sobre una Spec
```

## Repositorios y PRs (8 comandos)
```
/repos-list [--project]           Listar repositorios del proyecto
/repos-branches {repo}            Ramas activas de un repositorio
/repos-search {query}             Buscar en código fuente
/repos-pr-create {repo}           Crear Pull Request
/repos-pr-list [--project]        Listar PRs abiertas
/repos-pr-review {pr_id}          Revisar un PR de Azure DevOps
/pr-review [PR]                   Revisión multi-perspectiva (BA, Dev, QA, Sec, DevOps)
/pr-pending [--project]           PRs pendientes de revisión
```

## Pipelines CI/CD (5 comandos)
```
/pipeline-status [--project]      Estado de pipelines
/pipeline-run {pipeline}          Ejecutar un pipeline
/pipeline-logs {run_id}           Ver logs de ejecución
/pipeline-artifacts {run_id}      Descargar artefactos
/pipeline-create {repo}           Crear pipeline desde plantilla
```

## Infraestructura y Entornos (7 comandos)
```
/infra-detect {proyecto} {env}    Detectar infraestructura existente
/infra-plan {proyecto} {env}      Generar plan de infraestructura
/infra-estimate {proyecto}        Estimar costes por entorno
/infra-scale {recurso}            Proponer escalado (requiere aprobación humana)
/infra-status {proyecto}          Estado de infraestructura actual
/env-setup {proyecto}             Configurar entornos (DEV/PRE/PRO)
/env-promote {proyecto} {o} {d}   Promover entre entornos
```

## Proyectos y Planificación (7 comandos)
```
/project-kickoff {nombre}         Iniciar nuevo proyecto (estructura + Azure DevOps)
/project-assign {nombre}          Asignar equipo al proyecto
/project-audit {nombre}           Auditoría de salud del proyecto
/project-roadmap {nombre}         Generar roadmap visual
/project-release-plan {nombre}    Plan de releases
/epic-plan {proyecto}             Planificación multi-sprint de épicas
/backlog-capture                  Captura rápida de items al backlog
```

## Memoria y Contexto (6 comandos)
```
/memory-sync [--project]          Sincronizar insights en auto memory
/memory-save {tipo} {contenido}   Guardar en memoria persistente
/memory-search {query}            Buscar en memoria
/memory-context                   Inyectar contexto de memoria
/context-load                     Carga de contexto al iniciar sesión
/session-save                     Guardar decisiones antes de /clear
```

## Seguridad y Auditoría (5 comandos)
```
/security-review {spec}           Revisión OWASP pre-implementación
/security-audit [--project]       Análisis SAST contra OWASP Top 10
/security-alerts [--project]      Alertas de seguridad activas
/credential-scan [--project]      Escanear historial git por credenciales filtradas
/dependencies-audit [--project]   Auditoría de vulnerabilidades en dependencias
```

## Testing (2 comandos)
```
/testplan-status [--project]      Estado de test plans
/testplan-results {plan_id}       Resultados de ejecución de tests
```

## Calidad y Validación (7 comandos)
```
/changelog-update                 Actualizar CHANGELOG desde commits
/evaluate-repo [URL]              Auditoría de repo externo
/validate-filesize                Validar ≤150 líneas por fichero
/validate-schema                  Validar schema de frontmatter y settings
/review-cache-stats               Estadísticas de caché de code review
/review-cache-clear               Limpiar caché de code review
/sbom-generate [--project]        Generar SBOM (Software Bill of Materials)
```

## Developer Experience (3 comandos)
```
/dx-survey [--project]            Encuesta DX Core 4 adaptada
/dx-dashboard [--project]         Dashboard DX automatizado
/dx-recommendations [--project]   Friction points y recomendaciones
```

## Observabilidad de Agentes (3 comandos)
```
/agent-trace [--project]          Trazas de ejecución de agentes
/agent-cost [--project] [--sprint] Coste estimado por modelo y comando
/agent-efficiency [--project]     Métricas de eficiencia y re-work
```

## Equipo y Onboarding (3 comandos)
```
/team-onboarding {nombre}         Guía de onboarding personalizada
/team-evaluate {nombre}           Cuestionario de competencias
/team-privacy-notice {nombre}     Nota informativa RGPD
```

## Integraciones Externas (12 comandos)
```
/jira-sync {proyecto}             Sync Jira ↔ Azure DevOps
/linear-sync {proyecto}           Sync Linear ↔ Azure DevOps
/notion-sync {proyecto}           Sync documentación ↔ Notion
/confluence-publish {doc}         Publicar en Confluence
/wiki-publish {doc}               Publicar en Wiki de Azure DevOps
/wiki-sync [--project]            Sincronizar wiki
/slack-search {query}             Buscar en Slack
/notify-slack {canal} {msg}       Notificar en Slack
/notify-whatsapp {dest} {msg}     Notificar por WhatsApp
/whatsapp-search {query}          Buscar en WhatsApp
/notify-nctalk {sala} {msg}       Notificar en Nextcloud Talk
/nctalk-search {query}            Buscar en Nextcloud Talk
```

## Diagramas (4 comandos)
```
/diagram-generate {proyecto}      Generar diagrama de arquitectura
/diagram-import {fichero}         Importar diagrama → generar Work Items
/diagram-config                   Configurar herramientas de diagramas
/diagram-status [--project]       Estado de diagramas del proyecto
```

## Architecture Intelligence (5 comandos)
```
/arch-detect {repo|path}         Detectar patrón de arquitectura del proyecto
/arch-suggest {repo|path}        Sugerir mejoras de arquitectura priorizadas
/arch-recommend {requisitos}     Recomendar arquitectura para proyecto nuevo
/arch-fitness {repo|path}        Ejecutar fitness functions de arquitectura
/arch-compare {patrón1} {patrón2} Comparar dos patrones de arquitectura
```

## Inteligencia de Deuda Técnica (3 comandos)
```
/debt-analyze [--project]         Análisis automático de deuda (hotspots, coupling, smells)
/debt-prioritize [--project]      Priorización por impacto de negocio y ROI
/debt-budget [--sprint]           Presupuesto de deuda técnica por sprint
```

## Gobernanza IA (3 comandos)
```
/ai-model-card [--project]        Model card de agentes IA del proyecto
/ai-risk-assessment [--project]   Evaluación de riesgo EU AI Act
/ai-audit-log [--project]         Log de auditoría de ejecuciones IA
```

## Inteligencia de Compliance Regulatorio (3 comandos)
```
/compliance-scan {repo|path}     Escaneo automático de cumplimiento normativo en 12 sectores
/compliance-fix {repo|path}      Auto-fix de violaciones de compliance
/compliance-report {repo|path}   Informe de compliance por sector
```

## Emergencia (2 comandos)
```
/emergency-plan [--model MODEL]  Pre-descargar Ollama y modelo LLM para instalación offline
/emergency-mode {subcommand}     Gestionar modo emergencia con LLM local (setup/status/activate/deactivate/test)
```

## Otros (10+ comandos)
```
/help [filtro]                    Catálogo de comandos y primeros pasos
/adr-create {proyecto} {título}   Crear Architecture Decision Record
/agent-notes-archive {proy}       Archivar agent-notes del sprint
/debt-track [--project]           Seguimiento de deuda técnica
/dependency-map [--project]       Mapa de dependencias entre servicios
/legacy-assess {proyecto}         Evaluación de sistema legacy
/risk-log [--project]             Registro de riesgos del proyecto
/retro-actions [--project]        Seguimiento de acciones de retrospectiva
/worktree-setup {spec}            Configurar git worktree para implementación paralela
/inbox-check                      Revisar inbox de voz pendiente
/inbox-start                      Iniciar transcripción de buzón de voz
/figma-extract {url}              Extraer diseño desde Figma
/gdrive-upload {fichero}          Subir fichero a Google Drive
/github-activity [--project]      Actividad reciente en GitHub
/github-issues [--project]        Issues de GitHub
/sentry-bugs [--project]          Bugs desde Sentry → PBIs
/sentry-health [--project]        Salud técnica desde Sentry
```

---

## Equipo de Subagentes Especializados

El workspace incluye 24 subagentes que Claude puede invocar en paralelo o en secuencia,
cada uno optimizado para su tarea con el modelo LLM más adecuado:

**Agentes de gestión y arquitectura:**

| Agente | Modelo | Cuándo se usa |
|---|---|---|
| `architect` | Opus 4.6 | Diseño de arquitectura multi-lenguaje, asignación de capas, decisiones técnicas |
| `business-analyst` | Opus 4.6 | Análisis de PBIs, reglas de negocio, criterios de aceptación, JTBD, PRD |
| `sdd-spec-writer` | Opus 4.6 | Generación y validación de Specs SDD ejecutables |
| `code-reviewer` | Opus 4.6 | Quality gate: seguridad, SOLID, reglas del lenguaje (`{lang}-rules.md`) |
| `security-guardian` | Opus 4.6 | Auditoría de seguridad, secrets, y confidencialidad pre-commit |
| `infrastructure-agent` | Opus 4.6 | Infra multi-cloud: detectar, crear (tier mínimo), escalar (aprobación humana) |

**Agentes de desarrollo (Language Pack):**

| Agente | Modelo | Lenguajes |
|---|---|---|
| `dotnet-developer` | Sonnet 4.6 | C#/.NET, VB.NET |
| `typescript-developer` | Sonnet 4.6 | TypeScript/Node.js (NestJS, Express, Prisma) |
| `frontend-developer` | Sonnet 4.6 | Angular + React |
| `java-developer` | Sonnet 4.6 | Java/Spring Boot |
| `python-developer` | Sonnet 4.6 | Python (FastAPI, Django, SQLAlchemy) |
| `go-developer` | Sonnet 4.6 | Go |
| `rust-developer` | Sonnet 4.6 | Rust/Axum |
| `php-developer` | Sonnet 4.6 | PHP/Laravel |
| `mobile-developer` | Sonnet 4.6 | Swift/iOS, Kotlin/Android, Flutter |
| `ruby-developer` | Sonnet 4.6 | Ruby on Rails |
| `cobol-developer` | Opus 4.6 | Asistencia COBOL (documentación, copybooks, tests) |
| `terraform-developer` | Sonnet 4.6 | Terraform/IaC (NUNCA ejecuta apply) |

**Agentes de calidad y operaciones:**

| Agente | Modelo | Cuándo se usa |
|---|---|---|
| `test-engineer` | Sonnet 4.6 | Tests multi-lenguaje, TestContainers, cobertura |
| `test-runner` | Sonnet 4.6 | Post-commit: ejecución de tests, cobertura ≥ `TEST_COVERAGE_MIN_PERCENT` |
| `commit-guardian` | Sonnet 4.6 | Pre-commit: 10 checks (rama, security, build, tests, format, code review) |
| `tech-writer` | Haiku 4.5 | README, CHANGELOG, docs de proyecto |
| `azure-devops-operator` | Haiku 4.5 | WIQL, work items, sprint, capacity |
| `diagram-architect` | Sonnet 4.6 | Diseño de diagramas de arquitectura, C4, flujos de datos |

### Flujo SDD con agentes en paralelo

```
Usuario: /pbi-plan-sprint --project Alpha

  ┌─ business-analyst (Opus) ─────────────────┐
  │  Analiza PBIs candidatos                  │   EN PARALELO
  │  Verifica reglas de negocio               │
  └───────────────────────────────────────────┘
  ┌─ azure-devops-operator (Haiku) ───────────┐
  │  Obtiene sprint activo + capacidades      │   EN PARALELO
  └───────────────────────────────────────────┘
           ↓ (resultados combinados)
  ┌─ architect (Opus) ────────────────────────┐
  │  Asigna capas a cada task                 │
  │  Detecta dependencias técnicas            │
  │  Detecta Language Pack del proyecto       │
  └───────────────────────────────────────────┘
           ↓
  ┌─ sdd-spec-writer (Opus) ──────────────────┐
  │  Genera specs para tasks → agente         │
  └───────────────────────────────────────────┘
           ↓
  ┌─ {lang}-developer (Sonnet) ───┐  ┌─ test-engineer (Sonnet) ─┐
  │  Implementa tasks B, C, D     │  │  Escribe tests para E, F  │   EN PARALELO
  │  (agente según Language Pack)  │  │  (multi-lenguaje)         │
  └───────────────────────────────┘  └──────────────────────────┘
           ↓
  ┌─ commit-guardian (Sonnet) ────────────────┐
  │  10 checks: rama → security-guardian →    │
  │  build → tests → format → code-reviewer  │
  │  → README → CLAUDE.md → atomicidad →     │
  │  commit message                          │
  │                                          │
  │  Si code-reviewer RECHAZA:               │
  │    → {lang}-developer corrige            │
  │    → re-build → re-review (máx 2x)      │
  │  Si todo ✅ → git commit                 │
  └──────────────────────────────────────────┘
           ↓
  ┌─ test-runner (Sonnet) ──────────────────┐
  │  Ejecuta TODOS los tests del proyecto   │
  │  afectado por el commit                 │
  │                                         │
  │  Si tests fallan:                       │
  │    → {lang}-developer corrige (máx 2x)  │
  │  Si tests pasan → verifica cobertura    │
  │    ≥ TEST_COVERAGE_MIN_PERCENT → ✅     │
  │    < TEST_COVERAGE_MIN_PERCENT →        │
  │      architect (análisis gaps) →        │
  │      business-analyst (casos test) →    │
  │      {lang}-developer (implementa)      │
  └─────────────────────────────────────────┘
```

### Flujo de Infraestructura

```
PM: /infra-plan {proyecto} {env}

  ┌─ architect (Opus) ────────────────────────┐
  │  Define requisitos técnicos               │
  │  Lee infrastructure_config del proyecto   │
  └───────────────────────────────────────────┘
           ↓
  ┌─ infrastructure-agent (Opus) ─────────────┐
  │  1. DETECTAR: ¿recurso ya existe?         │
  │     └─ az/aws/gcloud: verificar estado    │
  │  2. PLANIFICAR: generar IaC (tier mínimo) │
  │  3. VALIDAR: terraform validate / tflint  │
  │  4. ESTIMAR: coste mensual por recurso    │
  │  5. PROPONER: INFRA-PROPOSAL.md           │
  └───────────────────────────────────────────┘
           ↓
  ⚠️ REVISIÓN HUMANA OBLIGATORIA
  El PM revisa la propuesta, el coste y aprueba
           ↓
  HUMANO ejecuta: terraform apply / az create
```

### Cómo invocar agentes

```
# Explícitamente
"Usa el agente architect para analizar si esta feature cabe en la capa Application"
"Usa business-analyst y architect en paralelo para analizar el PBI #1234"

# El agente correcto se invoca automáticamente según la descripción de la tarea
```

## Soporte

Para ajustar el comportamiento de Claude, edita los ficheros en:
- `.claude/skills/` — conocimiento de dominio (cada skill tiene su `SKILL.md`)
- `.claude/agents/` — subagentes especializados (modelo, herramientas, instrucciones)
- `.claude/commands/` — slash commands para flujos de trabajo
- `.claude/rules/` — reglas modulares cargadas bajo demanda

Las métricas de uso de SDD se registran automáticamente en `projects/{proyecto}/specs/sdd-metrics.md` al ejecutar `/spec-review --check-impl`.

---
