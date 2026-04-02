# Savia Models — Improvement Roadmap

> Consolidated from gap analyses against ideal Savia Models.
> Date: 2026-04-02

---

## Compliance Summary

| Project | Model | Score | % | Worst |
|---------|-------|-------|---|-------|
| savia-web | vue-spa | 15/27 | 56% | Security 33% |
| savia-monitor | rust-desktop | 6/27 | 22% | Testing 0% |
| sala-reservas | dotnet-clean | 8/27 | 30% | Structure 0% |
| savia-mobile | kotlin-android | TBD | TBD | On Linux |

**Average (3 measured): 36%**

---

## Public Showcase Tier — Our projects are our business card

### PUB-P0: First impressions (this week, 25h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| 01 | savia-monitor | Write README.md | 2h |
| 02 | savia-monitor | Fix CLAUDE.md (6 non-existent modules) | 1h |
| 03 | savia-web | Write README.md | 2h |
| 04 | ALL | Add ARCHITECTURE.md (brief) | 6h |
| 05 | projects/ | Create README.md (what each project is) | 2h |
| 06 | projects/ | Create PROJECT_TEMPLATE.md | 2h |
| 07 | savia-web | Fix v-html XSS (sanitize 3 files) | 4h |
| 08 | sala-reservas | Create .NET solution scaffold | 3h |
| 09 | proyecto-alpha | Mark as spec-only or add stubs | 1h |
| 10 | proyecto-beta | Add backlog examples | 2h |

### PUB-P1: Make exemplary (weeks 2-4, 34h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| 11 | savia-web | CONTRIBUTING.md | 2h |
| 12 | savia-monitor | Add 5+ Rust unit tests | 8h |
| 13 | savia-web | ESLint + Prettier | 4h |
| 14 | ALL | CI badge in README | 4h |
| 15 | sala-reservas | Implement AB101+AB102 specs | 6h |
| 16 | savia-web | Verify 228 tests pass + coverage badge | 2h |
| 17 | savia-monitor | CI with clippy + cargo test + npm test | 4h |
| 18 | docs/savia-models/ | README.md for visitors | 2h |
| 19 | pm-workspace | Link Savia Models from main README | 1h |

### PUB-P2: Showcase excellence (weeks 5-8, 28h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| 20 | savia-web | Screenshot gallery in README | 4h |
| 21 | savia-monitor | Screenshot of tray + dashboard | 2h |
| 22 | ALL | Savia Model compliance badge | 2h |
| 23 | docs/savia-models/ | Gap analysis as reusable tool | 4h |
| 24 | ALL models | Quick start section | 4h |
| 25 | pm-workspace | Blog post for launch | 4h |
| 26 | savia-web | Lighthouse score in README | 4h |
| 27 | ALL | Verify 150-line rule | 4h |

---

## Technical Compliance Tiers

### Tier 0: CRITICAL (week 1, 21h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| C1 | savia-web | Fix v-html XSS (3 files) | 4h |
| C2 | savia-web | Fix auth cookie (httpOnly) | 8h |
| C3 | savia-monitor | Add Rust tests (0 coverage) | 8h |
| C4 | savia-monitor | Fix CLAUDE.md lies | 1h |

### Tier 1: HIGH (weeks 2-3, 65h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H1 | savia-web | services/ layer | 4h |
| H2 | savia-web | Error handling | 4h |
| H3 | savia-web | ESLint + Prettier | 4h |
| H4 | savia-web | CI pipeline | 8h |
| H5 | savia-web | Bundle budget | 2h |
| H6 | savia-monitor | Refactor main.rs (<40 lines) | 4h |
| H7 | savia-monitor | Async migration | 8h |
| H8 | savia-monitor | thiserror + error handling | 4h |
| H9 | savia-monitor | CI pipeline | 8h |
| H10 | savia-monitor | CSP + IPC validation | 4h |
| H11 | savia-monitor | Module structure | 4h |
| H12 | sala-reservas | .NET solution structure | 3h |
| H13 | sala-reservas | Domain/Common | 2h |
| H14 | sala-reservas | Spec AB101 | 4h |
| H15 | sala-reservas | Spec AB102 | 2h |

### Tier 1b: Gaps found in cross-check (20h)

