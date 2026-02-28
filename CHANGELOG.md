# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

*Planned: v0.22.0 (SDD Mejorado/ATL), v0.23.0 (Code Review/GGA), v0.24.0 (Permissions + CI/CD), v0.25.0 (Security + Community).*

---

## [0.21.0] — 2026-02-28

Persistent memory system inspired by Engram (Gentleman Programming): JSONL-based memory store with full-text search, topic_key upsert for evolving decisions, SHA256 deduplication, `<private>` tag privacy filtering, and automatic context injection after compaction.

### Added

**Memory store** — `scripts/memory-store.sh`: bash script managing `output/.memory-store.jsonl` with 4 commands (save, search, context, stats). Features: topic_key upsert (same topic evolves in place, not duplicated), SHA256 hash dedup within 15-min window, `<private>` tag stripping to `[REDACTED]`, 2000-char content limit. Zero external dependencies.

**Post-compaction hook** — `scripts/post-compaction.sh` + SessionStart(compact) in settings.json: automatically injects last 20 memory entries after `/compact`. Groups by type (decisions, bugs, patterns, conventions, discoveries). Resolves the biggest pm-workspace pain point: context loss after compaction.

**3 memory commands** — `/memory-save {tipo} {título}` (with optional `--topic` for evolving decisions), `/memory-search {query}`, `/memory-context [--limit N]`.

### Changed

**`/context-load` updated** — Step 2 now reads from memory-store.jsonl instead of only decision-log.md. Falls back to decision-log for legacy compatibility.

**`/session-save` updated** — Now auto-saves decisions, bugs, and patterns to memory-store in addition to session log and decision-log (legacy). Supports `--topic` for known recurring decisions.

**CLAUDE.md** — Hooks 9→10 (post-compaction). Commands 86→89 (3 memory commands). Memory section updated with memory-store reference.

### Why

Inspired by Engram's approach to persistent memory: the agent decides what's worth remembering (not auto-capture everything), topic_key enables evolving decisions without polluting search, and post-compaction injection ensures context survives `/compact`. Unlike Engram (Go binary + SQLite), pm-workspace's implementation is pure bash + JSONL for zero dependencies.

---

## [0.20.1] — 2026-02-27

Fix developer_type format: revert specs to hyphen format (agent-single) and update test suite. Claude Code does not support colons in developer_type values.

### Fixed

**developer_type format** — Reverted v0.20.0's incorrect change from `agent-single` to `agent:single` in spec files. Fixed `test-workspace.sh` validation regex and layer-assignment-matrix grep to accept hyphen format.

---

## [0.20.0] — 2026-02-27

Context optimization and 150-line discipline enforcement: every skill, agent, and domain rule now complies with the project's own rule #11 (≤150 lines). Progressive disclosure via `references/` subdirectories. CI fixes for spec format validation and release workflow.

### Changed

**CLAUDE.md compacted (195→130 lines)** — Eliminated redundant hook listing, condensed agent flows, moved project table to CLAUDE.local.md only, combined Memory/Hooks/Agent Notes sections. 33% context reduction.

**9 skills refactored with progressive disclosure** — Core workflows stay in SKILL.md (≤145 lines), detailed content extracted to `references/` subdirectories. Skills affected: pbi-decomposition (574→145), spec-driven-development (333→135), diagram-import (279→123), azure-devops-queries (233→126), diagram-generation (195→121), executive-reporting (193→114), capacity-planning (187→119), time-tracking-report (178→123), sprint-management (175→120). ~26 reference files created.

**5 agents refactored** — Detailed check patterns, scripts, and decision trees extracted to `rules/domain/` companion files. Agents: security-guardian (284→102), test-runner (268→113), commit-guardian (250→136), infrastructure-agent (234→123), cobol-developer (181→120). 4 new domain reference files.

**5 domain rules refactored** — Extracted platform-specific strategies and cloud patterns. Rules: infrastructure-as-code (299→139), confidentiality-config (274→139), messaging-config (238→81), environment-config (186→131), command-ux-feedback (176→74). 5 new companion files.

**`context_cost` metadata** — Added `context_cost: medium|high` frontmatter field to refactored skills for context budget awareness.

### Fixed

**CI: spec developer_type format** — Test suite used `agent:single` (colon format) but specs and project convention use `agent-single` (hyphen format, required by Claude Code). Fixed test-workspace.sh validation regex + layer-assignment-matrix grep. Failures since v0.17.0.

**Release workflow: missing npm install** — Added `setup-node@v4` and `npm install --prefix scripts` steps to `.github/workflows/release.yml`. The test suite requires `node_modules` for Excel/PowerPoint validation.

### Metrics

- Files modified: ~30 | New reference files: ~30
- Total context savings: ~3,200 lines extracted to on-demand references
- Zero files >150 lines in skills, agents, or domain rules (language rules exempt)

---

## [0.19.0] — 2026-02-27

Governance hardening inspired by Fernando García Varela's article on AI governance failure modes: scope guard hook to detect silent scope creep, parallel session serialization rule to prevent contradictory changes, and ADR loading at session start to prevent architectural drift.

### Added

**Scope Guard Hook** — `.claude/hooks/scope-guard.sh` (Stop): detects files modified outside the declared scope of the active SDD spec. Compares `git diff` against the "Ficheros a Crear/Modificar" section of the most recently touched `.spec.md` file. Issues a warning to the PM (does not block) when out-of-scope files are found. Excludes test files, config, agent-notes, and other legitimate ancillary changes.

**Parallel session serialization rule** — New critical rule #18 in CLAUDE.md: "ANTES de lanzar Agent Teams o tareas paralelas, verificar que los scopes no se solapan. Si dos specs tocan los mismos módulos → serializar." Prevents the failure mode where two agents produce internally coherent but mutually contradictory code that merges cleanly but behaves incorrectly.

