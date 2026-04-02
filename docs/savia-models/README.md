# Savia Models

> Comprehensive software development models — one per language —
> that codify how to build, test, deploy, and maintain software
> correctly, integrating Savia Flow (methodology), Savia Shield
> (data sovereignty), and SDD (agentic development).

---

## What Are Savia Models?

Savia Models are **executable specifications**, not guidelines. Each model
covers the full software development lifecycle for a specific language:
philosophy, architecture, project structure, code patterns, testing,
security, DevOps, anti-patterns, and agentic integration.

They exist because AI agents amplify both good and bad practices ([DORA 2025](https://dora.dev/research/2025/dora-report/)).
These models are the strong foundation that determines whether AI helps or hurts.

## Available Models

| # | Model | Language | Application Types |
|---|-------|----------|-------------------|
| 01 | [Vue 3 SPA](01-vue-spa.md) | TypeScript | SPA, SSR, PWA |
| 02 | [.NET Clean Architecture](02-dotnet-clean.md) | C# | REST API, CQRS, microservices |
| 03 | [Kotlin Android](03-kotlin-android.md) | Kotlin | Android, Compose, offline-first |
| 04 | [Rust + Tauri Desktop](04-rust-tauri-vue-desktop.md) | Rust | Desktop, CLI, system tools |
| 05 | [Python](05-python.md) | Python | FastAPI, Django, CLI, ML |
| 06 | [Java](06-java.md) | Java | Spring Boot, microservices, batch |
| 07 | [Go](07-go.md) | Go | APIs, CLI, infrastructure tools |

**Coming soon**: Swift/iOS, Flutter/Dart, PHP/Laravel, Ruby/Rails.

## Universal Standard

The [Savia Model Standard](SAVIA-MODEL-STANDARD.md) defines what every
project must address — language-agnostic, architecture-agnostic. Each
per-language model extends it with idiomatic implementations.

21 cross-cutting concerns. 15 parts. Covering architecture, testing,
security, observability, CI/CD, documentation, accessibility, and
agentic integration.

## The 9 Sections (per model)

| # | Section | What it covers |
|---|---------|---------------|
| 1 | Philosophy and Culture | Why this model exists, trade-offs accepted |
| 2 | Architecture Principles | Layers, dependencies, patterns, boundaries |
| 3 | Project Structure | Exact directory layout, copy-paste ready |
| 4 | Code Patterns | Language-idiomatic patterns with examples |
| 5 | Testing and Quality | Complete pyramid, coverage targets |
| 6 | Security | OWASP, secrets, auth, data sovereignty |
| 7 | DevOps and Operations | CI/CD, Docker, monitoring, environments |
| 8 | Anti-Patterns | 15 DOs + 15 DONTs with rationale |
| 9 | Agentic Integration | Layer assignment, SDD specs, quality gates |

## Gap Analysis

Every project is scored 0-3 per section against its model:

- [savia-web gap analysis](gap-analysis-savia-web.md) — 56%
- [savia-monitor gap analysis](gap-analysis-savia-monitor.md) — 22%
- [sala-reservas gap analysis](gap-analysis-sala-reservas.md) — 30%

The [Improvement Roadmap](ROADMAP-IMPROVEMENTS.md) tracks progress
from 36% average to 85%+ target.

## Cross-Cutting Concerns

The [Cross-Cutting Concerns](CROSS-CUTTING-CONCERNS.md) document
defines topics every model must address: SOLID, i18n, migrations,
observability, Docker, testing, git strategy, caching, API docs,
accessibility, environments, error handling, and performance.

## Research Foundations

Built on empirical research, not opinions:

- **DORA 2025**: AI amplifies team dysfunction as often as capability
- **Anthropic 2026**: [Functional emotions in LLMs](https://www.anthropic.com/research/emotion-concepts-function) influence agent behavior
- **arXiv 2512.05470**: Context engineering via file-system abstraction
- **A2A Protocol**: Agent-to-agent communication standards (Google/Linux Foundation)
- **ISO 25010:2023**: Software quality model (9 characteristics)
- **OWASP 2025**: Supply chain security elevated to A03

## Philosophy

1. **Define perfection first, measure reality second** — standards from
   research, not from existing flawed code
2. **Executable over aspirational** — every section is copy-paste usable
3. **Philosophy before specification** — WHY before WHAT enables
   principled deviation

---

*v0.1 — 2026-04-02 | [Full vision](00-VISION.md) | [SPEC v0.2](SPEC-SAVIA-MODELS-V02.md)*
