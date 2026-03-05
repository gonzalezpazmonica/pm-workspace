# Roadmap

pm-workspace has evolved from a Scrum toolkit into a full PM intelligence platform with 360+ commands, 27 agents, 30 skills, 15 hooks, and its own persona (Savia). This roadmap groups the released versions into 34 thematic eras and outlines what comes next.

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

---

## ✅ Era 21 — Savia Everywhere: School, Travel, Git-Native Flow (v0.99.0–v1.5.0, Mar 2026)

Inspired by ecosystem research of 12+ Claude Code repositories (everything-claude-code, trail-of-bits, awesome-claude-code, etc.). Full analysis in `docs/propuestas/investigacion-ecosistema-claude-code-2026.md` and `docs/propuestas/era21-masterplan.md`.

- **Company Savia** (v0.99.0) — Git-based company repo with async messaging, E2E encryption (RSA-4096 + AES-256-CBC), @handle addressing, privacy-check pre-push. 7 commands, 5 scripts, 1 skill, 1 rule. Cross-platform compat layer (v0.99.1). Integration test orchestrator (v0.99.2).

- **Travel Mode** (v0.100.0, v1.1.0) — Portable Savia on USB drive. 5 commands: `/travel-pack`, `/travel-unpack`, `/travel-sync`, `/travel-verify`, `/travel-clean`. AES-256-CBC encryption for keys/PATs. SHA256 integrity verification. `savia-init.sh` auto-installer. 3 scripts.

- **Savia Flow Git-Native** (v0.101.0, v1.2.0) — Complete SDD/tickets/tasks/timesheets in Git folders. 17 commands across PBI, sprint, board, timesheet, and task lifecycle. Kanban board via filesystem (todo/in-progress/review/done folders). 6 scripts, 1 rule.

- **Script Hardening** (v1.0.0) — Fix 6 critical bugs (backup hash, contribute regex, memory-store injection, cache invalidation) + 7 medium fixes (macOS sed/date portability, POSIX regex, newline escaping). 9 scripts hardened.

- **Git Persistence Engine** (v1.3.0) — TSV-based index system for low-context lookups. 6 index types: profiles, messages, projects, tasks, specs, timesheets. 3 commands, 2 scripts. ~60-80% context reduction per query.

- **Savia School** (v1.4.0) — Educational vertical for classrooms. 12 commands. Alias-based enrollment (no PII). AES-256 encrypted evaluations. GDPR Art. 8/15/17 compliance. `school-safety-config.md` rule.

- **Ecosystem Integration & Validation** (v1.5.0) — Research of 12+ Claude Code repos. 12 improvement proposals. Company Savia full validation. 18/18 test suites (197 tests). E2E confidentiality testing. Subject sensitivity validation for encrypted messages.

---

## ✅ Era 22 — Company Savia v3 + Quality Framework (v1.6.0–v1.7.0, Mar 2026)

Branch-based isolation, self-improvement patterns, and quality gates. Full details in `docs/roadmap-v1.7.0.md`.

- **Company Savia v2** (v1.6.0) — Directory restructure: `team/` → `users/`, `company-inbox/` → `company/inbox/`, new `teams/`. User path simplification: removed `public/`, `savia-` prefixes. TSV index optimization.

- **Company Savia v3** (v1.7.0) — Git orphan branch isolation (`main`, `user/{handle}`, `team/{name}`, `exchange`). `savia-branch.sh` abstraction layer (7 commands). 20 core scripts rewritten. Rules #21 (Self-Improvement Loop) and #22 (Verification Before Done). Agent Self-Memory (10 agents). `/drift-check` + `drift-auditor` agent. `hook-pii-gate.sh` PII scanner. Frontend Component Rules. 120 Savia tests, 0 failures.

---

## ✅ Era 23 — Usage Guides & Vertical Onboarding (v1.8.0, Mar 2026)

Scenario-specific guides that put users in their shoes: zero-to-productive walkthroughs with roles, day-to-day workflows, and real command sequences. 10 guides across software, education, hardware, research, startups, nonprofits, legal, and healthcare.

