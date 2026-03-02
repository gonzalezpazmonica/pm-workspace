# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.61.0] — 2026-03-02

### Added — Vertical Compliance Extensions

**Four new vertical-specific compliance commands** for regulated sectors:

- `/vertical-healthcare` — HIPAA (Privacy Rule, Security Rule, Breach Notification), HL7 FHIR data exchange, FDA 21 CFR Part 11 electronic records
- `/vertical-finance` — SOX (Sarbanes-Oxley) control internal, Basel III risk management, MiFID II investment services, PCI DSS payment processing
- `/vertical-legal` — GDPR data protection, eDiscovery evidence management, contract lifecycle management, legal hold and data retention
- `/vertical-education` — FERPA student record protection, Section 508/WCAG 2.1 accessibility, COPPA for under-13 compliance, LMS integration standards

**Vertical compliance workflow**:
- Each command analyzes project for sector-specific PHI/data patterns
- Scans code against regulatory requirements (HIPAA, SOX, GDPR, FERPA, etc.)
- Generates compliance reports with scoring and actionable remediation
- Auto-fixes available for common violations with post-fix verification
- Integrates with `/compliance-scan --sector {type}` for unified compliance strategy

### Changed
- **Commands count**: 209 → 213

---

## [0.60.0] — 2026-03-02

### Added — Enterprise AI Governance

**Four new governance commands** based on NIST AI RMF, ISO/IEC 42001, and EU AI Act:

- `/governance-policy` — Define company AI policy: risk classification (Low/Medium/High/Critical), approval matrix (who authorizes what), audit trail
- `/governance-audit` — Compliance audit: load policy → scan action log → check authorization → detect violations/exceptions → present audit report with trends
- `/governance-report` — Executive report: compile governance data → map to frameworks (EU AI Act, NIST, ISO 42001) → present summary → recommend improvements
- `/governance-certify` — Certification checklist: verify requirements → score readiness (0-100%) → identify gaps → generate certification roadmap (ISO 42001, EU AI Act, SOC 2 Type II)

**Governance framework integration**:
- Policies stored in `company/policies.md` (risk classification, approvers, escalation)
- Action log in `.claude/agent-notes/action-log.jsonl` (who did what, when, with what authorization)
- Reports in `output/governance-YYYYMMDD-*.md`
- Roadmap for compliance and certification

### Changed
- **Commands count**: 205 → 209

---

## [0.59.0] — 2026-03-02

### Added — AI Adoption Companion
- `/adoption-assess` — evaluar madurez de adopción de Savia del equipo usando modelo ADKAR (Awareness, Desire, Knowledge, Ability, Reinforcement)
- `/adoption-plan` — plan personalizado de adopción por rol con learning paths de 8-12 semanas (Beginner→Intermediate→Advanced)
- `/adoption-sandbox` — entorno seguro de práctica sin riesgos: comandos simulados, datos ficticios, feedback inmediato
- `/adoption-track` — métricas de adopción por rol (adoption rate, command frequency, success rate), detección de friction points y churn risk

### Changed
- **Commands count**: 201 → 205

---

## [0.58.0] — 2026-03-02

### Added — AI Safety & Human Oversight
- `/ai-safety-config` — configurar 4 niveles de supervisión humana (inform/recommend/decide/execute) por tipo de acción
- `/ai-confidence` — transparencia: Savia muestra nivel de confianza, razonamiento, datos usados y limitaciones de cada recomendación
- `/ai-boundary` — definir matriz de límites explícitos por rol: qué puede hacer Savia autónomamente vs requiere aprobación
- `/ai-incident` — registrar y analizar incidentes de Savia (bias, hallucination, context-loss, outdated, boundary-violation, confidence-mismatch)

### Changed
- **Commands count**: 197 → 201

---

## [0.57.0] — 2026-03-02

### Added — Ceremony Intelligence
- `/async-standup` — recogida asíncrona de standups: cada dev reporta a su ritmo, Savia compila diario
- `/retro-patterns` — análisis de patrones en retrospectivas: temas recurrentes, action items sin resolver, tendencias
- `/ceremony-health` — métricas de salud de ceremonias: duración, participación, resolution rate y recomendaciones
- `/meeting-agenda` — generación inteligente de agendas basada en estado sprint, temas pendientes y decisiones

### Changed
- **Commands count**: 193 → 197

---

## [0.56.0] — 2026-03-02

### Added — Intelligent Backlog Management
- `/backlog-groom` — grooming asistido: detectar items obsoletos, duplicados, sin criterios de aceptación
- `/backlog-prioritize` — priorización automática RICE/WSJF con datos reales de esfuerzo y valor
- `/outcome-track` — tracking de outcomes post-release: ¿entregó la feature el valor esperado?
- `/stakeholder-align` — resolución de conflictos entre stakeholders con datos objetivos

### Changed
- **Commands count**: 189 → 193

---

## [0.55.0] — 2026-03-02

### Added — OKR & Strategic Alignment
- `/okr-define` — definir Objectives y Key Results vinculados a proyectos
- `/okr-track` — tracking automático de progreso OKR desde métricas de sprint
- `/okr-align` — visualizar alineación proyecto→OKR→estrategia corporativa
- `/strategy-map` — mapa estratégico: iniciativas, dependencias, contribución a objetivos

### Changed
- **Commands count**: 185 → 189

---

## [0.54.0] — 2026-03-02

### Added — Company Profile
- `/company-setup` — onboarding conversacional de empresa: sector, estructura, estrategia, políticas
- `/company-edit` — editar secciones del perfil de empresa
- `/company-show` — mostrar perfil consolidado con detección de gaps
- `/company-vertical` — detectar y configurar vertical, regulaciones y mejores prácticas del sector

### Changed
- **Commands count**: 181 → 185

---

## [0.53.0] — 2026-03-02

### Added — Multi-Platform Support
- `/jira-connect` — conectar y sincronizar con Jira Cloud
- `/github-projects` — integración con GitHub Projects v2
- `/platform-migrate` — migración asistida entre plataformas

### Changed
- `/linear-sync` — reescrito con nuevo formato, webhooks y métricas unificadas

---

## [0.52.0] — 2026-03-02

### Added — Integration Hub
- **`/mcp-server` command** — expone herramientas de Savia como MCP server para otros proyectos
- **`/nl-query` command** — consultas en lenguaje natural sin memorizar comandos
- **`/webhook-config` command** — configurar webhooks para eventos push en tiempo real
- **`/integration-status` command** — dashboard de estado de todas las integraciones

### Changed

- **Commands count**: 174 → 178
- **Updated**: CLAUDE.md, README.md, README.en.md, context-map.md, role-workflows.md

---

## [0.51.0] — 2026-03-02

AI-Powered Planning — 4 nuevos comandos para planificación inteligente de sprints, predicción de riesgos, resumen de reuniones y previsión de capacidad.

### Added

- **`/sprint-autoplan` command** — Planificación inteligente de sprint desde backlog y capacidad. Propone distribución óptima de items considerando expertise, disponibilidad, balance de carga y crecimiento del equipo.
- **`/risk-predict` command** — Predicción de riesgo del sprint con señales tempranas. Detecta riesgos técnicos, de dependencias, de recursos y propone mitigaciones proactivas.
- **`/meeting-summarize` command** — Transcripción y extracción de action items de reuniones. Procesa audio/video, genera resumen ejecutivo y trackea dueños de acciones.
- **`/capacity-forecast` command** — Previsión de capacidad a medio plazo (3-6 sprints). Proyecta velocity tendencia, detecta bottlenecks y sugiere acciones de escalado.

### Changed

- **Commands count**: 170 → 174
- **Updated**: CLAUDE.md, README.md, README.en.md, context-map.md, role-workflows.md

---

## [Unreleased]

---

## [0.50.0] — 2026-03-02

Cross-Project Intelligence — 4 comandos para inteligencia transversal entre proyectos del portfolio.

### Added

