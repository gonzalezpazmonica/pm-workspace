# Claude Code Best Practices
# ── Extended Reference ──────────────────────────────────────────────────────

> Sources:
> - https://code.claude.com/docs/en/best-practices (official Anthropic)
> - https://github.com/shanraisshan/claude-code-best-practice (community)
> Incorporated and adapted for .NET projects on 2026-02-25.

---

## 1. THE FUNDAMENTAL CONSTRAINT: THE CONTEXT WINDOW

Context is Claude Code's most critical resource. It fills up fast and
performance **degrades** as it approaches the limit. A single debugging cycle
can consume tens of thousands of tokens.

**Mandatory active management:**
- Monitor usage continuously with `/statusline` (configure to show context %)
- `/compact` manually when reaching **50% capacity**
- `/clear` between unrelated tasks to fully reset
- Subagents for long investigations (they don't consume the main context)
- If Claude starts ignoring instructions or making more errors: the context is full

---

## 2. GIVE CLAUDE A WAY TO VERIFY ITS WORK

The highest-impact change possible. Claude performs dramatically better when
it can verify its work autonomously.

### In .NET projects
```bash
# ALWAYS include in implementation prompts:
dotnet build --configuration Release              # Does it compile?
dotnet test --filter "Category=Unit"              # Do tests pass?
dotnet format --verify-no-changes                 # Does it respect the style?
dotnet list package --outdated                    # Are dependencies up to date?
```

### Verification patterns

| Strategy | Without verification | With verification |
|---|---|---|
| **Tests** | *"implement email validation"* | *"implement ValidateEmail. Cases: user@domain.com=true, invalid=false. Create xUnit tests and run them"* |
| **Build** | *"the build fails"* | *"the build fails with this error: [paste error]. Fix it and verify with `dotnet build`. Attack the root cause, don't suppress the error"* |
| **UI** | *"improve the dashboard"* | *"[paste screenshot] implement this design. Take a screenshot of the result and compare. List differences and fix them"* |
| **Regression** | *"refactor this method"* | *"refactor `CalculateCapacity()`. Existing tests must keep passing: `dotnet test --filter FullyQualifiedName~CapacityTests`"* |

**Golden rule:** If you can't verify it, don't ship it.

---

## 3. WORKFLOW: EXPLORE → PLAN → IMPLEMENT → COMMIT

Separating investigation from execution prevents solving the wrong problem.

```
Phase 1 — EXPLORE (Plan Mode activated with /plan)
  Claude reads files and answers questions WITHOUT making changes.
  Example: "Read /src/Services and understand how we manage user sessions"

Phase 2 — PLAN (still in Plan Mode)
  Claude creates a detailed implementation plan.
  Ctrl+G → opens the plan in the editor for editing before proceeding.
  Example: "I want to add OAuth authentication. Which files change? Create a plan."

Phase 3 — IMPLEMENT (back to Normal Mode)
  Claude codes while verifying against its own plan.
  Example: "Implement the OAuth flow from the plan. Write tests for the callback,
           run the suite and fix failures. Verify with `dotnet build`."

Phase 4 — COMMIT
  Claude commits with a descriptive message and opens a PR.
  Example: "Commit with a descriptive message and open a PR"
```

**When to skip planning:**
If you can describe the diff in a single sentence, go straight to implementation.
Planning adds overhead — use it when the task touches multiple files
or when you're unsure of the approach.

---

## 4. PRECISE AND CONTEXT-RICH PROMPTS

### Prompting patterns

| Strategy | Vague | Precise |
|---|---|---|
| **Scope the task** | *"add tests to OrderService.cs"* | *"write xUnit tests for OrderService.cs covering the case where the user has no stock. no database mocks, use TestContainers"* |
| **Point to the source** | *"why does OrderRepository have such a weird API?"* | *"look at the git history of OrderRepository and summarize how it ended up with that API"* |
| **Reference existing patterns** | *"add a new endpoint"* | *"look at how endpoints are implemented in `Controllers/OrdersController.cs` as an example. Follow that pattern to create `POST /api/v1/reservations`. No extra libraries, only the ones already in use"* |
| **Describe the symptom** | *"fix the login bug"* | *"users report that login fails after session timeout. Review `Services/AuthService.cs` especially the token refresh. Write a test that reproduces the failure, then fix it"* |

### Ways to enrich context

- **`@file`** → Claude reads the file before responding
- **Images** → copy/paste or drag screenshots
- **URLs** → documentation, reference APIs (add to `/permissions`)
- **Data piping** → `cat error.log | claude` to send content directly
- **Let Claude search** → *"use `dotnet nuget list` to see the packages and then..."*

---

## 5. ARCHITECTURE: Command → Agent → Skills

The central Claude Code pattern — progression of responsibility:

```
User → /command → Agent (orchestrates) → Skills (knowledge)
```

- **Commands** (`.claude/commands/*.md`) — lightweight entry points; they delegate
- **Agents** (`.claude/agents/*.md`) — orchestrate with their own tools and permissions
- **Skills** (`.claude/skills/<name>/SKILL.md`) — reusable knowledge modules
- **Rules** (`.claude/rules/*.md`) — modular instructions with optional scope
- **Hooks** (`.claude/hooks/`) — guaranteed deterministic actions on every event

Subagents are **never invoked via bash** — always with the `Task` tool.

### When to use each

| Need | Use |
|---|---|
| Reusable workflow | Command + Agent |
| Specific task with its own tools | Subagent |
| Reusable domain knowledge | Skill |
| Persistent instruction with scope | Rule |
| Deterministic action on every event | Hook |
| Guaranteed action without exceptions | Hook (not CLAUDE.md) |

---

## 6. AGENTS, SKILLS AND COMMANDS FRONTMATTER

### Agents (`.claude/agents/*.md`)
```yaml
---
name: agent-name
description: "When to invoke it. Add PROACTIVELY for auto-invocation."
tools: [Read, Write, Bash, Task]
model: sonnet          # haiku | sonnet | opus
permissionMode: acceptEdits
maxTurns: 20
color: cyan
---
```

### Skills (`.claude/skills/<name>/SKILL.md`)
```yaml
---
name: skill-name
description: "When it is invoked."
disable-model-invocation: false   # true = only user can invoke it
user-invocable: true              # false = only Claude, automatically
allowed-tools: [Read, Bash]
---
```

### Subagent for security review (.NET)
```markdown
---
name: dotnet-security-reviewer
description: Reviews .NET code for security vulnerabilities
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior security engineer specialized in .NET.
Review for: SQL injection, XSS, command injection,
authentication/authorization issues, secrets in code,
insecure deserialization, misconfigured CORS, dependencies with CVEs.
Provide specific line references and suggested fixes.
```

---

## 7. CONFIGURATION HIERARCHY

### Settings precedence (highest to lowest)
1. Command-line flags (current session)
2. `.claude/settings.local.json` (project, git-ignored)
3. `.claude/settings.json` (project, version-controlled in git)
4. `~/.claude/settings.local.json` (personal global)
5. `~/.claude/settings.json` (personal global)

### Permissions with wildcards (.NET)
```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet build *)",
      "Bash(dotnet test *)",
      "Bash(dotnet run *)",
      "Bash(dotnet format *)",
      "Bash(dotnet restore *)",
      "Bash(dotnet add package *)",
      "Bash(dotnet ef *)",
      "Bash(az devops *)",
      "Bash(git *)",
      "Edit(./**)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(chmod *)"
    ]
  }
}
```

`deny` rules have maximum priority — they cannot be overridden.

---

## 8. EFFECTIVE CLAUDE.md

### Include / Exclude

| Include | Exclude |
|---|---|
| Bash commands Claude can't guess | What Claude can infer from the code |
| Style rules that differ from defaults | Standard language conventions |
| Preferred test commands and runners | Detailed API documentation (link to it) |
| Repo conventions (branches, PRs, commits) | Frequently changing information |
| Project architectural decisions | Long explanations or tutorials |
| Dev environment quirks (required variables) | File-by-file descriptions |
| Non-obvious common errors | Self-evident practices like "write clean code" |

### Signs of a problematic CLAUDE.md
- Claude ignores a rule → the file is too long, the rule gets lost
- Claude asks things already answered → the wording is ambiguous
- Claude does something incorrect repeatedly → reinforce with "IMPORTANT" or "YOU MUST"

**Limit: 150 lines.** Treat it like code: review when something goes wrong, prune regularly.

### Imports in CLAUDE.md
```markdown
See @README.md for project overview and @package.json for npm commands.

# Additional instructions
- Git workflow: @docs/git-instructions.md
- Personal configuration: @~/.claude/my-project-instructions.md
```

---

## 9. CLAUDE.md LOADING IN MONOREPOS

```
/root/                  ← loaded at startup (current directory)
  CLAUDE.md             ← immediate load (ancestor)
  /frontend/
    CLAUDE.md           ← lazy load (when accessing frontend files)
  /backend/
    CLAUDE.md           ← lazy load (when accessing backend files)
```

- **Ancestor loading**: all CLAUDE.md files from cwd up to `/` are loaded at startup
- **Descendant loading**: lazy, only when accessing files in that subdirectory
- **`CLAUDE.local.md`**: personal preferences → add to `.gitignore`

---

## 10. SESSION AND CONTEXT MANAGEMENT

### Correct early and often
- **`Esc`** → stops Claude mid-action; context is preserved for redirection
- **`Esc + Esc` / `/rewind`** → opens rewind menu; restores conversation, code, or both
- **`"Undo that"`** → Claude reverts its changes
- **`/clear`** → resets context between unrelated tasks

### Correction pattern
If you've corrected Claude 2+ times on the same mistake → the context is contaminated
with failed approaches. Do `/clear` and start with a better prompt that incorporates
what you've learned.

### Checkpoints
Claude creates checkpoints automatically before each change.
`Esc + Esc` → `/rewind` → restore conversation / code / both.
Checkpoints persist across sessions.

### Resuming sessions
```bash
claude --continue      # resume the most recent conversation
claude --resume        # choose from recent sessions
/rename                # give a descriptive name: "oauth-migration", "fix-capacity-bug"
```

---

## 11. "INTERVIEW FIRST" — FOR LARGE FEATURES

For complex features, let Claude interview you before implementing:

```
I want to build [brief description]. Interview me in detail
using the AskUserQuestion tool.

Ask about technical implementation, UX, edge cases,
trade-offs and risks. Don't ask the obvious, dig into
the hard parts I may not have considered.

Keep interviewing until everything is covered, then write a
complete specification in SPEC.md.
```

Once the spec is completed, start a new session to implement it
(clean context, focused solely on implementation).

---

## 12. VERIFICATION PATTERNS FOR .NET

### Hooks for .NET — ensure quality on every change
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "dotnet build --no-restore 2>&1 | tail -5"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "dotnet test --no-build --filter 'Category=Unit'"
    }]
  }
}
```

### .NET conventions skill
```yaml
---
name: dotnet-conventions
description: C# and .NET code conventions for this project
---
# C# Conventions
- Use async/await throughout the chain — never .Result or .Wait()
- Prefer record types for immutable DTOs
- Dependency injection: always via constructor
- Entity Framework: use IQueryable<T>, don't load everything into memory
- Migrations: always review before applying in production
```

---

## 13. AUTOMATION AND SCALING

### Headless mode
```bash
claude -p "Explain what this project does"
claude -p "List all API endpoints" --output-format json
claude -p "Analyze this log" --output-format stream-json
```

### Writer/Reviewer pattern (.NET)
```
Session A (Writer):  "Implement a rate limiter for the API endpoints"
Session B (Reviewer): "Review the implementation in @src/Middleware/RateLimiter.cs.
                       Look for race conditions, edge cases and consistency with
                       existing ASP.NET middleware patterns."
