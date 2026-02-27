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
│   ├── commands/                ← 81 slash commands
│   │   ├── help.md              ← /help — catalog + first steps
│   │   ├── sprint-status.md ... ← Sprint & Reporting (10)
│   │   ├── pbi-decompose.md ... ← PBI & Discovery (6)
│   │   ├── spec-generate.md ... ← SDD (5)
│   │   ├── pr-review.md ...     ← Quality & PRs (4)
│   │   ├── team-onboarding.md ..← Team (3)
│   │   ├── infra-detect.md ...  ← Infrastructure (7)
│   │   ├── diagram-generate.md..← Diagrams (4)
│   │   ├── pipeline-status.md ..← Pipelines CI/CD (5)
│   │   ├── repos-list.md ...   ← Azure Repos (6)
│   │   ├── debt-track.md ...    ← Governance (5: tech debt, DORA, dependencies, retro actions, risks)
│   │   ├── legacy-assess.md ... ← Legacy & Capture (3: legacy assess, backlog capture, release notes)
│   │   ├── project-audit.md ... ← Project Onboarding (5: audit, release-plan, assign, roadmap, kickoff)
│   │   ├── wiki-publish.md ...  ← DevOps Extended (5: wiki, testplan, security alerts)
│   │   ├── inbox-check.md ...   ← Messaging & Inbox (6: WhatsApp, Nextcloud Talk, voice inbox)
│   │   ├── notify-slack.md ...  ← Connectors (12: Slack, GitHub, Sentry, GDrive, Linear, Atlassian, Notion, Figma)
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
│   ├── skills/                  ← 12 reusable skills
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
│   │   ├── diagram-import/      ← Diagram import → Features/PBIs/Tasks
│   │   │   └── references/      ← Mapping, PBI templates, business rules validation
│   │   └── azure-pipelines/     ← CI/CD with Azure Pipelines (YAML templates, stages)
│   │       └── references/      ← YAML templates, multi-environment stage patterns
│   │
│   └── rules/                   ← Modular rules
│       ├── pm-config.md         ← Azure DevOps constants (auto-loaded)
│       ├── pm-workflow.md       ← Scrum cadence and category index (auto-loaded)
│       ├── github-flow.md       ← Branching, PRs, releases, tags (auto-loaded)
│       ├── command-ux-feedback.md ← UX feedback standards (auto-loaded)
│       ├── command-validation.md← Pre-commit: validate commands (auto-loaded)
│       ├── file-size-limit.md   ← 150 lines rule (auto-loaded)
│       ├── readme-update.md     ← Rule 12: update READMEs (auto-loaded)
│       ├── language-packs.md    ← 16 supported languages table (auto-loaded)
│       ├── agents-catalog.md    ← 24 agents table (auto-loaded)
│       ├── context-health.md   ← Context management and output-first (auto-loaded)
│       ├── domain/              ← Domain-specific rules (on-demand, excluded from auto-loading)
│       │   ├── infrastructure-as-code.md
│       │   ├── confidentiality-config.md
│       │   ├── messaging-config.md
│       │   ├── environment-config.md
│       │   ├── connectors-config.md
│       │   ├── diagram-config.md
│       │   ├── azure-repos-config.md
│       │   └── mcp-migration.md
│       └── languages/           ← Per-language conventions (on-demand)
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
