# Changelog

All notable changes to PM-Workspace.
Format: [Keep a Changelog](https://keepachangelog.com). Versioning: [SemVer](https://semver.org).

---

## [2.20.0] — 2026-03-06

### Added — More Industry Verticals: Insurance, Retail, Telco (Era 48)

12 domain-specific commands for 3 additional industries.

- **Insurance (4 commands):** `/insurance-policy` (POL-NNN, lifecycle: create/renew/cancel, endorsement tracking), `/insurance-claim` (CLM-NNN, investigation→resolution, loss ratio analytics), `/solvency-report` (Solvency II: SCR/MCR/own funds, RAG indicator), `/underwriting-rule` (criteria definition, accept/refer/decline evaluation, audit trail).
- **Retail/eCommerce (4 commands):** `/product-catalog` (SKU-NNNN, pricing, stock, CSV/JSON export), `/order-track` (ORD-NNNN, status lifecycle, returns, revenue analytics), `/inventory-manage` (multi-warehouse, reorder points, dead stock alerts), `/promotion-engine` (PROMO-NNN, discount/BOGO/bundle/coupon, ROI analysis).
- **Telco (4 commands):** `/service-catalog-telco` (SVC-NNN, voz/datos/fibra/tv, SLA, bundling), `/network-incident` (NI-NNNN, eTOM classification, SLA compliance), `/subscriber-lifecycle` (SUB-NNNN, churn-risk scoring, ARPU/LTV), `/capacity-forecast-telco` (utilization, trend-based forecasting, expansion planning).

### Changed

- **ROADMAP.md** — Added Era 48 entry. Removed "More industry verticals" from backlog (implemented). Updated stats: 396+ commands.

---

## [2.19.0] — 2026-03-06

### Added — Adversarial Security Pipeline (Era 47)

Red Team / Blue Team / Auditor pattern for systematic security testing.

- **3 security agents**: `security-attacker` (Red Team: OWASP Top 10, CWE Top 25, dependency audit, VULN-NNN structured findings), `security-defender` (Blue Team: patches, hardening, NIST/CIS, FIX-NNN structured corrections), `security-auditor` (independent evaluation, security score 0-100, gap analysis, executive summary).
- **`/security-pipeline`** command — 3-phase sequential orchestration: Attack → Defend → Audit. Scopes: full, api, deps, config, secrets. Outputs per-project: vulns, fixes, and audit report.
- **`/threat-model`** command — STRIDE/PASTA threat modeling with asset inventory, threat analysis (probability × impact), control mapping, gap identification, prioritized recommendations.
- **`adversarial-security.md`** rule — Severity classification (critical/high/medium/low/info), scoring formula, agent independence, compliance integration (critical/high block main merge).
- **`adversarial-security/SKILL.md`** skill — CVSS scoring, STRIDE mapping table, OWASP Top 10 checklist, dependency audit commands (npm/pip/dotnet).

### Changed

- **ROADMAP.md** — Added Era 47 entry. Moved adversarial security from backlog to implemented. Updated stats: 384+ commands, 30 agents, 40 skills.

---

## [2.18.0] — 2026-03-06

### Added — Skill Evaluation Engine & Instincts System (Era 46)

Self-learning intelligence layer for automatic skill recommendation and adaptive behavior patterns.

- **`/skill-eval`** command — Analyzes prompts against available skills with composite scoring (keywords 40% + project context 30% + history 30%). Subcommands: analyze, recommend, activate, history, tune. Auto-detects 7 project types (software, research, hardware, legal, healthcare, nonprofit, education).
- **`/instinct-manage`** command — Manages Savia's learned behavior patterns with confidence scoring. Subcommands: list, add, disable, stats, decay, export. Confidence: initial 50%, +3% success, -5% failure, floor 20%, ceiling 95%. Decay: -5% per 30 days without use.
- **`skill-auto-activation.md`** rule — Suggests skills above 70% relevance threshold. Max 2 suggestions per interaction. Respects focus-mode. Learns from rejections (3 consecutive → stops suggesting).
- **`instincts-protocol.md`** rule — Lifecycle: detect ≥3 repetitions → propose → create → reinforce/penalize → decay → review. 5 categories: workflow, preference, shortcut, context, timing.
- **`skill-evaluation/SKILL.md`** skill — Prompt tokenization, 7 project-type detection, project→skills mapping, instinct integration (+20 boost for high-confidence instincts).
- **Registries**: `eval-registry.json` (skill activations), `instincts/registry.json` (instinct entries).

### Changed

- **ROADMAP.md** — Added Era 46 entry. Moved instincts + skill evaluation from backlog to implemented. Updated stats: 382+ commands, 39 skills.

---

## [2.17.0] — 2026-03-06

### Added — Vertical-Specific Commands: 5 Industry Domains (Era 45)

20 domain-specific commands implementing all gap proposals from Era 23 guide writing. Every command follows pm-workspace conventions (≤150 lines, YAML frontmatter, project-scoped storage).

- **Research Lab (5 commands):** `/experiment-log` (hypothesis→run→result→compare with EXP-NNN IDs), `/biblio-search` (DOI/BibTeX import, APA/IEEE/Vancouver citation export), `/dataset-version` (SHA256 integrity, DVC/Git LFS support), `/grant-track` (lifecycle: draft→submitted→review→approved/rejected, deadline alerts), `/ethics-protocol` (IRB tracking with experiment cross-references, renewal lineage).
- **Hardware Lab (3 commands):** `/hw-bom` (component registry, cost breakdown by category, CSV import/export), `/hw-revision` (REV-A/B/C lifecycle, BOM snapshots, tags: prototype/pilot/production), `/compliance-matrix` (CE/FCC/UL/RoHS/ISO, evidence linking, gap analysis reports).
- **Legal Firm (5 commands):** `/legal-deadline` (procesal/contractual/regulatorio, auto-alerts <48h/<7d/<14d), `/court-calendar` (ICS import/export, scheduling conflict detection), `/conflict-check` (client/matter screening, privacy-preserving reports), `/legal-template` (demanda/contestación/recurso/contrato/poder, variable substitution), `/billing-rate` (hourly/fixed/contingency/mixed, invoice generation).
- **Healthcare (5 commands):** `/pdca-cycle` (plan→do→check→act quality improvement cycles), `/incident-register` (severity classification, 5-why root cause analysis, GDPR-compliant), `/accreditation-track` (JCI/EFQM/ISO 9001/15189, evidence→requirement linking), `/training-compliance` (mandatory training, expiry alerts <30d), `/health-kpi` (define/measure/trend/dashboard, RAG status alerts).
- **Nonprofit (2 commands):** `/impact-metric` (SDG-aligned, output/outcome/impact tiers, donor reports), `/volunteer-manage` (register/availability/hours, retention tracking, GDPR/LOPD).

### Changed

- **ROADMAP.md** — Era 23 gap table marked as ✅ implemented. Added Era 45 entry. Updated stats: 380+ commands.

---

## [2.16.1] — 2026-03-06

### Changed — Repository Cleanup & Link Fixes

- **Removed** 5 obsolete files: `docs/roadmap-v1.7.0.md` (subsumed by ROADMAP.md Era 22), `docs/guia-adopcion-pm-workspace.docx` (replaced by ADOPTION_GUIDE.md), `docs/guia-incorporacion-lenguajes.docx` (replaced by .md equivalent), `docs/context-optimization-completed.md` and `docs/context-optimization-roadmap.md` (work already integrated).
- **Fixed** 8 broken links in English quick-starts (`quick-starts_en/`) — referenced Spanish filenames (`02-estructura`, `04-uso-sprint-informes`, `06-configuracion-avanzada`, `10-kpis-reglas`) instead of English (`02-structure`, `04-usage-sprint-reports`, `06-advanced-config`, `10-kpis-rules`).
- **Fixed** 2 broken links in enterprise consultancy guides pointing to non-existent `quick-start.md`.
- **Added** `docs/guides_en/guide-accessibility.md` — English translation of the accessibility step-by-step guide (was missing from bilingual pair).
- **Updated** references in `ROADMAP.md` and `CHANGELOG.md` to reflect removed files.

---

## [2.16.0] — 2026-03-06

### Added — Automated Rule Compliance Verification (Era 44)

Pre-commit gate that blocks commits violating domain rules, independent of LLM context.

- **compliance-gate.sh**: PreToolUse hook that runs compliance checks before every `git commit`. Blocks (exit 2) on violations instead of warning. Registered in `.claude/settings.json`.
- **runner.sh**: Orchestrator in `.claude/compliance/` running 4 check scripts on staged files. Supports `--all` mode for full repo scan.
- **check-changelog-links.sh**: Verifies every `## [X.Y.Z]` heading has a matching `[X.Y.Z]: URL` comparison link at the end of CHANGELOG.md.
- **check-file-size.sh**: Enforces ≤150 lines for commands, rules, and skills. Excludes languages/, references/, CHANGELOG.
- **check-command-frontmatter.sh**: Validates YAML frontmatter on newly staged commands.
- **check-readme-sync.sh**: Verifies README.md/README.en.md ≤150 lines and bilingual sync warning.
- **compliance-check.md**: `/compliance-check` command for manual verification.
- **RULES-COVERED.md**: Coverage manifest — 4 rules automated, extensible framework for adding more.

Fix: added missing `[2.15.0]` comparison link in CHANGELOG.md.

Tests: `bash .claude/compliance/runner.sh --all` — 4/4 checks passed. CI: 14/14 green.

---

## [2.15.0] — 2026-03-06

### Added — Universal Accessibility: Guided Work & Inclusive Design (Era 43)

Comprehensive accessibility system so people with disabilities can work in tech companies using pm-workspace. Central piece: Savia as digital job coach.

- **guided-work.md**: `/guided-work --task`, `--continue`, `--status`, `--pause`. Savia decomposes any task into micro-steps (3-5 min), presents ONE at a time with a question, waits, adapts. Three guidance levels: alto (closed questions, 3 lines max), medio (2-3 steps, open questions), bajo (full checklist). Block detection: reformulates on "no sé", checks in on silence, redirects on topic change. Based on N-CAPS (Nonlinear Context-Aware Prompting System) and ADHD-aware productivity framework (arxiv 2507.06864).
- **focus-mode.md**: `/focus-mode on`, `off`, `status`. Single-task mode — loads ONE PBI, hides sprint board and backlog. Complements guided-work (focus = clean environment, guided = active guidance).
- **accessibility-setup.md**: `/accessibility-setup`. 5-minute conversational wizard in 4 phases (Vision → Motor → Cognitive → Wellbeing). Creates/updates `accessibility.md` profile fragment.
- **accessibility-mode.md**: `/accessibility-mode on`, `off`, `status`, `configure`. Quick toggle for all adaptations with current config summary.
- **accessibility-output.md**: Domain rule adapting ALL Savia outputs based on profile: screen_reader → text descriptions, high_contrast → no color dependency, cognitive_load:low → 5 lines max, motor → command aliases. Priority chain: screen_reader > cognitive_load > high_contrast > rest.
- **guided-work-protocol.md**: Interaction protocol rule — task decomposition, question patterns per level, block detection table, calibrated celebrations ("Hecho. Paso X/N." — never condescending), context recovery, N-CAPS non-linear adaptation. Core principle: "The goal is not speed. It's that the person CAN complete it, at their pace, with dignity and autonomy."
- **inclusive-review.md**: Strengths-first code reviews when review_sensitivity=true. Vocabulary mapping: "Bug"→"Caso no cubierto", "Error"→"Oportunidad de mejora". Structure: strengths → opportunities → constructive close.
- **accessibility.md** (profile fragment template): 7th opt-in profile fragment. Fields: screen_reader, high_contrast, reduced_motion, cognitive_load (low/medium/high), focus_mode, guided_work, guided_work_level (alto/medio/bajo), motor_accommodation, voice_control, review_sensitivity, dyslexia_friendly, break_strategy, break_interval_min.
- **guide-accessibility.md**: Step-by-step guide per disability profile — visual, motor/RSI, ADHD, autism, dyslexia, hearing. Each with recommended config, workflow example, and tips.
- **accessibility-es.md / accessibility-en.md**: Bilingual quick-reference docs with feature list, common configurations table, and FAQ.
- **ACKNOWLEDGMENTS.md**: Credits to all inspiring projects (claude-code-templates, kimun, Engram, BullshitBench, claude-mem), studies (LLYC, Fundación ONCE, N-CAPS, DX Core 4, NIST/ISO/EU AI Act), and people (Daniel Avila, Eduardo Díaz, Miguel Luengo-Oroz).
- READMEs updated to link ACKNOWLEDGMENTS.md instead of inline credits.

Research sources: Fundación ONCE "Por Talento Digital" (30K+ trained), N-CAPS, arxiv 2411.13950 (ADHD/Autism in Software Development), arxiv 2507.06864 (ADHD-Aware Productivity Framework), DX Core 4.

Tests: `test-accessibility.sh` — 56 structural tests. CI: 14/14 green.

---

## [2.14.0] — 2026-03-06

### Added — Enterprise Readiness: Eras 36-42 (Score 5.6 → 8.1)

Seven Eras to make pm-workspace viable for large consultancies (500-5000 employees, 50+ projects):

- **v2.11.0 — Multi-Team Coordination (Era 36)**: `/team-orchestrator` with create, assign, deps, sync, status. Team Topologies (Skelton & Pais), RACI, cross-team dependency detection, circular alerts. Rule: `team-structure.md`. Skill: `team-coordination/`.
- **v2.12.0 — RBAC File-Based (Era 37)**: `/rbac-manager` with grant, revoke, audit, check. 4-tier roles (Admin/PM/Contributor/Viewer), pre-command enforcement, append-only audit trail. Rule: `rbac-model.md`. Skill: `rbac-management/`.
- **v2.12.1 — Cost & Billing (Era 38)**: `/cost-center` with log, report, budget, forecast, invoice. Timesheet JSONL, EVM (EAC/CPI/SPI), rate tables, client invoicing. Rules: `billing-model.md`, `cost-tracking.md`. Skill: `cost-management/`.
- **v2.12.2 — Onboarding at Scale (Era 39)**: `/onboard-enterprise` with import, checklist, progress, knowledge-transfer. CSV batch import, 4-phase onboarding, per-role checklists. Rule: `onboarding-enterprise.md`. Skill: `enterprise-onboarding/`.
- **v2.13.0 — Governance & Audit (Era 40)**: `/governance-enterprise` with audit-trail, compliance-check, decision-registry, certify. JSONL audit log, governance matrix (GDPR/AEPD/ISO27001/EU AI Act). Rules: `audit-trail-schema.md`, `governance-enterprise.md`. Skill: `governance-enterprise/`.
- **v2.13.1 — Enterprise Reporting (Era 41)**: `/enterprise-dashboard` with portfolio, team-health, risk-matrix, forecast. SPACE framework, Monte Carlo forecasting, cross-project risk aggregation. Rule: `enterprise-metrics.md`. Skill: `enterprise-analytics/`.
- **v2.14.0 — Scale & Integration (Era 42)**: `/scale-optimizer` with analyze, benchmark, recommend, knowledge-search. 3-tier scaling model, vendor sync, full-text search, CI/CD standardization. Rule: `scaling-patterns.md`. Skill: `scaling-operations/`.

Tests: 295 structural tests across 7 test scripts.

---

## [2.10.0] — 2026-03-06

### Added — Cognitive Sovereignty: AI Vendor Lock-in Audit (Era 35)

- **sovereignty-audit.md**: `/sovereignty-audit scan`, `report`, `exit-plan`, `recommend`. Diagnoses and quantifies organizational independence from AI providers. 5-dimension Sovereignty Score (0-100): data portability, LLM independence, organizational graph protection, consumption governance, exit optionality. Based on "La Trampa Cognitiva" (De Nicolás, 2026) — cognitive lock-in as the new enterprise dependency.
- **cognitive-sovereignty.md**: Domain rule with lock-in evolution framework (technical→contractual→process→cognitive), 5 dimensions with weighted scoring, vendor risk matrix, alarm signals, integration with governance-audit.
- **sovereignty-auditor/SKILL.md**: Scan orchestration (workspace analysis, score calculation), executive report generation, concrete exit plan with migration timeline, actionable recommendations mapped to pm-workspace commands.
- Tests: `test-sovereignty-audit.sh` — 50 structural tests across command, rule, skill, and cross-references.

---

## [2.9.0] — 2026-03-05

### Added — Wellbeing Guardian: Proactive Individual Wellbeing (Era 34)

- **wellbeing-guardian.md**: `/wellbeing-guardian status`, `configure`, `breaks`, `report`, `pause`. Proactive nudge system for individual work-life balance — break reminders, after-hours alerts, weekend disconnection suggestions. 5 break strategies (Pomodoro, 52-17, 5-50, custom, 20-20-20 eye rule). Non-blocking philosophy: suggestions, never interruptions.
- **wellbeing-config.md**: Domain rule with break science reference (HBR Feb 2026 research on AI-intensified work), strategy definitions, 5 nudge template categories, work schedule schema for user profiles, integration points with burnout-radar and sustainable-pace.
- **wellbeing-guardian/SKILL.md**: Orchestration — session start (load schedule, detect after-hours), periodic check (time-based nudges), configure (interactive setup), status, pause, breaks history, weekly report with break_compliance_score.
- **session-init-priority.md**: Added Wellbeing context entry (Media priority, ~25 tokens) for ambient work schedule awareness.
- Tests: `test-wellbeing-guardian.sh` — 50 structural tests across command, rule, skill, and cross-references.

---

## [2.8.2] — 2026-03-05

Emergency plan hardened for offline reliability.

### Changed

- **emergency-plan.sh/.ps1**: Added connectivity check (Step 0) — fails fast with clear message if no internet. Added idempotency to cached binary path — checks `ollama list` before pulling. Added verification step (Step 5) — confirms what is cached and ready for offline. Updated step numbering from [1/4]...[4/4] to [1/5]...[5/5]. Extracted `_extract_ollama()` and `_pull_small()` helpers to reduce duplication.

---

## [2.8.1] — 2026-03-05

Emergency mode model alias overrides — subagents now resolve in offline mode.

### Changed

- **emergency-setup.sh/.ps1**: Map `opus`/`sonnet`/`haiku` aliases to local Ollama models via official Claude Code variables (`ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`). Auto-tiered by RAM: 8GB→3b, 16GB→7b/7b/3b, 32GB+→14b/7b/3b.
- **emergency-plan.sh/.ps1**: Pre-download `qwen2.5:3b` alongside main model for haiku alias differentiation.
- **EMERGENCY.md / EMERGENCY.en.md**: New "Model Mapping" section. Updated unset commands. Claude Code Router documented as community option.
- **emergency-mode.md**: Document model alias variables in activate subcommand.

> Community contribution: Cristián Rojas identified the subagent resolution gap.

---

## [2.8.0] — 2026-03-05

### Added — Context Analysis Assistant (Era 33)

- **context-interview.md**: `/context-interview start`, `resume`, `summary`, `gaps`. 8-phase structured interview for client/project onboarding: Domain, Stakeholders, Stack, Constraints, Business Rules, Compliance (sector-adaptive), Timeline, Summary. Proactive gap detection.
- **context-interview-config.md**: Domain rule defining 8 interview phases, session format, sector-adaptive compliance questions (fintech, healthcare, legal, education), one-question-at-a-time rule, gap detection schema, persistence targets per phase.
- **context-interview-conductor/SKILL.md**: Interview orchestration — start, conduct phases, resume, summary, gaps. Adaptive questions per sector. Immediate persistence. Phase 8 generates consolidated summary with gap analysis.
- Tests: `test-context-interview.sh` — 49 structural tests across command, rule, skill, and cross-references.

---

## [2.7.0] — 2026-03-05

### Added — BacklogGit: Backlog Version Control (Era 32)

- **backlog-git.md**: `/backlog-git snapshot`, `diff`, `rollback`, `deviation-report`. Captures periodic markdown snapshots of backlogs from any PM tool (Azure DevOps, Jira, GitLab, Savia Flow, manual). Diff algorithm detects added/removed/modified items with scope creep and re-estimation metrics.
- **backlog-git-config.md**: Domain rule defining snapshot format (YAML frontmatter + items table), 5 source types with auto-detection, diff algorithm, deviation metrics, immutability rules, frequency guidance.
- **backlog-git-tracker/SKILL.md**: Snapshot capture (9 steps), diff with flexible references, rollback (info-only, NEVER auto-execute), deviation report with temporal metrics and ASCII charts.
- Tests: `test-backlog-git.sh` — 41 structural tests across command, rule, skill, and cross-references.

---

## [2.6.0] — 2026-03-05

### Added — Client Profiles (Era 31)

- **client-profile.md**: `/client-create {name}`, `/client-show {slug}`, `/client-edit {slug} [section]`, `/client-list`. First-class client entities in SaviaHub with identity, contacts, business rules, and projects.
- **client-profile-config.md**: Domain rule defining client directory structure (`profile.md`, `contacts.md`, `rules.md`, `projects/`), frontmatter schema, slug generation, status/SLA validation, security rules.
- **client-profile-manager/SKILL.md**: CRUD orchestration skill — create (10 steps), show (7 steps), edit, list with index regeneration, add-project. Error handling with fuzzy match.
- Tests: `test-client-profiles.sh` — 41 structural tests across command, rule, skill, cross-references, and SaviaHub integration.

---

## [2.5.0] — 2026-03-05

### Added — SaviaHub: Shared Knowledge Repository (Era 30)

- **savia-hub.md**: `/savia-hub` command with 5 subcommands — `init` (local or remote clone), `status`, `push`, `pull`, `flight-mode on|off`. Centralizes company identity, org chart, clients, users, and projects in a single Git repository.
- **savia-hub-config.md**: Domain rule defining repository structure (`company/`, `clients/`, `users/`), path configuration (`SAVIA_HUB_PATH`, `SAVIA_HUB_REMOTE`), local config format (`.savia-hub-config.md`), naming conventions, and security rules.
- **savia-hub-offline.md**: Domain rule for flight mode — activation/deactivation, sync queue (`.sync-queue.jsonl`), divergence detection, auto-sync config. Safety: NUNCA auto-resolver conflictos.
- **savia-hub-sync/SKILL.md**: Sync orchestration skill — init flow (delegates to `savia-hub-init.sh`), push (10-step with PM confirmation), pull (7-step with conflict handling), flight mode management.
- **savia-hub-init.sh**: Bash init script with `--remote URL`, `--path PATH`, `--help` flags. Creates directory structure, company templates, clients index, `.gitignore`, local config, initial commit. Idempotent.
- Tests: `test-savia-hub.sh` — 44 structural tests across command, rules, skill, init script, and cross-references.

---

## [2.4.0] — 2026-03-04

### Added — One-Line Installer (Era 29)

- **install.sh**: macOS + Linux one-line installer (`curl -fsSL ... | bash`). OS detection (macOS/Ubuntu/Fedora/Arch/Alpine/WSL), prerequisite checks (git, node ≥18, python3, jq), Claude Code auto-install, pm-workspace clone, npm deps, smoke test. Idempotent, configurable via `SAVIA_HOME` env var, `--skip-tests` and `--help` flags.
- **install.ps1**: Windows PowerShell one-line installer (`irm ... | iex`). Same flow adapted for PowerShell 5.1+. Winget/Chocolatey install hints. WSL detection with cross-platform suggestion.
- Tests: `test-install.sh` — structural validation for both installers.

---

## [2.3.0] — 2026-03-04

### Added — Scoring Intelligence (Era 28)

- **scoring-curves.md**: piecewise linear normalization for 6 dimensions (PR size, context usage, file size, velocity deviation, test coverage, Brier score). Smooth degradation with calibrated breakpoints instead of binary pass/fail. Inspired by kimun (lnds/kimun) and SonarSource/Microsoft Code Metrics.
- **score-diff.md**: `/score:diff` command comparing workspace metrics between git refs. Delta tracking with regression/improvement classification. Haiku subagent for data collection.
- **severity-classification.md**: Rule of Three severity system — 3+ occurrences → CRITICAL, 2 → WARNING, 1 → INFO. Temporal escalation (same WARNING × 3 sprints → auto-CRITICAL). Thresholds for PR quality, sprint health, context health, code quality.
- Tests: `test-scoring-intelligence.sh` — 39 tests across scoring curves, score diff, severity classification, integration and cross-references.

---

## [2.2.0] — 2026-03-04

### Added — Best Practices Audit & Documentation (Era 27)

- **CLAUDE-GUIDE.md**: guide and template for project-level CLAUDE.md files (minimal ~50 lines, complete ~120)
- **estudio-equality-shield.md**: full Equality Shield implementation study with academic references
- External audit of [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) repo: confirmed existing coverage of 12/13 recommended features (context-map, agent-self-memory, intelligent-hooks, source-tracking, semantic-hub-index, confidence-protocol, consensus-protocol, context-aging, command-ux-feedback, skillssh-publishing, output-first, file-size-limit)

---

## [2.1.0] — 2026-03-04

### Added — Equality Shield (Era 26)

- **equality-shield.md**: anti-bias domain rule based on LLYC "Espejismo de Igualdad" (2026) study blocking 6 bias types
- **bias-check.md**: `/bias:check` command for counterfactual bias auditing in sprints
- **politica-igualdad.md**: equality policy documentation with academic references (Dwivedi 2023, EMNLP 2025, RANLP 2025)
- Rule #23 in CLAUDE.md: mandatory counterfactual test in assignments and communications
- Tests: `test-equality-shield.sh` — 41 tests covering full framework validation

---

## [2.0.0] — 2026-03-04

Quality Validation Framework — Era 25. Multi-judge consensus, confidence calibration, and output coherence validation inspired by BullshitBench.

### Added

- **Multi-Judge Consensus** — 3-judge panel (reflection-validator, code-reviewer, business-analyst) with weighted scoring (0.4/0.3/0.3), verdicts (APPROVED/CONDITIONAL/REJECTED), veto rule for security/GDPR, dissent handling. Skill + rule + command `/validate-consensus`.
- **Confidence Calibration** — Tracks NL-resolution success/failure in JSONL log, computes per-band accuracy and Brier score, decay mechanism (-5% for 3 pattern failures, -10% for 5 command failures, floor 30%), recovery (+3% per success). Script `confidence-calibrate.sh` + protocol rule.
- **Output Coherence Validator** — `coherence-validator` agent (Sonnet 4.6) checks output↔objective alignment: coverage, internal consistency, completeness. Severity levels (ok/warning/critical). Skill + command `/check-coherence`.
- **98 new tests**: `test-consensus.sh` (33) + `test-confidence-calibration.sh` (30) + `test-coherence-validator.sh` (35).

### Changed

- **NL-command resolution** — Added recalibration section with confidence logging and decay mechanism.
- **Agents catalog** — Updated to 27 agents (added `coherence-validator`). Added consensus flow.
- **CLAUDE.md / READMEs** — Updated agent count (26→27), skill count (23→25).

---

## [1.9.1] — 2026-03-04

Reflection Validator agent and skill — System 2 meta-cognitive validation protocol.

### Added

- **`reflection-validator` agent** (Opus 4.6): 5-step System 2 protocol — extracts real objective, audits assumptions, simulates causal chain, detects gaps, corrects transparently.
- **`reflection-validation` skill** (SKILL.md, 148 lines): embeddable pattern for internal reflection, cognitive bias taxonomy, structured output format.
- **Agent memory** (`agent-memory/reflection-validator/MEMORY.md`): persistent context for reflection sessions.
- **65 new tests** (`scripts/test-reflection-validator.sh`): covers agent structure, skill protocol, memory, integration, and cognitive bias detection.

### Changed

- **Agents catalog** — Updated to 26 agents (added `drift-auditor` and `reflection-validator`).
- **CLAUDE.md / READMEs** — Updated agent count (25→26) and skill count (22→23).

---

## [1.9.0] — 2026-03-04

Memory improvements inspired by claude-mem + Natural Language command resolution system.

### Added

- **Concepts dimension** in `memory-store.sh`: `--concepts` parameter stores CSV tags as JSON array for 2D taxonomy (type + concepts).
- **Token economics**: every memory entry tracks `tokens_est` (content length / 4) for budget awareness.
- **Hybrid search**: scored multi-field search (title 3x, concepts 2x, content 1x) with `--type` and `--since` filters, top-10 limit.
- **`/memory-recall`** — Progressive disclosure in 3 layers: index (titles only), timeline (last N), detail (full entry).
- **`/memory-stats`** — Dedicated stats command with type/concept breakdown and token estimates.
- **`/memory-consolidate`** — Session consolidation: groups entries by concept, generates session-summary, deduplicates.
- **`/savia-recall`** — Unified search across memory store, agent MEMORY.md files, and lessons.md.
- **`memory-auto-capture.sh`** — PostToolUse async hook that auto-captures patterns from Edit/Write operations with 5-min rate limit.
- **Intent catalog** (`.claude/commands/references/intent-catalog.md`): 60+ NL patterns mapped to commands across 19 categories, bilingual ES/EN.
- **NL resolution rule** (`.claude/rules/domain/nl-command-resolution.md`): automatic intent detection, confidence scoring (base + context + history), anti-improvisation guards.
- **`/nl-query` rewritten**: loads intent catalog, scores confidence, resolves params from context, learns from successful mappings. Subcommands: `--explain`, `--learn`, `--history`.
- **32 new tests**: `test-memory-improvements.sh` (13 tests) + `test-nl-resolution.sh` (19 tests).

### Changed

- **`memory-store.sh`** — Enhanced `cmd_save()` (concepts, tokens), `cmd_search()` (scored, filtered), `cmd_stats()` (concept breakdown). Fixed dedup logic.
- **README.md / README.en.md** — Added new memory and NL commands to command catalog. Version history updated.

---

## [1.8.0] — 2026-03-04

Usage guides by scenario + README restructure + documentation alignment.

### Added

- **10 usage guides** in `docs/guides/`: Azure DevOps consultancy, Jira consultancy, Savia standalone, Education (Savia School), Hardware lab, Research lab, Startup, Non-profit, Legal firm, Healthcare. Each guide includes roles, setup, day-to-day workflows, command sequences, and example conversations with Savia.
- **20 gap proposals** identified during guide writing (hardware BOM, experiment tracking, grant lifecycle, legal deadlines, PDCA cycles, and more). Added to roadmap backlog.
- **Guides section** in both README.md and README.en.md with links to all 10 guides.

### Changed

- **README restructured**: removed 3 scattered release note blocks, added clean "Version History" table.
- **README.en.md aligned**: added missing `/excel-report`, `/savia-gallery`, `/vertical-*` commands and `/aepd-compliance` + `/governance-*` to match Spanish version.
- **CLAUDE.md compacted**: 123→119 lines to pass CI gate (max: 120).
- **ROADMAP.md updated**: added Era 22 (v1.6–v1.7) and Era 23 (v1.8 guides) with gap analysis table.

### Fixed

- **README parity**: English and Spanish READMEs now have identical feature coverage and command references.

---

## [1.7.0] — 2026-03-03

Company Savia v3: branch-based isolation with Git orphan branches + quality framework.

### Added

- **`savia-branch.sh`**: new abstraction layer for cross-branch read/write/list/exists/ensure-orphan/check-permission/fetch-messages via `git show` and temporary worktrees.
- **`test-savia-branches.sh`**: 15 tests for branch abstraction layer.
- **Rule #21 — Self-Improvement Loop**: persistent `tasks/lessons.md` reviewed at session start. Rule: `.claude/rules/domain/self-improvement.md`.
- **Rule #22 — Verification Before Done**: proof-based completion. Rule: `.claude/rules/domain/verification-before-done.md`.
- **Agent Self-Memory**: 10 agents with persistent `MEMORY.md` files (code-reviewer, architect, security-guardian, test-runner, triage, and 5 more). Rule: `.claude/rules/domain/agent-self-memory.md`.
- **`/drift-check` command**: audits CLAUDE.md rules vs repo state. Agent: `drift-auditor.md`.
- **`hook-pii-gate.sh`**: pre-commit PII scanner (emails, phones, API keys, IBAN, DNI/NIE).
- **Frontend Component Rules**: `.claude/rules/domain/frontend-components.md` (naming, a11y checklist, states, design tokens).
- **Roadmap v1.7.0**: archived (content integrated into `docs/ROADMAP.md` Era 22).

### Changed

- **20 core scripts migrated**: from directory-based to orphan branch isolation (main, user/{handle}, team/{name}, exchange).
- **8 test suites rewritten**: 120 Savia tests pass (branch-based architecture).
- **Config, skills, docs updated**: `company-savia-config.md`, `SKILL.md`, `message-schema.md` reflect branch architecture.
- **CLAUDE.md**: 22 rules (was 20). New checklist entries for self-improvement and verification.

### Fixed

- **`git fetch origin --all`**: invalid command replaced with `git fetch --all` across all tests.
- **`assert_ok` pattern**: fixed `$?` capture bug in test harnesses (was always 0).
- **Dispatcher command names**: tests now use short names (read, write, exists) matching savia-branch.sh dispatcher.

---

## [1.6.0] — 2026-03-03

Company Savia v2: complete directory restructure for clarity, consistency, and indexing.

### Changed

- **Directory layout**: `team/` → `users/`, `company-inbox/` → `company/inbox/`, new `teams/` directory with per-team member references.
- **User paths simplified**: removed `public/` subdirectory and `savia-` prefixes (`savia-inbox/` → `inbox/`, `savia-state/` → `state/`, `savia-flow/` → `flow/`).
- **35+ files updated**: all scripts, tests, config rules, skills, and docs aligned with new structure.

### Added

- **`inboxes.idx`**: new index mapping handle → inbox path for fast lookup.
- **`teams.idx`**: new index mapping team → members.
- **`teams/{name}/users/{handle}.md`**: per-team member reference files with role and join date.

### Fixed

- **`.gitignore`**: pubkey exclusion rule updated (`!**/pubkey.pem` instead of `!**/public/*.pem`).
- **Test company repo**: reinitialized with new structure.

---

## [1.5.1] — 2026-03-03

Confidentiality hardening: E2E encryption testing, subject sensitivity validation, 7 bug fixes, 5 new test suites.

### Added

- **5 test scripts**: `test-savia-confidentiality.sh` (34 tests — E2E encryption, metadata, non-recipient rejection, privacy scanner, idempotency, subject sensitivity), `test-savia-flow-tasks.sh` (24 tests), `test-savia-index.sh` (12 tests), `test-savia-travel.sh` (18 tests), `test-savia-school.sh` (34 tests).
- **1 script**: `savia-messaging-privacy.sh` — Subject sensitivity validation: detects monetary amounts, dates, company names, credentials, API keys, IPs, emails, DNI/NIE, IBAN in subjects. Warns but doesn't block delivery.
- **1 rule**: `messaging-subject-safety.md` — Agent guidance for safe subject lines. "Instead of X, use Y" table. 12 pattern categories.
- **Company Savia initialization**: Structure deployed to test repo via `company-repo-templates.sh`.

### Fixed

- **savia-flow-tasks.sh**: Multiline seq from `ls|grep|echo` pipeline; `mkdir` with braces inside quotes (no shell expansion).
- **savia-travel.sh**: `local` keyword used outside functions in `case` blocks — refactored into proper functions.
- **savia-index.sh**: Missing `init` dispatcher entry; `update_entry` shift bug (captured name before shift).
- **savia-school.sh**: `SCHOOL_ROOT` used `$1` (the command) as base path — replaced with `SCHOOL_BASE` env var.
- **savia-flow.sh**: Missing `do_sprint_start`/`do_sprint_close`/`do_metrics` adapter functions.
- **savia-flow-sprint.sh**: Case dispatcher executed when sourced — added `BASH_SOURCE` guard.
- **savia-messaging.sh**: Integrated `savia-messaging-privacy.sh` and `check_subject_sensitivity()` call before send.

### Changed

- **test-integration-company.sh**: Runs 18 suites (197 tests total, all green). Accepts repo URL as parameter.

[2.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.18.0...v2.19.0
[2.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.17.0...v2.18.0
[2.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.16.1...v2.17.0
[2.16.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.16.0...v2.16.1
[2.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.10.0...v2.14.0
[2.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.2...v2.9.0
[2.8.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.1...v2.8.2
[2.8.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.8.0...v2.8.1
[2.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.9.1...v2.0.0
[1.9.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.5.0...v1.5.1

---

## [1.5.0] — 2026-03-03

Ecosystem Integration: research of 12+ Claude Code repos with actionable improvements for pm-workspace.

### Added

- **2 research docs**: `investigacion-ecosistema-claude-code-2026.md` (12 repos analyzed), `era21-masterplan.md` (7 workstreams planned).
- **12 improvement proposals**: instincts system, adversarial security, skill evaluation engine, anti-rationalization hook, quality sweeps, deny rules, pass@k metrics, verify/fix loops, audit trail, AGENTS.md format, VoiceMode, event broker.

[1.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.4.0...v1.5.0

---

## [1.4.0] — 2026-03-03

Savia School: educational vertical for classrooms. Teachers tutor and evaluate, students create projects. GDPR/LOPD compliant.

### Added

- **12 commands**: `/school-setup`, `/school-enroll`, `/school-project`, `/school-submit`, `/school-evaluate`, `/school-progress`, `/school-portfolio`, `/school-diary`, `/school-export`, `/school-forget`, `/school-analytics`, `/school-rubric`.
- **2 scripts**: `savia-school.sh` (classroom management), `savia-school-security.sh` (encryption, audit, content filtering, GDPR compliance).
- **1 rule**: `school-safety-config.md` — Security config for school vertical (encryption, consent, isolation, content filtering).

### Security

- Alias-based enrollment (no PII in repository).
- AES-256-CBC encrypted evaluations (teacher-only decryption).
- GDPR Art. 8 (parental consent), Art. 15 (data export), Art. 17 (right to erasure).
- Student folder isolation. Audit trail for all operations.

[1.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.3.0...v1.4.0

---

## [1.3.0] — 2026-03-03

Git Persistence Engine: TSV indexes for low-context lookups. ~60-80% token reduction per query.

### Added

- **3 commands**: `/index-rebuild`, `/index-status`, `/index-compact` — Manage TSV indexes.
- **2 scripts**: `savia-index.sh` (core: lookup, update, remove, verify, compact), `savia-index-rebuild.sh` (rebuild profiles, messages, projects, specs, timesheets from source files).
- **6 index types**: profiles.idx, messages.idx, projects.idx, tasks.idx, specs.idx, timesheets.idx.

[1.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.2.0...v1.3.0

---

## [1.2.0] — 2026-03-03

SDD/Tickets/Tasks Git-native: complete Savia Flow task management in Git folders. No database dependency.

### Added

- **12 commands**: `/flow-task-create`, `/flow-task-move`, `/flow-task-assign`, `/flow-sprint-create`, `/flow-sprint-close`, `/flow-sprint-board`, `/flow-timesheet`, `/flow-timesheet-report`, `/flow-burndown`, `/flow-velocity`, `/flow-spec-create`, `/flow-backlog-groom`.
- **3 scripts**: `savia-flow-tasks.sh` (task CRUD + board), `savia-flow-sprint.sh` (sprint lifecycle + metrics), `savia-flow-timesheet.sh` (time tracking + reporting).
- **1 rule**: `flow-tasks-config.md` — Configuration for Git-native flow system.

[1.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.1.0...v1.2.0

---

## [1.1.0] — 2026-03-03

Travel Mode extended: full pack/unpack/sync/verify/clean lifecycle for portable Savia on USB.

### Added

- **5 commands**: `/travel-pack`, `/travel-unpack`, `/travel-sync`, `/travel-verify`, `/travel-clean`.
- **3 scripts**: `savia-travel.sh` (core dispatcher), `savia-travel-ops.sh` (advanced sync operations), `savia-travel-init.sh` (self-contained USB bootstrap).

### Security

- AES-256-CBC encryption for keys and PATs on USB.
- SHA256 integrity checksums for all files.
- Secure cleanup of traces from borrowed machines.

[1.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v1.0.0...v1.1.0

---

## [1.0.0] — 2026-03-03

Script Hardening: 6 critical + 7 medium fixes across 9 scripts. Cross-platform (macOS + Linux + WSL).

### Fixed

- **backup.sh**: Hash comparison bug (comparing plaintext vs SHA256), race condition in rotation (subshell pipe), cp -r without -p flag.
- **contribute.sh**: Perl regex lookahead (?!) invalid in grep -E — corporate email detection was silently failing.
- **memory-store.sh**: grep without -F allows regex injection via topic_key; newlines corrupt JSONL format.
- **pre-commit-review.sh**: Cache invalidation on empty CACHE_DIR.
- **session-init.sh**: Unquoted git branch variable.
- **update.sh**: sed -i not portable on macOS — now uses portable_sed_i.
- **context-aging.sh**: date -d doesn't exist on macOS — now detects OSTYPE.
- **validate-bash-global.sh**: \s not POSIX ERE — replaced with [[:space:]].
- **block-force-push.sh**: Pattern matching bypass via compound commands — added anchoring.

[1.0.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.101.0...v1.0.0

---

## [0.101.0] — 2026-03-03

Savia Flow: Git-based project management — PBIs, sprints, Kanban board, timesheets. No Azure DevOps dependency.

### Added

- **5 commands**: `/savia-pbi`, `/savia-sprint`, `/savia-board`, `/savia-timesheet`, `/savia-team` — Git-based PM lifecycle stored as markdown in company repo.
- **5 scripts**: `savia-flow.sh` (dispatcher), `savia-flow-ops.sh` (PBI CRUD), `savia-flow-sprint.sh` (sprint lifecycle + metrics), `savia-flow-board.sh` (ASCII Kanban), `savia-flow-templates.sh` (project/team scaffolding).
- **1 test script**: `test-savia-flow.sh` — 29 tests covering PBI create/assign/move, sprint start/close, log-time, board, metrics.
- **1 reference**: `flow-schemas.md` — YAML schema specs for PBI, Sprint, Timesheet, Team.

### Changed

- **`company-repo-templates-init.sh`** — Added `projects/` and `teams/` dirs to repo init.

[0.101.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.100.0...v0.101.0

---

## [0.100.0] — 2026-03-03

Travel Mode: portable USB bootstrap with `savia-init` for deploying pm-workspace on new machines.

### Added

- **2 commands**: `/savia-travel-pack`, `/savia-travel-init` — Pack and bootstrap pm-workspace portably.
- **2 scripts**: `savia-travel.sh` (pack), `savia-travel-init.sh` (bootstrap: OS detect, deps check, Claude Code install, workspace copy, profile restore).

[0.100.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.2...v0.100.0

---

## [0.99.2] — 2026-03-03

Integration tests against real Company Savia repo structure.

### Added

- **1 test script**: `test-integration-company.sh` — Orchestrates all 3 Company Savia test suites + smoke tests against cloned repo.

[0.99.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.1...v0.99.2

---

## [0.99.1] — 2026-03-03

Cross-platform compatibility: replace GNU-only patterns with portable helpers.

### Added

- **1 script**: `savia-compat.sh` — Portable helper library: `portable_base64_encode`, `portable_base64_decode`, `portable_sed_i`, `portable_read_config`, `portable_yaml_field`, `portable_wc_l`.

### Fixed

- **7 scripts**: Replaced `base64 -w0`, `grep -oP`, bare `sed -i` with portable helpers from `savia-compat.sh`. Affected: `savia-crypto-ops.sh`, `savia-messaging.sh`, `savia-messaging-inbox.sh`, `company-repo.sh`, `company-repo-ops.sh`, `backup.sh`, `test-savia-messaging.sh`.

[0.99.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.99.0...v0.99.1

---

## [0.99.0] — 2026-03-03

Company Savia: shared company repository with async messaging and E2E encryption.

### Added

- **7 commands**: `/company-repo`, `/savia-send`, `/savia-inbox`, `/savia-reply`, `/savia-announce`, `/savia-directory`, `/savia-broadcast` — Git-based company repo lifecycle and async messaging with @handle addressing.
- **4 scripts**: `company-repo.sh` (repo lifecycle), `savia-messaging.sh` (message CRUD), `savia-crypto.sh` (RSA-4096 + AES-256-CBC encryption), `privacy-check-company.sh` (pre-push privacy filter).
- **1 script**: `company-repo-templates.sh` — Heredoc templates for repo structure (CODEOWNERS, directory.md, org-chart, holidays, conventions).
- **1 skill**: `company-messaging` — Knowledge module with message schema, encryption protocol, and privacy rules.
- **1 rule**: `company-savia-config.md` — Configuration constants for repo, encryption, privacy, inbox, and messaging.
- **3 test scripts**: `test-company-repo.sh`, `test-savia-messaging.sh`, `test-savia-crypto.sh` — Full test coverage for repo lifecycle, messaging round-trip, and encryption.
- **Session-init integration**: unread inbox count displayed at startup (filesystem-only, no network).

[0.99.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.98.0...v0.99.0

---

## [0.98.0] — 2026-03-03

PR Guardian System — Automated PR validation with 8 quality gates + contextual digest.

### Added

- **`.github/workflows/pr-guardian.yml`** — 8-gate automated PR validation: description quality, conventional commits, CLAUDE.md context guard (≤120 lines), ShellCheck differential, Gitleaks secret scanning (700+ patterns), hook safety validator, context impact analysis, PR Digest (auto-comment in Spanish with risk assessment for maintainer).
- **`.claude/commands/pr-digest.md`** — `/pr-digest` command for manual contextual PR analysis. Classifies changes by area, evaluates risk level, measures context impact, generates executive summary in Spanish.
- **`.gitleaks.toml`** — Gitleaks configuration with allowlist for mock data, test fixtures, and placeholder patterns.
- **`docs/propuestas/propuesta-pr-guardian-system.md`** — Full design document with gap analysis, 8-gate architecture, and implementation plan.
- **`docs/propuestas/roadmap-research-era20.md`** — Era 20 research based on claude-code-best-practice analysis.

### Changed

- **`.github/pull_request_template.md`** — Added "Context impact" and "Hook safety" sections, conventional commits requirement.
- **`docs/ROADMAP.md`** — Added Era 19 (Open Source Synergy) and Era 20 (Persistent Intelligence & Adaptive Workflows) with 6 milestones.

[0.98.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.97.0...v0.98.0

---

## [0.97.0] — 2026-03-03

Era 20 — MCP Toolkit & Async Hooks.

### Added

- **`/mcp-recommend`** — Curated MCP recommendations by stack and role (Context7, DeepWiki, Playwright, Excalidraw, Docker, Slack).
- **`async-hooks-config.md`** — Hook classification (2 async, 10 blocking), event coverage 9/16 (56%), `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50`.

[0.97.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.96.0...v0.97.0

---

## [0.96.0] — 2026-03-03

Era 20 — Adaptive Output & Onboarding.

### Added

- **`/onboard`** — Guided onboarding for new team members with role-specific checklists (dev/PM/QA). Auto-explore, component map, personalized Day 1/Week 1/Month 1 plan.
- **`adaptive-output.md`** — Three output modes: Coaching (junior devs), Executive (stakeholders), Technical (senior engineers). Auto-detection from profile and command context.

[0.96.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.95.0...v0.96.0

---

## [0.95.0] — 2026-03-03

Era 20 — RPI Workflow Engine.

### Added

- **`/rpi-start`** — Research → Plan → Implement workflow with GO/NO-GO gates. Creates `rpi/{feature}/` folder structure orchestrating product-discovery, pbi-decomposition, and spec-driven-development skills.
- **`/rpi-status`** — Track progress of active RPI workflows with phase detection.

[0.95.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.94.0...v0.95.0

---

## [0.94.0] — 2026-03-03

Era 20 — Smart Command Frontmatter.

### Added

- **`smart-frontmatter.md`** — Domain rule defining model selection taxonomy (haiku/sonnet/opus), allowed-tools, context_cost, validation.

### Changed

- **57 commands** updated with `model` and `context_cost` frontmatter fields: 20 haiku, 29 sonnet, 8 opus.

[0.94.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.93.0...v0.94.0

---

## [0.93.0] — 2026-03-03

Era 20 — Savia Contextual Memory.

### Added

- **`/savia-recall`** — Query Savia's accumulated contextual memory (decisions, vocabulary, communication preferences).
- **`/savia-forget`** — GDPR-compliant memory pruning implementing Art. 17 RGPD.
- **`.claude/agent-memory/savia/MEMORY.md`** — Savia-specific persistent memory template.

[0.93.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.92.0...v0.93.0

---

## [0.92.0] — 2026-03-03

Era 20 — Agent Memory Foundation.

### Added

- **`.claude/agent-memory/`** — Persistent memory directory with MEMORY.md templates for 9 agents (architect, security-guardian, commit-guardian, code-reviewer, business-analyst, sdd-spec-writer, test-runner, dotnet-developer, savia).
- **`/agent-memory`** — Command to inspect and manage agent memory fragments (list, show, clear).
- **`agent-memory-protocol.md`** — Domain rule defining three memory scopes (project, local, user), hygiene rules, and integration with existing systems.

[0.92.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.91.0...v0.92.0

---

## [0.91.0] — 2026-03-03

Era 20 — Stress Testing & Bug Fixes. 5 bug fixes + 165 new tests + orchestrator.

### Fixed

- **`block-credential-leak.sh`** — jq fallback: if jq not installed, secrets no longer pass through. Added grep-based extraction.
- **`block-credential-leak.sh`** — Added missing Azure SAS token (`sv=20`), Google API key (`AIza`), and PEM private key detection patterns.
- **`session-init.sh`** — ERR trap now exits 1 (not 0) and includes `$LINENO` for diagnostics.
- **`agent-hook-premerge.sh`** — File line count uses `awk 'END{print NR}'` instead of `wc -l` (fixes off-by-one for files without trailing newline).
- **`agent-hook-premerge.sh`** — Merge conflict markers now detected with `\s*` prefix (catches indented markers).
- **`skillssh-adapter.sh`** — `references:` removal now uses `awk` frontmatter-aware parser instead of broad `sed` that matched comments.

### Added

- **`scripts/test-stress-hooks.sh`** — 25 stress tests for all 14 hooks under edge conditions (credential patterns, jq fallback, line counting, merge markers).
- **`scripts/test-stress-security.sh`** — 27 tests covering SEC-1 through SEC-9 security patterns.
- **`scripts/test-stress-scripts.sh`** — 21 tests for supporting scripts (skillssh-adapter, validate-commands, validate-ci-local, context-tracker, memory-store).
- **`scripts/test-era18-commands.sh`** — 32 tests validating Era 18 command structure (frontmatter, line limits, content).
- **`scripts/test-era18-rules.sh`** — 37 tests validating Era 18 rules (6 AI competencies, 4 AEPD phases, hook taxonomy, source tracking, skills.sh publishing).
- **`scripts/test-era18-formulas.sh`** — 23 tests for scoring formula correctness (AI Competency boundaries, AEPD weights, banking detection weights).
- **`scripts/test-stress-runner.sh`** — Orchestrator that runs all 9 test suites, aggregates counts, generates report in `output/test-results/`.

### Changed

- **`test-savia-e2e-harness.sh`** — Added Section 9: Era 18 Integration (6 tests).
- Tests: 64→229 (+165 new tests across 7 scripts)

[0.91.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.90.0...v0.91.0

---

## [0.90.0] — 2026-03-03

Era 19 — Open Source Synergy (6/6). ERA 19 COMPLETA.

### Added

- **`/mcp-browse`** — Comando para explorar el catálogo de 66+ MCPs del ecosistema claude-code-templates (database, devtools, browser_automation, deepresearch, productivity).
- **`/component-search`** — Búsqueda de componentes en el marketplace claude-code-templates (5.788+ components: agents, commands, hooks, MCPs, settings, skills).
- **`docs/recommended-mcps.md`** — Catálogo curado de MCPs recomendados para equipos PM/Scrum con instrucciones de instalación y contexto de uso.
- **`hooks/README.md`** — Documentación categorizada de los 14 hooks: seguridad (4), puertas de calidad (4), integración de agentes (3), flujo de desarrollo (3). Inspirado en la organización por categorías de claude-code-templates.
- **`agent-observability-patterns.md`** — Regla de dominio con patrones de observabilidad inspirados en el analytics dashboard de claude-code-templates: detección de estado en tiempo real, caché multinivel, WebSocket live updates, monitorización de rendimiento.
- **`component-marketplace.md`** — Regla de dominio que documenta la integración con el marketplace de componentes claude-code-templates (instalación, tipos de componentes, complementariedad).
- **Agradecimiento especial** en README.md y README.en.md a [claude-code-templates](https://github.com/davila7/claude-code-templates) de Daniel Avila (21K+ stars) como referencia imprescindible para herramientas libres para Claude Code.
- **`projects/claude-code-templates/`** — Repositorio clonado para seguimiento de releases, análisis de sinergias y preparación de contribuciones bidireccionales.
- **`SYNERGY-REPORT-PM-WORKSPACE.md`** — Informe completo de sinergias entre ambos proyectos con plan de contribución en 4 fases.

### Changed

- **README.md / README.en.md** — Añadida sección v0.90.0 con nuevos comandos y sección "Agradecimiento especial" con enlace a claude-code-templates.
- Commands: 271→273 · Rules: 50→52

[0.90.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.89.0...v0.90.0

---

## [0.89.0] — 2026-03-03

Era 18 — Compliance, Distribution & Intelligent Hooks (6/6). ERA 18 COMPLETA.

### Added

- **`/aepd-compliance`** — Auditoría de cumplimiento AEPD para IA agéntica (framework 4 fases: tecnología → cumplimiento → vulnerabilidades → medidas). Scoring calibrado.
- **`aepd-framework.md`** — Regla de dominio con el framework AEPD completo, mapping de controles pm-workspace, integración EU AI Act/NIST/ISO 42001.
- **`framework-aepd-agentic.md`** — Marcadores de detección de proyectos agénticos y checklist de compliance.
- **`skillssh-publishing.md`** — Especificación de formato para publicar en skills.sh marketplace (5 skills core mapeadas).
- **`scripts/skillssh-adapter.sh`** — Script de conversión pm-workspace → skills.sh (package.json, README, LICENSE).
- **`intelligent-hooks.md`** — Taxonomía de 3 tipos de hooks (Command/Prompt/Agent) con protocolo de calibración gradual.
- **`hooks/prompt-hook-commit.sh`** — Hook semántico de validación de mensajes de commit (heurísticas, sin LLM).
- **`hooks/agent-hook-premerge.sh`** — Quality gate pre-merge (secrets, TODOs, conflict markers, 150-line limit).
- **`/excel-report`** — Generar plantillas Excel interactivas (capacity, CEO, time-tracking) en CSV multi-tab.
- **`excel-templates.md`** — Estructuras CSV con fórmulas documentadas y reglas de validación.
- **`/savia-gallery`** — Catálogo interactivo de 271 comandos por rol y vertical con source tracking.
- **`source-tracking.md`** — Sistema de citación de fuentes (rule:/skill:/doc:/agent:/cmd:/ext:) con formatos inline/footer/compacto.
- **`ai-competency-framework.md`** — 6 competencias AI-era (Problem Formulation, Output Evaluation, Context Engineering, AI Orchestration, Critical Thinking, Ethical Awareness) con 4 niveles cada una.

### Changed

- **`governance-audit.md`** — Añadidos 4 criterios AEPD (EIPD, base jurídica, scope guard, protocolo brechas).
- **`governance-report.md`** — Añadido AEPD como framework soportado con score 4 fases.
- **`regulatory-compliance/SKILL.md`** — Nueva referencia framework-aepd-agentic.md.
- **`marketplace-publish.md`** — Añadido `--target skillssh` con referencia a adapter script.
- **`settings.json`** — Registrados 2 nuevos hooks (prompt-hook-commit, agent-hook-premerge).
- **`adoption-assess.md`** — Añadida opción `--ai-skills` con AI Competency radar (6 dimensiones).
- Commands: 268→271 · Hooks: 12→14

[0.89.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.83.0...v0.89.0

---

## [0.83.0] — 2026-03-02

Safe Boot, Deterministic CI, PR Governance — Savia arranca siempre: MCP servers vacíos (conexión bajo demanda), session-init blindado (sin red, sin jq, timeout 5s). Mock engine determinista (cksum hash, 29/29 consistente). Hooks de gobernanza PR (bloqueo auto-aprobación y bypass branch protection).

### Changed

- **`mcp.json`** — Servidores vacíos. Savia conecta bajo demanda con `/mcp-server start`, no al arranque.
- **`session-init.sh`** — v0.42.0: sin llamadas de red, sin dependencia `jq`, timeout global 5s, ERR trap para salida limpia garantizada. Context tracker en background.
- **`engines.sh`** — Mock determinista: varianza con `cksum` hash (no `$RANDOM`), context overflow solo en límite real (200k tokens).
- **`CLAUDE.md`** — 216→120 líneas: sección Savia duplicada eliminada, catálogo de comandos movido a referencia, regla 19 (arranque seguro).
- **`validate-bash-global.sh`** — Nuevos bloqueos: `gh pr review --approve` (auto-aprobación) y `gh pr merge --admin` (bypass branch protection).
- **`github-flow.md`** — Reglas explícitas: NUNCA auto-aprobar, NUNCA --admin.

[0.83.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.82.0...v0.83.0

---

## [0.82.0] — 2026-03-02

Auto-Compact — Compresión automática de contexto entre escenarios. Cuando el contexto acumulado supera un umbral configurable (default 40%), se ejecuta `retro-summary --compact` simulado que reduce 60-70% del contexto. Harness refactorizado en 3 ficheros (≤150 líneas cada uno).

### Added

- **`--auto-compact`** flag en harness.sh — activa compresión automática entre escenarios.
- **`--compact-threshold=N`** — umbral configurable (% de ventana 200K) para disparar compactación.
- **`engines.sh`** — Mock engine + live engine extraídos a fichero independiente.
- **`report-gen.sh`** — Generador de reports extraído a fichero independiente.
- Sección "Auto-Compaction Events" en el report cuando se activa.

### Changed

- **`harness.sh`** — Refactorizado de 269→150 líneas, ahora orquestador puro.
- **`test-savia-e2e-harness.sh`** — 44 tests (vs 38), incluye test de auto-compact.

[0.82.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.81.0...v0.82.0

---

## [0.81.0] — 2026-03-02

AI Role Tooling — Dos nuevos comandos basados en gaps detectados en role-evolution-ai: `/knowledge-prime` (genera `.priming/` con 7 secciones Fowler) y `/savia-persona-tune` (5 perfiles de tono/personalidad).

### Added

- **`/knowledge-prime`** — Genera `.priming/` analizando código, packages, ADRs y git log. 7 secciones: architecture, stack, sources, structure, naming, examples, anti-patterns.
- **`/savia-persona-tune`** — 5 perfiles (warm, technical, executive, mentor, minimal). Genera `.savia-persona.yml`.

### Changed

- CLAUDE.md, README.md, README.en.md — Command count 267→268.

[0.81.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.80.0...v0.81.0

---

## [0.80.0] — 2026-03-02

Context Optimization v2 — Mock engine realista calibrado por tipo de comando. State file para acumulación de contexto entre steps. Probabilidad de overflow crece con contexto acumulado (>80K: +10%, >120K: +20%).

### Changed

- **`harness.sh`** — Mock engine reescrito: rangos de tokens calibrados por comando, state file `state.json`, columna `context_acc` en CSV, sección "Context Accumulation" en report con umbrales 50%/70%.

[0.80.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.79.1...v0.80.0

---

## [0.79.1] — 2026-03-02

Role Evolution update — Reescrita `role-evolution-ai.md` con la taxonomía real de Kelman Celis (6 categorías: Estrategia, Ingeniería, Datos, Gobernanza, Interacción, Mantenimiento). Mapping equipo SocialApp a categorías Kelman. Gaps detectados → propuestas de mejora en roadmap.

### Changed

- **`role-evolution-ai.md`** — Reescrita completa: 6 categorías Kelman (vs genéricas previas), roles industria mapeados a Savia Flow, gaps detectados (RAG Engineer, Behavioral Trainer, AI UX Designer).
- **`ROADMAP.md`** — Añadido "AI Role Tooling" en propuestas: `/knowledge-prime`, `/savia-persona-tune`, mock engine realista.

[0.79.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.79.0...v0.79.1

---

## [0.79.0] — 2026-03-02

CI + Multimodal Agent Prep — GitHub Action para E2E mock en PRs. Reference de agentes multimodales (VLM vision+text+code) con roadmap de integración para quality gates visuales.

### Added

- **`.github/workflows/savia-e2e.yml`** — CI workflow: E2E mock test en PRs que modifiquen flow-* o savia-test.
- **`multimodal-agents.md`** — Reference: agentes VLM, tool-use, roadmap integración visual gates + spec from wireframe.

[0.79.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.78.0...v0.79.0

---

## [0.78.0] — 2026-03-02

Role Evolution — 6 categorías roles AI-era mapeadas a Savia Flow. Escenario stress test (10+ specs concurrentes).

### Added

- **`role-evolution-ai.md`** — 6 categorías (Orchestrator, Translator, Guardian, Builder, Context Engineer, Governance), mapping equipo, madurez L1-L4.
- **`05-stress.md`** — Escenario stress: 10+ specs, intake masivo, board full-load, retro exhaustivo.

[0.78.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.77.0...v0.78.0

---

## [0.77.0] — 2026-03-02

Knowledge Priming (Fowler) — 5 patrones para reducir fricción AI. Estructura `.priming/` por proyecto.

### Added

- **`knowledge-priming.md`** — 7 secciones priming, Design-First, Context Anchoring, Feedback Flywheel.

### Changed

- SKILL.md: +3 references (knowledge-priming, role-evolution-ai, multimodal-agents).

[0.77.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.76.0...v0.77.0

---

## [0.76.0] — 2026-03-02

Context Optimization — Correcciones del informe E2E v0.75.0. `max_context` budgets, `--spec` filter, escenario flow-protect.

### Changed

- `flow-board/intake/metrics/spec.md` — `max_context` en frontmatter para budget enforcement.
- `flow-intake.md` — Nuevo `--spec {ID}` para intake individual.
- `03-coordination.md` — Nuevo Step 5: flow-protect (WIP overload, deep work).
- `test-savia-e2e-harness.sh` — Check flow-protect en escenario 03.

[0.76.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.75.0...v0.76.0

---

## [0.75.0] — 2026-03-02

Savia E2E Test Harness — Entorno Docker aislado con agente autónomo que ejecuta Claude Code headless contra pm-workspace. Simula 4 roles de equipo ejecutando 23 pasos en 5 escenarios (setup → exploration → production → coordination → release). Recopila métricas de tokens, tiempos, errores y bloqueos de contexto. Modo mock para CI, modo live con API key real.

### Added

- **`docker/savia-test/`** — Test harness Docker: Dockerfile, docker-compose.yml, harness.sh orchestrator.
- **5 escenarios E2E** — 00-setup (3 pasos), 01-exploration (5), 02-production (5), 03-coordination (5), 04-release (5). 23 pasos totales cubriendo todo el ciclo Savia Flow.
- **Motor mock** — Simula respuestas con tokens aleatorios, 5% error rate (context overflow + timeout). Para CI sin API key.
- **Motor live** — Ejecuta `claude -p` headless real. Captura tokens, duración, errores. Configurable via env vars.
- **Métricas CSV** — scenario, step, role, command, tokens_in, tokens_out, duration_ms, status, error.
- **Informe automático** — report.md generado al final con resumen, failures, errors, token totals.

[0.75.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.74.0...v0.75.0

---

## [0.74.0] — 2026-03-02

Savia Flow Practice — Implementación práctica de la metodología Savia Flow: configuración Azure DevOps dual-track, tablero exploración/producción, intake continuo, métricas de flujo y creación de specs. Ejemplo completo: SocialApp (Ionic + microservicios + RabbitMQ) con equipo de 4 personas.

### Added

- **`/flow-setup`** — Configurar Azure DevOps para Savia Flow: board dual-track (Exploration + Production), campos custom (Track, Outcome ID, Cycle Time), area paths. Modos: `--plan` (preview), `--execute` (aplicar), `--validate` (verificar).
- **`/flow-board`** — Visualizar tablero dual-track: exploración a la izquierda, producción a la derecha. Alerta WIP limits excedidos. Filtros por track y persona.
- **`/flow-intake`** — Intake continuo: mover items Spec-Ready a Production. Valida acceptance criteria, check capacidad, asigna a builder disponible.
- **`/flow-metrics`** — Dashboard métricas de flujo: Cycle Time, Lead Time, Throughput, CFR. Métricas IA: spec-to-built time, handoff latency. Tendencias y comparativas.
- **`/flow-spec`** — Crear spec ejecutable desde outcome de exploración. Genera stub con 5 secciones Savia Flow, crea User Story vinculada al Epic padre.
- **Skill `savia-flow-practice/`** — Guía práctica con 6 references: azure-devops-config, backlog-structure, task-template-sdd, meetings-cadence, dual-track-coordination, example-socialapp.

### Changed

- Command count: 262 → 267 (+5 comandos flow)
- Skills: 20 → 21 (+savia-flow-practice)
- Context-map: añadido grupo Savia Flow

[0.74.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.73.0...v0.74.0

---

## [0.73.0] — 2026-03-02

Vertical Banking — Herramientas especializadas para equipos de desarrollo en banca: validación BIAN + ArchiMate, pipelines Kafka/EDA, data governance (lineage, clasificación, GDPR), auditoría MLOps (model risk, XAI, scoring). Auto-detección de proyectos bancarios.

### Added

- **`/banking-detect`** — Auto-detección de proyecto bancario. 5 fases: entidades BIAN (Account, Settlement, KYC/AML), rutas API bancarias, deps (Kafka, Snowflake, MLflow), config (BIAN_*, KAFKA_*, SWIFT_*), documentación. Score ≥55% → confirmar.
- **`/banking-bian`** — Validar arquitectura contra estándar BIAN. Mapeo microservicios a Service Domains (Payments, Settlement, Deposits, Lending, Risk). Diagrama ArchiMate en Mermaid. Detección de anti-patrones (God Service, Fragmented Domain).
- **`/banking-eda-validate`** — Validar pipelines Kafka/MSK/AMQ: topologías, DLQ, schemas Avro/Protobuf, idempotencia, ordering guarantees. Evaluar patrones EDA: Saga, CQRS, Event Sourcing. Circuit breakers en settlement flows.
- **`/banking-data-governance`** — Auditar data governance: lineage (BCBS 239), clasificación (PII/PCI/Confidencial), catálogo Snowflake/Iceberg, feature stores (batch + real-time). Validar GDPR/LOPD. Data mesh domain ownership.
- **`/banking-mlops-audit`** — Auditar pipeline MLOps bancario: versionado, CI/CD/CT, drift detection, model registry. Explicabilidad (XAI/SHAP/LIME). Model risk management (SR 11-7). Scoring architectures (batch/streaming/event-driven). GenAI (RAG, embeddings).
- **Skill `banking-architecture/`** — Skill con 3 references: BIAN framework, EDA patterns banking, data governance banking.
- **Regla `banking-detection.md`** — Regla de detección automática de proyectos bancarios con 5 fases y scoring.

### Changed

- Command count: 257 → 262 (+5 comandos banking)
- Context-map: añadido grupo Banking
- CLAUDE.md: añadida sección Banking Architecture

[0.73.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.72.0...v0.73.0

---

## [0.72.0] — 2026-03-02

Trace Intelligence — Búsqueda y análisis profundo de trazas distribuidas, investigación asistida de errores con root cause analysis, correlación multi-fuente de incidentes. Era 13 — Observability & Intelligence (2/2). ERA 13 COMPLETE!

### Added

- **`/trace-search {criterio}`** — Buscar y filtrar trazas en Grafana Tempo, Datadog APM, Azure App Insights, OpenTelemetry. Soporta búsqueda en lenguaje natural. Filtros: servicio, estado (error/slow), periodo temporal, código error, tipo de excepción, usuario. Resultados con paginación automática.
- **`/trace-analyze {trace-id}`** — Análisis profundo de traza específica. Waterfall ASCII timeline, detección de cuellos de botella (span más lento), cadena de errores (origen y propagación), detección de anomalías vs baseline, mapa de dependencias de servicios, recomendaciones contextuales. Output adaptado por rol.
- **`/error-investigate {descripción}`** — Investigación asistida de errores. Busca logs coincidentes, correlaciona trazas, analiza despliegues recientes, verifica métricas de infraestructura, identifica servicio origen, construye hipótesis de root cause, sugiere mitigación inmediata y preventiva.
- **`/incident-correlate [--incident-id ID]`** — Correlación cruzada de métricas (Grafana, Datadog, App Insights), logs (Loki, Datadog, App Insights), trazas (Tempo, APM, Dependencies), despliegues (CI/CD), alertas previas y cambios de configuración. Genera timeline unificado, detecta cascading failures, cuantifica blast radius, draft de post-mortem automático.

### Changed

- Command count: 253 → 257 (+4 comandos trace intelligence)
- Era 13 (Observability & Intelligence): COMPLETE! (2/2)

[0.72.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.71.0...v0.72.0

---

## [0.71.0] — 2026-03-02

Observability Core — Conexión a Grafana, Datadog, Azure App Insights, OpenTelemetry. Consultas en lenguaje natural a datos de observabilidad (PromQL, KQL, Datadog Query Language). Dashboards digeridos por rol (CEO, CTO, PM, Dev, QA, SRE). Health checks de fuentes. Era 13 — Observability & Intelligence (1/2).

### Added

- **`/obs-connect {platform}`** — Conectar Savia a Grafana, Datadog, App Insights, OpenTelemetry. Almacena credenciales cifradas (AES-256-CBC). Soporta múltiples instancias simultáneamente. Test de conexión automático.
- **`/obs-query {pregunta}`** — Consultas en lenguaje natural a datos de observabilidad. Traduce automáticamente a PromQL (Grafana), KQL (App Insights), Datadog Query Language. Detecta anomalías vs baseline. Correlaciona con deployments.
- **`/obs-dashboard [--role]`** — Dashboard digerido por rol. CEO: disponibilidad + SLA + costos. CTO: latencias por servicio + errors. PM: impacto en usuarios + features. Dev/SRE: detalles técnicos + logs/traces. QA: pre/post deploy comparisons.
- **`/obs-status`** — Health check de todas las fuentes conectadas. Estado de conexión, última sincronización, volumen de datos, alertas activas, recomendaciones.

### Changed

- Command count: 249 → 253 (+4 comandos observabilidad)
- Era 13 (Observability & Intelligence): iniciada (1/2)

[0.71.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.70.0...v0.71.0

---

## [0.70.0] — 2026-03-02

Multi-Tenant & Skills Marketplace — Workspaces aislados por departamento/equipo, marketplace interno de skills/playbooks, compartición de recursos con control de aprobación. Era 12 — Team Excellence & Enterprise (5/5). PLAN COMPLETADO: v0.54-v0.70 = 68 comandos en 17 versiones.

### Added

- **`/tenant-create`** — Crea workspace aislado por departamento con perfiles, roles, configuración de proyecto e herencia empresarial. Isolation levels: full (separado) o shared (datos separados, reglas comunes).
- **`/tenant-share`** — Comparte recursos (playbooks, templates, skills, reglas) entre tenants con flujo de aprobación, versionado y prevención de config drift.
- **`/marketplace-publish`** — Publica skills/playbooks al marketplace interno con metadatos, validación de calidad y sistema de ratings tipo Anthropic Skills.
- **`/marketplace-install`** — Instala recursos del marketplace con resolución de dependencias, preview y rollback automático. Verificación de compatibilidad.

### Changed

- Command count: 249 → 253 (+4 comandos multi-tenant y marketplace)
- Era 12 (Team Excellence & Enterprise): ahora completa (5/5 fases)

### Plan Roadmap Completado

**v0.54–v0.70**: 17 versiones, 68 nuevos comandos estructurados en 4 eras:
- Era 9 (v0.54–v0.57): Company Intelligence — 16 comandos
- Era 10 (v0.58–v0.61): AI Governance — 17 comandos
- Era 11 (v0.62–v0.65): Context Engineering 2.0 — 17 comandos
- Era 12 (v0.66–v0.70): Team Excellence & Enterprise — 18 comandos

**Total**: 253 comandos en pm-workspace. Todos los comandos ≤150 líneas, con YAML frontmatter, warm Savia persona (female owl), contexto Spanish.

[0.70.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.69.0...v0.70.0

---

## [0.69.0] — 2026-03-02

Audit Trail & Compliance — Inmutable audit trail de todas las acciones de Savia con exportación para auditorías externas, búsqueda contextual y alertas de anomalías. Era 12 — Team Excellence & Enterprise (4/5).

### Added

- **`/audit-trail`** — Log inmutable de todas acciones: comandos ejecutados, recomendaciones, decisiones, archivos. Append-only. Cumple EU AI Act, ISO 42001, NIST AI RMF.
- **`/audit-export`** — Exporta trail en JSON (SIEM), CSV (análisis), PDF (compliance). Incluye hash SHA-256 para verificación de integridad.
- **`/audit-search`** — Búsqueda contextual por fecha, usuario, acción. NL search soportado. Regex patterns. Timeline visualization. Saved searches.
- **`/audit-alert`** — Alertas automáticas por patrones anómalos: fuera de horario, comandos riesgo alto sin aprobación, volumen inusual, acceso a datos sensibles. Canales: Slack, email, dashboard.

### Changed

- Command count: 245 → 249 (+4 comandos auditoría)

[0.69.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.68.0...v0.69.0

---

## [0.68.0] — 2026-03-02

Accessibility & Inclusive Design — Auditoría WCAG 2.2, correcciones automáticas, reportes de conformidad, monitorización continua.

### Added

- **`/a11y-audit`** — Auditoría exhaustiva de accesibilidad WCAG 2.2 (AA/AAA) con detección de alt text, contraste, navegación por teclado, ARIA, focus management, jerarquía de encabezados
- **`/a11y-fix`** — Correcciones automáticas con preview y verificación; covers alt text, ARIA attributes, focus traps, skip links, color contrast
- **`/a11y-report`** — Reportes multi-formato: ejecutivo (score + gráficos), técnico (detalles + código), legal (VPAT/Section 508); tracking de tendencias
- **`/a11y-monitor`** — Monitorización continua en CI/CD; bloquea deploys con regresiones de accesibilidad; digest semanal

### Changed

- Command count: 245 → 249 (+4 comandos accesibilidad)

[0.68.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.67.0...v0.68.0

---

## [0.67.0] — 2026-03-02

Team Wellbeing & Sustainability — Detección temprana de burnout, equilibrado de carga y ritmo sostenible.

### Added

- **`/burnout-radar`** — Detección de señales tempranas de burnout con mapa de calor por miembro
- **`/workload-balance`** — Equilibrado objetivo de carga respetando especialidades
- **`/sustainable-pace`** — Cálculo de ritmo sostenible basado en histórico y capacidad
- **`/team-sentiment`** — Análisis de sentimiento del equipo con pulse surveys y tendencias

### Enhanced

- **role-workflows.md** — Aggregated wellbeing commands for SM/Flow Facilitator role
- **context-map.md** — Added wellbeing group for Team Excellence domain

### Changed

- Command count: 237 → 241 (+4 wellbeing commands in Era 12)
- Era 12 — Team Excellence & Enterprise (2/5 features)

[0.67.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.66.0...v0.67.0

---

## [0.66.0] — 2026-02-28

Advanced DX Metrics — Deep-work analysis, flow-state protection, developer experience profiling, and prevention-focused feedback loops.

### Added

- **`/dx-core4-survey`** — Adapted survey for Speed, Effectiveness, Quality, Impact dimensions
- **`/flow-protect`** — Detect and protect deep-work sessions; block interruptions; suggest focus blocks
- **`/deep-work-analyze`** — Analyze developer deep-work patterns; measure focus time and context switching
- **`/prevention-metrics`** — Preventive metrics: friction points before they block; suggested workflow improvements

### Changed

- Command count: 241 → 245 (+4 DX metrics commands)

[0.66.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.65.0...v0.66.0

---

## [0.65.0] — 2026-02-28

Multi-Layer Caching — Cache strategy, warm operations, analytics, and selective invalidation for context optimization.

### Added

- **`/cache-strategy`** — Define multi-layer cache policy (system, session, command, query levels)
- **`/cache-warm`** — Predictive pre-warming for next operations based on patterns
- **`/cache-analytics`** — Dashboard of cache hit rates, latency improvements, and cost savings
- **`/cache-invalidate`** — Selective invalidation after configuration changes; audit trail

### Changed

- Command count: 237 → 241 (+4 caching commands)

[0.65.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.64.0...v0.65.0

---

## [0.64.0] — 2026-03-02

Semantic Memory 2.0 — Four new memory intelligence commands for semantic compression, importance scoring, knowledge graphs, and intelligent pruning.

### Added

- **`/memory-compress`** — Semantic compression: reduce engrams by up to 80% while preserving fidelity via entity extraction, event summarization, decision condensation, context deduplication
- **`/memory-importance`** — Importance scoring: rank engrams by composite score (relevance × recency × frequency access). Identify high-value and low-value candidates
- **`/memory-graph`** — Knowledge graph from engrams: build relational map of entities, events, decisions. Query connections, detect isolated memories, generate Mermaid visualization
- **`/memory-prune`** — Intelligent pruning: archive low-importance memories, preserve critical ones. Reversible with restore. Never prunes decision-log entries

### Changed

- Command count: 237 → 241 (+4 memory commands)

[0.64.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.63.0...v0.64.0

---

## [0.63.0] — 2026-03-02

Evolving Playbooks — Four new playbook commands for capturing and evolving repetitive workflows using ACE framework.

### Added

- **`/playbook-create`** — Create evolutionary playbooks for releases, onboarding, audits, deploys
- **`/playbook-reflect`** — Post-execution reflection (ACE Reflector): analyze what worked, failed, improve
- **`/playbook-evolve`** — Evolve playbooks with insights (Generator→Reflector→Curator cycle from ACE)
- **`/playbook-library`** — Shareable library of mature playbooks across projects with effectiveness ratings

### Changed

- Command count: 233 → 237 (+4 playbook commands)

[0.63.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.62.0...v0.63.0

---

## [0.62.0] — 2026-03-02

Intelligent Context Loading — Four new context management commands for optimal token budgeting and lazy loading (Context Engineering 2.0).

### Added

- **`/context-budget`** — Token budget per session with optimization suggestions
- **`/context-defer`** — Deferred loading system (85% token reduction)
- **`/context-profile`** — Context consumption profiling (flame-graph style)
- **`/context-compress`** — Semantic compression (80% reduction target)

### Changed

- Command count: 229 → 233 (+4 context commands)

[0.62.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.61.0...v0.62.0

---

## [0.61.0] — 2026-03-02

Vertical Compliance Extensions — Four new vertical-specific compliance commands for regulated sectors (healthcare, finance, legal, education).

### Added

- **`/vertical-healthcare`** — HIPAA, HL7 FHIR, FDA 21 CFR Part 11
- **`/vertical-finance`** — SOX, Basel III, MiFID II, PCI DSS
- **`/vertical-legal`** — GDPR, eDiscovery, contract lifecycle, legal hold
- **`/vertical-education`** — FERPA, Section 508/WCAG, COPPA, LMS integration

### Changed

- Command count: 225 → 229 (+4 vertical compliance commands)

[0.61.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.60.0...v0.61.0

---

## [0.60.0] — 2026-03-02

Enterprise AI Governance — Four new governance commands based on NIST AI RMF, ISO/IEC 42001, and EU AI Act.

### Added

- **`/governance-policy`** — Define company AI policy, risk classification, approval matrix, audit trail
- **`/governance-audit`** — Compliance audit against policy
- **`/governance-report`** — Executive report mapped to frameworks
- **`/governance-certify`** — Certification checklist and readiness scoring

### Changed

- Command count: 221 → 225 (+4 governance commands)

[0.60.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.59.0...v0.60.0

---

## [0.59.0] — 2026-03-02

AI Adoption Companion — Four new adoption commands for team maturity assessment, personalized learning paths, safe practice environments, and friction tracking.

### Added

- **`/adoption-assess`** — Evaluate team adoption maturity using ADKAR model
- **`/adoption-plan`** — Personalized adoption plan by role with learning paths
- **`/adoption-sandbox`** — Safe practice environment without risks
- **`/adoption-track`** — Adoption metrics and friction point detection

### Changed

- Command count: 217 → 221 (+4 adoption commands)

[0.59.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.58.0...v0.59.0

---

## [0.58.0] — 2026-03-02

AI Safety & Human Oversight — Four new safety commands for supervision levels, confidence transparency, boundary definition, and incident tracking.

### Added

- **`/ai-safety-config`** — Configure supervision levels (inform/recommend/decide/execute)
- **`/ai-confidence`** — Transparency dashboard showing confidence, reasoning, data used
- **`/ai-boundary`** — Define explicit boundary matrix per role
- **`/ai-incident`** — Record and analyze Savia incidents

### Changed

- Command count: 213 → 217 (+4 safety commands)

[0.58.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.57.0...v0.58.0

---

## [0.57.0] — 2026-03-02

Ceremony Intelligence — Four new commands for asynchronous standups, retro pattern analysis, ceremony health metrics, and smart agenda generation.

### Added

- **`/async-standup`** — Asynchronous standup collection and compilation
- **`/retro-patterns`** — Pattern analysis from retrospectives
- **`/ceremony-health`** — Health metrics for ceremonies
- **`/meeting-agenda`** — Intelligent agenda generation

### Changed

- Command count: 209 → 213 (+4 ceremony commands)

[0.57.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.56.0...v0.57.0

---

## [0.56.0] — 2026-03-02

Intelligent Backlog Management — Four new commands for assisted grooming, smart prioritization (RICE/WSJF), outcome tracking, and conflict resolution.

### Added

- **`/backlog-groom`** — Detect obsolete, duplicate items without acceptance criteria
- **`/backlog-prioritize`** — Automatic RICE/WSJF prioritization
- **`/outcome-track`** — Post-release outcome tracking
- **`/stakeholder-align`** — Conflict resolution with objective data

### Changed

- Command count: 205 → 209 (+4 backlog commands)

[0.56.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.55.0...v0.56.0

---

## [0.55.0] — 2026-03-02

OKR & Strategic Alignment — Four new commands for OKR definition, tracking, visualization, and strategic mapping.

### Added

- **`/okr-define`** — Define Objectives and Key Results linked to projects
- **`/okr-track`** — Automatic OKR progress tracking
- **`/okr-align`** — Visualize project→OKR→strategy alignment
- **`/strategy-map`** — Strategic map with initiatives and dependencies

### Changed

- Command count: 201 → 205 (+4 strategy commands)

[0.55.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.54.0...v0.55.0

---

## [0.54.0] — 2026-03-02

Company Profile — Four new commands for enterprise onboarding and configuration.

### Added

- **`/company-setup`** — Conversational onboarding of enterprise profile
- **`/company-edit`** — Edit company profile sections
- **`/company-show`** — Display consolidated profile with gap detection
- **`/company-vertical`** — Detect and configure vertical and regulations

### Changed

- Command count: 197 → 201 (+4 company setup commands)

[0.54.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.53.0...v0.54.0

---

## [0.53.0] — 2026-03-02

Multi-Platform Support — Three new commands for multi-platform integration.

### Added

- **`/jira-connect`** — Connect and sync with Jira Cloud
- **`/github-projects`** — Integration with GitHub Projects v2
- **`/platform-migrate`** — Assisted migration between platforms

### Changed

- **`/linear-sync`** — Rewritten with new format, webhooks, unified metrics

[0.53.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.52.0...v0.53.0

---

## [0.52.0] — 2026-03-02

Integration Hub — Four new commands for MCP server exposure, natural language queries, webhook configuration, and integration status.

### Added

- **`/mcp-server`** — Expose Savia tools as MCP server for other projects
- **`/nl-query`** — Natural language queries without memorizing commands
- **`/webhook-config`** — Configure webhooks for real-time event push
- **`/integration-status`** — Dashboard of all integration health

### Changed

- Command count: 174 → 178 (+4 integration commands)

[0.52.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.51.0...v0.52.0

---

## [0.51.0] — 2026-03-02

AI-Powered Planning — Four new commands for intelligent sprint planning, risk prediction, meeting summarization, and capacity forecasting.

### Added

- **`/sprint-autoplan`** — Intelligent sprint planning from backlog and capacity
- **`/risk-predict`** — Sprint risk prediction with early signals
- **`/meeting-summarize`** — Transcription and action item extraction
- **`/capacity-forecast`** — Medium-term capacity forecasting (3-6 sprints)

### Changed

- Command count: 170 → 174 (+4 planning commands)

[0.51.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.50.0...v0.51.0

---

## [0.50.0] — 2026-03-02

Cross-Project Intelligence — Four new commands for portfolio-level visibility and analysis.

### Added

- **`/portfolio-deps`** — Inter-project dependency graph with bottleneck detection
- **`/backlog-patterns`** — Detect duplicates across projects
- **`/org-metrics`** — Aggregated DORA metrics at organization level
- **`/cross-project-search`** — Unified search across all portfolio projects

### Changed

- Command count: 166 → 170 (+4 cross-project commands)

[0.50.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.49.0...v0.50.0

---

## [0.49.0] — 2026-03-01

Product Owner Analytics — Four new commands providing strategic views for POs.

### Added

- **`/value-stream-map`** — Value stream mapping with bottleneck detection
- **`/feature-impact`** — Feature impact on ROI and engagement
- **`/stakeholder-report`** — Executive report for stakeholders
- **`/release-readiness`** — Release readiness verification

### Changed

- Command count: 162 → 166 (+4 PO commands)

[0.49.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.48.0...v0.49.0

---

## [0.48.0] — 2026-03-01

Tech Lead Intelligence — Four new commands for technology health and team knowledge.

### Added

- **`/tech-radar`** — Technology stack mapping (adopt/trial/hold/retire)
- **`/team-skills-matrix`** — Competency matrix with bus factor calculation
- **`/arch-health`** — Architectural health scoring
- **`/incident-postmortem`** — Blameless postmortem template

### Changed

- Command count: 158 → 162 (+4 tech lead commands)

[0.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.47.0...v0.48.0

---

## [0.47.0] — 2026-03-01

Developer Productivity — Four new commands for personal sprint view, deep focus, learning opportunities, and pattern catalog.

### Added

- **`/my-sprint`** — Personal sprint view (private, no comparisons)
- **`/my-focus`** — Deep focus mode with context loading
- **`/my-learning`** — Learning opportunity detection from commits
- **`/code-patterns`** — Living pattern catalog from codebase

### Changed

- Command count: 154 → 158 (+4 developer commands)

[0.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.46.0...v0.47.0

---

## [0.46.0] — 2026-03-01

QA and Testing Toolkit — Four new commands for complete testing workflow.

### Added

- **`/qa-dashboard`** — Quality panel with coverage and test metrics
- **`/qa-regression-plan`** — Regression test planning based on changes
- **`/qa-bug-triage`** — Assisted bug triage with duplicate detection
- **`/testplan-generate`** — Test plan generation from specs

### Changed

- Command count: 150 → 154 (+4 QA commands)

[0.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.45.0...v0.46.0

---

## [0.45.0] — 2026-03-01

Executive Reports for Leadership — Three new commands for C-level strategic views.

### Added

- **`/ceo-report`** — Multi-project executive report with traffic-light scoring
- **`/ceo-alerts`** — Strategic alert panel for director-level decisions
- **`/portfolio-overview`** — Bird's-eye portfolio view with dependencies

### Changed

- Command count: 147 → 150 (+3 CEO commands)

[0.45.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.44.0...v0.45.0

---

## [0.44.0] — 2026-03-01

Semantic Hub Topology — Agentexecution tracing, cost estimation, and efficiency metrics for subagent operations.

### Added

- **`/hub-audit`** — Topology audit revealing hubs, near-hubs, and dormant rules

### Changed

- Command count: 146 → 147 (+1 hub audit command)

[0.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.43.0...v0.44.0

---

## [0.43.0] — 2026-03-01

Context Aging and Verified Positioning — Semantic compression of old decisions using neuroscience-inspired aging.

### Added

- **`/context-age`** — Analyze and compress aged decisions
- **`/context-benchmark`** — Verify optimal information positioning
- **`scripts/context-aging.sh`** — Automation script

### Changed

- Command count: 144 → 146 (+2 context commands)

[0.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.42.0...v0.43.0

---

## [0.42.0] — 2026-03-01

Subagent Context Budget System — All 24 agents now have explicit max_context_tokens and output_max_tokens fields.

### Changed

- All 24 agent frontmatter files updated with context budgets (4 tiers)

[0.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.41.0...v0.42.0

---

## [0.41.0] — 2026-03-01

Session-Init Compression and CLAUDE.md Pre-compaction — 4-level priority system for session initialization.

### Changed

- **`session-init.sh`** — Rewritten with priority-based array system
- **CLAUDE.md** — Pre-compacted from 154 → 125 lines (36% reduction)

[0.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.40.0...v0.41.0

---

## [0.40.0] — 2026-03-01

Role-Adaptive Daily Routines, Project Health Dashboard, and Context Usage Optimization.

### Added

- **`/daily-routine`** — Role-adaptive daily routine
- **`/health-dashboard`** — Unified project health dashboard
- **`/context-optimize`** — Context usage analysis with recommendations
- **`scripts/context-tracker.sh`** — Lightweight context usage tracking

### Changed

- Command count: 141 → 144 (+3 context commands)

[0.40.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.39.0...v0.40.0

---

## [0.39.0] — 2026-03-01

Encrypted Cloud Backup System — AES-256-CBC encryption before cloud upload with auto-rotation.

### Added

- **`/backup`** — 5 subcommands for backup management
- **`scripts/backup.sh`** — Full backup lifecycle automation

### Changed

- Command count: 140 → 141 (+1 backup command)

[0.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.38.0...v0.39.0

---

## [0.38.0] — 2026-03-01

Private Review Protocol — Maintainer workflow for reviewing community PRs and issues.

### Added

- **`/review-community`** — 5 subcommands for PR/issue review and release

### Changed

- Command count: 139 → 140 (+1 review command)

[0.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.37.0...v0.38.0

---

## [0.37.0] — 2026-03-01

Vertical Detection System — Detect non-software sectors and propose specialized extensions.

### Added

- **`/vertical-propose`** — Detect vertical or receive name and generate extensions

### Changed

- Command count: 138 → 139 (+1 vertical detection command)

[0.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.36.0...v0.37.0

---

## [0.36.0] — 2026-03-01

Community & Collaboration System — Privacy-first contribution system with credential validation.

### Added

- **`/contribute`** — Create PRs, propose ideas, report bugs
- **`/feedback`** — Open issues with validation

### Changed

- Command count: 136 → 138 (+2 community commands)

[0.36.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.35.0...v0.36.0

---

## [0.35.0] — 2026-03-01

Savia — User Profiling System and Agent Mode. Introduce Savia identity with fragmented user profiles and agent mode support.

### Added

- **`/profile-setup`** — Savia's conversational onboarding
- **`/profile-edit`** — Edit profile sections
- **`/profile-switch`** — Switch between profiles
- **`/profile-show`** — Display active profile

### Changed

- Command count: 131 → 135 (+4 profile commands)
- ~72 existing commands updated with profile loading

[0.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.34.0...v0.35.0

---

## [0.34.0] — 2026-02-28

Performance Audit Intelligence — Static analysis for code performance hotspots.

### Added

- **`/perf-audit`** — Static performance analysis
- **`/perf-fix`** — Test-first optimization
- **`/perf-report`** — Executive performance report

### Changed

- Command count: 129 → 131 (+3 performance commands)

[0.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.3...v0.34.0

---

## [0.33.3] — 2026-02-28

Azure DevOps project validation — Automated audit of project configuration.

### Added

- **`/devops-validate`** — Audit Azure DevOps project config

### Changed

- Command count: 128 → 129 (+1 DevOps command)

[0.33.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.2...v0.33.3

---

## [0.33.2] — 2026-02-28

Detection algorithm calibration after real-world testing across regulated sectors.

### Changed

- Detection algorithm: 4 phases → 5 phases
- Confidence thresholds recalibrated

[0.33.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.1...v0.33.2

---

## [0.33.1] — 2026-02-28

Compliance commands improvements after real-world testing.

### Fixed

- Output file naming with date suffix
- Scoring formula documentation
- Dry-run vs actual execution indication

[0.33.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.0...v0.33.1

---

## [0.33.0] — 2026-02-28

Regulatory Compliance Intelligence — Automated sector detection and compliance scanning across 12 regulated industries.

### Added

- **`/compliance-scan`** — Automated compliance scanning
- **`/compliance-fix`** — Auto-fix framework for violations
- **`/compliance-report`** — Generate compliance report

### Changed

- Command count: 125 → 128 (+3 compliance commands)

[0.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.3...v0.33.0

---

## [0.32.3] — 2026-02-28

Multi-OS emergency mode — Support for Linux, macOS, and Windows.

[0.32.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.2...v0.32.3

---

## [0.32.2] — 2026-02-28

Fix Ollama download — Adapted to new tar.zst archive format.

[0.32.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.1...v0.32.2

---

## [0.32.1] — 2026-02-28

Emergency plan — Preventive pre-download of Ollama and LLM for offline installation.

[0.32.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.0...v0.32.1

---

## [0.32.0] — 2026-02-28

Emergency mode — Local LLM contingency plan with Ollama setup and offline operations.

### Added

- **`/emergency-mode`** — Manage emergency mode with local LLM

[0.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.31.0...v0.32.0

---

## [0.31.0] — 2026-02-28

Architecture intelligence — Pattern detection and recommendations across 16 languages.

### Added

- **`/arch-detect`** — Detect architecture pattern
- **`/arch-suggest`** — Generate improvement suggestions
- **`/arch-recommend`** — Recommend optimal pattern
- **`/arch-fitness`** — Define and execute fitness functions
- **`/arch-compare`** — Compare architecture patterns

[0.31.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.30.0...v0.31.0

---

## [0.30.0] — 2026-02-28

Technical debt intelligence — Automated analysis and prioritization.

### Added

- **`/debt-analyze`** — Automated debt discovery
- **`/debt-prioritize`** — Prioritize by business impact
- **`/debt-budget`** — Propose sprint debt budget

[0.30.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.29.0...v0.30.0

---

## [0.29.0] — 2026-02-28

AI governance and EU AI Act compliance — Model cards and risk assessment.

### Added

- **`/ai-model-card`** — Generate AI model cards
- **`/ai-risk-assessment`** — Risk assessment per EU AI Act
- **`/ai-audit-log`** — Chronological audit log from traces

[0.29.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.28.0...v0.29.0

---

## [0.28.0] — 2026-02-28

Developer Experience metrics — DX Core 4 surveys and automated dashboards.

### Added

- **`/dx-survey`** — Adapted DX Core 4 surveys
- **`/dx-dashboard`** — Automated DX dashboard
- **`/dx-recommendations`** — Friction point analysis

[0.28.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.27.0...v0.28.0

---

## [0.27.0] — 2026-02-28

Agent observability — Execution tracing, cost estimation, and efficiency metrics.

### Added

- **`/agent-trace`** — Dashboard of agent executions
- **`/agent-cost`** — Cost estimation per agent
- **`/agent-efficiency`** — Efficiency analysis

[0.27.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.26.0...v0.27.0

---

## [0.26.0] — 2026-02-28

Predictive analytics and flow metrics — Sprint forecasting with Monte Carlo simulation.

### Added

- **`/sprint-forecast`** — Predict sprint completion
- **`/flow-metrics`** — Value stream dashboard
- **`/velocity-trend`** — Velocity analysis

[0.26.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.25.0...v0.26.0

---

## [0.25.0] — 2026-02-28

Security hardening and community patterns — SAST audit, dependency scanning, and SBOM generation.

### Added

- **`/security-audit`** — SAST analysis against OWASP Top 10
- **`/dependencies-audit`** — Vulnerability scanning
- **`/sbom-generate`** — Generate SBOM
- **`/credential-scan`** — Scan git history for leaked credentials
- **`/epic-plan`** — Multi-sprint epic planning
- **`/worktree-setup`** — Automate git worktree creation

### Changed

- Command count: 96 → 102 (+6 security commands)

[0.25.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.24.0...v0.25.0

---

## [0.24.0] — 2026-02-28

Permissions and CI/CD hardening — Plan-gate hook and CI validation steps.

### Added

- **`/validate-filesize`** — Check file size compliance
- **`/validate-schema`** — Validate JSON schemas

### Changed

- Command count: 94 → 96 (+2 validation commands)

[0.24.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.23.0...v0.24.0

---

## [0.23.0] — 2026-02-28

Automated code review — Pre-commit review hook with SHA256 cache.

### Added

- **`/review-cache-stats`** — Show review cache statistics
- **`/review-cache-clear`** — Clear review cache

### Changed

- Command count: 92 → 94 (+2 review commands)

[0.23.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.22.0...v0.23.0

---

## [0.22.0] — 2026-02-28

SDD workflow enhanced with Agent Teams Lite patterns.

### Added

- **`/spec-explore`** — Pre-spec exploration
- **`/spec-design`** — Technical design phase
- **`/spec-verify`** — Spec compliance matrix

### Changed

- Command count: 89 → 92 (+3 SDD commands)

[0.22.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.21.0...v0.22.0

---

## [0.21.0] — 2026-02-28

Persistent memory system inspired by Engram — JSONL-based memory with deduplication.

### Added

- **`/memory-save`** — Save memory with topic
- **`/memory-search`** — Search memory store
- **`/memory-context`** — Load context from memory

### Changed

- Command count: 86 → 89 (+3 memory commands)

[0.21.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.1...v0.21.0

---

## [0.20.1] — 2026-02-27

Fix developer_type format — Revert to hyphen format.

[0.20.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.0...v0.20.1

---

## [0.20.0] — 2026-02-27

Context optimization and 150-line discipline enforcement.

### Changed

- 9 skills refactored with progressive disclosure
- 5 agents refactored with companion domain files
- CLAUDE.md compacted from 195 → 130 lines

[0.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.19.0...v0.20.0

---

## [0.19.0] — 2026-02-27

Governance hardening — Scope guard hook and parallel session serialization rule.

### Added

- **Scope Guard Hook** for scope creep detection

### Changed

- **`/context-load`** expanded with ADR loading

[0.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.18.0...v0.19.0

---

## [0.18.0] — 2026-02-27

Multi-agent coordination — Agent-notes system, TDD gate hook, and ADR support.

### Added

- **`/security-review`** — Pre-implementation security review
- **`/adr-create`** — Create Architecture Decision Records
- **`/agent-notes-archive`** — Archive completed agent-notes

### Changed

- SDD skill workflow expanded with security review and TDD gate

[0.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.17.0...v0.18.0

---

## [0.17.0] — 2026-02-27

Advanced agent capabilities and programmatic hooks system.

### Changed

- 23 agents upgraded with advanced frontmatter
- 11 skills updated with context and agent fields
- 7 programmatic hooks added via settings.json

[0.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.16.0...v0.17.0

---

## [0.16.0] — 2026-02-27

Intelligent memory system — Path-specific auto-loading and auto memory.

### Added

- **`/memory-sync`** — Consolidate session insights
- **`scripts/setup-memory.sh`** — Initialize memory structure

### Changed

- 21 language files and 3 domain files now have path-specific rules

[0.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.1...v0.16.0

---

## [0.15.1] — 2026-02-27

Auto-compact post-command — Prevent context saturation.

### Changed

- Auto-compact protocol enforced after every command
- 7 commands freed from context-ux-feedback dependency

[0.15.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.0...v0.15.1

---

## [0.15.0] — 2026-02-27

Command naming fix — All commands renamed from colon to hyphen notation.

### Fixed

- All 106 unique command references renamed across 164 files

[0.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.1...v0.15.0

---

## [0.14.1] — 2026-02-27

Context optimization — Auto-loaded baseline reduced by 79%.

### Changed

- 10 domain rules moved to on-demand loading
- `/help` rewritten with separate setup and catalog modes

[0.14.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.0...v0.14.1

---

## [0.14.0] — 2026-02-27

Session persistence — Save/load rituals for persistent "second brain".

### Added

- **`/session-save`** — Capture decisions before clearing
- **`decision-log.md`** — Private cumulative decision register

### Changed

- **`/context-load`** rewritten to load big picture

[0.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.2...v0.14.0

---

## [0.13.2] — 2026-02-27

Fix silent failures — Heavy commands now explicitly delegate to subagents.

### Fixed

- **`/project-audit`** silent failure fixed with subagent delegation

[0.13.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.1...v0.13.2

---

## [0.13.1] — 2026-02-27

Anti-improvisation — Commands strictly execute only what their spec defines.

### Changed

- **`/help`** rewritten with explicit stack detection

[0.13.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.0...v0.13.1

---

## [0.13.0] — 2026-02-27

Context health and operational resilience — Proactive context management.

### Added

- **Context health rule** with output-first pattern and compaction suggestions

### Changed

- Auto-loaded context reduced: 2,109 → 899 lines

[0.13.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.12.0...v0.13.0

---

## [0.12.0] — 2026-02-27

Context optimization — 58% reduction in auto-loaded context.

### Changed

- 8 rules moved from auto-load to on-demand
- Auto-loaded context reduced from 2,109 → 882 lines

[0.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.0...v0.12.0

---

## [0.11.0] — 2026-02-27

UX Feedback Standards — Consistent visual feedback for all commands.

### Added

- **UX Feedback rule** with mandatory standards for all commands

### Changed

- 6 core commands updated with UX feedback pattern

[0.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.10.0...v0.11.0

---

## [0.10.0] — 2026-02-27

Infrastructure and tooling — GitHub Actions and MCP migration guide.

### Added

- **GitHub Actions** PR auto-labeling workflow
- **MCP migration guide** for azdevops-queries functions

[0.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.9.0...v0.10.0

---

## [0.9.0] — 2026-02-27

Messaging & Voice Inbox — WhatsApp, Nextcloud Talk, and voice transcription.

### Added

- **`/notify-whatsapp`** — Send WhatsApp notifications
- **`/whatsapp-search`** — Search WhatsApp messages
- **`/notify-nctalk`** — Send Nextcloud Talk notifications
- **`/nctalk-search`** — Search Nextcloud Talk messages
- **`/inbox-check`** — Check and process new messages
- **`/inbox-start`** — Start background inbox monitoring

### Changed

- Command count: 75 → 81 (+6 messaging commands)
- Skills count: 12 → 13 (+voice-inbox)

[0.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.8.0...v0.9.0

---

## [0.8.0] — 2026-02-27

DevOps Extended — Azure DevOps Wiki, Test Plans, and security alerts.

### Added

- **`/wiki-publish`** — Publish to Azure DevOps Wiki
- **`/wiki-sync`** — Bidirectional wiki sync
- **`/testplan-status`** — Test Plans dashboard
- **`/testplan-results`** — Detailed test run results
- **`/security-alerts`** — Security alerts from Azure DevOps

### Changed

- Command count: 70 → 75 (+5 DevOps Extended commands)

[0.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.7.0...v0.8.0

---

## [0.7.0] — 2026-02-27

Project Onboarding Pipeline — 5-phase automated workflow.

### Added

- **`/project-audit`** — Phase 1: deep project audit
- **`/project-release-plan`** — Phase 2: prioritized release plan
- **`/project-assign`** — Phase 3: distribute work across team
- **`/project-roadmap`** — Phase 4: visual roadmap
- **`/project-kickoff`** — Phase 5: compile and notify

### Changed

- Command count: 65 → 70 (+5 onboarding commands)

[0.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.6.0...v0.7.0

---

## [0.6.0] — 2026-02-27

Legacy assessment and release notes — Backlog capture from unstructured sources.

### Added

- **`/legacy-assess`** — Legacy application assessment
- **`/backlog-capture`** — Create PBIs from unstructured input
- **`/sprint-release-notes`** — Auto-generate release notes

### Changed

- Command count: 62 → 65 (+3 legacy & capture commands)

[0.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...v0.6.0

---

## [0.5.0] — 2026-02-27

Governance foundations — Technical debt tracking and DORA metrics.

### Added

- **`/debt-track`** — Technical debt register
- **`/kpi-dora`** — DORA metrics dashboard
- **`/dependency-map`** — Cross-team/PBI dependency mapping
- **`/retro-actions`** — Retrospective action tracking
- **`/risk-log`** — Risk register

### Changed

- Command count: 57 → 62 (+5 governance commands)

[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0

---

## [0.4.0] — 2026-02-27

Connectors ecosystem and Azure DevOps MCP optimization.

### Added

- **Connector integrations** (12 commands)
- **Azure Pipelines** (5 commands)
- **Azure Repos management** (6 commands)

### Changed

- Command count: 46 → 57 (+11 new commands)
- Skills count: 11 → 12 (+azure-pipelines)

[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0

---

## [0.3.0] — 2026-02-26

Multi-language support, multi-environment, and infrastructure as code.

### Added

- **16 Language Packs** with conventions, rules, and agents
- **12 new developer agents** for different languages
- **7 new infrastructure commands**
- **File size governance** (max 150 lines per file)

### Changed

- Command count: 24 → 46
- Skills count: 11 → 23
- Agents count: 8 → 35

[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion.

### Added

- **Product Discovery workflow** (`/pbi-jtbd`, `/pbi-prd`)
- **Quality commands** (`/pr-review`, `/context-load`, `/changelog-update`, `/evaluate-repo`)
- **`product-discovery` skill** with JTBD and PRD templates
- **`test-runner` agent** for post-commit testing

### Changed

- Command count: 19 → 24 (+6)
- Skills count: 7 → 8
- Agents count: 9 → 11

[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

### Added

- **Core workspace** with CLAUDE.md and setup guide
- **Sprint management** commands (4)
- **Reporting commands** (6)
- **PBI decomposition commands** (4)
- **Spec-Driven Development** with skills and agents
- **Test project** (sala-reservas)
- **Test suite** (96 tests)
- **Documentation** with methodology

[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.0.0...v0.1.0
