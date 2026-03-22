<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**English** · [Versión en español](README.md)

# PM-Workspace

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Hi, I'm Savia 🦉

I'm Savia, the little owl that lives inside pm-workspace. My job is to keep your projects flowing: I manage sprints, break down backlogs, coordinate code agents, handle billing, generate executive reports, and watch over technical debt — all from Claude Code, in whatever language you use. I work with Azure DevOps, Jira, or 100% Git-native via Savia Flow. When you arrive for the first time, I introduce myself and get to know you. I adapt to you, not the other way around.

---

## Who are you?

Depending on your role, your experience with me will be different. Pick your quick-start:

| Role | What I do for you | Quick-start |
|---|---|---|
| **PM / Scrum Master** | Sprints, dailies, capacity, reporting | [→ quick-start-pm](docs/quick-starts_en/quick-start-pm.md) |
| **Tech Lead** | Architecture, tech debt, tech radar, PRs | [→ quick-start-tech-lead](docs/quick-starts_en/quick-start-tech-lead.md) |
| **Developer** | Specs, implementation, tests, my sprint | [→ quick-start-developer](docs/quick-starts_en/quick-start-developer.md) |
| **QA** | Test plans, coverage, regression, quality gates | [→ quick-start-qa](docs/quick-starts_en/quick-start-qa.md) |
| **Product Owner** | KPIs, backlog, feature impact, stakeholders | [→ quick-start-po](docs/quick-starts_en/quick-start-po.md) |
| **CEO / CTO** | Portfolio, DORA, governance, AI exposure | [→ quick-start-ceo](docs/quick-starts_en/quick-start-ceo.md) |

---

## How information flows

Everything in pm-workspace is connected. When your team logs hours, that feeds into costs; costs generate invoices; invoices show up in executive reports. Nothing is lost, nothing is duplicated.

```
Hours (timesheet)  ──→  Costs (cost-mgmt)  ──→  Invoices  ──→  CEO Report
       ↓                                                            ↑
Sprint items  ──→  Velocity trend  ──→  Capacity forecast  ──→  Executive alerts
       ↓
Spec (SDD)  ──→  Agent implements  ──→  Code review  ──→  Tests  ──→  DORA metrics
       ↓
Memory  ──→  Entity recall  ──→  Context load  ──→  Cross-session continuity
```

More detail in the [Data flow guide](docs/data-flow-guide-en.md).

---

## Where everything lives

```
pm-workspace/
├── .claude/
│   ├── commands/       ← 496 commands (what you can ask me)
│   ├── agents/         ← 46 specialized agents
│   ├── skills/         ← 82 skills with domain knowledge
│   ├── hooks/          ← 22 hooks that enforce rules automatically
│   └── rules/          ← context, language, and domain rules
├── docs/
│   ├── quick-starts/   ← role-based guides (PM, Dev, QA, PO, TL, CEO)
│   ├── readme/         ← detailed documentation (13 sections)
│   ├── guides/         ← 14 guides (Azure, Jira, startup, healthcare...)
│   └── savia-flow/     ← Git-native system docs
├── projects/
│   ├── savia-mobile-android/  ← native Android app + bridge
│   └── savia-web/             ← Vue.js web client for dashboards
├── zeroclaw/
│   ├── firmware/       ← MicroPython for ESP32 (selftest, heartbeat, LCD)
│   ├── host/           ← bridge, daemon, voice, guardrails, brain
│   ├── savia-voice/    ← next-gen voice daemon (full-duplex, Kokoro TTS)
│   ├── tests/          ← 77 hardware-free tests
│   └── ROADMAP.md      ← phases 0-6 towards autonomy
├── scripts/            ← validation, CI, utilities, savia-bridge.py
├── output/             ← generated files (reports, specs, exports)
└── CLAUDE.md           ← my identity and core rules
```

Every command has YAML frontmatter with metadata (model, context cost, description). Rules auto-load by file type or domain. Skills activate on demand.

---

## What I can do

**Project management** — Sprints, burndown, capacity, KPIs, dailies, retros. Automated reports in Excel and PowerPoint. Sprint completion prediction with Monte Carlo.

**Spec-Driven Development** — Tasks become executable specs. I implement handlers, tests, and repositories in 16 languages. Agents work in isolated worktrees to avoid conflicts.

**Code intelligence** — I detect architecture patterns (Clean, Hexagonal, DDD, CQRS, Microservices), measure architectural health with fitness functions, and prioritize tech debt by business impact. I generate architecture, flow, sequence and team orgchart diagrams exportable to Draw.io, Miro or local Mermaid. I also import existing orgcharts to automatically generate team structure (`/orgchart-import`).

**Security & compliance** — SAST against OWASP Top 10, SBOM, credential scanning, regulatory compliance across 12 sectors, AI governance with model cards and EU AI Act. Pre-PR confidentiality audit with context-aware agent + HMAC-SHA256 cryptographic signature verified in CI.

**Infrastructure** — Multi-cloud (Azure, AWS, GCP) with auto-detection, minimum tier by default, and scaling only with your approval. Configurable CI/CD pipelines.

**Memory & context** — Persistent memory store (JSONL), entity recall for stakeholders and components, progressive disclosure by context cost, and cross-session continuity. Context Gate (SPEC-015) skips skill scoring on trivial prompts. Progressive Loading L0/L1/L2 (SPEC-012) reduces skill tokens by 40-60%. Intelligent Compact (SPEC-016) extracts decisions and corrections before compacting — zero-loss. Session Memory Extraction (SPEC-013) persists knowledge at session end.