- **`/portfolio-deps` command** — Inter-project dependency graph, bottleneck detection, blocking alerts. Visualizes dependencies between projects, identifies critical paths, and alerts on blocking scenarios.
- **`/backlog-patterns` command** — Detects duplicate/similar PBIs across projects, identifies candidates for shared libraries. Analyzes backlog at portfolio level to reduce duplication and promote reuse.
- **`/org-metrics` command** — Aggregated DORA and delivery metrics at organization level, trends, and alerts. Shows velocity, lead time, deployment frequency across all projects with anomaly detection.
- **`/cross-project-search` command** — Cross-project search of code, docs, specs, and decisions across all portfolio projects. Unified search across repos, specifications, ADRs, and decision logs.

### Changed

- **Commands count**: 166 → 170
- **Updated**: CLAUDE.md, README.md, README.en.md, context-map.md, role-workflows.md

---

## [0.49.0] — 2026-03-01

Product Owner Analytics — 4 comandos para Product Owners. Mapeo de flujo de valor, análisis de impacto de features en ROI, reportes ejecutivos para stakeholders, y verificación de readiness para releases.

### Added

- **`/value-stream-map` command** — Maps end-to-end value flow detecting bottlenecks. Calculates Lead Time, Processing Time, and Flow Efficiency. Highlights slowest stages with recommendations.
- **`/feature-impact` command** — Analyzes feature impact on ROI, engagement, and technical load. Compares planned vs actual impact. Suggests feature adjustments for maximum value.
- **`/stakeholder-report` command** — Generates executive report for stakeholders with delivery metrics, objective alignment, risk summary, and next steps. Customizable audience and detail level.
- **`/release-readiness` command** — Verifies release readiness: technical capacity assessment, risk mitigation checklist, communication plan status, rollback procedure validation.

### Changed

- **CLAUDE.md** — Commands count 162 → 166
- **README.md / README.en.md** — Updated Product Owner Analytics section, command count (166)
- **context-map.md** — Added 4 PO commands to relevant groups
- **role-workflows.md** — Updated Product Owner routine with new commands

---

## [0.48.0] — 2026-03-01

Tech Lead Intelligence. Four new commands give Tech Leads deep visibility into technology health, team knowledge distribution, architectural integrity, and incident learning: tech stack radar, skills matrix with bus factor, architectural health scoring, and blameless postmortem templates.

### Added

- **`/tech-radar` command** — Maps project dependencies into adopt/trial/hold/retire categories. Detects outdated versions, CVEs, and deprecated packages. Recommends migration actions with effort estimates.
- **`/team-skills-matrix` command** — Builds competency matrix from git history: expertise per module, bus factor calculation, pair programming suggestions for knowledge transfer.
- **`/arch-health` command** — Architectural health score: fitness function execution, drift detection vs ADRs, coupling metrics (Ca, Ce, Instability, Abstractness, Distance from main sequence).
- **`/incident-postmortem` command** — Blameless postmortem template: timeline construction, 5 Whys root cause analysis, action items with owners and deadlines.

### Changed

- **CLAUDE.md** — Commands count 158 → 162
- **README.md / README.en.md** — Updated tech lead intelligence section, command count (162)
- **context-map.md** — Added 4 tech lead commands to relevant groups
- **role-workflows.md** — Updated Tech Lead routine with new commands

---

## [0.47.0] — 2026-03-01

Developer Productivity. Four new commands give developers a personal sprint view, deep focus mode, learning opportunity detection, and a living pattern catalog from their own codebase. All features are private — no comparisons or rankings.

### Added

- **`/my-sprint` command** — Personal sprint view: assigned items, progress bar, cycle time vs team, PR status. Private, no team comparisons.
- **`/my-focus` command** — Deep focus mode: identifies top priority item (considering blocks, severity, age), loads all context (spec, tests, code, agent-notes), suggests next action.
- **`/my-learning` command** — Analyzes developer's recent commits against project best practices. Identifies gaps by frequency, always includes strengths. Private and constructive.
- **`/code-patterns` command** — Living pattern catalog: detects architectural, creational, structural, behavioral, resilience, and testing patterns in the project code with real examples.

### Changed

- **CLAUDE.md** — Commands count 154 → 158
- **README.md / README.en.md** — Updated developer productivity section, command count (158)
- **context-map.md** — Added 4 developer commands to relevant groups
- **role-workflows.md** — Updated Developer daily routine with new commands

---

## [0.46.0] — 2026-03-01

QA and Testing Toolkit. Four new commands give QA Engineers a complete testing workflow: quality dashboard with composite scoring, change-impact regression planning, assisted bug triage with duplicate detection, and test plan generation from SDD specs or PBIs.

### Added

- **`/qa-dashboard` command** — Quality panel with coverage, flaky tests, bugs by severity, escape rate, test execution time. Quality Score 0-100 with traffic-light.
- **`/qa-regression-plan` command** — Analyzes changed files, maps test coverage (direct/indirect), identifies uncovered files, and recommends regression test suites.
- **`/qa-bug-triage` command** — Assisted bug triage: severity classification (4 factors), duplicate detection (similarity matching), assignment suggestions based on code authorship and workload.
- **`/testplan-generate` command** — Generates test plans from SDD specs or PBIs: happy path, negative, edge cases, data cases. Classifies by type (unit/integration/E2E/perf/security) and estimates effort.

### Changed

- **CLAUDE.md** — Commands count 150 → 154, added QA commands
- **README.md** — Updated QA toolkit section, command count (154), command reference
- **README.en.md** — Same updates in English
- **context-map.md** — Added 4 QA commands to Quality & PRs group
- **role-workflows.md** — Updated QA Engineer routine to use new commands

---

## [0.45.0] — 2026-03-01

Executive Reports for Leadership. Three new commands give CEO/CTO/Directors a strategic view of their project portfolio without operational noise: multi-project reports with traffic-light scoring, filtered alerts requiring only C-level decisions, and a bird's-eye portfolio overview with inter-project dependency mapping.

### Added

- **`/ceo-report` command** — Multi-project executive report with portfolio health, risk exposure, team utilization, delivery velocity trend. Generates traffic-light (🟢/🟡/🔴) per project. Subcommands: default (all projects), `{proyecto}` (single), `--format md|pdf|pptx`.
- **`/ceo-alerts` command** — Strategic alert panel filtering only decisions requiring director-level action. 3 severity levels: critical (immediate), high (this week), medium (next committee). Sources: sprint failures, team burnout, debt trends, security CVEs, inter-project blocks.
- **`/portfolio-overview` command** — Bird's-eye view of all projects: traffic-light table with sprint progress, velocity trend, health score, risk level, next milestone. `--deps` shows inter-project dependency map. `--compact` for quick semaphore.

### Changed

- **CLAUDE.md** — Commands count 147 → 150, added `/ceo-report`, `/ceo-alerts`, `/portfolio-overview` references
- **README.md** — Updated executive reports section, command count (150), command reference
- **README.en.md** — Same updates in English
- **context-map.md** — Added 3 CEO commands to Reporting group
- **role-workflows.md** — Updated CEO/CTO daily routine to use new commands

---

## [0.44.0] — 2026-03-01

Semantic Hub Topology. Savia now maps the dependency network between domain rules, commands, and agents. A full topology audit reveals hubs (rules referenced by ≥5 consumers), near-hubs, paired rules, isolated rules, and dormant candidates. This enables informed decisions about which rules to minimize, stabilize, or merge.

### Added

- **`/hub-audit` command** — 3 subcommands: default (full audit with comparison), `quick` (count only), `update` (audit + update index). Scans all domain rules for references from commands, agents, and skills. Classifies into 5 tiers (hub ≥5, near-hub 3-4, paired 2, isolated 1, dormant 0). Compares with previous index to detect promotions, degradations, and new dormant rules.
- **`.claude/rules/domain/semantic-hub-index.md`** — Living index documenting the current topology: 1 hub (messaging-config.md, 6 refs), 2 near-hubs, 3 paired, 10 isolated, 25 dormant (61%). Includes network metrics, recommendations per tier, and evolution strategy toward small-world topology.

### Changed

