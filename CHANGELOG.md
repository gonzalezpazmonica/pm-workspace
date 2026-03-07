## [2.30.0] — 2026-03-07

### Added — Era 59: MCP Tool Search & Smart Routing

Intelligent tool discovery for 400+ commands. Auto-categorization, keyword routing, and usage-based prioritization.

- **`tool-search-config` rule** — 8 command categories with routing heuristics. Auto-activates when tools exceed 128 in context.
- **`/tool-search {query}`** — Search commands, skills, and agents by keyword. Discovers tools across 400+ commands.
- **`/tool-catalog [category]`** — Categorized tool catalog with counts. Navigate the full command library.
- **`smart-routing` skill** — Intent classification, frequency tracking, Top-20 algorithm for always-available commands.

---

## [2.29.0] — 2026-03-07

### Added — Era 58: DOMAIN.md per Skill (Clara Philosophy)

Multi-level documentation layer: SKILL.md defines the "how", DOMAIN.md defines the "why" and domain context. Applied to top 10 skills following Clara Philosophy framework — bridging gap between architecture vision and code implementation.

- **DOMAIN.md** files added to: pbi-decomposition, product-discovery, rules-traceability, spec-driven-development, capacity-planning, sprint-management, azure-devops-queries, scheduled-messaging, context-caching, code-comprehension-report.
- **`clara-philosophy` rule** — Documentation standard: every skill requires SKILL.md (how) + DOMAIN.md (why). Max 60 lines per DOMAIN.md. Required sections: Why, Domain concepts, Business rules, Relationships, Key decisions.
- **`/plugin-validate` enhancement** — Checks for DOMAIN.md presence, max line count, required sections completeness.

---

## [2.27.0] — 2026-03-07

### Added — Era 56: Scheduled Messaging Integration

Wizard-guided setup for Claude Code Scheduled Tasks with automatic result delivery to messaging platforms.

- **`/scheduled-setup {platform}`** — Interactive wizard: platform selection → credential config → module generation → test → task creation. Supports: Telegram, Slack, Teams, WhatsApp (Twilio), NextCloud Talk.
- **`/scheduled-test {platform}`** — Send test message to verify integration.
- **`/scheduled-create`** — Create scheduled task with `--notify {platform}` and `--cron "schedule"`.
- **`/scheduled-list`** — List tasks with notification config and status.
- **`scheduled-messaging` skill** — 5-phase pipeline, 5 platform adapters, 5 pre-built templates (standup, blocker, burndown, deploy, security).
- **`scripts/notify-{platform}.sh`** — Auto-generated notification modules per platform.

---

## [2.26.0] — 2026-03-07

### Added — Era 55: Prompt Caching Strategy

Context loading optimization for prompt caching. Reduces input token costs by ordering stable content first with cache breakpoints.

- **`prompt-caching` rule** — 4-level caching hierarchy: PM globals → project context → skill content → dynamic request. Ordering rules and TTL guidance.
- **`/cache-optimize {project}`** — Analyze context loading order and suggest reordering for optimal cache hit rates. Shows estimated token savings.
- **`context-caching` skill** — Caching templates for common operations (PBI decomposition, spec generation, dev session). Token measurement patterns.

---

## [2.25.0] — 2026-03-07

### Added — Era 54: Plugin Bundle Packaging

Package PM-Workspace as distributable Claude Code plugin with validation and export commands.

- **`.claude-plugin/plugin.json`** — Plugin manifest with capabilities declaration, dependencies, and install paths.
- **`/plugin-export`** — Package current workspace as distributable plugin. Supports `--components` for partial export.
- **`/plugin-validate`** — Validate plugin structure: skills, agents, commands integrity, PII check, line limits.
- **`plugin-packaging` skill** — Packaging logic, validation rules, version management.