These gaps were in the analysis but missing from the original roadmap.

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H16 | savia-web | Enforce dependency direction (lint rule) | 2h |
| H17 | savia-web | Expand types/ (extract from stores/components) | 4h |
| H18 | savia-monitor | Fix unwrap() on icon loading | 1h |
| H19 | savia-monitor | Add coverage config (tarpaulin + vitest) | 2h |
| H20 | savia-monitor | TLS cert validation for reqwest | 1h |
| H21 | savia-monitor | Layer Assignment Matrix in CLAUDE.md | 2h |
| H22 | savia-monitor | Create first SDD spec | 4h |
| H23 | sala-reservas | MediatR pipeline behaviors | 2h |
| H24 | sala-reservas | global.json with SDK pin | 0.5h |
| H25 | sala-reservas | CORS + rate limiting in API spec | 1h |
| H26 | sala-reservas | Quality gates: add format + security scan | 1h |

### Tier 2: MEDIUM (weeks 4-6, 68h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| M1 | savia-web | E2E screenshots (all 20) | 8h |
| M2 | savia-web | CSP headers | 2h |
| M3 | savia-web | Zod API validation | 4h |
| M4 | savia-web | i18n completion | 2h |
| M5 | savia-web | Path aliases (@/) | 1h |
| M6 | savia-web | Layer Assignment Matrix | 2h |
| M7 | savia-web | Add utils/ and constants/ | 1h |
| M8 | savia-web | E2E responsive breakpoints | 4h |
| M9 | savia-web | Quality gate config in CLAUDE.md | 1h |
| M10 | savia-web | Docker containerization | 3h |
| M11 | savia-monitor | Vue component tests | 8h |
| M12 | savia-monitor | IPC integration tests | 4h |
| M13 | savia-monitor | Release profile (LTO, strip) | 1h |
| M14 | savia-monitor | Auto-update | 8h |
| M15 | savia-monitor | Type sharing (ts-rs) | 4h |
| M16 | savia-monitor | Cargo workspace structure | 2h |
| M17 | sala-reservas | Infra + API specs | 8h |
| M18 | sala-reservas | Coverlet + per-layer targets | 1h |
| M19 | sala-reservas | .editorconfig + analyzers | 1h |
| M20 | sala-reservas | CI pipeline | 3h |
| M21 | sala-reservas | Specs: primary constructors + sealed | 1h |

### Tier 3: LOW (weeks 7+, 49h)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| L1 | savia-web | Visual regression | 8h |
| L2 | savia-web | Error tracking (Sentry) | 4h |
| L3 | savia-web | Lighthouse CI | 4h |
| L4 | savia-web | ARCHITECTURE + CONTRIBUTING | 4h |
| L5 | savia-monitor | README + ARCHITECTURE | 4h |
| L6 | savia-monitor | Crash reporting | 4h |
| L7 | savia-monitor | Code signing | 4h |
| L8 | sala-reservas | Docker + health checks | 3h |
| L9 | sala-reservas | OpenTelemetry + Serilog | 3h |
| L10 | sala-reservas | Integration tests (TestContainers) | 4h |
| L11 | ALL | Philosophy sections in CLAUDE.md | 3h |
| L12 | projects/ | README.md + PROJECT_TEMPLATE | 4h |

---

## Grand Total

Showcase: 87h (P0 25h + P1 34h + P2 28h)
Technical: 223h (T0 21h + T1 65h + T1b 20h + T2 68h + T3 49h)
Combined after dedup: ~250h over ~11 weeks
Target: 36% to 85%+ | Zero gaps unplanned (verified 2026-04-02)

---

## Expected Compliance Progression

| After | savia-web | monitor | sala-reservas | Avg |
|-------|-----------|---------|---------------|-----|
| Today | 56% | 22% | 30% | 36% |
| Tier 0 | 63% | 30% | 30% | 41% |
| Tier 1 | 78% | 56% | 56% | 63% |
| Tier 2 | 85% | 74% | 70% | 76% |
| Tier 3 | 93% | 85% | 82% | 87% |

---

## Research-Driven Improvements (Era 173)

> From 4 parallel research streams (2026-04-02/03):
> Savia Models v0.2 spec research, per-language toolchain audit,
> architecture standards audit, Anthropic emotions paper, arXiv
> context engineering paper, A2A protocol analysis.

### Cross-Cutting: Savia Model Standard Additions

| # | Improvement | Source | Effort | Priority |
|---|------------|--------|--------|----------|
| R1 | **AI5: Agent Emotional Architecture** — stress monitoring, calm design, desperation prevention | Anthropic "Emotion concepts" (2026-04-02) | 8h | DONE (Era 173) |
| R2 | **AI6: Context Engineering** — context manifests, 3-tier lifecycle, evaluator pattern | arXiv:2512.05470 "Everything is Context" | 4h | DONE (standard) |
| R3 | **AI7: Agent Interoperability** — Agent Cards, formal task states, A2A patterns | Google A2A Protocol + OpenA2A | 4h | DONE (standard) |
| R4 | Business Rule Annotations per language — novel contribution, no industry standard exists | Research finding (gap) | 8h | P1 |
| R5 | 5 new cross-cutting concerns: feature flags, GDPR by design, SBOM/supply chain, tech debt quantification, docs-as-code | Standards audit | 12h | P1 |
| R6 | ISO 25010:2023 update (9 characteristics, not 8 — added Safety) | ISO audit | 2h | DONE (standard) |
| R7 | 12+4 Factor App checklist per model | Google Cloud proposal | 4h | P2 |