### Changed

**`/context-load` expanded (5→6 steps)** — New step 4/6 "ADRs activos": reads Architecture Decision Records with `status: accepted` from all active projects at session start. Shows up to 5 most recent ADRs with title, date, and project. Prevents long-term architectural drift by reminding the PM of active design decisions.

**`docs/agent-teams-sdd.md`** — New §"Regla de Serialización de Scope" with verification protocol, example showing conflict detection, risk explanation, and reference to scope-guard hook as second line of defense.

**SDD skill** — Added serialization rule reference in §3.3 (agent-team pattern): must verify scope overlap before launching parallel tasks.

**`.claude/settings.json`** — Added `scope-guard.sh` as second Stop hook (after `stop-quality-gate.sh`).

**CLAUDE.md** — New rule #18 (parallel serialization). Hooks count 8→9. New scope-guard entry in hooks section.

**README.md + README.en.md** — Updated hooks count (8→9), added scope guard and serialization features in descriptions. New critical rule #9 (parallel scope verification).

### Why

Inspired by Fernando García Varela's article "IA y Código. Domesticando a mi Nueva Mascota!!!" — after 6 months of serious AI adoption, he identified structural failure modes that productivity studies miss. Two gaps in pm-workspace matched his findings: (1) no programmatic detection of scope creep during agent execution, and (2) no formal protocol for verifying scope disjunction before parallel sessions. The scope guard hook provides runtime detection, the serialization rule provides prevention, and ADR loading at session start addresses his concern about architectural decisions drifting over time.

---

## [0.18.0] — 2026-02-27

Multi-agent coordination inspired by Miguel Palacios' agent team model: agent-notes for persistent inter-agent memory, TDD gate hook for test-first enforcement, security review pre-implementation, Architecture Decision Records, and enhanced SDD handoff protocol with full traceability.

### Added

**Agent Notes system** — `docs/agent-notes-protocol.md` + `docs/templates/agent-note-template.md`: formalized inter-agent communication where each agent writes deliverables in `projects/{proyecto}/agent-notes/` with YAML metadata (ticket, phase, agent, status, dependencies). Next agent in chain reads previous notes before acting. Naming convention: `{ticket}-{tipo}-{fecha}.md`.

**TDD Gate Hook** — `.claude/hooks/tdd-gate.sh` (PreToolUse on Edit/Write): blocks developer agents from editing production code if no corresponding test file exists. Enforces test-first: test-engineer writes tests (Red), developer implements (Green), then refactors. Applied to all 10 developer agents.

**`/security-review {spec}`** — Pre-implementation security review command. Unlike security-guardian (pre-commit code audit), this reviews the spec and architecture against OWASP Top 10 **before** any code is written. Produces a security checklist as INPUT for the developer, not as a final gate.

**`/adr-create {proyecto} {título}`** — Creates Architecture Decision Records with standard format (context, decision, alternatives, consequences). Template at `docs/templates/adr-template.md`. Stored in `projects/{proyecto}/adrs/`.

**`/agent-notes-archive {proyecto}`** — Archives completed agent-notes from closed sprints to `agent-notes/archive/{sprint}/`.

### Changed

**SDD skill workflow expanded** — New phases inserted between spec generation and implementation:
- Phase 2.5: Security Review pre-implementation (`/security-review`)
- Phase 2.6: TDD Gate — test-engineer writes tests BEFORE developer implements
- Phase 3.1: Developer now reads agent-notes (legacy-analysis, architecture-decision, security-checklist, test-strategy) before implementing
- Phase 3.5: Developer writes implementation-log agent-note post-implementation

**10 developer agents** — Added `tdd-gate.sh` PreToolUse hook to: dotnet, typescript, frontend, java, python, go, rust, php, ruby, cobol developers. Blocks production code edits without prior tests.

**architect agent** — New "Agent Notes" section: must write architecture-decision notes and ADRs. Stronger restrictions: "NUNCA decides sin documentar". Security review recommendation for security-impacting decisions.

**test-engineer agent** — New "TDD Gate" section explaining test-first enforcement. New "Agent Notes" section for test-strategy deliverables. Restriction: "NUNCA saltarte el TDD".

**CLAUDE.md** — New §"Agent Notes y ADRs" section. Updated hooks count (7→8, added tdd-gate). Updated SDD flow to include security-review and TDD gate. Updated command count (84→87). New checklist items for agent-notes/ and adrs/.

**README.md + README.en.md** — Added multi-agent coordination feature, Architecture and Security command section, agent-notes protocol doc reference, updated command count.

### Why

Inspired by Miguel Palacios' article "No es Vibe Coding" — his team of 6 specialized AI agents uses three pillars: ticket tracking, agent-notes as persistent memory, and strict workflow handoffs. PM-Workspace had sophisticated agents but lacked formalized inter-agent communication. Agent-notes solve context loss between sessions. TDD gate moves testing from "validation after the fact" to "contract before implementation". Security review shifts from "catch bugs in code" to "prevent bugs by design". ADRs provide traceable architectural decisions that survive across sprints and team changes.

---

## [0.17.0] — 2026-02-27

Advanced agent capabilities, programmatic hooks, Agent Teams support, and SDD spec refinements. Every subagent now has persistent memory, preloaded skills, appropriate permission modes, and developer agents use worktree isolation for parallel implementation.

### Added

