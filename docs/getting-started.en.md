# Getting Started — pm-workspace

> From zero to productive in 15 minutes.

---

## 1. Prerequisites

- **Claude Code** installed and authenticated (`claude --version`)
- **Git** >= 2.30 (`git --version`)
- **gh CLI** >= 2.0 for PRs and issues (`gh --version`)
- **jq** for JSON parsing (`jq --version`)
- (Optional) **Ollama** for Savia Shield (`ollama --version`)

## 2. Clone and first run

```bash
git clone https://github.com/your-org/pm-workspace.git
cd pm-workspace
claude
```

On first launch, Savia detects you have no profile and introduces herself. Answer her questions: name, role, projects. This creates your profile in `.claude/profiles/users/{slug}/`.

Want to skip the profile? Just type a command directly. Savia will not insist.

## 3. Set up your project

```bash
/project-new
```

Follow the wizard. Savia detects your PM tool (Azure DevOps, Jira, or Savia Flow) and creates the structure in `projects/{name}/`.

For Azure DevOps, you need a PAT saved in `$HOME/.azure/devops-pat` (single line, no newline). Scopes: Work Items R/W, Project R, Analytics R.

## 4. Hook profiles

Hooks control which rules run automatically. There are 4 profiles:

| Profile | What it enables | When to use |
|---------|----------------|-------------|
| `minimal` | Security blockers only | Demos, first steps |
| `standard` | Security + quality gates | Daily work (default) |
| `strict` | All + extra scrutiny | Pre-release, critical code |
| `ci` | Same as standard, non-interactive | CI/CD pipelines |

```bash
# View active profile
bash scripts/hook-profile.sh get

# Change profile
bash scripts/hook-profile.sh set standard
```

## 5. Savia Shield (data protection)

If you work with client data, enable Savia Shield:

```bash
/savia-shield enable
/savia-shield status
```

Shield prevents sensitive data (N4/N4b) from leaking into public files (N1). It operates through 5 layers: regex, local LLM, post-write audit, reversible masking, and base64 detection.

Full guide: [docs/savia-shield-guide.en.md](savia-shield-guide.en.md)

## 6. Maps: .scm and .ctx

pm-workspace generates two navigable indexes:

- **`.scm` (Capability Map)**: catalog of commands, skills, and agents indexed by intent. Answers "what can Savia do".
- **`.ctx` (Context Index)**: map of where each type of information lives (rules, memory, projects). Answers "where to look or store data".

Both are plain text, auto-generated, with progressive loading (L0/L1/L2).

Status: in proposal (SPEC-053, SPEC-054). When available, generate with:

```bash
bash scripts/generate-capability-map.sh    # .scm
bash scripts/generate-context-index.sh     # .ctx
```

## 7. Quickstart by role

| Role | First commands | Daily routine |
|------|---------------|---------------|
| **PM** | `/sprint-status`, `/team-workload`, `/daily-routine` | `/async-standup`, `/board-flow` |
| **Tech Lead** | `/arch-health`, `/pr-pending`, `/tech-radar` | `/spec-status`, `/debt-analyze` |
| **Developer** | `/my-sprint`, `/my-focus`, `/dev-session` | PRs, `/spec-implement` |
| **QA** | `/qa-dashboard`, `/testplan-generate` | `/qa-regression-plan`, `/a11y-audit` |
| **Product Owner** | `/kpi-dashboard`, `/backlog-prioritize` | `/feature-impact`, `/capacity-forecast` |
| **CEO / CTO** | `/portfolio-overview`, `/ceo-report` | `/ceo-alerts`, `/governance-audit` |

Each role has a detailed guide: `docs/quick-starts/quick-start-{role}.md`

## 8. Configuration reference

| What to configure | Where | Example |
|-------------------|-------|---------|
| Azure DevOps PAT | `$HOME/.azure/devops-pat` | Single-line token |
| User profile | `.claude/profiles/users/{slug}/` | Created by `/profile-setup` |
| Hook profile | `~/.savia/hook-profile` | `standard` |
| Savia Shield | `.claude/settings.local.json` | `SAVIA_SHIELD_ENABLED: true` |
| Connectors | `claude.ai/settings/connectors` | Slack, GitHub, Jira |
| Project PM tool | `projects/{name}/CLAUDE.md` | Org URL, iteration path |
| Private config | `CLAUDE.local.md` (gitignored) | Real projects |

## 9. Next steps

1. Run `/help` to browse the interactive command catalog
2. Run `/daily-routine` for Savia to propose your daily workflow
3. Read your role guide in `docs/quick-starts/`
4. If you use client data: enable Savia Shield
5. If something breaks: `/workspace-doctor` diagnoses the environment

---

> Detailed docs: `docs/readme/` (13 sections) and `docs/guides/` (15 scenario guides).