**Executive reporting** — Multi-project CEO report, executive alerts, portfolio overview, DORA metrics, value stream mapping.

**Universal accessibility** — Step-by-step guided work for people with disabilities (visual, motor, ADHD, autism, dyslexia, hearing). 3-5 min micro-tasks, block detection, adaptive reformulation.

**Industry verticals** — Research lab, hardware lab, legal, healthcare, nonprofit, insurance, retail and telco — 32 specialized commands covering 8 industries with native workflows.

**Adversarial security & adaptive intelligence** — Red/Blue/Auditor pipeline with score 0-100, STRIDE/PASTA threat modeling. Skill evaluation engine with auto-detection of 7 project types and instincts system with confidence scoring.

**Autonomous modes** — Overnight sprint, code improvement loop, tech research, and dev onboarding with AI buddy. Agents propose, humans approve: `agent/*` branches, Draft PRs, mandatory human review.

**Collaboration** — Company Savia (E2E encrypted messaging), Savia Flow (Git-native PM), Travel Mode, encrypted backup, Savia School. Reference: [496 commands · 46 agents · 82 skills](docs/readme/12-comandos-agentes.md)

**Savia Mobile** — Native Android app (Kotlin/Compose) that connects to pm-workspace via [Savia Bridge](scripts/savia-bridge.py) — an HTTPS/SSE server that wraps Claude Code CLI. Real-time streaming chat, encrypted local storage, Material 3 theme. Details: [Savia Mobile](projects/savia-mobile-android/README.md)

**Savia Web** — Vue.js 3 + TypeScript + Vite web client with 10 dashboard pages (sprints, debt, DORA, capacity, etc.) and 10 ECharts components. [Savia Bridge](scripts/savia-bridge.py) exposes 8 reporting endpoints (velocity, burndown, DORA, workload, quality, debt, cycle-time, portfolio). Deploy script at `setup-savia-web.sh`. Details: [Savia Web](projects/savia-web/README.md)

**SaviaClaw** — Savia in the physical world. ESP32 with 16x2 LCD, MicroPython firmware (selftest, heartbeat, JSON commands, WiFi). Host daemon with auto-reconnect. Brain Bridge: ESP32 → Claude CLI → LCD. Savia Voice v2.4: full-duplex daemon with Silero VAD + faster-whisper + Claude stream-json + Kokoro TTS local (200ms/phrase). Conversation model with overlap classification (backchannel/stop/collaborative). Pre-cache of 64 phrases for zero latency. 7 deterministic guardrails. 77 hardware-free tests. [Roadmap](zeroclaw/ROADMAP.md)

**Dependency sovereignty** — SPEC-017: 32GB USB drive containing fully offline Savia. Standalone Python, pip wheels, Whisper/Kokoro/Ollama models, ffmpeg, jq, Node.js, Claude Code. 4 tiers (4-20GB). SaviaOS: bootable Ubuntu minimal distro from USB, boots on any x86_64 PC without touching the disk. `sovereignty-pack.sh` prepares the USB from a machine with internet.

---

## Installation

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex
```

Configurable with `SAVIA_HOME`, `--skip-tests`. Details: `install.sh --help`

---

## Documentation

| Section | Description |
|---|---|
| [Introduction & example](docs/readme_en/01-introduccion.md) | First 5 minutes |
| [Workspace structure](docs/readme_en/02-estructura.md) | Directories and layout |
| [Initial configuration](docs/readme_en/03-configuracion.md) | PAT, constants, verification |
| [Adoption guide](docs/ADOPTION_GUIDE.en.md) | Step by step for consulting firms |
| [Sprints & reports](docs/readme_en/04-uso-sprint-informes.md) | Sprint, reporting, KPIs |
| [Spec-Driven Development](docs/readme_en/05-sdd.md) | SDD: specs, agents, patterns |
| [Data flow](docs/data-flow-guide-en.md) | How the parts connect |
| [Commands & agents](docs/readme/12-comandos-agentes.md) | 496 commands + 46 agents |
| [Scenario guides](docs/guides_en/README.md) | Azure, Jira, startup, healthcare... |
| [AI Augmentation](docs/ai-augmentation-opportunities-en.md) | Opportunities by sector |
| [Context Engineering](docs/context-engineering-en.md) | Context & AI improvements |
| [Savia Mobile](projects/savia-mobile-android/README.md) | Android app + Bridge |
| [SaviaClaw Roadmap](zeroclaw/ROADMAP.md) | Hardware: ESP32 + voice + sensors |

---

## Rules that are never skipped

Not even I skip them: no hardcoding PATs, confirm before writing to Azure DevOps, read the project's CLAUDE.md before acting, no launching agents without an approved spec, no secrets in the repo, no `terraform apply` in PRO without approval, always branch + PR. Full detail in [KPIs & rules](docs/readme_en/10-kpis-reglas.md).

---

## Contributing

Use `/contribute` to create PRs directly. Use `/feedback` to open issues. Before sending anything, I validate there's no private data. Your privacy comes first.

Credits to the projects, studies, and people that inspired features: [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).

> Full changelog in [CHANGELOG.md](CHANGELOG.md) · Releases at [GitHub Releases](https://github.com/gonzalezpazmonica/pm-workspace/releases)

*🦉 Savia — your AI-powered PM. Compatible with Azure DevOps, Jira, and Savia Flow.*