**Programmatic hooks system (7 hooks)** — `.claude/hooks/` with enforcement via `.claude/settings.json`:
- `session-init.sh` (SessionStart) — verifies PAT, tools, git branch, sets env vars via `CLAUDE_ENV_FILE`
- `validate-bash-global.sh` (PreToolUse) — blocks `rm -rf /`, `chmod 777`, `curl|bash`, `sudo`
- `block-force-push.sh` (PreToolUse) — blocks `push --force`, push to main/master, `commit --amend`, `reset --hard`
- `block-credential-leak.sh` (PreToolUse) — detects passwords, API keys, tokens, PATs in commands
- `block-infra-destructive.sh` (PreToolUse) — blocks `terraform destroy`, apply in PRE/PRO, `az group delete`, `kubectl delete namespace`
- `post-edit-lint.sh` (PostToolUse, async) — auto-lints files after edit (ruff, eslint, gofmt, rustfmt, rubocop, php-cs-fixer, terraform fmt)
- `stop-quality-gate.sh` (Stop) — detects secrets in staged changes before allowing Claude to finish

**`.claude/settings.json`** — project-level settings with hooks configuration (SessionStart, PreToolUse, PostToolUse, Stop) and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable.

**Agent Teams documentation** — `docs/agent-teams-sdd.md`: guide for experimental multi-agent parallel implementation using lead + teammates pattern with shared task list and worktree isolation.

### Changed

**All 23 agents upgraded** with advanced frontmatter:
- `memory: project` — persistent learning across sessions for all agents
- `skills:` — preloaded skills per agent role (eliminates runtime skill discovery)
- `permissionMode:` — `plan` for planners, `acceptEdits` for developers, `dontAsk` for guardians, `default` for infra
- `isolation: worktree` — all developer agents (dotnet, typescript, frontend, java, python, go, rust, php, ruby) run in isolated worktrees for parallel implementation
- `hooks:` — PreToolUse hooks for guardians and infrastructure agents

**11 skills updated** with `context: fork` and `agent:` fields — skills now declare which subagent should execute them and run in forked context to avoid polluting the main session.

**SDD spec template refined** — added "Inputs / Outputs Contract" with typed parameters, "Constraints and Limits" section (performance, security, compatibility, scalability), "Iteration & Convergence Criteria" section, and SDD principle note ("Describe QUÉ no CÓMO").

**CLAUDE.md** — new §"Hooks Programáticos" section, updated structure diagram with `hooks/` and `settings.json`, Agent Teams reference in flows, updated agent count.

**README.md + README.en.md** — added hooks and agent capabilities feature descriptions, Agent Teams doc reference, updated command/agent counts.

### Why

Claude Code's subagent system supports `memory`, `skills`, `permissionMode`, `isolation`, and `hooks` in agent frontmatter, plus project-level hooks in `settings.json`. PM-Workspace was relying on textual rules in CLAUDE.md for enforcement — agents could accidentally bypass them. With programmatic hooks, critical rules (no force push, no secrets, no destructive infra) are enforced at the tool level before execution. Agent capabilities (memory, worktree isolation, skill preloading) eliminate redundant setup and enable true parallel SDD implementation.

---

## [0.16.0] — 2026-02-27

Intelligent memory system: path-specific auto-loading for all 24 language/domain rule files, auto memory templates per project, new `/memory-sync` command, and comprehensive documentation for symlinks, `--add-dir`, and user-level rules.

### Added

**Path-specific rules (`paths:` frontmatter)** — 21 language files and 3 domain files now include YAML frontmatter with `paths:` patterns. Claude Code auto-loads the correct conventions when touching files of that language (e.g., `.cs` triggers dotnet-conventions, `.py` triggers python-conventions). No manual `@` import needed for language rules.

**`/memory-sync` command** — Consolidates session insights (architecture decisions, debugging solutions, sprint metrics, team patterns) into auto memory topic files. Keeps `MEMORY.md` under 200 lines as an index.

**`scripts/setup-memory.sh`** — Initializes auto memory structure for a project: creates `MEMORY.md` index + 5 topic files (sprint-history, architecture, debugging, team-patterns, devops-notes).

**`docs/memory-system.md`** — Comprehensive guide covering: memory hierarchy, path-specific rules, auto memory, `@` imports, symlinks for shared rules, `--add-dir` for external projects, and user-level rules in `~/.claude/rules/`.

### Changed

**CLAUDE.md** — New §"Sistema de Memoria" section. Added `rules/languages/` to structure diagram. New checklist item for auto memory setup. Reference to `docs/memory-system.md`.

**README.md + README.en.md** — Added "Memory and Context" command section, memory system feature description, and doc reference in the documentation table.

### Why

Claude Code's memory system (v2025+) supports path-specific frontmatter, auto memory with topic files, and hierarchical rule loading. PM-Workspace was loading all language rules manually via `@` imports. With `paths:` frontmatter, the correct conventions activate automatically — reducing context pollution and eliminating manual loading errors. Auto memory provides persistent learning across sessions per project.

---

## [0.15.1] — 2026-02-27

Auto-compact post-command: prevents context saturation after heavy commands. Removed `@command-ux-feedback.md` dependency from 7 commands (saves 148 lines per execution). After every slash command, Claude now suggests `/compact` to free context.

### Added

**Auto-compact protocol** — New §9 in `command-ux-feedback.md`: after EVERY slash command, banner must include `⚡ /compact`. Soft block if PM requests another command without compacting first.

### Changed

**7 commands freed from `@command-ux-feedback.md`** — Removed on-demand load of 148-line rule file from: `project-audit`, `sprint-status`, `kpi-dora`, `debt-track`, `evaluate-repo`, `context-load`, `session-save`. UX rules already enforced via CLAUDE.md #15-#17.
**`context-health.md` §3 rewritten** — "Compactación proactiva" → "Auto-compact post-comando (OBLIGATORIO)". Simplified rules, added soft-block mechanism.
**CLAUDE.md rule #16 updated** — Now mandates auto-compact suggestion after every command execution.

