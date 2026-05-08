# Quick Start — pm-workspace

> Get productive with pm-workspace in 5 minutes.

## What is pm-workspace?

A Claude Code workspace for Project Managers, with 454 commands, 67 skills, 33 agents, and 17 safety hooks — all orchestrated through natural language.

## First Steps

1. **Open a project**: `/project-open <nombre>` or ask Savia to create one
2. **Check sprint status**: `/sprint-status` shows current sprint progress
3. **Decompose a PBI**: `/pbi-decompose` breaks user stories into tasks
4. **Run a standup**: `/standup-generate` produces daily standup summaries

## Key Command Categories

**Project Management**: `/sprint-*`, `/backlog-*`, `/pbi-*`, `/capacity-*`
**Quality & Testing**: `/test-*`, `/audit-*`, `/coverage-*`
**Security**: `/security-scan`, `/vuln-scan`
**Reporting**: `/executive-report`, `/time-tracking-report`
**Team**: `/team-onboard`, `/wellbeing-check`, `/developer-experience`

## Discovering Commands

```bash
# List all available commands
ls .opencode/commands/

# Search for commands by keyword
grep -rl "sprint" .opencode/commands/

# Generate full component index
bash scripts/generate-index.sh --markdown
```

## Skills & Maturity

Every skill has a maturity level in its frontmatter:

- **stable** (51) — production-ready, well-documented, tested
- **beta** (2) — functional but may evolve
- **alpha** (14) — experimental, missing frontmatter or documentation

## Safety Hooks

All destructive operations are gated by PreToolUse hooks:

- `block-credential-leak` — prevents committing secrets
- `block-force-push` — blocks force push to main/master
- `block-infra-destructive` — gates terraform/az/aws destroy ops
- `tdd-gate` — requires test files before production code
- `validate-bash-global` — blocks dangerous bash commands

## Running Tests

```bash
# Full test suite
bash tests/run-all.sh

# Individual suite
bats tests/hooks/test-block-credential-leak.bats

# Quality audit
bash scripts/audit-test-quality.sh --summary

# Coverage report
bash scripts/coverage-report.sh --summary

# Security scan
bash scripts/security-scan.sh --verbose
```

## Project Structure

```
pm-workspace/
├── .claude/
│   ├── commands/     # 454 slash commands
│   ├── skills/       # 67 skills with SKILL.md
│   ├── agents/       # 33 sub-agents
│   ├── hooks/        # 17 PreToolUse hooks
│   ├── rules/        # 105 domain rules
│   └── settings.json # Hook configuration
├── scripts/          # Tooling (test, audit, coverage, security)
├── tests/            # BATS test suites
├── docs/             # Documentation
└── projects/         # Project workspaces (gitignored)
```

## Further Reading

- [CONTRIBUTING.md](../CONTRIBUTING.md) — contribution guidelines
- [SECURITY.md](../SECURITY.md) — security policy
- [CHANGELOG.md](../CHANGELOG.md) — version history with Era references
- [ROADMAP.md](ROADMAP.md) — strategic direction
