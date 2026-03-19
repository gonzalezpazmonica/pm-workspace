# Roadmap Unificado — pm-workspace / Savia

**Updated:** 2026-03-19 | **Version:** v3.3.0 | **475+ commands · 43 agents · 79 skills · 16 hooks**

Status: **Done** · **In progress** · **Planned** · **Proposed**

---

## Done — Eras 1-118 (v0.1.0 → v3.3.0)

### Foundation → Enterprise (Eras 1-52)

PM core, 16 language packs, context engineering (58% reduction), engram memory,
security (SAST/SBOM), Savia persona, profiles, vertical detection, role-specific
routines, Company Savia (RSA-4096), Travel Mode (AES-256), Savia Flow (17 cmds),
Git Persistence Engine, Savia School, DX metrics, accessibility (N-CAPS),
adversarial security (Red/Blue/Auditor), Visual QA, dev sessions (5-phase).

### Mobile + Web (Eras 53-87)

Savia Mobile v0.1 (Kotlin/Compose, 157 tests). Savia Web Phases 1-3: dashboard,
backlog (Spec>PBI>Task), file browser, i18n, pipelines, n8n, multi-user auth,
chat with SSE, session management. 228 unit + 150 E2E tests.

### Quality + Intelligence (Eras 88-116)

BATS (84 tests), weighted coverage (65%), security hardening, lazy loading,
sync adapters, autonomous pipeline engine, radical honesty (Rule #24),
digest traceability, visual-digest (4-pass OCR), meeting-digest Phase 4.

### Era 117 — Document Digest Suite (v3.2.0)

4 digest agents (PDF, Word, Excel, PPTX), Prompt Optimizer (/skill-optimize),
agent audit (43 agents, 12 fixed), auto-trigger protocol.

### Era 118 — Open-Source Research Improvements (v3.3.0)

5 improvements from GitNexus, NemoClaw, GSD, Context Hub, Everything Claude Code:
codebase-map, agent-policies, dev-session-locks, doc-quality-feedback, skill-lifecycle.
PR Guardian threshold raised (150+75/commit).

---

## In Progress

### Savia Web — Phase 4: Git Manager

Visual Git Manager integrado (3 sub-fases: viewer → staging → advanced).
SVG commit graph, diff viewer, staging area, branch CRUD, merge, blame.
Modelo: Ungit. Specs pendientes de crear. Bridge endpoints + Vue components.

**Estado**: roadmap detallado listo, implementacion pausada por onboarding TrazaBios.

### Savia Mobile v0.2 — Full PM

Auto-updater, project selector, dashboard widgets, command palette, kanban,
time tracking, quick capture, approvals. 26/26 tests passing.

---

## Planned — Q2 2026 (priorizado)

### P1. Savia Web Git Manager (Score 4.90)

3 sub-fases en 3 semanas. Core differentiator.
Spec: `projects/savia-web/specs/roadmap-git-manager.md`

### P2. Web Test Regression + Coverage (Score 4.70)

Cubrir gaps E2E, screenshots obligatorios, cobertura >= 80%.

### P3. Power Features CLI (Score 4.60)

- PF1: Autonomous Budget Guard (`--max-budget-usd`)
- PF2: Semantic Compact Filter (preserve context-aware)
- PF3: PM Keybindings (6 chord shortcuts)
- PF4: PR Context Loader (`--from-pr {url}`)

### P4. Web Notifications RT + Dashboard Real (Score 4.30)

SSE generico, store de notificaciones, dashboard con datos reales, widgets por rol.

### P5. Web Approvals + Code Review Integrado (Score 4.10)

PRs con diffs, approve/reject, enlace bidireccional approval ↔ backlog.

### P6. Markdown Editor In-Browser (Score 4.00)

WYSIWYG + raw mode para .md: business rules, specs, CLAUDE.md. Save via Bridge.

---

## Planned — Q3 2026

### P7. Context Engineering Audit (Score 4.50)

Auditar @ references, prunar skills auto-generados, reducir dormant rules.
ETH Zurich study: human-written +4%, AI-generated -3% + 20% cost.

### P8. Voice Integration (Score 4.15)

Voice-first para ceremonias Scrum. Abstract VoiceProvider (Whisper FOSS).

### P9. Supervisor Agent (Score 3.80)

Monitoriza otros agentes, detecta stalls >30min, reasigna, genera resumen.
Prerequisito para sesiones autonomas multi-dia.

### P10. Competence Model (Score 3.75)

Per-person skill tracking. Asignacion optima por competencia + crecimiento.
Equality Shield compliant.

### P11. Mobile Responsive + PWA (Score 3.70)

Responsive breakpoints, PWA manifest, touch-friendly kanban/graph.

### P12. Push Notifications + Smartwatch (Score 3.65)

ntfy.sh (FOSS), Wear OS complications, rich notifications con acciones.

---

## Proposed — Q4 2026+

- Extended Time Horizon (multi-day autonomous, depends on Supervisor Agent) — 3.75
- Semantic Memory (sqlite-vec + sentence-transformers, FOSS only) — 3.60
- Plugin Marketplace (community registry + security sandbox) — 3.55
- Multilingualism (FR/IT/PT/DE/ZH) — 3.50
- API REST Layer (only if client demand, MCP covers most) — 3.40
- SSO/LDAP via OIDC (Keycloak FOSS) — 3.35
- Knowledge Graph Decay (cognitive decay for semantic memory) — 3.30
- Rust Runtime for Hooks (only if >500ms bottleneck) — 3.25

---

## Rejected

- Google Sheets/Drive as data store (violates Git-as-truth)
- ServiceNow/SAP/Salesforce connectors (proprietary SDKs)
- Tableau/Power BI integration (CSV export, user chooses tool)
- Kafka/EventBridge streaming (over-engineering)
- VS Code extension (Anthropic shipped official)
- Claude in Chrome extension (native browsing agent)

---

## Scoring (5 dimensions, 1-5 each)

- **PM Impact** (30%) — improves real project management?
- **Anti lock-in** (25%) — works offline/standalone? No vendor dependency?
- **FOSS** (20%) — uses/generates free software?
- **Inverse complexity** (15%) — 5=trivial, 1=months
- **Savia Flow alignment** (10%) — fits 6 principles

---

## Sources consolidated

- `docs/propuestas/roadmap-research-era18.md` → absorbed into Done (Era 18)
- `docs/propuestas/roadmap-research-era20.md` → absorbed into Done (Era 20)
- `docs/roadmap-code-review-improvements.md` → absorbed into Done (v2.74.0)
- `projects/savia-web/ROADMAP.md` → P1-P6 integrated here
- `projects/savia-web/specs/roadmap-git-manager.md` → referenced from P1

Community votes via GitHub Issues.
