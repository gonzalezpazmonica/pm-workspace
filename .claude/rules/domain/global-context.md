# Global Context — Company DNA for All Agents

> Inspired by FAIR-Perplexica's GLOBAL_CONTEXT pattern.
> A compact context (~100 tokens) injected into every agent prompt.

## Purpose

Every subagent starts with zero knowledge about the company. Loading the full
company profile costs ~400 tokens. The global context is a pre-computed
one-liner that gives agents minimal but sufficient organizational awareness.

## Generation

The global context is generated from the company profile and cached in:
`$HOME/.savia/global-context.txt`

Regenerate when company profile changes: `/company-edit` → auto-regenerate.

### Template

```
{company_name} · {sector} · {team_size} people · {tech_stack} ·
{pm_tool} · {sprint_duration}-week sprints · {language} ·
{key_constraint_1} · {key_constraint_2}
```

### Example

```
Software consultancy · healthcare vertical · 8 people · .NET 8 + Azure ·
Azure DevOps · 2-week sprints · Spanish · HIPAA compliance required ·
data residency EU only
```

## Injection Protocol

When invoking a subagent via Task:

1. Read `$HOME/.savia/global-context.txt` (if exists)
2. Prepend to the agent's prompt: `[Context: {global_context}]`
3. If file doesn't exist: skip (graceful degradation)

Cost: ~25-40 tokens per agent invocation. Saves ~360 tokens vs full profile.

## Generation Script

`scripts/generate-global-context.sh` reads:
- `.claude/profiles/company/identity.md` → name, sector
- `.claude/profiles/company/technology.md` → stack
- `CLAUDE.local.md` → PM tool, sprint config
- Active project CLAUDE.md → key constraints

Output: single line, max 100 tokens, cached to `$HOME/.savia/global-context.txt`.

## When to Regenerate

- After `/company-setup` or `/company-edit`
- After changing `CLAUDE.local.md` PM tool config
- After `/project-new` if first project (adds sector context)
- Manual: `bash scripts/generate-global-context.sh`

## Fallback

If global context file doesn't exist: agents work without it (current behavior).
No agent should fail because global context is missing.

## Privacy

Global context is N2 (company level, gitignored):
- Lives in `$HOME/.savia/` (not in repo)
- Contains company name and sector (acceptable for local use)
- NEVER committed to git
- NEVER sent to external APIs (only used as LLM prompt context)
