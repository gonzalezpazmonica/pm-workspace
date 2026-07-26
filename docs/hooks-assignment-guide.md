# Hook Assignment Guide

> SE-270 Slice 5 — AC-5.5. Ref: `scripts/hook-assignment-rule.sh`

## Core rule

**Minor annoyance → docs/skill. Data loss → hook.**

If the consequence of the model ignoring the guardrail is a minor
annoyance (inconsistent naming, missing comment, style violation),
document it. If the consequence is a production incident or data loss
(credential leak, force-push, destructive bash, PII exposure), put it
in a hook.

## Decision tree

```
Is the consequence of ignoring this guardrail...
                    |
    ┌───────────────+───────────────┐
    |                               |
PERMANENT damage              TEMPORARY annoyance
(data loss, breach,           (bad style, missing
 credential exposure,         comment, verbose
 destructive action)          output, wrong naming)
    |                               |
    v                               v
  HOOK                            DOC / SKILL
    |                               |
    v                               v
PreToolUse command              Skill instruction
with blocking mode             or CLAUDE.md rule
exit 2 = deny tool
    |
    +-- If impact unclear:
        Start as HOOK with warn-only mode
        Audit after 30 days
        No true positives → downgrade to DOC
```

## Handler types (choose by cost)

| Type | Use when | Cost |
|---|---|---|
| `command` | Deterministic check (regex, file exists, exit code) | Low |
| `prompt` | One-shot LLM evaluation (classification, format check) | Medium |
| `agent` | Multi-step verification with tool access | High |
| `http` | External service gate (shield, auth, policy) | Variable |

## Matcher specificity

| Matcher | When to use | Risk |
|---|---|---|
| `Bash(git commit*)` | Specific: exact tool + args pattern | Low |
| `Edit\|Write` | Specific: tool union for file mutations | Low |
| `Task` | Tool-only: all Task calls | Medium |
| `.*` | Broader: fires on every tool call | High — prefer narrowing |
| `""` (empty) | Unscoped: fires on every trigger of the event | High — always add a matcher |

## Examples

### Correct: hook for credential leak detection

```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "/path/to/block-credential-leak.sh",
    "timeout": 5
  }]
}
```

**Why:** Credential leak in bash output = permanent exposure. Hook with
exit code 2 blocks the tool call.

### Correct: doc for naming conventions

```json
// In .claude/rules/style.md, NOT as a hook:
"Use snake_case for bash scripts. PascalCase for C# classes."
```

**Why:** Wrong naming = minor annoyance. Document it, don't hook it.

### Incorrect: hook for comment format

```json
// BAD — this should be documentation:
{
  "matcher": "Write",
  "hooks": [{
    "type": "command",
    "command": "check-comment-format.sh"
  }]
}
```

**Why:** Missing/wrong comment = minor annoyance. A hook adds latency
to every Write call for a cosmetic check. Document the convention instead.

### Incorrect: doc only for force-push blocking

```
// BAD — this should be a hook:
// "In docs/contributing.md: don't force push."
```

**Why:** Force push can permanently destroy history. Must be a
PreToolUse hook with exit 2 blocking the Bash(git push*) tool call.

## Tiebreaker protocol

When impact is unclear:

1. Start as PreToolUse hook with warn-only mode (exit 0 always, log a warning)
2. Set a 30-day audit window
3. After 30 days, check `output/hook-audit/` for true positives
4. Zero true positives → downgrade to documentation
5. One or more true positives → keep as hook, consider blocking mode

## Implementation checklist

- [ ] Classify impact: permanent damage or temporary annoyance?
- [ ] If HOOK: choose handler type by cost
- [ ] If HOOK: write specific matcher (no `.*` unless unavoidable)
- [ ] If HOOK: add early-exit guard (cheap check first)
- [ ] If HOOK: declare budget (≤100ms for hot-path PreToolUse)
- [ ] If DOC: add to relevant skill or CLAUDE.md section
- [ ] Run `scripts/hook-type-audit.sh` to verify type distribution
- [ ] Run `scripts/hook-latency-budget.sh` to verify latency budget
- [ ] Run `scripts/hook-matcher-audit.sh` to verify matcher specificity

## Verification

```bash
# Check a proposal
bash scripts/hook-assignment-rule.sh --check "prevent rm -rf on production data"

# Run full audit suite
bash scripts/hook-type-audit.sh
bash scripts/hook-latency-budget.sh
bash scripts/hook-matcher-audit.sh
```

## References

- SE-270 Slice 5 acceptance criteria (AC-5.1 through AC-5.5)
- `scripts/hook-assignment-rule.sh` — programmatic checker
- `scripts/hook-type-audit.sh` — type distribution audit
- `scripts/hook-latency-budget.sh` — latency budget enforcement
- `scripts/hook-matcher-audit.sh` — matcher specificity audit
- SE-270 proposal: `docs/propuestas/SE-270-harness-hygiene.md`