### Per-Model: Toolchain Updates

| # | Model | Update | Source | Effort |
|---|-------|--------|--------|--------|
| T1 | TypeScript | Biome as ESLint alternative, Drizzle as Prisma alternative, Vitest confirmed winner | Toolchain research | 2h |
| T2 | .NET | Wolverine replacing MediatR (licensing), ErrorOr for Result types, .NET 10 LTS target | Toolchain research | 2h |
| T3 | Python | uv confirmed winner (replaces pip/poetry), Ruff confirmed (replaces flake8+black) | Toolchain research | 1h |
| T4 | Java | Virtual Threads over Reactor for new projects, Gradle KTS confirmed | Toolchain research | 2h |
| T5 | Go | stdlib net/http (1.22+) now sufficient, sqlc confirmed, slog (stdlib) adopted | Toolchain research | 1h |
| T6 | Rust | Axum confirmed winner, thiserror/anyhow convention documented | Toolchain research | 1h |
| T7 | Kotlin | KSP migration from KAPT, Hilt confirmed, Compose Navigation | Toolchain research | 1h |

### New Models (SPEC v0.2)

| # | Model | Architecture | Key Tech | Effort |
|---|-------|-------------|----------|--------|
| N1 | savia-model-swift | MVVM + SwiftUI, TCA for complex | Swift 6.2, async/await, SwiftData | 16h |
| N2 | savia-model-flutter | Feature-First, Riverpod 3 | Dart 3, go_router, drift | 16h |
| N3 | savia-model-php | Service Layer + DDD | Laravel 12, Pest, Livewire | 16h |
| N4 | savia-model-ruby | Convention + POROs | Rails 8, Hotwire, Solid Queue | 16h |

### SPEC v0.2 Layers (Agentic Orchestrator)

| # | Layer | Content | Effort |
|---|-------|---------|--------|
| L1 | Role Perspectives | 12 roles: artifacts, decisions, quality gates, AI assistance per role | 24h |
| L2 | End-to-End Traceability | OpenTelemetry per stack, business rule annotations, correlation IDs, reverse queries | 16h |
| L3 | Pedagogical Scaffolding | Bloom's taxonomy mapping, ZPD progression (80% AI → 20%), 5 projects per language | 20h |

### pm-workspace Agent Infrastructure

| # | Improvement | Source | Effort | Priority |
|---|------------|--------|--------|----------|
| A1 | Agent Cards (machine-readable capability registry) | A2A Protocol | 8h | P1 |
| A2 | Formal task state machine (add input_required, canceled) | A2A Protocol | 4h | P1 |
| A3 | Context Manifest generation per agent invocation | arXiv:2512.05470 | 8h | P2 |
| A4 | Post-response context evaluator (hallucination/contradiction check) | arXiv:2512.05470 | 12h | P2 |
| A5 | Agent trust scoring (behavioral analysis → permission adjustment) | OpenA2A AIM | 16h | P3 |
| A6 | Push notification pattern for async multi-agent workflows | A2A Protocol | 8h | P3 |
| A7 | Conflict precedents (pre-defined resolution when agents disagree) | Nanostack `/conductor` | 4h | P2 |
| A8 | Phase-aware concurrency (prevent writes during read-only phases) | Nanostack `guard` | 4h | P2 |
| A9 | Structured sprint journal (auto-document lessons per sprint) | Nanostack `/compound` | 4h | P2 |

---

## Grand Total (Updated)

| Category | Hours | Status |
|----------|-------|--------|
| Showcase (P0-P2) | 87h | Planned |
| Technical Compliance (T0-T3) | 223h | Planned |
| Research-driven standard | 12h | DONE (Era 173) |
| Toolchain updates (T1-T7) | 10h | Ready |
| New models (N1-N4) | 64h | Ready |
| SPEC v0.2 layers (L1-L3) | 60h | Ready |
| Agent infrastructure (A1-A6) | 56h | Ready |
| **TOTAL** | **~512h** | |

---

*Updated: 2026-04-03 | Next review: after Tier 0 + toolchain updates*
