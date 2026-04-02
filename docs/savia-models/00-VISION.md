# Savia Models — Vision Document v0.1

> Comprehensive software development models — one per stack x architecture
> x team scale — documented as executable Markdown specifications for
> humans and AI agents. Each model codifies how to build, test, deploy,
> and maintain software correctly, integrating Savia Flow (methodology),
> Savia Shield (data sovereignty), and SDD (agentic development).

---

## Why Savia Models Exist

Teams repeat the same architectural mistakes because knowledge is
fragmented. AI agents amplify both good and bad practices — DORA 2025
proved "AI amplifies team dysfunction as often as capability."

Savia Models provide complete, opinionated, executable specifications.
Not guidelines. Models. Like awesome-design-md's DESIGN.md but for the
entire software development lifecycle.

## The 3 Principles

### 1. Define perfection first, measure reality second

We do NOT derive best practices from existing code. We define the ideal
from global research and proven patterns, then measure our own projects
against that ideal. Anchoring on existing code normalizes its flaws.

### 2. Executable over aspirational

Every model is copy-paste usable: project structure, quality gates,
agent integration, CI/CD pipeline — all concrete and actionable.

### 3. Philosophy before specification

Every section starts with WHY before WHAT. Understanding intent
enables principled deviation. Inspired by awesome-design-md.

---

## The 9 Sections (adapted from awesome-design-md)

| # | Section | Purpose |
|---|---------|---------|
| 1 | Philosophy and Culture | Why this model exists, trade-offs accepted |
| 2 | Architecture Principles | Layers, dependencies, patterns, boundaries |
| 3 | Project Structure | Exact directory layout, copy-paste ready |
| 4 | Code Patterns | Language-idiomatic patterns with examples |
| 5 | Testing and Quality | Test pyramid, coverage targets, what NOT to test |
| 6 | Security and Data Sovereignty | OWASP, secrets, auth, Savia Shield integration |
| 7 | DevOps and Operations | CI/CD, deployment, monitoring, environments |
| 8 | Anti-Patterns and Guardrails | 15 DOs + 15 DONTs with rationale |
| 9 | Agentic Integration | Layer assignment matrix, SDD specs, quality gates |

---

## Dimensions

Each model sits at the intersection of:

**Stack**: Python, Rust, .NET, Java, TypeScript, Go, Kotlin, Swift, Vue, React, Angular, Flutter

**Architecture**: Monolith, Microservices, Desktop, Mobile, Serverless, CLI, Library

**Team Scale**: Solo (1), Small (2-5), Growth (6-20), Enterprise (20+)

---

## Phase 1 Models

| # | Model | Stack | Exemplar |
|---|-------|-------|----------|
| 1 | savia-model-vue-spa | Vue 3 + TS + Vite | savia-web |
| 2 | savia-model-dotnet-clean | .NET 8 + EF Core | sala-reservas |
| 3 | savia-model-kotlin-android | Kotlin + Compose | savia-mobile |
| 4 | savia-model-rust-desktop | Rust + Tauri + Vue | savia-monitor |

Phase 2: Python/FastAPI, NestJS, Java/Spring, Go, React, Angular,
microservices, serverless, Flutter.

---

## Gap Analysis Protocol

Each project scored 0-3 per section against its model:
- 0 absent, 1 partial, 2 compliant, 3 exemplary
- Gaps become the improvement roadmap
- Our projects are the first exemplars — not excused from scrutiny

---

## Sources

- awesome-design-md (VoltAgent) — 9-section executable spec format
- Claude Code — hook-first, lazy-loading, subagent isolation
- DORA 2025 — AI amplifies dysfunction as often as capability
- Thoughtworks/arXiv — SDD as emerging standard methodology
- Jason Taylor/Ardalis — Clean Architecture .NET templates
- Three Dots Labs — Clean Architecture Go (pragmatic)
- mehdihadeli/awesome-software-architecture — curated patterns
- Anthropic 2026 Agentic Coding Trends Report
- Hexagonal Architecture convergence across all stacks

---

*v0.1 — 2026-04-02 | Status: Draft*
