# Estructura del Workspace

> **Nota:** El directorio raíz del workspace (`~/claude/`) **es** el repositorio. Se trabaja siempre desde la raíz. El `.gitignore` gestiona qué queda privado (proyectos reales, credenciales, configuración local).

```
~/claude/                        ← Raíz de trabajo Y repositorio GitHub
├── CLAUDE.md                    ← Punto de entrada de Claude Code (≤150 líneas)
├── docs/SETUP.md                ← Guía de configuración paso a paso
├── README.md                    ← Este fichero
├── .gitignore                   ← Privacidad: proyectos reales, secrets, local config
│
├── .claude/
│   ├── settings.local.json      ← Permisos de Claude Code (git-ignorado)
│   ├── .env                     ← Variables de entorno (git-ignorado)
│   ├── mcp.json                 ← Configuración MCP opcional
│   │
│   ├── commands/                ← 35 slash commands
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
│   │   ├── pbi-jtbd.md           ← Discovery: Jobs to be Done
│   │   ├── pbi-prd.md            ← Discovery: Product Requirements
│   │   ├── pr-review.md          ← Review multi-perspectiva de PR
│   │   ├── context-load.md       ← Carga de contexto al iniciar sesión
│   │   ├── changelog-update.md   ← Actualizar CHANGELOG desde commits
│   │   ├── evaluate-repo.md      ← Auditoría de repos externos
│   │   ├── spec-generate.md      ← SDD
│   │   ├── spec-implement.md     ← SDD
│   │   ├── spec-review.md        ← SDD
│   │   ├── spec-status.md        ← SDD
│   │   ├── agent-run.md          ← SDD
│   │   ├── team-onboarding.md    ← Onboarding de nuevos miembros
│   │   ├── team-evaluate.md      ← Evaluación de competencias
│   │   └── team-privacy-notice.md ← Nota informativa RGPD
│   │
│   ├── skills/                  ← 9 skills personalizadas
│   │   ├── azure-devops-queries/
│   │   ├── sprint-management/
│   │   ├── capacity-planning/
│   │   ├── time-tracking-report/
│   │   ├── executive-reporting/
│   │   ├── product-discovery/     ← JTBD + PRD antes de decompose
│   │   │   └── references/
│   │   │       ├── jtbd-template.md
│   │   │       └── prd-template.md
│   │   ├── pbi-decomposition/
│   │   │   └── references/
│   │   │       └── assignment-scoring.md
│   │   ├── team-onboarding/          ← Onboarding + evaluación de competencias
│   │   │   └── references/
│   │   │       ├── onboarding-checklist.md
│   │   │       ├── questionnaire-template.md
│   │   │       ├── expertise-mapping.md
│   │   │       └── privacy-notice-template.md
│   │   └── spec-driven-development/
│   │       ├── SKILL.md
│   │       └── references/
│   │           ├── spec-template.md           ← Plantilla de specs
│   │           ├── layer-assignment-matrix.md ← Qué va a agente vs humano
│   │           └── agent-team-patterns.md     ← Patrones de equipos de agentes
│   │
│   └── rules/                   ← Reglas modulares (carga bajo demanda)
│       ├── pm-config.md         ← Constantes completas Azure DevOps
│       ├── pm-workflow.md       ← Cadencia Scrum y tabla de comandos
│       ├── {lang}-conventions.md← Convenciones por lenguaje (16 Language Packs)
│       ├── {lang}-rules.md      ← Reglas de calidad por lenguaje
│       ├── environment-config.md← Configuración multi-entorno (DEV/PRE/PRO)
│       ├── confidentiality-config.md ← Protección de secrets y connection strings
│       ├── infrastructure-as-code.md ← IaC multi-cloud (Azure, AWS, GCP)
│       ├── readme-update.md     ← Cuándo y cómo actualizar este README
│       └── github-flow.md       ← Branching workflow: ramas, PRs, protección de main
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
