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
│   ├── commands/                ← 30 slash commands
│   │   ├── help.md              ← /help — catalog + first steps
│   │   ├── sprint-status.md ... ← Sprint & Reporting (10)
│   │   ├── pbi-decompose.md ... ← PBI & Discovery (6)
│   │   ├── spec-generate.md ... ← SDD (5)
│   │   ├── pr-review.md ...     ← Quality & PRs (4)
│   │   ├── team-onboarding.md ..← Team (3)
│   │   ├── infra-detect.md ...  ← Infrastructure (7)
│   │   ├── context-load.md      ← Utilities
│   │   └── references/          ← Reference files (not loaded as commands)
│   │       ├── command-catalog.md
│   │       └── ... (11 files)
│   │
│   ├── agents/                  ← 23 specialized subagents
│   │   ├── business-analyst.md
│   │   ├── architect.md
│   │   ├── code-reviewer.md
│   │   ├── commit-guardian.md
│   │   ├── security-guardian.md
│   │   ├── test-runner.md
│   │   ├── sdd-spec-writer.md
│   │   ├── infrastructure-agent.md
│   │   ├── dotnet-developer.md  ← + 10 language-specific developers
│   │   └── ...
│   │
│   ├── skills/                  ← 9 reusable skills
│   │   ├── azure-devops-queries/
│   │   ├── sprint-management/
│   │   ├── capacity-planning/
│   │   ├── time-tracking-report/
│   │   ├── executive-reporting/
│   │   ├── product-discovery/
│   │   ├── pbi-decomposition/
│   │   ├── team-onboarding/
│   │   └── spec-driven-development/
│   │       └── references/      ← Templates, matrices, team patterns
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
│       ├── agents-catalog.md    ← 23 agents table
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