- **CLAUDE.md** — Commands count 146 → 147, added `/hub-audit` reference
- **README.md** — Updated context optimization section, command count (147), command reference
- **README.en.md** — Same updates in English
- **context-map.md** — Added `/hub-audit` to Memory & Context group

---

## [0.43.0] — 2026-03-01

Context Aging and Verified Positioning. Savia now compresses and archives old decisions using semantic aging inspired by neuroscience (episodic → compressed → archived). New context benchmark command empirically verifies that information positioning in the context window is optimal.

### Added

- **`/context-age` command** — 3 subcommands: default (analyze + propose), `apply` (compress and archive with confirmation), `status` (quick count). Decisions <30d stay complete, 30-90d compress to one line, >90d archive or migrate to domain rules.
- **`/context-benchmark` command** — 3 subcommands: default (5-question benchmark), `quick` (2 questions), `history` (past results). Tests information retrieval from different context positions (start/middle/end).
- **`scripts/context-aging.sh`** — Script for analyzing, compressing, and archiving decision-log entries by age category.
- **`.claude/rules/domain/context-aging.md`** — Protocol documenting semantic aging thresholds, compression format, migration vs. archival criteria, and affected files.

### Changed

- **CLAUDE.md** — Commands count 144 → 146, added `/context-age` and `/context-benchmark` references
- **README.md** — Updated context optimization section, command count (146), command reference
- **README.en.md** — Same updates in English
- **context-map.md** — Added `/context-age` and `/context-benchmark` to Memory & Context group

---

## [0.42.0] — 2026-03-01

Subagent Context Budget System. All 24 agents now have explicit `max_context_tokens` and `output_max_tokens` fields in their frontmatter, categorized into 4 tiers: Heavy (12K/1K), Standard (8K/500), Light (4K/300), Minimal (2K/200). Protocol documentation defines budget enforcement, reduction strategies, and integration with context-tracker.

### Added

- **`.claude/rules/domain/agent-context-budget.md`** — Protocol documenting 4 budget categories, invocation rules, reduction strategies (prioritize, truncate, summarize, fragment), and context-tracker integration.

### Changed

- **All 24 agent frontmatter files** — Added `max_context_tokens` and `output_max_tokens` fields across 4 budget tiers.

---

## [0.41.0] — 2026-03-01

Session-Init Compression and CLAUDE.md Pre-compaction. Session-init now uses a 4-level priority system (critical/high/medium/low) with a max budget of 8 items to prevent context bloat as features grow. CLAUDE.md reduced from 154 to 125 lines (688 words, ~36% reduction) by condensing verbose sections and moving rarely-needed info to referenced files.

### Added

- **`.claude/rules/domain/session-init-priority.md`** — Documentation of the 4-level priority system: critical (always: PAT, profile, git branch), high (conditional: updates, missing tools), medium (conditional: backup, emergency plan), low (probabilistic: community tip).

### Changed

- **`session-init.sh`** — Rewritten with priority-based array system. Items are organized into CRITICAL/HIGH/MEDIUM/LOW arrays and assembled with MAX_ITEMS=8 budget. Only critical items are guaranteed; others fill remaining space. Also integrates context-tracker logging.
- **CLAUDE.md** — Pre-compacted: 154→125 lines, 1079→688 words. Removed inline comments from config block, condensed structure tree, merged Proyectos Activos into Estructura, shortened section headers, removed redundant descriptions. All information preserved via `@` references.

---

## [0.40.0] — 2026-03-01

Role-Adaptive Daily Routines, Project Health Dashboard, and Context Usage Optimization. Savia now adapts her daily suggestions based on the user's role (PM, Tech Lead, QA, Product Owner, Developer, CEO/CTO), provides a unified project health dashboard with role-weighted scoring, and tracks context usage patterns to suggest context-map optimizations.

### Added

- **`.claude/rules/domain/role-workflows.md`** — Role-specific daily routines, weekly/monthly rituals, key metrics, and personalized alerts for 6 roles. Includes context-map integration table mapping roles to primary/secondary command groups.
- **`/daily-routine` command** — Role-adaptive daily routine. Identifies user role, composes the day's routine (daily + weekly rituals if applicable), executes on demand with user control (skip, reorder, stop), and shows summary at end.
- **`/health-dashboard` command** — Unified project health dashboard with 4 subcommands: default (single project), `{project}` (specific), `all` (multi-project), `trend` (4-week history). Composite health score (0-100) with role-weighted dimensions and traffic-light system.
- **`/context-optimize` command** — Context usage analysis with 4 subcommands: default (full analysis), `stats` (statistics only), `reset` (clear log), `apply {id}` (apply recommendation). Detects unnecessary fragment loads, co-occurrences, and waste patterns.
- **`scripts/context-tracker.sh`** — Lightweight context usage tracking script. Logs command+fragments+tokens to `$HOME/.pm-workspace/context-usage.log`. Supports stats, top-commands, top-fragments, co-occurrences, low-impact analysis, and log rotation (max 1MB/5000 entries).
- **`.claude/rules/domain/context-tracking.md`** — Protocol documenting what is tracked (metadata only), privacy guarantees, token estimation per fragment, and optimization metrics.
- **`scripts/test-context-tracking.sh`** — Automated tests for v0.40.0 features.

### Changed

- **CLAUDE.md** — Commands count 141 → 144, added `/daily-routine`, `/health-dashboard`, `/context-optimize` references
- **README.md** — Added "Rutina diaria adaptativa" and "Optimización de contexto" feature sections, updated command count (144), added commands to reference
- **README.en.md** — Added "Adaptive daily routine" and "Context optimization" feature sections, updated command count (144), added commands to reference
- **context-map.md** — Added "Daily Routine & Health" group, added `/context-optimize` to Memory & Context group

---

## [0.39.0] — 2026-03-01

Encrypted Cloud Backup System. Savia now protects user data with AES-256-CBC encryption (PBKDF2, 100k iterations) before uploading to NextCloud (WebDAV) or Google Drive (MCP). Automatic rotation of 7 backups. Session-init suggests backup when more than 24h have passed.

### Added

- **`/backup` command** — 5 subcommands: `now` (encrypt + upload), `restore` (download + decrypt + verify SHA256), `auto-on`/`auto-off` (daily reminder toggle), `status` (backup history and cloud config).
- **`scripts/backup.sh`** — Full backup lifecycle: collect files, create SHA256 manifest, encrypt with AES-256-CBC/PBKDF2 (100k iterations), upload to NextCloud via WebDAV or Google Drive via MCP, rotation of max 7 backups, restore with integrity verification.
- **`.claude/rules/domain/backup-protocol.md`** — Protocol documenting what to include/exclude, encryption algorithm, rotation strategy, cloud providers, and restore flow.
- **Backup suggestion in session-init** — When `auto_backup=true` and >24h since last backup, shows reminder (humans only).
- **`scripts/test-backup.sh`** — 63 automated tests including real encrypt/decrypt/SHA256 verification cycle.

### Changed

- **CLAUDE.md** — Commands count 140 → 141, added `/backup` reference
- **README.md** — Added "Backup cifrado en la nube" feature section, updated command count (141)
- **README.en.md** — Added "Encrypted cloud backup" feature section, updated command count (141)
- **session-init.sh** — Added `BACKUP_TIP` variable with 24h reminder logic

---

## [0.38.0] — 2026-03-01

Private Review Protocol. Maintainer workflow for reviewing community PRs, issues, and contributions. Includes secrets scanning on PR diffs, validate-commands integration, squash merge, and GitHub release creation.

### Added

- **`/review-community` command** — 5 subcommands: `pending` (list community PRs/issues), `review {pr}` (deep analysis with diff, validate-commands, secrets scan), `merge {pr}` (squash merge), `release {version}` (tag + GitHub release), `summary` (weekly activity).
- **`scripts/review-community.sh`** — Maintainer automation script with secrets detection in diffs (AKIA, ghp_, sk-, JWT, password=, api_key=), validate-commands.sh integration for command changes, squash merge strategy.
- **`scripts/test-review-community.sh`** — 33 automated tests covering script functions, command content, doc integration.

