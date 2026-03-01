# Roadmap

pm-workspace has evolved from a Scrum toolkit into a full PM intelligence platform with 166 commands, 24 agents, 19 skills, and its own persona (Savia). This roadmap groups the 49 released versions into thematic eras and outlines what comes next.

Status: ✅ Released · 🟡 In progress · 💡 Proposed

Community votes via 👍 on GitHub Issues. See [How to influence the roadmap](#how-to-influence-the-roadmap).

---

## ✅ Era 1 — Foundation (v0.1.0–v0.2.0, Feb 2026)

Core workspace: sprint management, reporting, PBI decomposition, Spec-Driven Development, product discovery (JTBD + PRD), PR review, security guardians. 96-test suite.

---

## ✅ Era 2 — Ecosystem Expansion (v0.3.0–v0.11.0, Feb 2026)

Grew from 16 to 81 commands in 9 releases:

- **Multi-language** (v0.3.0) — 16 language packs from C#/.NET to COBOL and Flutter
- **Connectors** (v0.4.0) — Slack, Jira, Confluence, Google Drive, Notion, Linear, 6 Azure Repos commands, 5 pipeline commands
- **Governance** (v0.5.0) — DORA metrics, tech debt tracking, dependency mapping, risk register
- **Legacy & Capture** (v0.6.0) — Legacy assessment, backlog capture from unstructured sources
- **Project Onboarding** (v0.7.0) — 5-phase audit-to-kickoff pipeline
- **DevOps Extended** (v0.8.0) — Wiki management, Test Plans, security alerts
- **Messaging** (v0.9.0) — WhatsApp (personal), Nextcloud Talk, voice transcription with Faster-Whisper
- **CI/CD** (v0.10.0) — GitHub Actions auto-labeling, MCP migration guide
- **UX Standards** (v0.11.0) — Mandatory feedback banners, progress indicators, error recovery

---

## ✅ Era 3 — Context Intelligence (v0.12.0–v0.20.0, Feb 2026)

The workspace learned to manage its own context window:

- **Context optimization** (v0.12.0) — 58% reduction in auto-loaded context
- **Context health** (v0.13.0) — Proactive saturation prevention, output-first pattern
- **Session persistence** (v0.14.0) — Save/load rituals, persistent "second brain"
- **Command naming fix** (v0.15.0) — Colons to hyphens (106 commands across 164 files)
- **Memory system** (v0.16.0) — Path-specific auto-loading, `/memory-sync`
- **Agent capabilities** (v0.17.0) — Persistent memory, skill preloading, worktree isolation
- **Multi-agent coordination** (v0.18.0) — Agent notes, TDD gate, ADRs, SDD handoff
- **Governance hardening** (v0.19.0) — Scope guard, session serialization, drift prevention
- **150-line discipline** (v0.20.0) — All files ≤150 lines, progressive disclosure

---

## ✅ Era 4 — Advanced Intelligence (v0.21.0–v0.34.0, Feb 2026)

Deep analysis capabilities across architecture, security, compliance, and prediction:

- **Engram memory** (v0.21.0) — JSONL store, SHA256 dedup, topic upsert, privacy filtering
- **SDD enhanced** (v0.22.0) — Pre-spec exploration, delta specs, hierarchical decomposition
- **Code review** (v0.23.0) — Pre-commit hook, SHA256 cache, centralized rules
- **CI hardening** (v0.24.0) — Plan-gate hook, file size CI, frontmatter validation
- **Security** (v0.25.0) — SAST audit, SBOM, dependency scanning, credential scan
- **Predictive analytics** (v0.26.0) — Monte Carlo forecasting, Value Stream Mapping, velocity trends
- **Agent observability** (v0.27.0) — Execution tracing, cost estimation, efficiency metrics
- **DX metrics** (v0.28.0) — DX Core 4 surveys, friction analysis, DX dashboard
- **AI governance** (v0.29.0) — EU AI Act compliance, model cards, risk assessment
- **Debt intelligence** (v0.30.0) — Business-impact prioritization, sprint debt budgeting
- **Architecture intelligence** (v0.31.0) — Pattern detection, fitness functions, 16-language support
- **Emergency mode** (v0.32.0) — Ollama contingency, offline PM operations
- **Regulatory compliance** (v0.33.0) — 12 regulated industries, auto-fix with verification
- **Performance audit** (v0.34.0) — Static hotspot analysis, async anti-patterns, test-first

---

## ✅ Era 5 — Savia & Personalization (v0.35.0–v0.39.0, Mar 2026)

pm-workspace got its identity — Savia, the wise little owl:

- **Savia & profiles** (v0.35.0) — Conversational onboarding, fragmented profiles, 6 roles, agent mode
- **Community system** (v0.36.0) — Privacy-first contributions, PAT/IP/email blocking
- **Vertical detection** (v0.37.0) — 10 non-software sectors, calibrated scoring, specialized extensions
- **Review protocol** (v0.38.0) — Maintainer workflow for community PRs, secrets scanning
- **Encrypted backups** (v0.39.0) — AES-256-CBC, NextCloud/Google Drive, 7-backup rotation

---

## ✅ Era 6 — Context Engineering (v0.40.0–v0.44.0, Mar 2026)

Inspired by Synaptic Context Engineering — optimizing every token:

- **Role-adaptive routines** (v0.40.0) — Daily suggestions per role, health dashboard, context-map
- **Session compression** (v0.41.0) — 4-level priority system, CLAUDE.md 36% reduction
- **Agent budgets** (v0.42.0) — Token budgets for all 24 agents (4 tiers)
- **Context aging** (v0.43.0) — Semantic aging (episodic → compressed → archived), benchmarking
- **Semantic hub** (v0.44.0) — Dependency topology, hub/isolated/dormant classification

---

## ✅ Era 7 — Role-Specific Features (v0.45.0–v0.49.0, Mar 2026)

19 commands tailored to each role in the team:

- **Executive Reports** (v0.45.0) — `/ceo-report`, `/ceo-alerts`, `/portfolio-overview`
- **QA Toolkit** (v0.46.0) — `/qa-dashboard`, `/qa-regression-plan`, `/qa-bug-triage`, `/testplan-generate`
- **Developer Productivity** (v0.47.0) — `/my-sprint`, `/my-focus`, `/my-learning`, `/code-patterns`
- **Tech Lead Intelligence** (v0.48.0) — `/tech-radar`, `/team-skills-matrix`, `/arch-health`, `/incident-postmortem`
- **Product Owner Analytics** (v0.49.0) — `/value-stream-map`, `/feature-impact`, `/stakeholder-report`, `/release-readiness`

---

## 💡 Proposed — v0.50.0+

Ideas under consideration. Open an issue or vote with 👍 to prioritize.

**Real-time integrations**
- Live Azure DevOps webhooks — push-based sprint updates instead of polling
- GitHub PR status streaming — real-time review notifications
- Slack/Teams bot mode — Savia responds directly in team channels

**Cross-project intelligence**
- Portfolio dependency graph — visualize and alert on inter-project bottlenecks
- Shared backlog patterns — detect duplicated PBIs across projects
- Org-level DORA metrics — aggregate delivery metrics across teams

**AI-powered planning**
- Sprint auto-planning — suggest optimal sprint composition from backlog and capacity
- Risk prediction — ML model trained on historical sprint data to forecast failures
- Meeting summarizer — transcribe and extract action items from Sprint Reviews

**Developer experience**
- VS Code / Cursor extension — run pm-workspace commands from the editor sidebar
- MCP server mode — expose Savia's tools to other Claude Code projects
- Natural language queries — "how is the sprint going?" without memorizing commands

**Multi-platform**
- Jira Cloud integration as alternative to Azure DevOps
- GitHub Projects integration
- Linear integration with full bidirectional sync

---

## How to influence the roadmap

1. Check if your idea already has an open issue — if so, add a 👍 reaction.
2. If not, open a new issue using the **Feature request** template.
3. The most-voted open issues are pulled into the next milestone during planning.
4. Want to implement something? Comment on the issue first — maintainers will confirm the approach fits before you invest time in a PR.