Session A:           "Here's the review feedback: [output B]. Fix the issues."
```

### Fan-out for .NET migrations at scale
```bash
# Example: update NuGet packages across all solution projects
dotnet sln list | grep .csproj > projects.txt
for project in $(cat projects.txt); do
  claude -p "Update outdated NuGet packages in $project.
             Run dotnet test afterwards. Return OK or FAIL with the reason."
    --allowedTools "Edit,Bash(dotnet *),Bash(git commit *)"
done
```

---

## 14. COMMON FAILURE PATTERNS (AND THEIR FIXES)

| Failure | Symptom | Fix |
|---|---|---|
| **"Kitchen sink" session** | Mixing unrelated tasks | `/clear` between tasks |
| **Infinite correction** | Correcting 2+ times the same mistake | `/clear` + better prompt |
| **Bloated CLAUDE.md** | Claude ignores half the rules | Prune ruthlessly (150 lines max) |
| **Trust without verify** | Plausible code that doesn't work on edge cases | Always use verification tests/scripts |
| **Infinite exploration** | Claude reads hundreds of files, context full | Scope investigations or use subagents |
| **Bash blocked in .NET** | Timeouts on long `dotnet test` runs | `--filter "Category=Unit"` for fast tests |

---

## 15. ESSENTIAL MCP SERVERS

| MCP | What for |
|---|---|
| **Context7** | Up-to-date library documentation (avoids hallucinated APIs) |
| **Playwright** | UI automation, testing and verification with screenshots |
| **Claude in Chrome** | Live DOM inspection, console and browser network |
| **DeepWiki** | Structured documentation of GitHub repositories |
| **Azure DevOps MCP** | Advanced chained operations on Azure DevOps |

---

## 16. BORIS CHERNY'S TIPS (February 2026)

1. **Terminal**: `/config` for theme, `/terminal-setup` for shift+enter, `/vim` for vim mode
2. **Effort**: `/model` → High recommended for maximum intelligence
3. **Plugins**: install LSPs, MCPs and skills from the Anthropic marketplace
4. **Agents**: `.claude/agents/*.md` with name, color, tools and their own model
5. **Permissions**: `/permissions` + wildcards + `settings.json` in git for the team
6. **Sandbox**: `/sandbox` for isolation and fewer permission prompts
7. **Status line**: `/statusline` to display model, context, cost, custom metrics
8. **Keybindings**: `/keybindings` with live reload
9. **Hooks**: intercept lifecycle for logging, notifications, auto-continue
10. **Output styles**: `/config` → Explanatory (learning), Learning (coaching), Custom
11. **Version settings**: `settings.json` in git = shared configuration with the team

---

## 17. CLI REFERENCE COMMANDS

```bash
# Session startup and management
claude --continue                  # resume last session
claude --resume                    # choose from recent sessions
claude --model opus                # select model
claude --max-turns 50              # turn limit
claude -p "prompt"                 # headless mode (scripts, CI)
claude -p "prompt" --output-format json   # structured output

# During the session
/plan                              # activate plan mode (explore without modifying)
/compact                           # manually compact context (do at 50%)
/compact "preserve list of modified files"
/rewind                            # checkpoints menu
/clear                             # reset context
/doctor                            # Claude Code diagnostics
/permissions                       # manage permissions
/sandbox                           # activate sandbox
/model                             # change model / effort level
/config                            # configure terminal and output style
/statusline                        # configure status bar
/hooks                             # configure hooks interactively
/memory                            # view and edit persistent memory
/rename                            # name the current session
/cost                              # view current session cost
/init                              # generate initial CLAUDE.md from the project
```

---

## 18. INTERNAL ARCHITECTURE INSIGHTS

Key performance findings from Claude Code architecture review:

1. **CLAUDE.md is per-turn cost**: It is prepended to the first user message
   (dynamic suffix), NOT in the cached system prompt. Every line costs tokens
   on EVERY turn. The 150-line rule is more critical than previously understood.

2. **25KB memory cap**: MEMORY.md has a 25KB byte limit in addition to the
   200-line limit. Keep index entries under 150 characters.

3. **Auto-compact effective window**: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is
   percentage of effective window (contextWindow - 20K output - 13K buffer).
   For Opus 200K: effective ~167K. Set to 65% (~108K) for balanced sessions.

4. **SessionEnd hooks timeout at 1.5s**: Much shorter than the 10-min default
   for other hooks. Keep session-end hooks minimal (no network calls).

5. **Skills zero context until invoked**: Only frontmatter (name, description)
   is loaded at listing time. Full SKILL.md loaded on invocation. 85+ skills
   cost nothing until used. Skill descriptions are critical for routing.

6. **Nested CLAUDE.md cleared on compact**: After auto-compact, accessing
   project subdirectories re-triggers their CLAUDE.md injection. Do not rely
   on nested CLAUDE.md for state that must survive compaction.

7. **@ imports only in text nodes**: Resolved by the markdown lexer, NOT
   inside code blocks or inline code. Never put @imports in fenced blocks.