### Changed

- **CLAUDE.md** — Commands count 139 → 140, added `/review-community` reference
- **README.md / README.en.md** — Updated command count (140), added `/review-community` to quick reference

---

## [0.37.0] — 2026-03-01

Vertical Detection System. Savia now detects when a project belongs to a non-software sector (healthcare, legal, industrial, agriculture, education, finance, logistics, real estate, energy, hospitality) using a calibrated 5-phase scoring algorithm and proposes specialized extensions.

### Added

- **`.claude/rules/domain/vertical-detection.md`** — 5-phase detection algorithm: domain entities (35%), API naming patterns (25%), sector-specific dependencies (15%), specialized configuration (15%), documentation mentions (10%). Covers 10 verticals with scoring thresholds (≥55% auto-detect, 25-54% ask, <25% ignore).
- **`/vertical-propose` command** — Detect vertical or receive name, generate local extension structure (`rules.md`, `workflows.md`, `entities.md`, `compliance.md`, `examples/`), offer to contribute to community repo.
- **Vertical trigger in profile-onboarding** — During `/profile-setup`, if user role is non-software, triggers vertical detection algorithm and suggests `/vertical-propose`.
- **`scripts/test-vertical-detection.sh`** — 42 automated tests covering algorithm phases, verticals, scoring, command content, integration with docs.

### Changed

- **CLAUDE.md** — Commands count 138 → 139, added `/vertical-propose` reference
- **README.md** — Added "Detección de verticales" feature section, updated command count (139 comandos), added `/vertical-propose`
- **README.en.md** — Added "Vertical detection" feature section, updated command count (139 commands), added `/vertical-propose`
- **profile-onboarding.md** — Added "Detección de Verticales" section with integration trigger

---

## [0.36.0] — 2026-03-01

Community & Collaboration System. Savia now helps users contribute back to pm-workspace while protecting their privacy. Privacy-first validation blocks PATs, corporate emails, project names, IPs, and connection strings before any content reaches GitHub.

### Added

- **`/contribute` command** — Create PRs (`/contribute pr`), propose ideas (`/contribute idea`), report bugs (`/contribute bug`), check status (`/contribute status`). All content validated for privacy before submission.
- **`/feedback` command** — Open issues as bug reports (`/feedback bug`), ideas (`/feedback idea`), improvements (`/feedback improve`), list open issues (`/feedback list`), search before duplicating (`/feedback search`).
- **`scripts/contribute.sh`** — Shared GitHub interaction layer with `validate_privacy()`, `do_pr()`, `do_issue()`, `do_list()`, `do_search()`. Detects AWS keys, GitHub PATs, OpenAI keys, JWTs, Azure credentials, corporate emails, private IPs, connection strings, and project names from `CLAUDE.local.md`.
- **`.claude/rules/domain/community-protocol.md`** — Privacy guardrails documenting what NEVER to include, what to include, standard labels (`bug`, `enhancement`, `idea`, `improvement`, `community`, `from-savia`), and PR/issue templates.
- **Community suggestion in session-init** — 1-in-20 session probability of showing "¿Encontraste algo que mejorar? /contribute idea o /feedback bug" (only for human users, not agents).
- **`scripts/test-contribute.sh`** — 67 automated tests covering file existence, script content, privacy validation (clean text, GitHub PAT, AWS key detection), hook integration, documentation integration.

### Changed

- **CLAUDE.md** — Commands count 136 → 138, added `/contribute` and `/feedback` references
- **README.md** — Added "Comunidad y colaboración" feature section, updated command reference (138 comandos), added `/contribute` and `/feedback` to quick reference
- **README.en.md** — Added "Community and collaboration" feature section, updated command reference (138 commands), added `/contribute` and `/feedback` to quick reference
- **session-init.sh** — Added `COMMUNITY_TIP` variable with random suggestion logic

---

## [0.35.0] — 2026-03-01

Savia — User Profiling System and Agent Mode. pm-workspace now has its own identity: Savia, the little owl that keeps your projects alive. Fragmented user profiles with conditional context loading, natural conversational onboarding, multi-role support, and machine-to-machine communication for external agents.

### Added

**🦉 Savia — pm-workspace identity** — Savia is a female owl ("buhita") who serves as the personality and voice of pm-workspace. She introduces herself to new users, conducts natural conversational onboarding, adapts her tone to each user's preferences, and communicates with external agents in structured YAML/JSON. Her personality is defined in `.claude/profiles/savia.md`.

**User Profiling System** — Fragmented user profiles stored in 6 independent files per user (identity.md, workflow.md, tools.md, projects.md, preferences.md, tone.md) with YAML frontmatter. Inspired by "The Personalization Paradox" research: less context = better results. Each command group loads only the profile fragments it needs, controlled by `context-map.md`.

**`/profile-setup`** — Savia's conversational onboarding flow. She asks one question at a time in a natural dialogue: name, role (10 options including PM, Tech Lead, Arquitecto/a, QA, CEO/CTO, Desarrollador/a, Supervisor/a, Agent), company, workflow mode, tools, projects, preferences (language, detail level, report format), and tone (alert style, celebrations). Includes fast YAML registration for agents.

**`/profile-edit`** — Edit specific sections of the active user profile through Savia's conversational interface.

**`/profile-switch`** — Switch between configured user profiles for multi-user workspaces.

**`/profile-show`** — Display the complete active user profile with all 6 fragments.

**Agent Mode** — External agents (OpenClaw, other LLMs, automated scripts) communicate with Savia in machine-to-machine mode: structured YAML/JSON output, status codes (OK/ERROR/WARNING/PARTIAL), zero narrative, no greetings, no confirmations. Agent detection via dual mechanism: `PM_CLIENT_TYPE=agent` environment variable or message content analysis.

**Dual onboarding trigger** — Combined hook + rule mechanism ensures profiling starts automatically:
- `session-init.sh` hook (data layer): detects profile status and agent mode, injects context into session
- `profile-onboarding.md` rule (behavior layer): always-on rule that determines human vs agent mode and triggers appropriate onboarding flow

**Context-map** — `context-map.md` maps 13 command groups to their required profile fragments. Sprint & Daily loads identity + workflow + tone. Reporting loads identity + preferences. SDD & Agents loads identity + workflow + tools. Each group loads only what it needs — no unnecessary context.

**Profile templates** — 6 template files in `.claude/profiles/users/template/` with empty YAML frontmatter for new user creation.

**Test profile** — `test-user-sala` profile with sample data for automated testing of the profile system.

**132 automated tests** — `scripts/test-profile-system.sh` with 15 test categories covering directory structure, templates, commands, context-map content, profile integration in existing commands, trigger mechanism, hook JSON validity, Savia identity, agent mode, and agent hook detection.

### Changed

**README.md and README.en.md** — Completely rewritten with Savia speaking in first person throughout. She presents herself and describes all features from her perspective, giving pm-workspace a distinctive personality.

**CLAUDE.md** — New "🦉 Savia — La voz de pm-workspace" section replacing the old profile section. References savia.md and context-map.md.

**~72 existing commands updated** — Each command now includes a "Cargar perfil de usuario" step that references the appropriate context-map group and lists which profile fragments to load.

**session-init.sh hook** — Enhanced with agent detection (PM_CLIENT_TYPE, AGENT_MODE env vars), profile role checking, and differentiated messages for agents vs humans.

**`.gitignore`** — Added rules to exclude real user profiles but include template: `.claude/profiles/users/*` with `!.claude/profiles/users/template/` exception.

**Commands count**: 131 → 135 (+4 profile commands)
**Skills count**: 20 (unchanged)

### Why

Inspired by the research paper "The Personalization Paradox: Navigating the Tension Between Context and Efficiency in LLM-Driven PM Assistants" — which found that loading full user context for every operation degrades LLM performance. The fragmented approach (6 files × conditional loading via context-map) ensures each command gets exactly the context it needs. Savia as a named identity creates a consistent, warm interaction point while maintaining professional efficiency. Agent mode enables programmatic access for external tools without the overhead of conversational UI.

