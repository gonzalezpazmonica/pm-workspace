# Referencia Rápida de Comandos

## Sprint y Reporting
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

## PBI Decomposition
```
/pbi:decompose {id}               Descomponer un PBI en tasks
/pbi:decompose-batch {id1,id2}    Descomponer varios PBIs
/pbi:assign {pbi_id}              (Re)asignar tasks de un PBI
/pbi:plan-sprint                  Planning completo del sprint
```

## Spec-Driven Development
```
/spec:generate {task_id}          Generar Spec desde Task de Azure DevOps
/spec:implement {spec_file}       Implementar Spec (agente o humano)
/spec:review {spec_file}          Revisar calidad de Spec o implementación
/spec:status [--project]          Dashboard de Specs del sprint
/agent:run {spec_file} [--team]   Lanzar agente Claude sobre una Spec
```

## Product Discovery
```
/pbi:jtbd {id}                   Generar JTBD (Jobs to be Done) para un PBI
/pbi:prd {id}                    Generar PRD (Product Requirements) para un PBI
```

## Calidad y Operaciones
```
/pr:review [PR]                  Revisión multi-perspectiva de PR (BA, Dev, QA, Sec, DevOps)
/context:load                    Carga de contexto al iniciar sesión (big picture)
/session:save                    Guarda decisiones y pendientes antes de /clear
/changelog:update                Actualizar CHANGELOG.md desde commits convencionales
/evaluate:repo [URL]             Auditoría de seguridad y calidad de repo externo
```

## Gestión de Equipo
```
/team:onboarding {nombre}       Guía de onboarding personalizada (contexto + código)
/team:evaluate {nombre}         Cuestionario interactivo de competencias → perfil en equipo.md
/team:privacy-notice {nombre}   Nota informativa RGPD obligatoria antes de evaluar
```

## Infraestructura y Entornos
```
/infra:detect {proyecto} {env}  Detectar infraestructura existente
/infra:plan {proyecto} {env}    Generar plan de infraestructura
/infra:estimate {proyecto}      Estimar costes por entorno
/infra:scale {recurso}          Proponer escalado (requiere aprobación humana)
/infra:status {proyecto}        Estado de infraestructura actual
/env:setup {proyecto}           Configurar entornos (DEV/PRE/PRO)
/env:promote {proyecto} {o} {d} Promover entre entornos (PRE→PRO requiere aprobación)
```

---

## Equipo de Subagentes Especializados

El workspace incluye 23 subagentes que Claude puede invocar en paralelo o en secuencia,
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

### Flujo SDD con agentes en paralelo

```
Usuario: /pbi:plan-sprint --project Alpha

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
PM: /infra:plan {proyecto} {env}

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

Las métricas de uso de SDD se registran automáticamente en `projects/{proyecto}/specs/sdd-metrics.md` al ejecutar `/spec:review --check-impl`.

---
