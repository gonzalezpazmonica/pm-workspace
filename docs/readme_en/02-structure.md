# Workspace Structure

```
pm-workspace/
├── CLAUDE.md                    ← Claude Code entry point (global constants)
├── docs/SETUP.md                ← Step-by-step configuration guide
├── README.md                    ← Spanish version
├── README.en.md                 ← This file (English)
├── .gitignore
│
├── .claude/
│   ├── settings.local.json      ← Claude Code permissions
│   ├── .env                     ← Environment variables (DO NOT commit)
│   ├── mcp.json                 ← Optional MCP configuration
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
│   │   ├── pr-review.md          ← Multi-perspective PR review
│   │   ├── context-load.md       ← Session context loading
│   │   ├── changelog-update.md   ← Update CHANGELOG from commits
│   │   ├── evaluate-repo.md      ← External repo audit
│   │   ├── spec-generate.md      ← SDD
│   │   ├── spec-implement.md     ← SDD
│   │   ├── spec-review.md        ← SDD
│   │   ├── spec-status.md        ← SDD
│   │   ├── agent-run.md          ← SDD
│   │   ├── team-onboarding.md    ← New member onboarding
│   │   ├── team-evaluate.md      ← Competency assessment
│   │   └── team-privacy-notice.md ← GDPR privacy notice
│   │
│   ├── skills/                  ← 9 custom skills
│   │   ├── azure-devops-queries/
│   │   ├── sprint-management/
│   │   ├── capacity-planning/
│   │   ├── time-tracking-report/
│   │   ├── executive-reporting/
│   │   ├── product-discovery/     ← JTBD + PRD before decompose
│   │   │   └── references/
│   │   │       ├── jtbd-template.md
│   │   │       └── prd-template.md
│   │   ├── pbi-decomposition/
│   │   │   └── references/
│   │   │       └── assignment-scoring.md
│   │   ├── team-onboarding/          ← Onboarding + competency assessment
│   │   │   └── references/
│   │   │       ├── onboarding-checklist.md
│   │   │       ├── questionnaire-template.md
│   │   │       ├── expertise-mapping.md
│   │   │       └── privacy-notice-template.md
│   │   └── spec-driven-development/
│   │       ├── SKILL.md
│   │       └── references/
│   │           ├── spec-template.md         ← Spec template
│   │           ├── layer-assignment-matrix.md ← What goes to agent vs human
│   │           └── agent-team-patterns.md   ← Agent team patterns
│   │
│   └── rules/                   ← Modular rules (loaded on demand)
│       ├── pm-config.md         ← Full Azure DevOps constants
│       ├── pm-workflow.md       ← Scrum cadence and command table
│       ├── {lang}-conventions.md← Per-language conventions (16 Language Packs)
│       ├── {lang}-rules.md      ← Per-language quality rules
│       ├── environment-config.md← Multi-environment config (DEV/PRE/PRO)
│       ├── confidentiality-config.md ← Secrets and connection string protection
│       ├── infrastructure-as-code.md ← Multi-cloud IaC (Azure, AWS, GCP)
│       ├── readme-update.md     ← When and how to update this README
│       └── github-flow.md       ← Branching workflow: branches, PRs, main protection
│
├── docs/
│   ├── reglas-scrum.md
│   ├── politica-estimacion.md
│   ├── kpis-equipo.md
│   ├── plantillas-informes.md
│   └── flujo-trabajo.md         ← Includes section 8: SDD workflow
│
├── projects/
│   ├── project-alpha/
│   │   ├── CLAUDE.md            ← Project constants + SDD config
│   │   ├── equipo.md            ← Human team + Claude agents as developers
│   │   ├── reglas-negocio.md
│   │   ├── source/              ← git clone the repo here
│   │   ├── sprints/
│   │   └── specs/               ← SDD specs
│   │       ├── sdd-metrics.md
│   │       ├── templates/
│   │       └── sprint-YYYY-MM/
│   ├── project-beta/
│   │   └── (same structure)
│   └── sala-reservas/           ← ⚗️ TEST PROJECT (see section below)
│       ├── CLAUDE.md
│       ├── equipo.md            ← 4 devs + PM + Claude agents
│       ├── reglas-negocio.md    ← 16 documented business rules
│       ├── sprints/
│       │   └── sprint-2026-04/
│       │       └── planning.md
│       ├── specs/
│       │   ├── sdd-metrics.md
│       │   └── sprint-2026-04/
│       │       ├── AB101-B3-create-sala-handler.spec.md
│       │       └── AB102-D1-unit-tests-salas.spec.md
│       └── test-data/           ← Azure DevOps API mock JSON
│           ├── mock-workitems.json
│           ├── mock-sprint.json
│           └── mock-capacities.json
│
├── scripts/
│   ├── azdevops-queries.sh      ← Bash: Azure DevOps REST API queries
│   ├── capacity-calculator.py  ← Python: real capacity calculation
│   └── report-generator.js     ← Node.js: Excel/PPT report generation
│
└── output/
    ├── sprints/
    ├── reports/
    ├── executive/
    └── agent-runs/              ← Claude agent execution logs
```