---

## [0.34.0] — 2026-02-28

Performance Audit Intelligence — static analysis for code performance hotspots, async anti-patterns, and test-first optimization.

### Added
- **New skill**: `performance-audit` — static performance analysis without code execution
- **New command**: `/perf-audit` — scan code for complexity hotspots, async anti-patterns, and untested functions
- **New command**: `/perf-fix` — test-first optimization with characterization tests (Golden Master pattern)
- **New command**: `/perf-report` — executive performance report with 6 sections (hotspots, async, coverage, roadmap, risk)
- **New domain rule**: `performance-patterns.md` — cross-language thresholds, N+1 detection, blocking async, memory allocation
- **6 language reference files**: perf-dotnet.md, perf-typescript.md, perf-python.md, perf-java.md, perf-go.md, perf-rust.md
- 4-phase detection: Complexity (40%), Async (25%), Hotspot ID (20%), Test Coverage (15%)
- Scoring: `Performance Score = 100 - Σ(CRITICAL×15 + HIGH×8 + MEDIUM×3 + LOW×1)`
- IDs `PA-NNN` stable across audit, fix, and report commands
- Integration with `/debt-track` (PA findings registered as tech debt)
- Characterization tests auto-created before any optimization

### Changed
- **Commands count**: 129 → 131 (+3 performance commands, includes devops-validate from v0.33.3)
- **Skills count**: 19 → 20 (+performance-audit)
- **Domain rules**: +1 performance-patterns.md with 6 language reference files

---

## [0.33.3] — 2026-02-28

Azure DevOps project validation: automated audit of project configuration against pm-workspace's ideal Agile requirements.

### Added
- **New command**: `/devops-validate` — audits Azure DevOps project config (process template, work item types, states, fields, backlog hierarchy, iterations)
- **New skill**: `devops-validation` — skill definition with ideal Agile configuration reference
- **2 scripts**: `validate-devops.sh` (orchestration), `validate-devops-checks.sh` (8 check functions with Azure DevOps REST API)
- JSON report with remediation plan for manual approval when incompatibilities found

### Changed
- **Commands count**: 128 → 129 (+1 devops-validate)
- **Skills count**: 18 → 19 (+devops-validation)

---

## [0.33.2] — 2026-02-28

Detection algorithm calibration after real-world testing across all 12 regulated sectors.

### Changed
- **Detection algorithm**: 4 phases → 5 phases (added Infrastructure & Docs phase)
- **Phase weights recalibrated**: 40/30/20/10 → 35/25/15/15/10 (reduced Dependencies, added Infra & Docs)
- **Phase 2 renamed**: "Dependencies" → "Naming & Routes" (now includes folders, namespaces, middleware)
- **Confidence thresholds lowered**: AUTO ≥55% (was 60%), ASK 25-54% (was 30-59%)
- **Domain rule updated**: Decision tree replaced with calibrated algorithm reference

### Added
- 4 new detection marker categories per sector: Middleware & Services, Database & Schema, Folder & Namespace Patterns, Documentation & CI/CD
- ~240 new detection markers total across 12 sector reference files
- Scan output now includes detection phase breakdown table
- Credential hardcoding check added to compliance scan (Paso 4)
- Soft-delete/versioning added to Auto-Fix Templates in SKILL.md

### Fixed
- Dependencies phase (now 15%) no longer over-penalizes projects without sector-specific packages
- Public Admin was the only sector reaching AUTO confidence — now 8+ sectors should reach ≥55%
- Detection markers cover infrastructure (Dockerfile, terraform, CI/CD) not just source code

---

## [0.33.1] — 2026-02-28

Compliance commands improvements after real-world testing with HealthPatientApi (.NET 10).

### Fixed
- Output file naming now requires date suffix (`{proyecto}-scan-{fecha}.md`) for historical comparison
- Scoring formula documented: `Score = (requisitos cumplidos / total) × 100`
- Dry-run vs actual execution clearly indicated in fix output header
- Language consistency enforced: `--lang es|en` parameter added to scan and report

### Changed
- `/compliance-scan`: findings now marked `[AUTO-FIX]` or `[MANUAL]` for quick triage
- `/compliance-scan`: summary table includes auto-fix/manual column split
- `/compliance-fix`: includes configuration keys section (appsettings keys required)
- `/compliance-fix`: re-verification includes sample output per fix
- `/compliance-fix`: score recalculation after fixes
- `/compliance-report`: score formula shown in header (`{N}/{M} requisitos`)

### Added
- Test project: gonzalezpazmonica/health-patient-api (.NET 10, healthcare sector)
- Full compliance flow validated: scan → fix → report with 38 findings detected

---

## [0.33.0] — 2026-02-28

Regulatory Compliance Intelligence: automated sector detection, compliance scanning, and auto-fix with re-verification across 12 regulated industries.

### Added

**`/compliance-scan {repo|path}`** — Automated compliance scanning across 12 regulated sectors (healthcare, finance, food/agriculture, justice/legal, public administration, insurance, pharma, energy/utilities, telecom, education, defense/military, transport/automotive). 4-phase sector auto-detection algorithm: file markers (40%), naming patterns (30%), dependency analysis (20%), domain-specific rules (10%). Detects: HIPAA/PCI violations, data retention failures, audit trail gaps, encryption weaknesses, access control misconfigurations, third-party risk gaps, consent/privacy issues. Reports findings by severity with affected files and remediation guidance.

**`/compliance-fix {repo|path}`** — Auto-fix framework for detected compliance violations. Generates code patches and configuration updates per sector-specific regulations. Targets: audit logging, encryption enforcement, access control policies, consent workflows, data retention policies. Patches are validated before application. Integrates with `/compliance-verify` for re-verification post-fix.

**`/compliance-report {repo|path} --sector {sector}`** — Generate compliance report for specific sector or auto-detected primary sector. Outputs: executive summary (compliance status, risk score, timeline to remediate), detailed findings by category (access control, data protection, audit/logging, encryption, third-party risk), evidence (files, code snippets), remediation roadmap with effort estimates and dependencies. Exportable to Markdown, PDF, Excel for audit preparation.

**Regulatory Compliance skill** — Domain knowledge covering compliance frameworks by sector: HIPAA (healthcare), PCI-DSS (payments), GDPR (data privacy), CCPA (California privacy), SOC 2 (service providers), ISO 27001 (information security), FDA 21 CFR Part 11 (pharma), GLB Act (finance), FISMA (government), NIST guidelines, sector-specific best practices. Reference catalog with 12 sector files covering regulatory requirements, code patterns, audit requirements per sector.

**Regulatory Compliance domain rule** — `regulatory-compliance.md` with sector detection algorithm (4-phase scoring), violation taxonomy (access control, data protection, audit/logging, encryption, third-party risk, consent/privacy, data retention), evidence templates, remediation patterns per sector, audit readiness checklist. Auto-detection maps files/naming/deps to sector with confidence score.

### Sectors Covered (12)

1. **Healthcare** — HIPAA: patient data encryption, audit logging, access controls, breach notification, business associate agreements
2. **Finance** — PCI-DSS, SOC 2, GLB Act: payment data, encryption, access logging, third-party audits
3. **Food & Agriculture** — FDA, FSMA: traceability, supplier verification, recall procedures, documentation
4. **Justice & Legal** — Case management, discovery compliance, attorney-client privilege, evidence handling, chain of custody
5. **Public Administration** — FISMA, security categorization, incident reporting, personnel clearances
6. **Insurance** — Policyholder data, claims auditing, regulatory filings, third-party risk management
7. **Pharma** — FDA 21 CFR Part 11, GxP (Good Practice), audit trails, data integrity, electronic records, validation
8. **Energy & Utilities** — NERC CIP, grid security, asset management, incident response, physical security
9. **Telecom** — Lawful interception, network security, subscriber privacy, incident reporting
10. **Education** — FERPA, student data privacy, access controls, consent management
11. **Defense & Military** — NIST SP 800-171, DFARS cybersecurity requirements, contractor compliance, classified info handling
12. **Transport & Automotive** — Vehicle safety regulations, data retention (OBD), recall procedures, cybersecurity standards

