# Roadmap

pm-workspace has evolved from a Scrum toolkit into a full PM intelligence platform with 280+ commands, 24 agents, 21 skills, and its own persona (Savia). This roadmap groups the 83 released versions into thematic eras and outlines what comes next.

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

## 💡 Era 18 — Compliance, Distribution & Intelligent Hooks (v0.84.0+, proposed)

Based on research of 15 external sources. Full analysis in `docs/propuestas/roadmap-research-era18.md`.

### Priority 1 — AEPD Compliance & skills.sh Distribution

| Version | Feature | Description |
|---|---|---|
| v0.84.0 | `/aepd-compliance` | Vertical de compliance para IA agéntica española (framework AEPD: tecnología → cumplimiento → vulnerabilidades → medidas). Extiende `/governance-audit` con criterios AEPD. Diferencial vs. herramientas anglosajonas. |
| v0.85.0 | skills.sh publishing | Publicar 5 skills core (sprint-management, capacity-planning, pbi-decomposition, spec-driven-development, diagram-generation) en skills.sh marketplace. Adaptar formato, README por skill. |

### Priority 2 — Intelligent Hooks & Excel Integration

| Version | Feature | Description |
|---|---|---|
| v0.86.0 | Prompt & Agent hooks | Prompt hooks: LLM para validaciones semánticas (commit messages, spec coherence). Agent hooks: subagentes de verificación pre-merge (tests, seguridad, dependencias). Calibración gradual (warnings → blocks). |
| v0.87.0 | Excel reporting | Templates interactivos Claude-in-Excel para `/capacity-planning`, `/ceo-report`, `/time-tracking-report`. Fórmulas dinámicas multi-tab, escenarios. |

### Priority 3 — Catalog & Source Tracking

| Version | Feature | Description |
|---|---|---|
| v0.88.0 | Savia Gallery + Source tracking | Catálogo visual de 280+ comandos por rol/vertical (inspirado en component.gallery). Source tracking: cada output incluye fuentes consultadas. |
| v0.89.0 | AI competency framework | Extender `/adoption-assess` con habilidades "working with AI" (formulación, evaluación de outputs, pensamiento crítico). |

### Backlog — Strategic Evaluation

- **Claude Connectors vs MCP** — Evaluar si Connectors simplifican la arquitectura de integraciones
- **More industry verticals** — Insurance (Guidewire, Solvency II), Retail/eCommerce, Telco (OSS/BSS, eTOM/SID)
- **Multimodal quality gates** — Visual regression via VLM screenshot analysis, diagram-to-spec, wireframe-driven decompose
- **Observability extensions** — New Relic, Splunk, Elastic APM. LLM observability (token usage, prompt latency, model drift)
- **Developer experience** — VS Code / Cursor extension, CLI mode, mobile companion (read-only sprint status)
- **Claude in Chrome integration** — Extracción de datos de portales web sin API para Savia

---

## How to influence the roadmap

1. Check if your idea already has an open issue — if so, add a 👍 reaction.
2. If not, open a new issue using the **Feature request** template.
3. The most-voted open issues are pulled into the next milestone during planning.
4. Want to implement something? Comment on the issue first — maintainers will confirm the approach fits before you invest time in a PR.
