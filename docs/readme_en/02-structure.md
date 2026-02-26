# Workspace Structure

> **Note:** The workspace root (`~/claude/`) **is** the repository. Always work from the root. `.gitignore` manages what stays private (real projects, credentials, local config).

```
~/claude/                        ← Working root AND GitHub repository
├── CLAUDE.md                    ← Claude Code entry point (≤150 lines)
├── .claudeignore                ← Excludes worktrees and languages from auto-loading
├── .gitignore                   ← Privacy: real projects, secrets, local config
├── docs/SETUP.md                ← Step-by-step configuration guide
├── README.md / README.en.md     ← Main documentation (ES/EN)
│
├── .claude/
│   ├── settings.local.json      ← Claude Code permissions (git-ignored)
│   │
│   ├── commands/                ← 39 slash commands
│   │   ├── help.md              ← /help — catalog + first steps
│   │   ├── sprint-status.md ... ← Sprint & Reporting (10)
│   │   ├── pbi-decompose.md ... ← PBI & Discovery (6)
│   │   ├── spec-generate.md ... ← SDD (5)
│   │   ├── pr-review.md ...     ← Quality & PRs (4)
│   │   ├── team-onboarding.md ..← Team (3)
│   │   ├── infra-detect.md ...  ← Infrastructure (7)
│   │   ├── diagram-generate.md..← Diagrams (4)
│   │   ├── notify-slack.md ...  ← Connectors (5: Slack, Sentry, Notion)
│   │   ├── context-load.md      ← Utilities
│   │   └── references/          ← Reference files (not loaded as commands)
│   │       ├── command-catalog.md
│   │       └── ... (11 files)
│   │
│   ├── agents/                  ← 24 specialized subagents
│   │   ├── business-analyst.md
│   │   ├── architect.md
│   │   ├── code-reviewer.md
│   │   ├── commit-guardian.md
│   │   ├── security-guardian.md
│   │   ├── test-runner.md
│   │   ├── sdd-spec-writer.md
│   │   ├── infrastructure-agent.md
│   │   ├── diagram-architect.md ← Architecture diagram analysis
│   │   ├── dotnet-developer.md  ← + 10 language-specific developers
│   │   └── ...
│   │
│   ├── skills/                  ← 11 reusable skills
│   │   ├── azure-devops-queries/
│   │   ├── sprint-management/
│   │   ├── capacity-planning/
│   │   ├── time-tracking-report/
│   │   ├── executive-reporting/
│   │   ├── product-discovery/
│   │   ├── pbi-decomposition/
│   │   ├── team-onboarding/
│   │   ├── spec-driven-development/
│   │   │   └── references/      ← Templates, matrices, team patterns
│   │   ├── diagram-generation/  ← Diagram generation (Draw.io, Miro, Mermaid)
│   │   │   └── references/      ← Mermaid templates, shapes, boards
│   │   └── diagram-import/      ← Diagram import → Features/PBIs/Tasks
│   │       └── references/      ← Mapping, PBI templates, business rules validation
│   │
│   └── rules/                   ← Modular rules
│       ├── pm-config.md         ← Azure DevOps constants
│       ├── pm-workflow.md       ← Scrum cadence and command table
│       ├── github-flow.md       ← Branching, PRs, releases, tags
│       ├── environment-config.md
│       ├── confidentiality-config.md
│       ├── infrastructure-as-code.md
│       ├── language-packs.md    ← 16 supported languages table
│       ├── command-validation.md← Pre-commit: validate commands
│       ├── file-size-limit.md   ← 150 lines rule
│       ├── readme-update.md     ← Rule 12: update READMEs
│       ├── connectors-config.md ← Claude connectors config (Slack, GitHub, Sentry...)
│       ├── diagram-config.md    ← Draw.io/Miro configuration
│       ├── agents-catalog.md    ← 24 agents table
│       └── languages/           ← Per-language conventions (excluded from auto-loading)
│           ├── csharp-rules.md
│           ├── dotnet-conventions.md
│           └── ... (21 files for 16 languages)
│
├── docs/                        ← Methodology, guides, README sections
│   ├── readme/ (13 sections ES)
│   ├── readme_en/ (13 sections EN)
│   ├── best-practices-claude-code.md
│   ├── ADOPTION_GUIDE.md / .en.md
│   └── ...
│
├── projects/                    ← Real projects (git-ignored)
│   ├── proyecto-alpha/          ← Example: CLAUDE.md, equipo.md, specs/
│   ├── proyecto-beta/
│   └── sala-reservas/           ← Test project with mock data
│
├── scripts/
│   ├── azdevops-queries.sh      ← Azure DevOps REST API queries
│   ├── test-workspace.sh        ← Workspace structure validation
│   └── validate-commands.sh     ← Static validation of slash commands
│
└── output/                      ← Generated reports (git-ignored)
    ├── sprints/
    ├── reports/
    └── agent-runs/              ← Agent execution logs
```

---

## `.claudeignore`

Controls which directories are **not loaded into context** by Claude Code:

- `.claude/worktrees/` — Claude Code creates workspace copies per session; without exclusion, they saturate the context
- `.claude/rules/languages/` — 21 convention files (6,900+ lines) loaded on-demand when an agent needs them

> Without `.claudeignore`, auto-loaded context exceeds limits and all slash commands fail with "Prompt is too long".
