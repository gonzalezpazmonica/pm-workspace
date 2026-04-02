# Savia Models — Improvement Roadmap v2

> Audited and reprioritized 2026-04-03 (Era 173).
> Criteria: security first, public credibility second, then depth.

---

## Compliance Summary (baseline 2026-04-02)

| Project | Model | Score | % | Worst |
|---------|-------|-------|---|-------|
| savia-web | vue-spa | 15/27 | 56% | Security 33% |
| savia-monitor | rust-desktop | 6/27 | 22% | Testing 0% |
| sala-reservas | dotnet-clean | 8/27 | 30% | Structure 0% |
| savia-mobile | kotlin-android | TBD | TBD | On Linux |

**Average: 36%** — Target: 85%+

---

## Sprint 1 — SECURITY + CREDIBILITY (this week, ~30h)

> Principle: fix what's dangerous, then fix what's embarrassing.

### 1A. Security (CRITICAL — vulnerabilities in public repo)

| # | Project | Action | Effort | Why |
|---|---------|--------|--------|-----|
| C1 | savia-web | Fix v-html XSS (3 files) | 4h | Active XSS vulnerability |
| C2 | savia-web | Fix auth cookie (httpOnly) | 8h | Token theft vector |
| C4 | savia-monitor | Fix CLAUDE.md (lists 6 non-existent modules) | 1h | Misleading documentation |

### 1B. Public credibility (first impressions for GitHub visitors)

| # | Project | Action | Effort | Why |
|---|---------|--------|--------|-----|
| 05 | projects/ | README.md explaining each project | 2h | Visitors land here confused |
| 18 | docs/savia-models/ | README.md for visitors | 2h | No entry point to Savia Models |
| 19 | pm-workspace | Link Savia Models from main README | 1h | Discovery path |
| 01 | savia-monitor | Write README.md | 2h | Zero README = zero credibility |
| 03 | savia-web | Write README.md | 2h | Same |
| 06 | projects/ | PROJECT_TEMPLATE.md | 2h | Reproducibility |

### 1C. Quick wins (pm-workspace improvements, no external repos)

| # | Action | Effort | Why |
|---|--------|--------|-----|
| R5a | Add 5 new cross-cutting concerns to CROSS-CUTTING-CONCERNS.md | 4h | Gaps found in research |
| T1-T7 | Update 7 language models with toolchain findings | 2h | Low effort, high value |

**Sprint 1 total: ~30h | Compliance target: 41%**

---

## Sprint 2 — TESTING + CI (weeks 2-3, ~50h)

> Principle: untested code is untrustworthy code.

### 2A. Testing (biggest compliance gap)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| C3 | savia-monitor | Add Rust unit tests (0→5+) | 8h |
| 16 | savia-web | Verify 228 tests pass + coverage badge | 2h |
| H19 | savia-monitor | Coverage config (tarpaulin + vitest) | 2h |
| 15 | sala-reservas | Implement specs AB101+AB102 | 6h |

### 2B. CI pipelines (no CI = no quality guarantee)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H4 | savia-web | CI pipeline (lint + test + build) | 8h |
| H9 | savia-monitor | CI pipeline (clippy + cargo test + npm test) | 8h |
| M20 | sala-reservas | CI pipeline (build + test + format) | 3h |
| 14 | ALL | CI badge in README | 4h |

### 2C. Code quality (enables CI to catch real issues)

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H3 | savia-web | ESLint + Prettier config | 4h |
| H18 | savia-monitor | Fix unwrap() on icon loading | 1h |
| H24 | sala-reservas | global.json with SDK pin | 0.5h |
| H26 | sala-reservas | Quality gates (format + security scan) | 1h |

**Sprint 2 total: ~50h | Compliance target: 56%**

---

## Sprint 3 — ARCHITECTURE + STRUCTURE (weeks 4-5, ~45h)

> Principle: structure enables sustainable velocity.

### 3A. Architecture refactoring

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H1 | savia-web | Extract services/ layer | 4h |
| H2 | savia-web | Error handling (no silent swallowing) | 4h |
| H6 | savia-monitor | Refactor main.rs (<40 lines) | 4h |
| H7 | savia-monitor | Async migration (tokio) | 8h |
| H8 | savia-monitor | thiserror + error handling | 4h |
| H11 | savia-monitor | Module structure alignment | 4h |
| H12 | sala-reservas | .NET solution structure (4 projects) | 3h |
| H13 | sala-reservas | Domain/Common layers | 2h |

### 3B. Documentation alignment

| # | Project | Action | Effort |
|---|---------|--------|--------|
| 04 | ALL | Add ARCHITECTURE.md (brief, C4 L1-L2) | 6h |
| H21 | savia-monitor | Layer Assignment Matrix in CLAUDE.md | 2h |
| L11 | ALL | Philosophy sections in CLAUDE.md | 3h |

**Sprint 3 total: ~45h | Compliance target: 70%**

---

## Sprint 4 — HARDENING (weeks 6-7, ~45h)

> Principle: secure, validated, observable.

### 4A. Security hardening

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H10 | savia-monitor | CSP + IPC validation | 4h |
| H20 | savia-monitor | TLS cert validation (reqwest) | 1h |
| M2 | savia-web | CSP headers | 2h |
| M3 | savia-web | Zod API validation | 4h |
| H25 | sala-reservas | CORS + rate limiting | 1h |

### 4B. Testing depth

| # | Project | Action | Effort |
|---|---------|--------|--------|
| M1 | savia-web | E2E screenshots (all specs) | 8h |
| M11 | savia-monitor | Vue component tests | 8h |
| M12 | savia-monitor | IPC integration tests | 4h |
| M18 | sala-reservas | Coverlet + per-layer coverage targets | 1h |

### 4C. DevOps maturity

