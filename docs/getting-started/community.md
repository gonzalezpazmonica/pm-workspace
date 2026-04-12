---
title: Getting Started — Community (Core)
order: 1
category: getting-started
---

# Getting Started with Savia Core

Savia Core is a sovereign agentic PM workspace. It runs entirely on your
machine, manages sprints, backlogs, specs, and code through 49 specialized
agents — all orchestrated from your terminal via Claude Code.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- Git repository initialized
- Bash 4+ (macOS: `brew install bash`)

## First session

```bash
cd your-project
claude
# Savia introduces herself and asks for your profile
```

Savia will guide you through profile setup on first launch. After that:

```
/help                    # see available commands
/sprint-status           # if you have Azure DevOps configured
/spec-generate           # create a spec from a task description
/dev-session start       # start implementing a spec with agents
```

## Key concepts

- **Specs** live in `docs/propuestas/` — they are the contract between you and the agents
- **Agents** (49) are specialized: architect, developer, tester, reviewer, etc.
- **Hooks** (31) enforce quality gates automatically — you don't need to remember rules
- **Memory** persists across sessions — Savia remembers your corrections and preferences

## Next steps

- Read the [7 foundational principles](../core/principles.md)
- Explore [Savia Enterprise](enterprise.md) for multi-tenant and compliance features
- See the [full command catalog](../reference/commands-catalog.md)
