# Architecture — System Design & Data Flow

pm-workspace is a hierarchical system where settings.json gates drive orchestration through hooks, which load skills, which delegate to agents, which operate under rules.

## Component Hierarchy

```
settings.json (5 hook events)
    ├─ SessionStart
    ├─ PreToolUse
    ├─ PostToolUse
    ├─ Stop
    └─ SubagentStop
         ↓
    17 hooks (security gates, quality checks, logging)
         ↓
    Commands (.claude/commands/*)
    (454 slash commands / workflows)
         ↓
    Skills (.claude/skills/*)
    (67 reusable capabilities)
         ↓
    Agents (.claude/agents/*)
    (33 specialized orchestrators)
         ↓
    Rules (.claude/rules/domain/*)
    (105 domain rules + conventions)
         ↓
    Execution (Bash, Git, Language SDKs)
```

## Data Flow: Command Invocation → Execution

### Phase 1: Command Invocation

1. User invokes `/command-name --param value`
2. Claude Code loads command definition from `.claude/commands/command-name.md`
3. Command frontmatter parsed: `model`, `context_cost`, `allowed-tools`, `arguments`

### Phase 2: Hook Validation (PreToolUse)

1. **session-init** validates session state (one-time)
2. **validate-bash-global** checks bash syntax safety
3. **plan-gate** suggests spec if planning without specification
4. **agent-dispatch-validate** ensures subagent context is complete (if delegating)

**Decision point:**
- ✅ All hooks pass → proceed to Phase 3
- ❌ Security hook blocks → stop, show error, ask user to fix

### Phase 3: Skill Loading & Delegation

1. If command uses `@skill-name`, load `.claude/skills/skill-name/SKILL.md`
2. Skill defines its own task steps and subagent delegation
3. Skill reads project context from `.claude/settings.json` and `projects/{project}/CLAUDE.md`
4. Skill determines if delegation to agents is needed (Task tool)

### Phase 4: Agent Orchestration

1. Skill invokes Task with agent name and context
2. Agent receives fresh context budget (max 12K tokens)
3. Agent reads applicable rules from `.claude/rules/domain/*`
4. Agent generates output (code, specs, analysis)
5. Output saved to `output/` or applied to codebase

### Phase 5: Post-Execution Hooks (PostToolUse)

