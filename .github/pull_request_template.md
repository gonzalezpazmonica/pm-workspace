## Resumen

<!-- Resumen en español (2-5 bullets). PR Guardian lo incluye en el email de digest. -->

-

## What does this PR add or fix?

<!-- 2-3 sentence summary in English for the international community. Must be >50 characters. -->

## Type of contribution

- [ ] New slash command
- [ ] New agent
- [ ] New skill
- [ ] New hook
- [ ] New domain rule
- [ ] Bug fix
- [ ] Documentation improvement
- [ ] Test suite addition
- [ ] Refactor (no behaviour change)
- [ ] Other: ___

## Context impact

- [ ] This PR does NOT modify CLAUDE.md or files loaded at startup
- [ ] This PR modifies context files — estimated impact: ___ lines added/removed
- [ ] CLAUDE.md stays within 120 lines limit

## Hook safety (if modifying hooks)

- [ ] Hook has explicit timeout ≤30s in settings.json
- [ ] Observability/logging hooks are marked `async: true`
- [ ] No `set -e` in PreToolUse hooks
- [ ] No network calls in synchronous hooks

## Files added / modified

<!-- List the key files and what each one does -->
- `.opencode/commands/` —
- `.opencode/skills/` —
- `.opencode/hooks/` —
- `scripts/` —
- `docs/` —

## How to test this

<!-- Step-by-step instructions for the reviewer to verify the change works -->

1.
2.
3.

## Test suite

- [ ] `./scripts/test-workspace.sh --mock` passes ≥ 93/96
- [ ] `shellcheck` passes on new/modified `.sh` files
- [ ] I added tests for new files (if applicable)

## Checklist

- [ ] PR title follows conventional commits: `type(scope): description`
- [ ] Command/skill name follows existing conventions (kebab-case)
- [ ] I tested this in a real Claude Code conversation at least once
- [ ] No real PATs, org URLs, project names, or client data included
- [ ] Documentation in the file is sufficient for a PM to understand it without reading this PR
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Related issues

Closes #
