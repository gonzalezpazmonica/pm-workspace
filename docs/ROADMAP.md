# Roadmap

pm-workspace has evolved from a Scrum toolkit into a full PM intelligence platform with 281 commands, 24 agents, 21 skills, 14 hooks, and its own persona (Savia). This roadmap groups the 98 released versions into 20 thematic eras and outlines what comes next.

Status: ✅ Released · 🟡 In progress · 💡 Proposed

Community votes via 👍 on GitHub Issues. See [How to influence the roadmap](#how-to-influence-the-roadmap).

---

## ✅ Eras 1–6 — Foundation to Context Engineering (v0.1.0–v0.44.0, Feb–Mar 2026)

| Era | Versions | Theme | Highlights |
|---|---|---|---|
| 1 — Foundation | v0.1.0–v0.2.0 | Core workspace | Sprint management, reporting, PBI decomposition, SDD, discovery, PR review |
| 2 — Ecosystem | v0.3.0–v0.11.0 | 16→81 commands | 16 language packs, Slack/Jira/Notion connectors, DevOps, CI/CD, UX standards |
| 3 — Context Intelligence | v0.12.0–v0.20.0 | Context window mgmt | 58% context reduction, session persistence, memory system, 150-line discipline |
| 4 — Advanced Intelligence | v0.21.0–v0.34.0 | Deep analysis | Engram memory, security (SAST/SBOM), Monte Carlo, AI governance, architecture |
| 5 — Savia & Personalization | v0.35.0–v0.39.0 | Identity & community | Savia persona, profiles, vertical detection, community PRs, encrypted backups |
| 6 — Context Engineering | v0.40.0–v0.44.0 | Token optimization | Role-adaptive routines, session compression, agent budgets, context aging, semantic hub |

---

## ✅ Eras 7–13 — Roles to Observability (v0.45.0–v0.72.0, Mar 2026)

| Era | Versions | Theme | Highlights |
|---|---|---|---|
| 7 — Role-Specific | v0.45.0–v0.49.0 | 19 role commands | Executive Reports, QA Toolkit, Developer Productivity, Tech Lead, Product Owner |
| 8 — Platform Intelligence | v0.50.0–v0.53.0 | Cross-project | Cross-Project Intelligence, AI Planning, Integration Hub, Multi-Platform |
| 9 — Company Intelligence | v0.54.0–v0.57.0 | Strategic alignment | Company Profile, OKR & Strategy, Intelligent Backlog, Ceremony Intelligence |
| 10 — AI Governance | v0.58.0–v0.61.0 | Responsible AI | AI Safety, Adoption Companion, Enterprise Governance, Vertical Compliance |
| 11 — Context Eng. 2.0 | v0.62.0–v0.65.0 | 200+ cmd scale | Intelligent Loading, Evolving Playbooks ACE, Semantic Memory 2.0, Multi-Layer Cache |
| 12 — Team Excellence | v0.66.0–v0.70.0 | Enterprise | DX Metrics, Team Wellbeing, Accessibility, Audit Trail, Multi-Tenant & Marketplace |
| 13 — Observability | v0.71.0–v0.72.0 | Monitoring | Grafana, Datadog, Azure App Insights, OpenTelemetry. Trace Intelligence |

---

## 📖 Savia Flow — Metodología Adaptativa

pm-workspace includes **Savia Flow**, a complete adaptive PM methodology for AI-augmented teams. Full docs in `docs/savia-flow/` (12 documents, 7500+ lines). 7 pillars: outcome-driven, continuous flow, dual-track, SDD, autonomous quality gates, evolved roles, flow metrics (DORA-based).

---

## ✅ Era 14 — Industry Verticals (v0.73.0, Mar 2026)

Specialized tooling for regulated industries, starting with banking:

- **Vertical Banking** (v0.73.0) — `/banking-detect`, `/banking-bian`, `/banking-eda-validate`, `/banking-data-governance`, `/banking-mlops-audit`. Skill with BIAN framework, EDA patterns, and data governance references.

---

## ✅ Era 15 — Savia Flow Practice (v0.74.0–v0.75.0, Mar 2026)

Practical implementation of Savia Flow: Azure DevOps dual-track, SocialApp example, E2E test harness.

- **Savia Flow Practice** (v0.74.0) — `/flow-setup`, `/flow-board`, `/flow-intake`, `/flow-metrics`, `/flow-spec`. Skill with 6 references. SocialApp example (Ionic + microservices).
- **E2E Test Harness** (v0.75.0) — Docker + autonomous agent. 5 scenarios, 23 steps, mock + live engines. Metrics CSV + auto-report.

---

## ✅ Era 16 — Context Intelligence & AI Roles (v0.76.0–v0.79.0, Mar 2026)

Improvements driven by E2E test results + Fowler Knowledge Priming + NVIDIA multimodal agents + AI-era role evolution.

- **Context Optimization** (v0.76.0) — `max_context` budgets per command, `--spec` filter for intake, `flow-protect` scenario in E2E, stress test scenario (10+ concurrent specs).
- **Knowledge Priming** (v0.77.0) — 7-section priming docs (Fowler pattern), `.priming/` project structure, Design-First + Context Anchoring + Feedback Flywheel integration.
- **Role Evolution** (v0.78.0) — 6 AI-era role categories mapped to Savia Flow, maturity metrics per role, augmented builder patterns.
- **CI + Multimodal Prep** (v0.79.0) — GitHub Action for E2E mock on PRs, multimodal agent reference (VLM vision+text+code), roadmap for visual quality gates.

---

## ✅ Era 17 — AI Tooling & Auto-Compact (v0.80.0–v0.82.0, Mar 2026)

Realistic mock engine, AI role tooling (Knowledge Priming + Persona Tuning), and automatic context compression for E2E harness.

- **Context Optimization v2** (v0.80.0) — Mock engine calibrado por tipo de comando, state file para acumulación de contexto, probabilidad de overflow contextual.
- **AI Role Tooling** (v0.81.0) — `/knowledge-prime` (7 secciones Fowler), `/savia-persona-tune` (5 perfiles de tono).
- **Auto-Compact** (v0.82.0) — `--auto-compact` flag, `--compact-threshold=N`, harness refactorizado en 3 ficheros (≤150 líneas).

---

## ✅ v0.83.0 — Safe Boot, Deterministic CI, PR Governance (Mar 2026)

Stability and safety release:

- **Safe Boot** — MCP servers vacíos al arranque; Savia conecta bajo demanda con `/mcp-server start`. `session-init.sh` v0.42.0: sin red, sin `jq`, timeout 5s, ERR trap. `CLAUDE.md` de 216→120 líneas (regla 19: arranque seguro).
- **Deterministic CI** — Mock engine usa `cksum` hash en vez de `$RANDOM`. Context overflow solo en límite real (200k tokens). 29/29 consistente.
- **PR Governance** — Hook bloquea `gh pr review --approve` (auto-aprobación) y `gh pr merge --admin` (bypass branch protection). `github-flow.md` actualizado.

---

## ✅ Era 18 — Compliance, Distribution & Intelligent Hooks (v0.84.0–v0.89.0, Mar 2026)

Based on research of 15 external sources. Full analysis in `docs/propuestas/roadmap-research-era18.md`.

- **AEPD Compliance** (v0.84.0) — `/aepd-compliance` for agentic AI (4-phase AEPD framework). Extended `/governance-audit` and `/governance-report` with AEPD criteria.
- **skills.sh Publishing** (v0.85.0) — `skillssh-publishing.md` spec, `skillssh-adapter.sh` conversion script, 5 core skills mapped, `--target skillssh` in `/marketplace-publish`.
- **Intelligent Hooks** (v0.86.0) — 3-type hook taxonomy (Command/Prompt/Agent), `prompt-hook-commit.sh` (semantic commit validation), `agent-hook-premerge.sh` (quality gate). Calibration protocol.
- **Excel Reporting** (v0.87.0) — `/excel-report` with multi-tab CSV templates (capacity, CEO, time-tracking). Formula documentation, validation rules.
- **Savia Gallery + Source Tracking** (v0.88.0) — `/savia-gallery` (271 commands by role/vertical). `source-tracking.md` with citation formats (rule:/skill:/doc:/agent:/cmd:/ext:).
- **AI Competency Framework** (v0.89.0) — 6 AI-era competencies with 4 levels each. ADKAR integration via `/adoption-assess --ai-skills`. Scoring 0-100.

---

## ✅ Era 19 — Open Source Synergy (v0.90.0, Mar 2026)

Bidirectional collaboration with the open-source Claude Code ecosystem. Research-driven integration with [claude-code-templates](https://github.com/davila7/claude-code-templates) (21K+ stars, 5,788+ components).

- **Open Source Synergy** (v0.90.0) — `/mcp-browse` (66+ MCPs catalog), `/component-search` (5,788+ components). `docs/recommended-mcps.md` curated MCP guide. `hooks/README.md` categorized documentation. `agent-observability-patterns.md` + `component-marketplace.md` domain rules. Contributed enterprise hooks + agents to claude-code-templates (PR #397).

---

## ✅ Era 20 — Persistent Intelligence & Adaptive Workflows (v0.91.0–v0.98.0, Mar 2026)

Inspired by patterns from [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) (6.6K+ stars). This era transforms pm-workspace from a stateless tool into a learning system. Core theme: **agents that remember, commands that adapt, workflows that validate**.

- **Stress Testing & Bug Fixes** (v0.91.0) — 5 bug fixes (credential-leak jq fallback, session-init ERR trap, premerge line count, scope-guard spec selection, skillssh-adapter). 165 new tests across 7 scripts (stress-hooks, stress-security, stress-scripts, era18-commands, era18-rules, era18-formulas). `test-stress-runner.sh` orchestrator. Tests: 64→229.

- **Agent Memory Foundation** (v0.92.0) — Persistent memory for subagents across sessions. Three scopes: `project` (shared, git-tracked in `.claude/agent-memory/`), `local` (personal, git-ignored in `.claude/agent-memory-local/`), `user` (cross-project in `~/.claude/agent-memory/`). MEMORY.md files for 9 agents. `/agent-memory` command + `agent-memory-protocol.md` rule.

- **Savia Contextual Memory** (v0.93.0) — Savia remembers teams across sessions. Project-scope memory for decisions, vocabulary, communication preferences, and lessons learned. `/savia-recall` to query accumulated context. `/savia-forget` for GDPR-compliant memory pruning (Art. 17 RGPD).

- **Smart Command Frontmatter** (v0.94.0) — Advanced frontmatter for 57 commands. `model` field (haiku/sonnet/opus), `context_cost` (low/medium/high). Tiered rollout: 20 haiku, 29 sonnet, 8 opus. `smart-frontmatter.md` validation rule.

- **RPI Workflow Engine** (v0.95.0) — Formal Research → Plan → Implement workflow with GO/NO-GO gates. `/rpi-start` creates `rpi/{feature}/` folder structure. Orchestrates existing skills: product-discovery, pbi-decomposition, spec-driven-development. `/rpi-status` for progress tracking.

- **Adaptive Output & Onboarding** (v0.96.0) — Three output modes: Coaching (junior devs), Executive (stakeholders), Technical (senior engineers). Auto-detection from user profile and command context. `/onboard` with role-specific checklists (dev/PM/QA). `adaptive-output.md` rule.

- **MCP Toolkit & Async Hooks** (v0.97.0) — `/mcp-recommend` with curated catalog (Context7, DeepWiki, Playwright, Excalidraw, Docker, Slack). `async-hooks-config.md`: hook classification, event coverage 9/16 (56%), `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50`.

- **PR Guardian System** (v0.98.0) — `pr-guardian.yml` with 8 automated gates: description quality, conventional commits, CLAUDE.md context guard (≤120 lines), ShellCheck differential, Gitleaks (700+ patterns), hook safety validator, context impact analysis, PR Digest (auto-comment in Spanish). `/pr-digest` command. `.gitleaks.toml`. Updated PR template with context impact + hook safety sections.

### Backlog — Strategic Evaluation

- **Claude Connectors vs MCP** — Evaluar si Connectors simplifican la arquitectura de integraciones
- **More industry verticals** — Insurance (Guidewire, Solvency II), Retail/eCommerce, Telco (OSS/BSS, eTOM/SID)
- **Multimodal quality gates** — Visual regression via VLM screenshot analysis, diagram-to-spec, wireframe-driven decompose
- **Observability extensions** — New Relic, Splunk, Elastic APM. LLM observability (token usage, prompt latency, model drift)
- **Developer experience** — VS Code / Cursor extension, CLI mode, mobile companion (read-only sprint status)
- **Claude in Chrome integration** — Extracción de datos de portales web sin API para Savia
- **Voice integration** — `/voice-pm` when Claude Code `/voice` reaches GA. Voice-to-command for sprint ceremonies (dictated standups, retros, reviews). Builds on existing `voice-inbox` skill.

---

## How to influence the roadmap

1. Check if your idea already has an open issue — if so, add a 👍 reaction.
2. If not, open a new issue using the **Feature request** template.
3. The most-voted open issues are pulled into the next milestone during planning.
4. Want to implement something? Comment on the issue first — maintainers will confirm the approach fits before you invest time in a PR.
