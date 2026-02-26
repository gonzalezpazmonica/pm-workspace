# Estructura del Workspace

> **Nota:** El directorio raíz del workspace (`~/claude/`) **es** el repositorio. Se trabaja siempre desde la raíz. El `.gitignore` gestiona qué queda privado (proyectos reales, credenciales, configuración local).

```
~/claude/                        ← Raíz de trabajo Y repositorio GitHub
├── CLAUDE.md                    ← Punto de entrada de Claude Code (≤150 líneas)
├── .claudeignore                ← Excluye worktrees y languages de carga automática
├── .gitignore                   ← Privacidad: proyectos reales, secrets, local config
├── docs/SETUP.md                ← Guía de configuración paso a paso
├── README.md / README.en.md     ← Documentación principal (ES/EN)
│
├── .claude/
│   ├── settings.local.json      ← Permisos de Claude Code (git-ignorado)
│   │
│   ├── commands/                ← 44 slash commands
│   │   ├── help.md              ← /help — catálogo + primeros pasos
│   │   ├── sprint-status.md ... ← Sprint y Reporting (10)
│   │   ├── pbi-decompose.md ... ← PBI y Discovery (6)
│   │   ├── spec-generate.md ... ← SDD (5)
│   │   ├── pr-review.md ...     ← Calidad y PRs (4)
│   │   ├── team-onboarding.md ..← Equipo (3)
│   │   ├── infra-detect.md ...  ← Infraestructura (7)
│   │   ├── diagram-generate.md..← Diagramas (4)
│   │   ├── notify-slack.md ...  ← Conectores (10: Slack, GitHub, Sentry, GDrive, Linear, Atlassian)
│   │   ├── context-load.md      ← Utilidades
│   │   └── references/          ← Ficheros de referencia (no se cargan como commands)
│   │       ├── command-catalog.md
│   │       ├── spec-template.md
│   │       └── ... (11 ficheros)
│   │
│   ├── agents/                  ← 24 subagentes especializados
│   │   ├── business-analyst.md
│   │   ├── architect.md
│   │   ├── code-reviewer.md
│   │   ├── commit-guardian.md
│   │   ├── security-guardian.md
│   │   ├── test-runner.md
│   │   ├── sdd-spec-writer.md
│   │   ├── infrastructure-agent.md
│   │   ├── diagram-architect.md ← Análisis arquitectónico de diagramas
│   │   ├── dotnet-developer.md  ← + 10 developers por lenguaje
│   │   └── ...
│   │
│   ├── skills/                  ← 11 skills reutilizables
│   │   ├── azure-devops-queries/
│   │   ├── sprint-management/
│   │   ├── capacity-planning/
│   │   ├── time-tracking-report/
│   │   ├── executive-reporting/
│   │   ├── product-discovery/
│   │   ├── pbi-decomposition/
│   │   ├── team-onboarding/
│   │   ├── spec-driven-development/
│   │   │   └── references/      ← Templates, matrices, patrones de equipo
│   │   ├── diagram-generation/  ← Generación de diagramas (Draw.io, Miro, Mermaid)
│   │   │   └── references/      ← Plantillas Mermaid, shapes, boards
│   │   └── diagram-import/      ← Importación de diagramas → Features/PBIs/Tasks
│   │       └── references/      ← Mapping, templates PBI, validación reglas negocio
│   │
│   └── rules/                   ← Reglas modulares
│       ├── pm-config.md         ← Constantes Azure DevOps
│       ├── pm-workflow.md       ← Cadencia Scrum y tabla de comandos
│       ├── github-flow.md       ← Branching, PRs, releases, tags
│       ├── environment-config.md
│       ├── confidentiality-config.md
│       ├── infrastructure-as-code.md
│       ├── language-packs.md    ← Tabla de 16 lenguajes soportados
│       ├── command-validation.md← Pre-commit: validar commands
│       ├── file-size-limit.md   ← Regla 150 líneas
│       ├── readme-update.md     ← Regla 12: actualizar READMEs
│       ├── connectors-config.md ← Configuración conectores Claude (Slack, GitHub, Sentry...)
│       ├── diagram-config.md    ← Configuración Draw.io/Miro
│       ├── agents-catalog.md    ← Tabla de 24 agentes
│       └── languages/           ← Convenciones por lenguaje (excluido de carga automática)
│           ├── csharp-rules.md
│           ├── dotnet-conventions.md
│           └── ... (21 ficheros para 16 lenguajes)
│
├── docs/                        ← Metodología, guías, secciones README
│   ├── readme/ (13 secciones ES)
│   ├── readme_en/ (13 secciones EN)
│   ├── best-practices-claude-code.md
│   ├── guia-incorporacion-lenguajes.md
│   ├── ADOPTION_GUIDE.md / .en.md
│   └── ...
│
├── projects/                    ← Proyectos reales (git-ignorados)
│   ├── proyecto-alpha/          ← Ejemplo: CLAUDE.md, equipo.md, specs/
│   ├── proyecto-beta/
│   └── sala-reservas/           ← Proyecto de test con mock data
│
├── scripts/
│   ├── azdevops-queries.sh      ← Queries a Azure DevOps REST API
│   ├── test-workspace.sh        ← Validación de estructura del workspace
│   └── validate-commands.sh     ← Validación estática de slash commands
│
└── output/                      ← Informes generados (git-ignorado)
    ├── sprints/
    ├── reports/
    └── agent-runs/              ← Logs de ejecuciones de agentes
```

---

## `.claudeignore`

Fichero que controla qué directorios **no se cargan en el contexto** de Claude Code:

- `.claude/worktrees/` — Claude Code crea copias del workspace por sesión; sin excluirlas, saturan el contexto
- `.claude/rules/languages/` — 21 ficheros de convenciones (6.900+ líneas) que se cargan bajo demanda cuando un agente los necesita

> Sin `.claudeignore`, el contexto auto-cargado supera los límites y todos los slash commands fallan con "Prompt is too long".