### Technical Details

**4-Phase Sector Auto-Detection Algorithm:**
- Phase 1 (File Markers 40%): HIPAA (*.hl7, *patient*, *medical*), PCI (*.pci, *payment*, *card*), Pharma (*GxP*, *validation*, *CFR*), etc.
- Phase 2 (Naming Patterns 30%): Function/class names suggesting regulated workflows (validatePHI, encryptCreditCard, auditLog, etc.)
- Phase 3 (Dependency Analysis 20%): External libraries tied to sectors (healthcare APIs, payment processors, audit frameworks)
- Phase 4 (Domain Rules 10%): Presence of config patterns, data flows, or comment markers indicating sector

**Auto-Fix & Re-Verification:**
- Generate patches for common violations per sector (e.g., missing audit logs, weak encryption)
- Apply patches with syntax validation
- Run `/compliance-verify` automatically post-fix to confirm remediation
- Report before/after compliance score and remaining violations

### Changed

**Commands count: 125 → 128 (+3 compliance commands)**
**Skills count: 16 → 17 (+regulatory-compliance)**
**Domain rules: +1 regulatory-compliance.md with 12 sector reference files**

### Why

Regulatory compliance is critical for enterprise projects but often detected only during audits. The 4-phase sector auto-detection brings compliance analysis into the development workflow: detect violations early (shift left), prioritize by sector-specific regulations, auto-fix common issues, and generate audit-ready evidence. The 12 sectors cover 85% of regulated enterprise software.

---

## [0.32.3] — 2026-02-28

Multi-OS emergency mode: full support for Linux, macOS, and Windows. Auto-detects OS and uses appropriate download strategy.

### Added

