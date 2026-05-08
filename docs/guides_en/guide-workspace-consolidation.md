# Workspace Consolidation

> Version: v4.9 | Era: 178 | Since: 2026-04-04

## What it is

An integrity audit that verifies that the counters documented in README, CHANGELOG, and ROADMAP match the actual repository contents. It detects drift between documentation and code: commands, agents, skills, hooks, tests, and LLM models.

## Requirements

Pre-installed. Only requires access to the repository.

## Basic usage

The consolidation runs as part of the audit workflow. The report is generated in the standard output directory.

The report covers:
- Actual vs documented count of commands, agents, skills, hooks
- Test suite inventory with scores
- Orphaned hooks (registered but missing file, or vice versa)
- Installed LLM models and their status

## What it verifies

| Dimension | Actual source | Documented source |
|-----------|---------------|-------------------|
| Commands | `ls .opencode/commands/*.md` | README counter |
| Agents | `ls .opencode/agents/*.md` | README counter |
| Skills | `ls .opencode/skills/*/SKILL.md` | README counter |
| Hooks | settings.json hook entries | README counter |
| Tests | `ls tests/*.bats` | README counter |

## Current counters (v4.10)

- 508 commands
- 48 agents
- 89 skills (100% with DOMAIN.md)
- 48 hooks
- 93 test suites
- 16 language packs

## When to run

- Before each release (verify that README reflects reality)
- After adding or removing commands, skills, agents, or hooks
- As part of periodic workspace audits
- When inconsistencies between documentation and code are detected

## Integration

- **validate-ci-local.sh**: includes basic counter verification
- **/hub-audit**: complements with semantic analysis of connections between rules
- **CHANGELOG**: each version entry must reflect correct counters
- **README updates**: after consolidation, update the 9 READMEs if there are changes

## Troubleshooting

**Counters do not match**: run the counts manually to identify the source of drift:
```bash
ls .opencode/commands/*.md | wc -l
ls .opencode/agents/*.md | wc -l
ls -d .opencode/skills/*/SKILL.md | wc -l
```

**Orphaned hooks**: a hook may be registered in settings.json but its `.sh` file does not exist (or vice versa). Review `.claude/settings.json` and `.opencode/hooks/`

**New test suites not registered**: verify that each new `.bats` file is referenced in `tests/run-all.sh`