| # | Project | Action | Effort |
|---|---------|--------|--------|
| H5 | savia-web | Bundle budget enforcement | 2h |
| M10 | savia-web | Docker containerization | 3h |
| M13 | savia-monitor | Release profile (LTO, strip) | 1h |
| M19 | sala-reservas | .editorconfig + analyzers | 1h |

**Sprint 4 total: ~45h | Compliance target: 78%**

---

## Sprint 5 — SHOWCASE (weeks 8-9, ~35h)

> Principle: show don't tell.

| # | Project | Action | Effort |
|---|---------|--------|--------|
| 20 | savia-web | Screenshot gallery in README | 4h |
| 21 | savia-monitor | Screenshot of tray + dashboard | 2h |
| 22 | ALL | Savia Model compliance badge | 2h |
| 11 | savia-web | CONTRIBUTING.md | 2h |
| L4 | savia-web | ARCHITECTURE + CONTRIBUTING | 4h |
| L5 | savia-monitor | README + ARCHITECTURE | 4h |
| 26 | savia-web | Lighthouse score in README | 4h |
| 25 | pm-workspace | Blog post for launch | 4h |
| 24 | ALL models | Quick start section | 4h |
| 23 | docs/savia-models/ | Gap analysis as reusable tool | 4h |

**Sprint 5 total: ~35h | Compliance target: 85%**

---

## Sprint 6 — EXCELLENCE (weeks 10-11, ~40h)

> Principle: from good to exemplary.

| # | Action | Effort |
|---|--------|--------|
| L1 | savia-web: Visual regression tests | 8h |
| L2 | savia-web: Error tracking (Sentry) | 4h |
| L3 | savia-web: Lighthouse CI | 4h |
| L8 | sala-reservas: Docker + health checks | 3h |
| L9 | sala-reservas: OpenTelemetry + Serilog | 3h |
| L10 | sala-reservas: Integration tests (TestContainers) | 4h |
| M14 | savia-monitor: Auto-update mechanism | 8h |
| L6 | savia-monitor: Crash reporting | 4h |

**Sprint 6 total: ~40h | Compliance target: 87%**

---

## Phase 2 — EVOLUTION (weeks 12+)

### Research-driven Standard Additions (already codified in STANDARD)

| # | Item | Status |
|---|------|--------|
| R1 | AI5: Agent Emotional Architecture | DONE (Era 173) |
| R2 | AI6: Context Engineering | DONE (Era 173) |
| R3 | AI7: Agent Interoperability | DONE (Era 173) |
| R6 | ISO 25010:2023 (9 characteristics) | DONE (Era 173) |
| R4 | Business Rule Annotations per language | Ready (8h) |
| R5 | 5 new cross-cutting concerns | Sprint 1 (4h partial) |
| R7 | 12+4 Factor App checklist | Ready (4h) |

### New Language Models

| # | Model | Effort | Prerequisite |
|---|-------|--------|-------------|
| N1 | savia-model-swift | 16h | After current 3 at 70%+ |
| N2 | savia-model-flutter | 16h | After current 3 at 70%+ |
| N3 | savia-model-php | 16h | After current 3 at 70%+ |
| N4 | savia-model-ruby | 16h | After current 3 at 70%+ |

### SPEC v0.2 Layers (Agentic Orchestrator)

| # | Layer | Effort | Prerequisite |
|---|-------|--------|-------------|
| L1 | Role Perspectives (12 roles) | 24h | Projects exemplify patterns |
| L2 | End-to-End Traceability | 16h | SDD + Flow integration |
| L3 | Pedagogical Scaffolding | 20h | Templates per language |

### Agent Infrastructure

| # | Item | Effort | Priority |
|---|------|--------|----------|
| A1 | Agent Cards (capability registry) | 8h | P1 |
| A2 | Formal task states (input_required) | 4h | P1 |
| A7 | Conflict precedents | 4h | P2 |
| A8 | Phase-aware concurrency | 4h | P2 |
| A9 | Sprint journal automation | 4h | P2 |
| A3 | Context manifests | 8h | P2 |
| A4 | Context evaluator | 12h | P2 |
| A5 | Agent trust scoring | 16h | P3 |
| A6 | Push notifications (async) | 8h | P3 |

---

## Compliance Progression

| After | savia-web | monitor | sala-reservas | Avg |
|-------|-----------|---------|---------------|-----|
| Today | 56% | 22% | 30% | 36% |
| Sprint 1 | 63% | 30% | 30% | 41% |
| Sprint 2 | 70% | 44% | 52% | 56% |
| Sprint 3 | 78% | 63% | 63% | 68% |
| Sprint 4 | 85% | 74% | 70% | 76% |
| Sprint 5 | 89% | 81% | 78% | 83% |
| Sprint 6 | 93% | 85% | 82% | 87% |

---

## Summary

| Phase | Hours | Timeframe |
|-------|-------|-----------|
| Sprint 1: Security + Credibility | 30h | Week 1 |
| Sprint 2: Testing + CI | 50h | Weeks 2-3 |
| Sprint 3: Architecture | 45h | Weeks 4-5 |
| Sprint 4: Hardening | 45h | Weeks 6-7 |
| Sprint 5: Showcase | 35h | Weeks 8-9 |
| Sprint 6: Excellence | 40h | Weeks 10-11 |
| **Phase 1 subtotal** | **245h** | **11 weeks** |
| Phase 2: New models (4) | 64h | Weeks 12-15 |
| Phase 2: SPEC v0.2 layers | 60h | Weeks 12-15 |
| Phase 2: Agent infrastructure | 68h | Weeks 16+ |
| Phase 2: Remaining research | 16h | Ongoing |
| **Grand total** | **~453h** | |

---

*Audited: 2026-04-03 | Next review: after Sprint 1*