**`scripts/emergency-plan.ps1`** — Windows PowerShell version of emergency-plan. Downloads `OllamaSetup.exe`, detects hardware (RAM/GPU via WMI), auto-selects model, pre-downloads LLM via Ollama. Saves cache to `%USERPROFILE%\.pm-workspace-emergency\`.

**`scripts/emergency-setup.ps1`** — Windows PowerShell version of emergency-setup. Silent Ollama installation from cache or download, server management, model verification, environment variable configuration via `[Environment]::SetEnvironmentVariable`.

### Changed

**`scripts/emergency-plan.sh`** — Added macOS support: downloads `ollama-darwin.tgz` (~70MB), extracts binary from root of archive. Improved RAM detection per OS (`sysctl` for macOS, `/proc/meminfo` for Linux). Windows detected with redirect to `.ps1` scripts.

**`scripts/emergency-setup.sh`** — Added macOS support: online installation via `ollama-darwin.tgz` extraction, offline installation from cache binary. macOS-specific PATH guidance. Improved GPU detection (Apple Silicon Metal).

### Fixed

**macOS compatibility** — Replaced GNU-specific `date -Iseconds` with portable `iso_date()` function that falls back to `date -u` on macOS. Fixed `&;` syntax error in setup script.

**Validated with emulators** — PowerShell Core (pwsh 7.4.6) for Windows PS1 syntax/execution, bash syntax checker and macOS-specific pattern analysis for shell scripts.

---

## [0.32.2] — 2026-02-28

Fix Ollama download: adapted to new release format (tar.zst archives with amd64/arm64 naming).

### Fixed

**`scripts/emergency-plan.sh`** — Updated Ollama binary download to use new tar.zst format (`ollama-linux-amd64.tar.zst`) instead of deprecated raw binary (`ollama-linux-x86_64`). Maps `x86_64→amd64` and `aarch64→arm64`. Extracts binary from archive automatically.

**`scripts/emergency-setup.sh`** — Updated offline cache binary path to match new `ollama-bin` naming from emergency-plan.

---

## [0.32.1] — 2026-02-28

Emergency plan: preventive pre-download of Ollama and LLM for fully offline installation, with first-run detection and automatic suggestion.

### Added

**`/emergency-plan`** — Pre-downloads Ollama installer, binary, and LLM model to local cache (`~/.pm-workspace-emergency/`). Detects hardware and selects optimal model automatically. When `emergency-setup` runs without internet, it uses this cache for fully offline installation. Includes `--check` flag to verify execution status.

**`scripts/emergency-plan.sh`** — Interactive pre-download script: detects OS/RAM/GPU, downloads Ollama installer + binary, pulls LLM model into Ollama cache, saves metadata (`plan-info.json`), and creates execution marker. Supports `--model` for custom model selection and `--check` for status verification.

### Changed

**`scripts/emergency-setup.sh`** — Now detects internet connectivity at startup. When offline, automatically uses local cache from `emergency-plan` to install Ollama binary and use pre-downloaded model. Falls back gracefully with clear instructions if cache is missing.

**`session-init.sh`** — Now checks if `emergency-plan` has been executed on the current machine. If not, shows a reminder in the session context suggesting the user run `/emergency-plan` to prepare for offline contingency.

---

## [0.32.0] — 2026-02-28

Emergency mode: local LLM contingency plan with Ollama setup, hardware detection, offline PM operations, and step-by-step emergency documentation.

### Added

**`/emergency-mode`** — Manages emergency mode with local LLM. Subcommands: `setup` (install Ollama + download model), `status` (system diagnostics), `activate` (switch to local LLM), `deactivate` (restore cloud), `test` (verify local LLM responds). Automatically recommends model based on available RAM (3B for 8GB, 7B for 16GB, 14B for 32GB+).

**`scripts/emergency-setup.sh`** — Interactive setup script that detects OS/RAM/GPU, installs Ollama, downloads recommended model (default: Qwen 2.5 7B), configures ANTHROPIC_BASE_URL for Claude Code, and verifies connectivity. Color output with progress indicators.

**`scripts/emergency-status.sh`** — System diagnostics showing Ollama installation status, server status, available models with sizes, environment variables, RAM/GPU info, and issue detection with suggested fixes.

**`scripts/emergency-fallback.sh`** — PM operations that work without any LLM: `git-summary` (7-day activity), `board-snapshot` (export to markdown), `team-checklist` (Scrum ceremonies), `pr-list` (pending PRs), `branch-status` (active branches).

**Emergency documentation** — `docs/EMERGENCY.md` (Spanish) and `docs/EMERGENCY.en.md` (English) with step-by-step guide: when to activate, 5-minute setup, what works in emergency mode, hardware requirements by model size, return to normal, and troubleshooting.

---

## [0.31.0] — 2026-02-28

Architecture intelligence: pattern detection, improvement suggestions, recommendations for new projects, fitness functions, and pattern comparisons across 16 languages.

### Added

**`/arch-detect {repo|path}`** — Detects the architecture pattern of a repository using a 4-phase scoring algorithm: folder structure analysis (40%), dependency direction analysis (30%), naming convention analysis (20%), and configuration analysis (10%). Identifies primary pattern, adherence level (High/Medium/Low), violations, and secondary patterns. Supports all 16 languages with language-specific detection markers.

**`/arch-suggest {repo|path}`** — Generates prioritized architecture improvement suggestions based on detection results. Classifies findings into Quick Wins (high impact, low effort), Projects (high impact, high effort), and Nice to Have. Identifies god classes, inverse dependencies, missing abstractions, and tight coupling. Includes architectural health metrics.

**`/arch-recommend {requirements}`** — Recommends the optimal architecture pattern for a new project based on requirements (app type, language, scale, team size, domain complexity). Uses weighted scoring across 7 patterns and 9 factors. Generates folder structure proposal, dependency suggestions, and ADR draft.

**`/arch-fitness {repo|path}`** — Defines and executes architecture fitness functions (integrity rules). Includes pattern-specific rules (layer independence, no circular dependencies, naming conventions) and generic rules (file size limits, import limits, no hardcoded secrets). Reports PASS/FAIL per rule with affected files and suggested fixes.

**`/arch-compare {pattern1} {pattern2}`** — Generates detailed comparison between two architecture patterns across 10 dimensions: complexity, learning curve, testability, scalability, maintainability, minimum team size, ideal use case, anti-use case, popular frameworks, and enforcement tools. Optional project context for personalized recommendation.

**Architecture Intelligence skill** — New skill with pattern detection algorithm, fitness function templates, and reference catalog with 11 language-specific pattern files covering .NET, TypeScript, Java, Python, Go, Rust, PHP, Mobile (Swift/Kotlin/Flutter), Ruby, Legacy (COBOL/VB.NET), and Terraform.

**Architecture patterns domain rule** — Cross-language reference with 7 pattern definitions, detection markers, enforcement tools per language, and fitness function categories.

---

## [0.30.0] — 2026-02-28

Technical debt intelligence: automated analysis, business-impact prioritization, and sprint debt budgeting.

### Added

**`/debt-analyze`** — Automated technical debt discovery: complexity hotspots (cyclomatic complexity × change frequency), temporal coupling (files that change together), code smells (long files, deep nesting), churn analysis (30/60/90 days), and age analysis. Optional SonarQube enrichment. Outputs ranked debt items with severity and estimated effort.

**`/debt-prioritize`** — Prioritizes debt by business impact using weighted scoring: Business Impact 40% (proximity to upcoming PBIs), Change Frequency 30%, Velocity Impact 20%, Risk 10%. Cross-references with flow metrics for bottleneck identification. ROI estimates per item.

**`/debt-budget`** — Proposes sprint debt budget based on velocity trend and re-work rate. Heuristic: declining velocity → 20-30%, stable → 10-15%, improving → 5-10%. Lists specific items that fit in budget with projected velocity improvement.

### Changed

**`/debt-track`** — Enhanced with references to the new debt intelligence commands and integration section explaining the combined manual + automated approach.

---

## [0.29.0] — 2026-02-28

AI governance and EU AI Act compliance: model cards, risk assessment, audit logging, and governance rules.

### Added

**`/ai-model-card`** — Generates AI model cards for the project: agent inventory with models, tasks, data access, decision points, human oversight, and limitations. Follows EU AI Act Article 11 requirements. Includes usage statistics from agent traces when available.

**`/ai-risk-assessment`** — Risk assessment per EU AI Act categories (Prohibited, High-Risk, Limited, Minimal). Classifies each agent with justification and required measures. Flags project-specific agents that could reach high-risk status.

**`/ai-audit-log`** — Chronological audit log from agent traces: user, agent, action, data scope, outcome, duration. Filterable by date, agent, user. Demonstrates Article 12 compliance (record-keeping).

**Rule: `ai-governance.md`** — Domain rule defining AI governance principles (transparency, accountability, human oversight), EU AI Act requirements mapping (Articles 9, 11, 12, 14), decision taxonomy (autonomous prohibited, assisted allowed), and quarterly compliance checklist.

---

## [0.28.0] — 2026-02-28

Developer Experience metrics: DX Core 4 surveys, automated DX dashboard, friction point analysis, and developer-experience skill.

### Added

**`/dx-survey`** — Generates adapted DX Core 4 surveys (Speed, Effectiveness, Quality, Impact) complemented with SPACE dimensions. 12-15 Likert questions + 3 open questions. Processes results with statistical summaries and trend comparison vs previous survey.

**`/dx-dashboard`** — Automated DX dashboard from workspace data: PR cycle time, spec cycle time, build feedback, cognitive load proxy (files/spec, dependencies/task), tool satisfaction proxy (command success rate, cache hits). RAG indicators and trend vs previous sprint.

**`/dx-recommendations`** — Analyzes friction points from traces, specs, PRs, and surveys. Top-5 ranked by impact across 5 categories (Tooling, Process, Communication, Knowledge, Infrastructure). Each with supporting data, action, and expected improvement.

**Skill: `developer-experience`** — Framework reference covering DX Core 4, SPACE, cognitive load types, feedback loop optimization, survey design, actionable metrics, and integration with pm-workspace data sources.

---

## [0.27.0] — 2026-02-28

Agent observability: execution tracing, cost estimation, and efficiency metrics for subagent operations.

### Added

**`/agent-trace`** — Dashboard of agent execution traces: timestamp, agent, command, tokens in/out, duration, files modified, outcome (success/failure/partial). Filters by agent, count, or failures only. Summary with total tokens, average duration, and success rate.

**`/agent-cost`** — Estimates agent usage cost per sprint/project. Configurable pricing per model (Opus $15/$75, Sonnet $3/$15, Haiku $0.80/$4 per M tokens). Groups by agent, command, sprint. Trend analysis and optimization recommendations.

**`/agent-efficiency`** — Agent efficiency analysis: specs completed/attempted, average time by complexity, re-work rate, first-pass success rate, agent utilization in Agent Teams. Benchmarks against last 3 sprints.

**Hook: `agent-trace-log.sh`** — PostToolUse async hook that automatically logs every Task (subagent) invocation to `projects/{project}/traces/agent-traces.jsonl` in JSONL format.

---

## [0.26.0] — 2026-02-28

Predictive analytics and flow metrics: sprint forecasting with Monte Carlo simulation, Value Stream Mapping dashboard, velocity trending with anomaly detection, and enhanced board-flow with Flow Efficiency.

### Added

**`/sprint-forecast`** — Predicts sprint completion using Monte Carlo simulation (N=1000) over historical velocity (last 3-5 sprints). Outputs confidence intervals at P70/P85/P95, identifies at-risk items, and recommends actions. Falls back to mock data without Azure DevOps connection.

**`/flow-metrics`** — Complete Value Stream dashboard: Lead Time E2E (idea→production), Cycle Time, Flow Efficiency (active time / total elapsed), %Complete & Accurate, WIP Aging with alerts, WIP distribution by type (Feature/Bug/Debt/Risk), Flow Load by state, and Throughput trend (last 4 weeks).

**`/velocity-trend`** — Velocity analysis over 6-8 sprints with 3-sprint moving average, anomaly detection (>1.5σ threshold), factor identification (team changes, holidays, scope), and trend direction (accelerating/stable/decelerating).

**Skill: `predictive-analytics`** — Reference skill covering Monte Carlo formulas, confidence intervals, Flow Efficiency calculation, WIP Aging thresholds, throughput regression, and Azure DevOps integration patterns.

### Changed

**`/board-flow`** — Enhanced with Flow Efficiency percentage, %Complete & Accurate, and WIP Aging table with status indicators (🔴/🟡/🟢). Added reference to `/flow-metrics` for full dashboard.

---

## [0.25.0] — 2026-02-28

Security hardening and community patterns: SAST audit, dependency vulnerability scanning, SBOM generation, credential history scanning, epic-level planning, worktree automation, and enhanced credential leak detection.

### Added

**`/security-audit`** — SAST analysis against OWASP Top 10 (2021): broken access control, cryptographic failures, injection, insecure design, security misconfiguration, XSS, logging failures, SSRF. Categorizes findings as CRITICAL/WARNING/INFO with file:line references and fix recommendations.

**`/dependencies-audit`** — Scans project dependencies for known vulnerabilities. Auto-detects stack (npm, pip, dotnet, go, cargo, composer, bundler) and runs native audit tools. Reports CVEs with severity and recommended upgrade versions.

**`/sbom-generate`** — Generates Software Bill of Materials in CycloneDX JSON format. Lists direct and transitive dependencies with versions and scopes. Output: `output/sbom/{proyecto}-sbom-{fecha}.json`.

**`/credential-scan`** — Scans git history (last 50 commits) and current files for leaked credentials: AWS keys (AKIA...), GitHub tokens (ghp_...), OpenAI keys (sk-...), private keys, Azure connection strings. Provides rotation and cleanup recommendations.

**`/epic-plan`** — Multi-sprint epic planning: decomposes epics into PBIs, distributes across sprints respecting capacity and dependencies, generates Mermaid Gantt roadmap. Output: `output/epic-plans/`.

**`/worktree-setup`** — Automates git worktree creation for parallel agent implementation. Creates feature branches, copies local config, verifies build, and provides cleanup for completed worktrees.

### Changed

**`block-credential-leak.sh` enhanced** — 5 new patterns: AWS Access Keys (`AKIA`), GitHub tokens (`ghp_`), OpenAI keys (`sk-`), Azure connection strings, JWT tokens. Better false-positive handling for test files and examples.

**CLAUDE.md** — Commands 96→102 (+6 security/community commands).

### Why

Security should shift left: `/security-audit` catches OWASP issues before they reach production, `/dependencies-audit` catches known CVEs before they're exploited, `/sbom-generate` provides supply chain transparency. `/credential-scan` catches historical leaks that current hooks would miss. `/epic-plan` addresses the gap between PBI-level planning and strategic roadmapping. `/worktree-setup` automates the manual steps needed for parallel agent development.

---

## [0.24.0] — 2026-02-28

Permissions and CI/CD hardening: plan-gate hook warns before implementing without spec, file size validation in CI, settings.json schema validation, command frontmatter validation, and two new governance commands.

### Added

**Plan-gate hook** — `.claude/hooks/plan-gate.sh` (PreToolUse on Edit/Write): warns if code edits start without a recently approved spec. Checks for `.spec.md` files modified in last 14 days. Warning only (does not block). Encourages SDD discipline: spec first, then implement.

**CI validation steps** — `.github/workflows/ci.yml` expanded with: (1) file size validation — all skills, agents, commands, domain rules checked for ≤150 lines, (2) JSON schema validation — `settings.json` must be valid JSON, (3) command frontmatter validation — all commands must have `name` and `description` fields.

**`/validate-filesize`** — Scans all managed files (skills, agents, rules, commands, scripts) for ≤150 lines compliance. Reports violations with file paths and line counts.

**`/validate-schema`** — Validates settings.json JSON structure, command frontmatter (name, description, agent), and skill frontmatter (name, description, context).

### Changed

**CLAUDE.md** — Hooks 11→12 (plan-gate). Commands 94→96.

### Why

CI should catch regressions that manual review misses: a file growing past 150 lines, a command missing its frontmatter, or a broken settings.json. The plan-gate hook nudges toward SDD discipline without blocking — a soft reminder that specs should precede implementation.

---

## [0.23.0] — 2026-02-28

Automated code review inspired by Guardian Angel (Gentleman Programming): pre-commit review hook with SHA256 cache, centralized review rules (REJECT/REQUIRE/PREFER), staging area reads, and cache management commands.

### Added

**Pre-commit review hook** — `.claude/hooks/pre-commit-review.sh` (Stop): reviews staged files before finalizing. Reads from `git show :file` (staging area, not filesystem — prevents race conditions). Detects: debug statements in production, hardcoded secrets, TODOs without tickets, TypeScript `any`. SHA256 cache: hash of (file content + rules) → skip if unchanged. Only caches PASSED results (FAILED always re-reviewed). Cache invalidated automatically when rules file changes.

**Code review rules** — `.claude/rules/domain/code-review-rules.md`: centralized rules with GGA-style keywords. REJECT (blocking): secrets, merge conflicts, debugger statements. REQUIRE (mandatory): TODOs with tickets, TypeScript types, error handling. PREFER (suggestions): constants over magic numbers, early return, readonly/const. Per-project overrides in `projects/{proy}/code-review-rules.md`.

**Review cache utility** — `scripts/review-cache.sh`: stats (entries, size, token savings estimate), clear (invalidate all), list (recent entries).

**2 cache commands** — `/review-cache-stats` (show hit rate and savings), `/review-cache-clear` (invalidate cache).

### Changed

**`/pr-review` updated** — Now references centralized code-review-rules.md. Added diff-only mode: sends only the diff (not full files) to reduce context consumption for large PRs.

**CLAUDE.md** — Hooks 10→11 (pre-commit-review). Commands 92→94.

### Why

Inspired by Guardian Angel's approach: review from staging area prevents race conditions, SHA256 cache avoids re-reviewing unchanged files, centralized rules (not scattered across agents) ensure consistency. Unlike GGA (multi-provider), pm-workspace uses Claude as the single reviewer with rule-based pattern detection for common issues.

---

## [0.22.0] — 2026-02-28

SDD workflow enhanced with Agent Teams Lite patterns (Gentleman Programming): pre-spec exploration, technical design phase, spec compliance matrix, delta specs, and hierarchical task decomposition by phases.

### Added

**`/spec-explore {task-id}`** — Pre-spec exploration command. Launches a subagent to analyze the codebase before writing the spec: identifies affected files, compares implementation approaches, maps dependencies. Output: `output/explorations/{task-id}-exploration.md`. Provides informed context for `/spec-generate`.

**`/spec-design {spec-file}`** — Technical design phase. Generates a design document from an approved spec: technical decisions, data flow, files to modify, testing strategy. Output: `projects/{proy}/specs/{sprint}/{task-id}-design.md`. Can run in parallel with spec generation (DAG pattern from ATL).

**`/spec-verify {spec-file}`** — Spec compliance matrix. Cross-references each Given/When/Then scenario from the spec against actual test results. Generates: `| Requirement | Scenario | Test | Result |`. A scenario is COMPLIANT only if a passing test exists — existing code alone is NOT sufficient evidence (ATL pattern).

**Compliance matrix reference** — `references/compliance-matrix.md` in SDD skill: template, rules (PASS/FAIL/MISSING mapping), consolidation workflow for sprint close.

### Changed

**SDD skill updated** — New §2.7 Delta Specs: incremental spec modifications using ADDED/MODIFIED/REMOVED sections instead of full rewrites. Deltas consolidated at sprint close via `/spec-verify`.

**PBI decomposition** — New rule #7: hierarchical task numbering by phases (Foundation 1.x → Core 2.x → Integration 3.x → Testing 4.x → Cleanup 5.x). Tasks grouped by phase for clearer execution order.

**CLAUDE.md** — Commands 89→92 (+3 SDD commands).

### Why

Inspired by Agent Teams Lite's approach to SDD: exploration before spec writing prevents specs based on assumptions, design phase separates "what" from "how", compliance matrix provides objective verification (not "code looks right" but "tests prove it works"), and delta specs reduce noise in evolving requirements. Hierarchical task numbering from ATL's DAG phases improves execution clarity.

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

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.55.0...HEAD
[0.55.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.54.0...v0.55.0
[0.54.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.53.0...v0.54.0
[0.53.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.52.0...v0.53.0
[0.52.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.51.0...v0.52.0
[0.51.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.50.0...v0.51.0
[0.50.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.49.0...v0.50.0
[0.49.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.48.0...v0.49.0
[0.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.47.0...v0.48.0
[0.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.46.0...v0.47.0
[0.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.45.0...v0.46.0
[0.45.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.44.0...v0.45.0
[0.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.43.0...v0.44.0
[0.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.42.0...v0.43.0
[0.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.41.0...v0.42.0
[0.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.40.0...v0.41.0
[0.40.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.39.0...v0.40.0
[0.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.38.0...v0.39.0
[0.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.37.0...v0.38.0
[0.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.36.0...v0.37.0
[0.36.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.35.0...v0.36.0
[0.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.34.0...v0.35.0
[0.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.3...v0.34.0
[0.33.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.2...v0.33.3
[0.33.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.1...v0.33.2
[0.33.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.0...v0.33.1
[0.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.3...v0.33.0
[0.32.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.2...v0.32.3
[0.32.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.1...v0.32.2
[0.32.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.0...v0.32.1
[0.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.31.0...v0.32.0
[0.31.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.30.0...v0.31.0
[0.30.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.29.0...v0.30.0
[0.29.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.28.0...v0.29.0
[0.28.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.27.0...v0.28.0
[0.27.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.26.0...v0.27.0
[0.26.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.25.0...v0.26.0
[0.25.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.24.0...v0.25.0
[0.24.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.23.0...v0.24.0
[0.23.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.21.0...v0.22.0
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
