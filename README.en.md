<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**English** | [Español](README.md) | [Galego](README.gl.md) | [Euskara](README.eu.md) | [Català](README.ca.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Italiano](README.it.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Your dev team deserves a PM that never sleeps

Sprints go off track. Backlogs grow without prioritization. Executive reports are crafted by hand. Technical debt piles up unmeasured. AI agents generate code without specs or tests.

**pm-workspace** fixes this. It's a complete PM that lives inside Claude Code: manages sprints, decomposes backlogs, coordinates code agents with executable specs, generates executive reports, and tracks technical debt — in your language, with your data protected on your machine.

---

## Get started in 3 minutes

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash

# 2. Open Claude Code in the directory
cd pm-workspace && claude

# 3. Savia greets you and asks your name. Then:
/sprint-status          # ← your first command
```

Savia adapts to you. If you're a PM, she shows sprints and capacity. If you're a developer, your backlog and specs. If you're a CEO, portfolio and DORA metrics.

**Windows:** `irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex`

---

## What problems it solves

| Problem | Without pm-workspace | With pm-workspace |
|---|---|---|
| Sprint status | Open Azure DevOps, filter, calculate | `/sprint-status` → full dashboard |
| Executive report | 2h in Excel/PowerPoint | `/ceo-report` → generated with real data |
| Implement feature | Dev interprets the ticket | `/spec-generate` → executable spec → agent implements → tests → PR |
| Technical debt | "We'll fix it later" | `/debt-analyze` → prioritized by impact |
| Code review | Manually review 300 lines | `/pr-review` → 3 perspectives (security, architecture, business) |
| Onboard new dev | 2 weeks reading code | `/onboard` → personalized guide + AI buddy |

---

## Hi, I'm Savia 🦉

I'm the little owl that lives inside pm-workspace. I adapt to your role, your language, and how you work. I work with Azure DevOps, Jira, or 100% Git-native with Savia Flow.

**Quick-starts by role:**

| Role | Quick-start |
|---|---|
| PM / Scrum Master | [→ quick-start-pm](docs/quick-starts/quick-start-pm.md) |
| Tech Lead | [→ quick-start-tech-lead](docs/quick-starts/quick-start-tech-lead.md) |
| Developer | [→ quick-start-developer](docs/quick-starts/quick-start-developer.md) |
| QA | [→ quick-start-qa](docs/quick-starts/quick-start-qa.md) |
| Product Owner | [→ quick-start-po](docs/quick-starts/quick-start-po.md) |
| CEO / CTO | [→ quick-start-ceo](docs/quick-starts/quick-start-ceo.md) |

---

## What's inside

**508 commands · 48 agents · 90 skills · 49 hooks · 16 languages · 130 test suites**

### Project management
Sprints, burndown, capacity, dailies, retros, KPIs. Reports in Excel and PowerPoint. Monte Carlo prediction. Billing and costs.

### Spec-Driven Development (SDD)
Tasks become specs. Agents implement in 16 languages (C#, TypeScript, Python, Java, Go, Rust, PHP, Ruby, Swift, Kotlin, Flutter, COBOL...) in isolated worktrees. Automated code review + mandatory human review.

### Security
SAST against OWASP Top 10, Red/Blue/Auditor pipeline, dynamic pentesting, SBOM, compliance across 12 sectors. Savia Shield: local data classification with on-premise LLM, reversible masking, cryptographic PR signing. Emergency Watchdog: automatic fallback to local LLM (Gemma 4 / Qwen) if internet goes down.

### Persistent memory
Plain text (JSONL). Entity recall, semantic search, cross-session continuity. Automatic decision extraction before compaction. AES-256 encrypted Personal Vault.

### Accessibility
Guided work for people with disabilities (visual, motor, ADHD, autism, dyslexia). Micro-tasks, block detection, adaptive reformulation.

### Code intelligence
Architecture detection (Clean, Hexagonal, DDD, CQRS, Microservices). Fitness functions. Human Code Maps (.hcm) that reduce cognitive debt.

### Autonomous modes
Overnight sprint, code improvement, tech research. Agents propose on `agent/*` branches with Draft PRs — the human always decides.

### Extensions
[Savia Mobile](projects/savia-mobile-android/README.md) (native Android) · [Savia Web](projects/savia-web/README.md) (Vue.js dashboards) · [SaviaClaw](zeroclaw/ROADMAP.md) (ESP32 + full-duplex voice)

---

## Structure

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 508 commands
│   ├── agents/         ← 48 specialized agents
│   ├── skills/         ← 89 domain skills
│   ├── hooks/          ← 49 deterministic hooks
│   └── rules/          ← context and language rules
├── docs/               ← guides by role, scenario, sector
├── projects/           ← projects (git-ignored for privacy)
├── scripts/            ← validation, CI, utilities
├── zeroclaw/           ← ESP32 hardware + voice
└── CLAUDE.md           ← identity and core rules
```

---

## Documentation

| Section | Description |
|---|---|
| [Getting Started](docs/getting-started.md) | From zero to productive |
| [Data Flow](docs/data-flow-guide-es.md) | How the parts connect |
| [Confidentiality](docs/confidentiality-levels.md) | 5 levels (N1-N4b) |
| [Savia Shield](docs/savia-shield.md) | Data sovereignty |
| [SDD](docs/readme/05-sdd.md) | Spec-Driven Development |
| [Commands & Agents](docs/readme/12-comandos-agentes.md) | Full reference |
| [Scenario Guides](docs/guides/README.md) | Azure, Jira, startup, healthcare... |
| [Adoption](docs/ADOPTION_GUIDE.md) | Step by step for consultancies |

---

## Principles

1. **Plain text is truth** — .md and .jsonl. If the AI is gone, data remains readable
2. **Absolute privacy** — user data never leaves their machine
3. **The human decides** — AI proposes, never autonomous merge or deploy
4. **Apache 2.0 / MIT** — no vendor lock-in, no telemetry

---

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). PRs welcome.

## License

[MIT](LICENSE) — Created by [Mónica González Paz](https://github.com/gonzalezpazmonica)