---

## [0.15.0] — 2026-02-27

Command naming fix: Claude Code only supports hyphens in slash command names, not colons. All 106 unique command references across 164 files renamed from colon notation (`/project:audit`) to hyphen notation (`/project-audit`). This fix ensures all documented commands actually work as slash commands.

### Fixed

**All command references renamed** — Colon notation (`/project:audit`, `/sprint:status`, etc.) replaced with hyphen notation (`/project-audit`, `/sprint-status`, etc.) across all documentation, commands, rules, skills, READMEs, CHANGELOG, guides, templates, and scripts. 164 files, 1203 lines changed.

### Why

Claude Code command names only support lowercase letters, numbers, and hyphens (max 64 chars). Colons were never valid — commands like `/project:audit` were interpreted as free text, not as slash commands. The actual command files already used hyphens (`project-audit.md`, `name: project-audit`), but all documentation referenced them with colons.

---

## [0.14.1] — 2026-02-27

Context optimization: auto-loaded baseline reduced by 79% (929 → 193 lines). All 10 domain rules moved to `rules/domain/` (loaded on-demand via `@` references). `/help` rewritten to separate `--setup` from catalog display.

### Changed

**Auto-loaded context** — Moved 10 rules from `.claude/rules/` to `.claude/rules/domain/`. Only `CLAUDE.md` (137 lines) + `CLAUDE.local.md` (36 lines) + base rules (20 lines) load automatically. Domain rules load on-demand when commands reference them via `@`.
**`/help` rewritten** — `--setup` now only runs checks (no catalog). Plain `/help` saves catalog to `output/help-catalog.md` and shows 15-line summary. Removed `@command-ux-feedback.md` dependency.
**`CLAUDE.md` compacted** — Removed verbose rule descriptions, updated all `@` references to `domain/` paths.
**All command `@` references updated** — 9 commands + 1 skill updated from `@.claude/rules/X.md` to `@.claude/rules/domain/X.md`.

---

## [0.14.0] — 2026-02-27

Session persistence: knowledge no longer lost between sessions. Inspired by Obsidian vault pattern — pm-workspace now has save/load rituals that build a persistent "second brain" for the PM.

### Added

**`/session-save` command** — Captures decisions, results, modified files, and pending tasks before `/clear`. Saves to two destinations: session log (`output/sessions/`) and cumulative decision log (`decision-log.md`).
**`decision-log.md`** — Private (git-ignored) cumulative register of PM decisions. Max 50 entries. Loaded by `/context-load` at session start.
**`output/sessions/`** — Session history with full context for continuity.

### Changed

**`/context-load` rewritten** — Now loads the "big picture": recent decisions from decision-log, last session's pending tasks, project health (last audit score, open debt, risks), plus git activity. Stack-aware (GitHub-only vs Azure DevOps).
**Command count** — 81 → 83 commands (added session-save, help --setup as separate entry).

---

## [0.13.2] — 2026-02-27

Fix silent failures: heavy commands (project-audit, evaluate-repo, legacy-assess) now explicitly delegate analysis to subagents. Added stack detection to project-audit prerequisite checks.

### Fixed

**`/project-audit` silent failure** — At 100% context, the command produced zero output. Root cause: anti-improvisation rule prevented Claude from using subagents (not defined in command spec). Now explicitly delegates to `Task` subagent.

### Changed

**`/project-audit`** — Rewritten: mandatory subagent delegation (§4), stack-aware prereqs (GitHub-only vs Azure DevOps), output-first summary.
**`/evaluate-repo`** — Added mandatory subagent delegation for analysis.
**`/legacy-assess`** — Added mandatory subagent delegation for analysis.

---

## [0.13.1] — 2026-02-27

Anti-improvisation: commands now strictly execute only what their `.md` file defines. `/help --setup` rewritten with explicit stack detection (GitHub-only vs Azure DevOps) and conditional checks.

### Changed

**`/help` rewritten** — Stack detection from `CLAUDE.local.md`, conditional checks per stack, catalog split by availability. No more improvised edits to `CLAUDE.local.md`.
**`command-ux-feedback.md` §8** — New anti-improvisation rule: commands ONLY perform defined actions, undefined scenarios → error with suggestion.
**CLAUDE.md rule #17** — Anti-improvisation elevated to critical rule.

---

## [0.13.0] — 2026-02-27

Context health and operational resilience: proactive context management to prevent saturation. Output-first pattern, subagent delegation, compaction suggestions, session focus. pm-workflow.md slimmed from 140→42 lines. Auto-loaded context: 899 lines (was 2,109 pre-v0.12.0).

### Added

**Context health rule** — `context-health.md`
- Output-first: results > 30 lines → file, summary in chat
- Subagent delegation for heavy commands (audit, evaluate, legacy, spec)
- Proactive compaction: suggest `/compact` after 10+ turns or 3+ commands
- Session focus: one task per session, `/clear` between topics
- Persistent state via project files (debt-register, risk-register, audits)

**Critical rule #16** — Context management in CLAUDE.md
**Compaction instructions** — Preserve files, scores, decisions on `/compact`

### Changed

- `pm-workflow.md`: 140→42 lines (-70%), command table to `references/command-catalog.md`
- `command-ux-feedback.md`: added output-first section, compacted from 155→138 lines
- `command-catalog.md`: updated from 37→81 commands, compact inline format

---

## [0.12.0] — 2026-02-27

Context optimization: 58% reduction in auto-loaded context. Domain-specific rules moved to on-demand loading, freeing ~1,200 lines of context window for actual PM work. Prevents context saturation that caused commands to fail silently at high usage.