- [x] `docs/guides/guide-azure-devops.md` — Software consultancy with Azure DevOps (full Scrum + SDD + CI/CD)
- [x] `docs/guides/guide-jira.md` — Software consultancy with Jira (sync + hybrid workflow)
- [x] `docs/guides/guide-savia-standalone.md` — Software team using only Savia + Savia Flow (no external PM tool)
- [x] `docs/guides/guide-education.md` — Educational center (Savia School + classroom management)
- [x] `docs/guides/guide-hardware-lab.md` — Hardware prototyping lab (BOM, iterations, compliance)
- [x] `docs/guides/guide-research-lab.md` — Research laboratory (papers, experiments, datasets, grants)
- [x] `docs/guides/guide-startup.md` — Early-stage startup (lean, MVP, rapid iteration)
- [x] `docs/guides/guide-nonprofit.md` — NGO / Non-profit (grant management, volunteer coordination, impact reporting)
- [x] `docs/guides/guide-legal-firm.md` — Legal firm (case management, document review, compliance tracking)
- [x] `docs/guides/guide-healthcare.md` — Healthcare organization (HIPAA, patient flow, clinical protocols)

### Gaps identified during guide writing (proposed for future eras)

| Source | Gap | Proposed command |
|---|---|---|
| Hardware Lab | BOM management | `/hw-bom {add\|list\|cost\|export}` |
| Hardware Lab | Hardware revision tracking | `/hw-revision {create\|compare\|history}` |
| Hardware Lab | Compliance evidence matrix | `/compliance-matrix {standard\|status\|export}` |
| Research Lab | Experiment tracking | `/experiment-log {create\|run\|result\|compare}` |
| Research Lab | Literature/bibliography management | `/biblio-add {doi\|bibtex}`, `/biblio-search` |
| Research Lab | Dataset versioning (DVC/LFS) | `/dataset-version {register\|diff\|pull}` |
| Research Lab | Grant lifecycle management | `/grant-track {submit\|status\|report}` |
| Research Lab | Ethics/IRB protocol tracking | `/ethics-protocol {create\|status\|expire}` |
| Nonprofit | Impact metrics | `/impact-metric {define\|log\|report}` |
| Nonprofit | Volunteer management | `/volunteer-manage {register\|availability\|hours}` |
| Legal Firm | Legal deadline management with alerts | `/legal-deadline {set\|list\|alert}` |
| Legal Firm | Court calendar integration | `/court-calendar {import\|sync}` |
| Legal Firm | Conflict of interest check | `/conflict-check {client\|matter}` |
| Legal Firm | Legal document templates | `/legal-template {demanda\|contestacion\|recurso}` |
| Legal Firm | Billing rate management | `/billing-rate {set\|calculate\|invoice}` |
| Healthcare | PDCA cycle as native entity | `/pdca-cycle {plan\|do\|check\|act}` |
| Healthcare | Patient safety incident tracking | `/incident-register {classify\|investigate\|action}` |
| Healthcare | Accreditation tracking (JCI/EFQM/ISO) | `/accreditation-track {standard\|evidence\|gap}` |
| Healthcare | Training compliance per professional | `/training-compliance {status\|expired\|plan}` |
| Healthcare | Health KPI dashboard | `/health-kpi {define\|measure\|trend}` |

---

## ✅ Era 24 — Memory Intelligence & Natural Language Resolution (v1.9.0–v1.9.1, Mar 2026)

