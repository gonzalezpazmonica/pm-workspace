# Contributing to PM-Workspace

Thank you for considering a contribution. PM-Workspace grows through real-world use: the best contributions come from PMs who found something missing while managing an actual project.

Before you start, please read this document and the [Code of Conduct](CODE_OF_CONDUCT.md).

---

## What we're looking for

The highest-impact contributions are:

**New slash commands** (`.claude/commands/`) — if you've had a conversation with Claude that solved a PM problem not yet covered, package it as a reusable command. Commands currently in high demand: `risk:log`, `sprint:release-notes`, `backlog:capture`, `pr:status`, `tech-debt:review`. See [ROADMAP.md](ROADMAP.md) for the full list.

**New skills** (`.claude/skills/`) — skills that extend Claude's behaviour into new territory: Jira integration, Kanban / SAFe methodology support, non-.NET stacks (Java Spring, Node.js, Python FastAPI), or new reporting formats.

**Test suite additions** — new test categories in `scripts/test-workspace.sh`, additional mock data scenarios in `projects/sala-reservas/test-data/`, or new spec examples.

**Bug fixes** — corrections to `scripts/azdevops-queries.sh`, `scripts/capacity-calculator.py`, or `scripts/report-generator.js`.

**Documentation** — clarifications in SKILL.md files, additional examples in the README, translations.

---

## Quick start

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/pm-workspace.git
cd pm-workspace

# 2. Create a branch
git checkout -b feature/your-feature-name

# 3. Make your changes

# 4. Verify the test suite still passes
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
# Expected: ≥ 93/96 PASSED

# 5. Open a Pull Request against main
```

---

## Branch naming

| Prefix | Use for |
|--------|---------|
| `feature/` | New command, skill, or integration |
| `fix/` | Bug correction |
| `docs/` | Documentation only |
| `test/` | Test suite or mock data changes |
| `refactor/` | Restructuring without behaviour change |

Examples: `feature/risk-log-command`, `fix/capacity-formula-zero-days`, `docs/add-jira-example`

---

## Standards for new commands and skills

### Slash commands (`.claude/commands/nombre-comando.md`)

Every new command must include:

1. A one-paragraph description at the top explaining what it does and when to use it.
2. Numbered steps describing the process Claude should follow.
3. Explicit handling of the most common error case (e.g. "if the task has no parent PBI, ask the user to provide the PBI ID").
4. At least one usage example, ideally showing both the user's input and Claude's response.
5. A reference to any skills it depends on.

Follow the naming convention of existing commands: `namespace:action` (e.g. `sprint:status`, `pbi:decompose`, `spec:generate`).

### Skills (`.claude/skills/nombre-skill/`)

Every skill directory must contain a `SKILL.md` with:

1. One-line description (used in the skill registry).
2. When to use this skill (trigger conditions).
3. Configuration parameters (which fields in the project's `CLAUDE.md` affect this skill).
4. References to external documentation if the skill integrates with an external API.
5. Limitations and known edge cases.

---

## Testing your contribution

If you add new files that should always exist in a correctly configured workspace, add the corresponding tests to `scripts/test-workspace.sh` in the appropriate suite.

```bash
# Run the full suite
./scripts/test-workspace.sh --mock

# Run only the relevant category
./scripts/test-workspace.sh --mock --only sdd
./scripts/test-workspace.sh --mock --only structure

# Verbose output for debugging
./scripts/test-workspace.sh --mock --verbose
```

The CI pipeline runs these exact commands on every PR. Your PR will not be merged if the test suite regresses.

---

## Submitting a Pull Request

Use the PR template provided in `.github/pull_request_template.md`. Fill in every section — incomplete PRs will be asked to provide the missing information before review begins.

**Review process:**
- A maintainer will review within 7 days.
- Expect feedback and iteration; this is normal and not a rejection.
- Once approved, a maintainer will merge and include your change in the next release.

---

## Reporting bugs and proposing features

Open a GitHub Issue using one of the provided templates. Choose **Bug report** or **Feature request** from the template selector.

Use these title prefixes if you write the issue manually:

```
[BUG]      /sprint:status does not show alerts when WIP = 0
[FEATURE]  Add support for Kanban methodology
[DOCS]     SDD example in README does not match current behaviour
[QUESTION] How to configure workspace for multi-repo projects?
```

Always include: Claude Code version (`claude --version`), the command or skill involved, what you expected and what happened, and whether the issue is reproducible with `projects/sala-reservas` in mock mode.

---

## What we will not accept

- Hardcoded credentials, PATs, organisation URLs, or any real project data.
- Changes that break the mock test suite without a documented, intentional reason.
- Commands or skills whose purpose duplicates existing functionality without meaningfully improving it.
- AI-generated contributions submitted without manual testing — we require that every command has been tested at least once in a real Claude Code conversation.

---

## Recognition

Every contributor is listed in [CONTRIBUTORS.md](CONTRIBUTORS.md). First-time contributors are highlighted in the release notes.