### Changed

**Context architecture overhaul**
- Created `rules/domain/` subdirectory for domain-specific rules (excluded from auto-loading via `.claudeignore`)
- 8 rules moved from auto-load to on-demand: `infrastructure-as-code.md` (289 lines), `confidentiality-config.md` (274), `messaging-config.md` (238), `environment-config.md` (186), `mcp-migration.md` (72), `connectors-config.md` (66), `azure-repos-config.md` (52), `diagram-config.md` (50)
- Auto-loaded context reduced from 2,109 lines to 882 lines (-58%)
- 10 core rules remain auto-loaded: pm-config, pm-workflow, github-flow, command-ux-feedback, command-validation, file-size-limit, readme-update, language-packs, agents-catalog, pm-config.local
- Commands that need domain rules now reference them explicitly with `@.claude/rules/domain/` path
- `.claudeignore` updated to exclude `rules/domain/` alongside existing `rules/languages/` exclusion

**References updated across 17 files:**
- CLAUDE.md: 4 rule references updated to `domain/` path
- 6 messaging commands: messaging-config reference updated
- 4 Azure Repos commands: azure-repos-config reference updated
- 1 skill (azure-pipelines): environment-config reference updated
- pm-workflow.md: 8 references updated
- docs (ES/EN): structure trees updated showing auto-loaded vs on-demand

---

## [0.11.0] — 2026-02-27

UX Feedback Standards: Every command now provides consistent visual feedback — start banners, progress indicators, error handling with interactive recovery, and end banners. The PM always knows what's happening. Interactive setup mode in `/help --setup` guides through configuration step by step.

### Added

**UX Feedback rule** — `command-ux-feedback.md`
- Mandatory feedback standards for ALL commands (start banner, progress, errors, end banner)
- Interactive prerequisite resolution: missing config → ask PM → save → retry automatically
- Progress indicators for multi-step commands (`📋 Paso 1/N — Descripción...`)
- Three completion states: success (`✅`), partial (`⚠️`), error (`❌`)
- Automatic retry after interactive configuration — PM never re-types the command

### Changed

**`/help` rewritten with interactive setup mode**
- Shows `✅`/`❌` per configuration check with clear explanations
- For each missing item: explains why it's needed, asks for the value interactively, saves it, confirms
- After resolving all issues, re-verifies and shows updated status
- Retry flow: fail → ask → save → retry → show result

**6 core commands updated with UX feedback pattern:**
- `/sprint-status` — banners, prerequisite checks, progress steps, completion summary
- `/project-audit` — banners, interactive project creation if missing, 5-step progress, detailed completion
- `/evaluate-repo` — banners, clone verification, 5-step progress, score summary
- `/debt-track` — banners, parameter validation, 3-step progress, debt ratio summary
- `/kpi-dora` — banners, prerequisite checks, 4-step progress, performer classification
- `/context-load` — banners, 5-step progress, session summary

**Documentation updated:**
- `pm-workflow.md` — added UX Feedback reference
- `docs/readme/02-estructura.md` — added `command-ux-feedback.md` to rules tree
- `docs/readme_en/02-structure.md` — same update (EN)

---

## [0.10.0] — 2026-02-27

Infrastructure and tooling: GitHub Actions workflow for auto-labeling PRs, and MCP migration guide documenting which `azdevops-queries.sh` functions are replaced by MCP tools and which must be kept.

### Added

**GitHub Actions** — PR #45
- `auto-label-pr.yml` — automatically labels PRs based on branch prefix (`feature/` → feature, `fix/` → fix, `docs/` → docs, etc.) and adds size labels (XS/S/M/L/XL) based on total lines changed. Creates labels on first use with color coding

**MCP migration guide** — `mcp-migration.md` config rule
- Documents equivalence between `azdevops-queries.sh` functions and MCP tools
- 5 functions fully migrated to MCP: `get_current_sprint`, `get_sprint_items`, `get_board_status`, `update_workitem`, `batch_get_workitems`
- 3 functions kept in script (no MCP equivalent): `get_burndown_data` (Analytics OData), `get_team_capacities` (Work API), `get_velocity_history` (hybrid)
- Decision rule: CRUD → MCP, Analytics/OData/Capacities → keep script

### Changed
- `azdevops-queries.sh` header updated with migration notes and reference to `mcp-migration.md`
- `pm-workflow.md` updated with MCP migration reference

---

## [0.9.0] — 2026-02-27

Messaging & Voice Inbox: WhatsApp (personal, no requiere Business) y Nextcloud Talk como canales de comunicación bidireccional. El PM puede enviar mensajes de voz por WhatsApp y pm-workspace los transcribe con Faster-Whisper (local, sin APIs externas), interpreta la intención y propone el comando correspondiente. Tres modos de operación: manual, background polling y listener persistente. Adds 6 new commands, 1 skill, 1 config rule. Total: 81 slash commands, 13 skills.

### Added

**Messaging & Inbox commands (6)** — PR #44
- `/notify-whatsapp {contacto} {msg}` — enviar notificaciones e informes por WhatsApp al PM o grupo del equipo. Funciona con cuenta personal (no requiere Business). Soporta adjuntos (PDF, imágenes)
- `/whatsapp-search {query}` — buscar mensajes en WhatsApp como contexto: decisiones, acuerdos, conversaciones del equipo. Datos en SQLite local (nunca se envían a terceros)
- `/notify-nctalk {sala} {msg}` — enviar notificaciones a sala de Nextcloud Talk. Funciona con cualquier instancia Nextcloud (self-hosted o cloud). Soporta ficheros adjuntos via Nextcloud Files
- `/nctalk-search {query}` — buscar mensajes en Nextcloud Talk: decisiones y contexto del equipo
- `/inbox-check` — revisar mensajes nuevos en todos los canales configurados. Transcribe audios con Faster-Whisper (local), interpreta peticiones del PM y propone el comando de pm-workspace correspondiente
- `/inbox-start --interval {min}` — iniciar monitor de inbox en background. Polling cada N minutos mientras la sesión esté abierta. Se detiene automáticamente al cerrar sesión