Inspired by [claude-mem](https://github.com/thedotmack/claude-mem) analysis. 6 memory improvements + NL→command resolution system.

- **Concepts dimension** — 2D taxonomy (type + concepts) for memory entries. CSV tags as JSON array.
- **Progressive disclosure** — 3-layer recall: index, timeline, detail. `/memory-recall`.
- **Token economics** — Every entry tracks `tokens_est`. `/memory-stats` for budget awareness.
- **Session consolidation** — `/memory-consolidate` groups by concept, deduplicates.
- **Auto-capture hook** — `memory-auto-capture.sh` PostToolUse async with 5-min rate limit.
- **Hybrid search** — Scored multi-field with `--type`/`--since` filters, top-10.
- **Intent catalog** — 60+ NL patterns mapped to commands, bilingual ES/EN.
- **NL resolution** — `/nl-query` rewritten + `nl-command-resolution.md` rule.
- **Unified recall** — `/savia-recall` searches memory + agents + lessons.
- **32 new tests** — `test-memory-improvements.sh` (13) + `test-nl-resolution.sh` (19).

---

## ✅ Era 25 — Quality Validation Framework (v2.0.0, Mar 2026)

Inspired by [BullshitBench](https://github.com/petergpt/bullshit-benchmark) analysis. 3-judge consensus, confidence calibration, and output coherence validation. 335+ commands, 27 agents, 25 skills.

- **Multi-Judge Consensus** — Panel of 3 judges (reflection-validator, code-reviewer, business-analyst). Weighted scoring (0.4/0.3/0.3). Verdicts: APPROVED/CONDITIONAL/REJECTED. Security/GDPR veto rule. Dissent handling. `/validate-consensus` command.
- **Confidence Calibration** — JSONL logging of NL resolutions. Per-band accuracy tracking. Brier score computation. Decay mechanism (-5% for 3 pattern failures, floor 30%). Recovery (+3% per success). `confidence-calibrate.sh` script.
- **Output Coherence Validator** — `coherence-validator` agent (Sonnet 4.6). 3 checks: objective coverage, internal consistency, completeness. Severity: ok/warning/critical. `/check-coherence` command.
- **98 new tests** — `test-consensus.sh` (33) + `test-confidence-calibration.sh` (30) + `test-coherence-validator.sh` (35).

---

## ✅ Era 26 — Equality Shield (v2.1.0, Mar 2026)

Inspired by LLYC "Espejismo de Igualdad" (2026) audit of bias in AI systems for team management. 6 critical biases identified and mitigated with counterfactual testing. 360+ commands, 27 agents, 25 skills.

- **Equality Shield Rule** — `equality-shield.md`: Framework blocking 6 biases (vocational assignment, tonal disparity, emotional labeling, experience bias, leadership exceptionalism, communication polarization). Counterfactual test obligatory before assignments/evaluations.
- **Bias Check Command** — `/bias:check` for contrafactual audits on sprints: rewrite gender-neutral assignments, verify consistency, flag sesgos.
- **Equality Policy Documentation** — `politica-igualdad.md`: Policy framework with academic references (Dwivedi et al., EMNLP 2025, RANLP 2025, trail-of-bits).
- **Rule #23 in CLAUDE.md** — Counterfactual test mandatory in assignments and communications.
- **Complete Test Suite** — `test-equality-shield.sh`: validation of framework, counterfactual logic, policy compliance.

---

## ✅ Era 27 — Best Practices Audit & Documentation (v2.2.0, Mar 2026)

External audit of [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) repo confirms pm-workspace covers 12/13 recommended features. One new addition: project-level CLAUDE.md guide.

- **CLAUDE-GUIDE.md** — Template and best practices for `projects/{name}/CLAUDE.md` files (~50 line minimal, ~120 line complete)
- **estudio-equality-shield.md** — Full implementation study with academic references for the Equality Shield
- **Coverage audit** — Confirmed existing coverage: context-map, agent-self-memory, intelligent-hooks, source-tracking, semantic-hub-index, confidence-protocol, consensus-protocol, context-aging, command-ux-feedback, skillssh-publishing, output-first, file-size-limit

---

## ✅ Era 28 — Scoring Intelligence (v2.3.0, Mar 2026)

Inspired by [kimun](https://github.com/lnds/kimun) analysis. Piecewise linear scoring curves, score diffing between git refs, and Rule of Three severity classification. 360+ commands, 27 agents, 25 skills.

- **Scoring Curves** — `scoring-curves.md`: 6 dimension curves (PR size, context usage, file size, velocity deviation, test coverage, Brier score) with calibrated breakpoints and linear interpolation. Replaces binary pass/fail scoring. Based on SonarSource and Microsoft Code Metrics thresholds.
- **Score Diff** — `/score:diff` command comparing workspace health between git refs. Delta tracking with regression/improvement classification. Outputs to `output/scores/`. Haiku subagent for efficient data collection.
- **Severity Classification** — `severity-classification.md`: Rule of Three pattern (3+ → CRITICAL, 2 → WARNING, 1 → INFO). Temporal escalation: same WARNING for 3 consecutive sprints auto-escalates to CRITICAL. Thresholds for PR quality, sprint health, context health, and code quality.
- **39 new tests** — `test-scoring-intelligence.sh` covering all 3 features + integration + cross-references.

---

## ✅ Era 29 — One-Line Installer (v2.4.0, Mar 2026)

Single-command installation for all platforms. Eliminates 5+ manual steps — paste one line, get Savia running.

- **install.sh** — macOS + Linux installer (`curl -fsSL ... | bash`). OS detection (macOS/Ubuntu/Fedora/Arch/Alpine/WSL), prerequisite checks, Claude Code auto-install, pm-workspace clone, npm deps, smoke test. Idempotent, `SAVIA_HOME` env var, `--skip-tests`.
- **install.ps1** — Windows PowerShell installer (`irm ... | iex`). Same flow for PowerShell 5.1+. Winget/Chocolatey hints. WSL detection.
- **test-install.sh** — Structural validation for both installers.

---

## ✅ Era 30 — SaviaHub: Shared Knowledge Repository (v2.5.0, Mar 2026)

Foundation for shared team knowledge. Git repository (local or remote) centralizing company identity, clients, users, and projects. Offline-first with flight mode.

- **SaviaHub** (v2.5.0) — `/savia-hub init`, `/savia-hub status`, `/savia-hub push`, `/savia-hub pull`, `/savia-hub flight-mode`. Sync skill, 2 domain rules, init script. 44 tests.

---

## ✅ Era 31 — Client Profiles (v2.6.0, Mar 2026)

First-class client entities in SaviaHub. Identity, contacts, business rules, and projects per client.

- **Client Profiles** (v2.6.0) — `/client-create`, `/client-show`, `/client-edit`, `/client-list`. Profile with frontmatter (sector, SLA, status), contacts table, business rules, project subdirectories. Slug generation, index auto-maintenance. 1 skill, 1 rule. 41 tests.

---

## ✅ Era 32 — BacklogGit: Backlog Version Control (v2.7.0, Mar 2026)

Periodic markdown snapshots of backlogs from any PM tool. Diff, rollback (info-only), and deviation reporting.

- **BacklogGit** (v2.7.0) — `/backlog-git snapshot`, `diff`, `rollback`, `deviation-report`. 5 sources (Azure DevOps, Jira, GitLab, Savia Flow, manual). Scope creep detection, re-estimation tracking. Append-only immutable snapshots. 1 skill, 1 rule. 41 tests.

---

## ✅ Era 33 — Context Analysis Assistant (v2.8.0, Mar 2026)

Proactive onboarding interview for new clients and projects. 8-phase structured questionnaire with sector-adaptive compliance.

- **Context Assistant** (v2.8.0) — `/context-interview start`, `resume`, `summary`, `gaps`. 8 phases: Domain, Stakeholders, Stack, Constraints, Business Rules, Compliance (sector-adaptive), Timeline, Summary. Gap detection. One-question-at-a-time. 1 skill, 1 rule. 49 tests.

---

## ✅ Era 34 — Wellbeing Guardian: Proactive Individual Wellbeing (v2.9.0, Mar 2026)

Proactive nudge system for individual work-life balance. Based on HBR research "AI Doesn't Reduce Work—It Intensifies It" (Feb 2026, Berkeley Haas). Break science: Pomodoro, 52-17, 5-50 method, 20-20-20 eye rule, INSST Spain guidelines.

- **Wellbeing Guardian** (v2.9.0) — `/wellbeing-guardian status`, `configure`, `breaks`, `report`, `pause`. Work schedule in user profile (start/end hours, lunch, conciliation). 5 break strategies. Non-blocking nudges (after-hours alerts, break reminders, weekend disconnection). Integration with burnout-radar (break_compliance_score) and sustainable-pace (wellbeing_factor). Session-init context (~25 tokens). 1 skill, 1 rule. 50 tests.

---

### Backlog — Strategic Evaluation

- **Claude Connectors vs MCP** — Evaluar si Connectors simplifican la arquitectura de integraciones
- **More industry verticals** — Insurance (Guidewire, Solvency II), Retail/eCommerce, Telco (OSS/BSS, eTOM/SID)
- **Multimodal quality gates** — Visual regression via VLM screenshot analysis, diagram-to-spec, wireframe-driven decompose
- **Observability extensions** — New Relic, Splunk, Elastic APM. LLM observability (token usage, prompt latency, model drift)
- **Developer experience** — VS Code / Cursor extension, CLI mode, mobile companion (read-only sprint status)
- **Claude in Chrome integration** — Extracción de datos de portales web sin API para Savia
- **Voice integration** — `/voice-pm` when Claude Code `/voice` reaches GA. Voice-to-command for sprint ceremonies (dictated standups, retros, reviews). Builds on existing `voice-inbox` skill.
- **Instincts system** — Self-learning patterns with confidence scoring (inspired by everything-claude-code)
- **Adversarial security pipeline** — Attacker/Defender/Auditor agents (inspired by everything-claude-code + trail-of-bits)
- **Skill evaluation engine** — Automatic skill activation based on prompt analysis (inspired by claude-code-showcase)

---

## How to influence the roadmap

1. Check if your idea already has an open issue — if so, add a 👍 reaction.
2. If not, open a new issue using the **Feature request** template.
3. The most-voted open issues are pulled into the next milestone during planning.
4. Want to implement something? Comment on the issue first — maintainers will confirm the approach fits before you invest time in a PR.