- **post-edit-lint** runs formatters async (doesn't block)
- **memory-auto-capture** learns patterns from edits (async)
- **agent-trace-log** records agent activity for metrics (async)

### Phase 6: Final Validation (Stop Hook)

- **pre-commit-review** comprehensive check: tests, format, security, code review
- **scope-guard** warns if modified files exceed spec scope
- **stop-quality-gate** detects any remaining secrets

**Decision point:**
- ✅ All checks pass → session can end
- ⚠️ Warnings only → inform user, allow continuation
- ❌ Blockers found → require fixes before end

## Directory Structure & Purpose

```
pm-workspace/
├── .claude/                      ← Claude Code configuration
│   ├── commands/                 (454 commands: slash workflows)
│   ├── skills/                   (67 skills: reusable capabilities)
│   │   ├── spec-driven-development/
│   │   ├── azure-devops-queries/
│   │   ├── diagram-generation/
│   │   ├── ... (see /help for full list)
│   ├── agents/                   (33 agents: specialized orchestrators)
│   ├── hooks/                    (17 hooks: lifecycle gates)
│   ├── rules/
│   │   ├── domain/               (105 domain rules)
│   │   ├── languages/            (16 language packs)
│   │   └── compliance/           (compliance runner)
│   ├── plans/                    (execution plans, ADRs)
│   ├── profiles/                 (user profiles, team structure)
│   ├── agent-memory/             (persistent agent learning)
│   ├── compliance/               (compliance checks runner)
│   ├── settings.json             (hooks configuration)
│   └── README.md                 (Claude Code setup guide)
│
├── docs/                         ← Public documentation
│   ├── ARCHITECTURE.md           (this file)
│   ├── HOOKS.md                  (hook reference)
│   ├── AGENTS.md                 (agent reference)
│   ├── TROUBLESHOOTING.md        (debugging guide)
│   ├── reglas-scrum.md
│   ├── política-estimacion.md
│   └── ... (20+ reference docs)
│
├── projects/                     ← Customer projects
│   ├── {project}/
│   │   ├── CLAUDE.md             (project context)
│   │   ├── .agent-maps/          (machine-readable AST maps — .acm files)
│   │   ├── .human-maps/          (human-readable narrative maps — .hcm files)
│   │   └── ... (specs, tests, docs)
│   └── ... (other projects)
│
├── scripts/                      ← Automation & CI/CD
│   ├── validate-ci-local.sh      (pre-commit validation)
│   ├── validate-commands.sh
│   ├── context-tracker.sh
│   └── ... (15+ operational scripts)
│
├── tests/                        ← Test suites
│   ├── hooks/                    (BATS tests, 100% coverage)
│   ├── skills/
│   └── integration/
│
├── output/                       ← Generated artifacts
│   ├── audits/
│   ├── reports/
│   ├── dev-sessions/
│   └── agent-traces/
│
├── CLAUDE.md                     (pm-workspace definition)
├── CHANGELOG.md                  (version history)
├── settings.json                 (git config, team structure)
└── README.md                     (getting started)
```

## Settings.json: Hooks Configuration

```json
{
  "hooks": {
    "SessionStart": [
      { "type": "command", "command": "session-init.sh" }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "command": "validate-bash-global.sh" },
      { "matcher": "Edit|Write", "command": "plan-gate.sh" },
      { "matcher": "Task", "command": "agent-dispatch-validate.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "async": true, "command": "post-edit-lint.sh" },
      { "matcher": "Task", "async": true, "command": "agent-trace-log.sh" }
    ],
    "Stop": [
      { "command": "pre-commit-review.sh" },
      { "command": "scope-guard.sh" }
    ]
  }
}
```

## Component Interactions

### Commands ↔ Skills

- **Commands** define the user interface (slash workflow)
- **Skills** implement the capability
- 1 command may use 0, 1, or multiple skills
- Example: `/sprint-plan` command uses `sprint-planning` and `capacity-planning` skills

### Skills ↔ Agents

- **Skills** orchestrate multi-step workflows
- **Agents** provide specialized expertise (implementation, analysis, review)
- Skills delegate compute-heavy tasks to agents via Task tool
- Example: `spec-driven-development` skill delegates to architect, sdd-spec-writer, developers

### Agents ↔ Rules

- **Agents** read applicable rules when executing
- **Rules** provide domain knowledge, conventions, constraints
- Rules are loaded on-demand via `@rule-name` references
- Example: code-reviewer reads `code-review-rules.md`, `dotnet-developer` reads `dotnet-conventions.md`

### Hooks ↔ Flows

- **Hooks** gate operations at lifecycle events
- **Flows** (skills + agents) are what hooks protect
- Hooks block unsafe flows, allow safe ones
- Example: `block-credential-leak` hook prevents flow execution if secrets detected

## Current Metrics

| Component | Count | Location |
|---|---|---|
| **Commands** | 454 | `.claude/commands/` |
| **Skills** | 67 | `.claude/skills/` |
| **Agents** | 33 | `.claude/agents/` |
| **Hooks** | 17 | `.claude/hooks/` (100% tested) |
| **Domain Rules** | 105 | `.claude/rules/domain/` |
| **Language Packs** | 16 | `.claude/rules/languages/` |
| **Tests (BATS)** | 17 hook suites | `tests/hooks/` |
| **Documentation** | 20+ | `docs/` |

## Key Design Decisions

1. **Hooks first, then flow** — Validate safety before any execution
2. **Agent isolation** — Each agent gets fresh context (<12K tokens)
3. **Async logging** — Observability never blocks user interaction
4. **Rules as data** — Constraints externalized from code
5. **100% test coverage** — Critical paths (hooks) fully tested
6. **Composability** — Skills build on each other via agent delegation
7. **Dual code intelligence** — Each project carries machine-readable `.acm` maps (agent AST) and human-readable `.hcm` maps (narrative comprehension). Both live in `projects/{name}/` to keep context self-contained. See `docs/ast-strategy.md`.

## Performance Characteristics

| Operation | Time | Bottleneck |
|---|---|---|
| Session init | ~5s | File I/O (safety net) |
| Command invocation | <100ms | Hook validation |
| Simple skill execution | ~10s | Claude Code inference |
| SDD pipeline (full) | ~2-5min | Agent orchestration + code generation |
| Test suite run | ~30s | BATS execution |

## Extension Points

To add new capabilities:

1. **New command** → Create `.claude/commands/my-command.md`
2. **New skill** → Create `.claude/skills/my-skill/SKILL.md` + `DOMAIN.md`
3. **New agent** → Create `.claude/agents/my-agent.md` (profile + instructions)
4. **New rule** → Create `.claude/rules/domain/my-rule.md`
5. **New hook** → Add to `.claude/hooks/` + `settings.json` + BATS tests
6. **Project comprehension map** → `/codemap:generate-human {project}` creates `projects/{name}/.human-maps/{name}.hcm`

All extensions inherit the same safety gates and context budgets.

## Security Model

1. **Pre-execution gates** (PreToolUse): block dangerous operations
2. **Isolation**: agents run with limited context, no cross-agent state
3. **Credential protection**: dedicated hook (`block-credential-leak`) prevents secret leaks
4. **Audit trail**: all significant actions logged (hooks, agents)
5. **No privilege escalation**: agents cannot modify settings.json, rules, or other agents

## See Also

- Command: `/help` — List all 454 commands with descriptions
- Command: `/architecture show` — Visualize system dependency graph
- Document: `docs/HOOKS.md` — Hook reference
- Document: `docs/AGENTS.md` — Agent catalog
- Document: `docs/TROUBLESHOOTING.md` — Debugging guide