**Voice Inbox skill** — transcripción de audio y flujo audio→texto→acción
- Faster-Whisper local (modelos: tiny, base, small, medium, large-v3)
- Detección automática de idioma
- Mapeo de intención: voz del PM → comando de pm-workspace con nivel de confianza
- Confirmación obligatoria antes de ejecutar (configurable)

**Messaging config rule** — `messaging-config.md`
- Configuración centralizada: WhatsApp (personal vía whatsmeow) + Nextcloud Talk (API REST v4)
- 3 modos de operación documentados con ejemplos: manual, background polling, listener persistente
- Documentación completa de primer uso, instalación y configuración de cada canal
- Referencia MCP tools (WhatsApp) y API endpoints (Nextcloud Talk)

### Changed
- Command count: 75 → 81 (+6 messaging & inbox)
- Skills count: 12 → 13 (+voice-inbox)
- Help command updated with Mensajería e Inbox (6) category
- `pm-workflow.md` updated with 6 new commands + 2 new references (messaging-config, voice-inbox)
- READMEs (ES/EN) updated with messaging & inbox commands

---

## [0.8.0] — 2026-02-27

DevOps Extended: Azure DevOps Wiki management, Test Plans visibility, and security alerts. Leverages remaining MCP tool domains. Adds 5 new commands. Total: 75 slash commands.

### Added

**DevOps Extended commands (5)** — PR #43
- `/wiki-publish {file} --project {p}` — publish markdown documentation to Azure DevOps Wiki. Supports create and update operations via MCP wiki tools
- `/wiki-sync --project {p}` — bidirectional sync between local docs and Azure DevOps Wiki. Three modes: status (compare), push (local→wiki), pull (wiki→local). Conflict detection
- `/testplan-status --project {p}` — Test Plans dashboard: active plans, suites, test cases, execution rates (passed/failed/blocked/not run), PBI test coverage, alerts for untested PBIs
- `/testplan-results --project {p} --run {id}` — detailed test run results: failure analysis, stack traces, flaky test detection, trend over last N runs, recommendations for Bug PBI creation
- `/security-alerts --project {p}` — security alerts from Azure DevOps Advanced Security: CVEs, exposed secrets, code vulnerabilities. Severity filtering, trend analysis, optional PBI creation for critical/high alerts

### Changed
- Command count: 70 → 75 (+5 DevOps Extended)
- Help command updated with DevOps Extended (5) category
- `pm-workflow.md` updated with 5 new command entries
- READMEs (ES/EN) updated with DevOps Extended commands

---

## [0.7.0] — 2026-02-27

Project Onboarding Pipeline: 5-phase automated workflow for onboarding new projects. From audit to kickoff in one pipeline. Adds 5 new commands. Total: 70 slash commands.

### Added

**Project Onboarding commands (5)** — PR #42
- `/project-audit --project {p}` — (Phase 1) Deep project audit: 8 dimensions (code quality, tests, architecture, debt, security, docs, CI/CD, team health). Generates prioritized action report with 3 tiers: critical, improvable, correct. Leverages `/debt-track`, `/kpi-dora`, `/pipeline-status`, `/sentry-health` internally
- `/project-release-plan --project {p}` — (Phase 2) Prioritized release plan from audit + backlog. Groups PBIs into releases respecting dependencies, risk, and business value. Supports greenfield and legacy (strangler fig) strategies
- `/project-assign --project {p}` — (Phase 3) Distribute work across team by skills, seniority, and capacity. Scoring algorithm: skill_match (40%) + capacity (30%) + seniority_fit (20%) + context_bonus (10%). Alerts for overload and bus factor
- `/project-roadmap --project {p}` — (Phase 4) Visual roadmap: Mermaid Gantt with milestones, dependencies, releases. Exports to Draw.io/Miro. Two audiences: tech (detailed) and executive (summary)
- `/project-kickoff --project {p}` — (Phase 5) Compile phases 1-4 into kickoff report. Notify PM via Slack/email. Optionally create Sprint 1 in Azure DevOps with Release 1 scope

### Changed
- Command count: 65 → 70 (+5 onboarding)
- Help command updated with Project Onboarding (5) category
- `pm-workflow.md` updated with 5 new onboarding command entries
- READMEs (ES/EN) updated with project onboarding commands

---

## [0.6.0] — 2026-02-27

Legacy assessment, backlog capture from unstructured sources, and automated release notes generation. Adds 3 new commands. Total: 65 slash commands.

### Added

**Legacy & Capture commands (3)** — PR #41
- `/legacy-assess --project {p}` — legacy application assessment: complexity score (6 dimensions), maintenance cost, risk rating, modernization roadmap using strangler fig pattern. Output: `output/assessments/YYYYMMDD-legacy-{project}.md`
- `/backlog-capture --project {p} --source {tipo}` — create PBIs from unstructured input: emails, meeting notes, Slack messages, support tickets. Deduplicates against existing backlog, classifies by type and priority
- `/sprint-release-notes --project {p}` — auto-generate release notes combining Azure DevOps work items + conventional commits + merged PRs. Three audience levels: tech, stakeholder, public

### Changed
- Command count: 62 → 65 (+3 legacy & capture)
- Help command updated with Legacy & Capture (3) category
- `pm-workflow.md` updated with 3 new command entries
- READMEs (ES/EN) updated with legacy & capture commands

---

## [0.5.0] — 2026-02-27

Governance foundations: technical debt tracking, DORA metrics, dependency mapping, retrospective action follow-up, and risk management. Adds 5 new governance commands. Total: 62 slash commands.

### Added

**Governance commands (5)** — PR #40
- `/debt-track --project {p}` — technical debt register: debt ratio, trend per sprint, SonarQube integration. Stores data in `projects/{p}/debt-register.md`
- `/kpi-dora --project {p}` — DORA metrics dashboard: deployment frequency, lead time, change failure rate, MTTR. Classifies as Elite/High/Medium/Low per DORA 2025 benchmarks
- `/dependency-map --project {p}` — cross-team/cross-PBI dependency mapping with blocking alerts, circular dependency detection, critical path analysis. Visual graph via `/diagram-generate`
- `/retro-actions --project {p}` — retrospective action items tracking: ownership, status, % implementation across sprints. Detects recurrent themes and suggests elevation to initiatives
- `/risk-log --project {p}` — risk register: probability × impact matrix (1-3 scale), exposure scoring, risk burndown chart. Stores in `projects/{p}/risk-register.md`

### Changed
- Command count: 57 → 62 (+5 governance)
- Help command updated with Governance (5) category
- `pm-workflow.md` updated with 5 new governance command entries
- READMEs (ES/EN) updated with governance commands

---

## [0.4.0] — 2026-02-27

Connectors ecosystem, Azure DevOps MCP optimization, CI/CD pipelines, and Azure Repos management. Adds 8 connector integrations (23 commands), 5 pipeline commands, 6 Azure Repos commands, 1 new skill, and 1 new config rule. Total: 57 slash commands, 12 skills.

### Added

**Connector integrations (8 connectors, 12 commands)** — PRs #27–#34
- `/notify-slack {canal} {msg}` — send notifications and reports to Slack channels
- `/slack-search {query}` — search messages and decisions in Slack for context
- `/github-activity {repo}` — analyze GitHub activity: PRs, commits, contributors
- `/github-issues {repo}` — manage GitHub issues: search, create, sync with Azure DevOps
- `/sentry-health --project {p}` — health metrics from Sentry: error rate, crash rate, p95 latency
- `/sentry-bugs --project {p}` — create Bug PBIs in Azure DevOps from frequent Sentry errors
- `/gdrive-upload {file} --project {p}` — upload generated reports and documents to Google Drive
- `/linear-sync --project {p}` — bidirectional sync Linear issues ↔ Azure DevOps PBIs/Tasks
- `/jira-sync --project {p}` — bidirectional sync Jira issues ↔ Azure DevOps PBIs
- `/confluence-publish {file} --project {p}` — publish documentation and reports to Confluence
- `/notion-sync --project {p}` — bidirectional document sync with Notion databases
- `/figma-extract {url} --project {p}` — extract UI components, screens, and design tokens from Figma
- `connectors-config.md` — centralized connector configuration with per-connector enable/disable

**Azure Pipelines CI/CD (5 commands, 1 skill)** — PR #35
- `/pipeline-status --project {p}` — pipeline health: last builds, success rate, duration, alerts
- `/pipeline-run --project {p} {pipeline}` — execute pipeline with preview and PM confirmation
- `/pipeline-logs --project {p} --build {id}` — build logs: timeline, errors, warnings
- `/pipeline-create --project {p} --name {n}` — create pipeline from YAML templates with preview
- `/pipeline-artifacts --project {p} --build {id}` — list/download build artifacts
- `azure-pipelines` skill with YAML templates (build+test, multi-env, PR validation, nightly) and stage patterns (DEV→PRE→PRO with approval gates)

**Azure Repos management (6 commands, 1 config rule)** — PR #36
- `/repos-list --project {p}` — list Azure DevOps repositories with stats
- `/repos-branches --project {p} --repo {r}` — branch management: list, create, compare
- `/repos-pr-create --project {p} --repo {r}` — create PR with work item linking, reviewers, auto-complete
- `/repos-pr-list --project {p}` — list PRs: pending, assigned to PM, by reviewer
- `/repos-pr-review --project {p} --pr {id}` — multi-perspective PR review (BA, Dev, QA, Security, DevOps)
- `/repos-search --project {p} {query}` — search code across Azure Repos
- `azure-repos-config.md` — dual Git provider support (`GIT_PROVIDER = "github" | "azure-repos"` per project)

**DevOps workflow improvements** — PR #26
- Task ID in branch names: `feature/#XXXX-descripcion`
- Auto-reviewer assignment on PR creation
- PM notification filter for relevant updates

### Changed
- PAT scopes expanded: `Code R/W`, `Build R/W`, `Release R` (for pipeline and repo operations)
- Command count: 46 → 57 (+5 pipeline, +6 repos, no net change from connectors already counted in 0.3.0 changelog)
- Skills count: 11 → 12 (+azure-pipelines)
- Help command updated with Pipelines (5) and Azure Repos (6) categories
- `pm-workflow.md` updated with 11 new command entries
- READMEs (ES/EN) updated with new commands, skill, and rule entries
- GitHub CLI (`gh`) added as workspace dependency in SETUP.md

---

## [0.3.0] — 2026-02-26

Multi-language, multi-environment, infrastructure as code, documentation reorganization, and file size governance. Adds 16 Language Packs, 7 new commands, 1 new agent, 12 new developer agents, and a 150-line file size rule.

### Added

**Multi-language support (16 Language Packs)**
- Per-language conventions, rules, developer agents, and layer matrices for: C#/.NET, TypeScript/Node.js, Angular, React, Java/Spring Boot, Python, Go, Rust, PHP/Laravel, Swift/iOS, Kotlin/Android, Ruby/Rails, VB.NET, COBOL, Terraform/IaC, Flutter/Dart
- 12 new developer agents: `typescript-developer`, `frontend-developer`, `java-developer`, `python-developer`, `go-developer`, `rust-developer`, `php-developer`, `mobile-developer`, `ruby-developer`, `cobol-developer`, `terraform-developer`, `infrastructure-agent`
- `language-packs.md` — centralized Language Pack catalog with auto-detection table
- `agents-catalog.md` — centralized agent catalog with flow diagrams
- `docs/guia-incorporacion-lenguajes.md` — step-by-step guide for adding new languages

**Multi-environment and Infrastructure as Code**
- `environment-config.md` — configurable multi-environment system (DEV/PRE/PRO by default, customizable names and counts)
- `confidentiality-config.md` — secrets protection policy (Key Vault, SSM, Secret Manager, config.local/)
- `infrastructure-as-code.md` — multi-cloud IaC support (Terraform, Azure CLI, AWS CLI, GCP CLI, Bicep, CDK, Pulumi)
- `infrastructure-agent` (Opus 4.6) — auto-detect existing resources, minimum viable tier, cost estimation, human approval for scaling
- 7 new commands: `/infra-detect`, `/infra-plan`, `/infra-estimate`, `/infra-scale`, `/infra-status`, `/env-setup`, `/env-promote`

**File size governance**
- `file-size-limit.md` — max 150 lines per file (code, rules, docs, tests); legacy inherited code exempt unless PM requests refactor

**Team evaluation and onboarding**
- `/team-evaluate` — competency evaluation across 8 dimensions with radar charts
- `business-analyst` agent extended with onboarding and GDPR-compliant evaluation capabilities
- Onboarding proposal and evaluation framework in `docs/propuestas/`

### Changed
- README.md and README.en.md split into 12 sections each under `docs/readme/` and `docs/readme_en/`; root READMEs now serve as compact hub documents (~130 lines)
- Documentation moved from root to `docs/`: ADOPTION_GUIDE, SETUP, ROADMAP, proposals, .docx guides
- CLAUDE.md compacted from 217 to 127 lines; agent and language tables externalized to dedicated rule files
- Workspace totals: 24 → 35 commands, 11 → 23 agents, 8 → 9 skills
- All .NET-only references updated to multi-language throughout documentation
- Cross-references updated across 6 files after reorganization

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion. Adds 6 new slash commands, 1 new skill, enhances 2 existing agents, and aligns all documentation.

### Added

**Product Discovery workflow**
- `/pbi-jtbd {id}` — generate Jobs to be Done document for a PBI before technical decomposition
- `/pbi-prd {id}` — generate Product Requirements Document (MoSCoW prioritisation, Gherkin acceptance criteria, risks)
- `product-discovery` skill with JTBD and PRD reference templates

**Quality and operations commands**
- `/pr-review [PR]` — multi-perspective PR review from 5 angles
- `/context-load` — session initialisation: loads CLAUDE.md, checks git, summarises commits, verifies tools
- `/changelog-update` — automates CHANGELOG.md updates from conventional commits
- `/evaluate-repo [URL]` — static security and quality evaluation of external repositories

**Agents and rules enhancements**
- `security-guardian` — SEC-8: merge conflict markers detection
- `commit-guardian` — CHECK 9: commit atomicity verification
- `csharp-rules.md` — 70+ static analysis rules + 12 Clean Architecture/DDD rules
- `test-runner` agent — post-commit test execution and coverage orchestration
- `CLAUDE_MODEL_MID` — new constant for mid-tier model (Sonnet)

### Changed
- Models upgraded to generation 4.6: Opus `claude-opus-4-6`, Sonnet `claude-sonnet-4-6`
- `commit-guardian` expanded from 8 to 10 checks
- `security-guardian` expanded from 8 to 9 checks
- Workspace totals: 19 → 24 commands, 7 → 8 skills, 9 → 11 agents

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

### Added

**Core workspace**
- `CLAUDE.md` — global entry point with org constants, project registry, and tool definitions
- `docs/SETUP.md` — step-by-step setup guide

**Sprint management commands**
- `/sprint-status`, `/sprint-plan`, `/sprint-review`, `/sprint-retro`

**Reporting commands**
- `/report-hours`, `/report-executive`, `/report-capacity`
- `/team-workload`, `/board-flow`, `/kpi-dashboard`

**PBI decomposition commands**
- `/pbi-decompose`, `/pbi-decompose-batch`, `/pbi-assign`, `/pbi-plan-sprint`

**Skills**
- `azure-devops-queries`, `sprint-management`, `capacity-planning`
- `time-tracking-report`, `executive-reporting`, `pbi-decomposition`

**Spec-Driven Development (SDD)**
- `/spec-generate`, `/spec-implement`, `/spec-review`, `/spec-status`, `/agent-run`
- `spec-driven-development` skill with spec template, layer matrix, agent patterns

**Test project** (`projects/sala-reservas/`)
- Meeting room booking app (.NET 8, Clean Architecture, CQRS/MediatR)
- 16 business rules, 3 PBIs, 2 complete SDD specs

**Test suite** (`scripts/test-workspace.sh`)
- 96 tests across 9 categories with mock and real modes

**Documentation**
- `README.md` with 9 annotated examples
- `docs/` methodology: Scrum rules, estimation policy, KPIs, report templates, workflow guide

---

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.21.0...HEAD
[0.21.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.1...v0.21.0
[0.20.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.0...v0.20.1
[0.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.1...v0.16.0
[0.15.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.2...v0.14.0
[0.13.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.1...v0.13.2
[0.13.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
