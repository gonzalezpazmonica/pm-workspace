# Savia Model Standard v1.0 — The Universal Base Model

> The common foundation all Savia Models inherit from. Language-agnostic,
> architecture-agnostic, team-scale-agnostic. Each per-language model
> extends this standard with idiomatic implementations.
>
> Status: DRAFT | Date: 2026-04-02
> Sources: DORA 2025, Anthropic Agentic Trends 2026, OWASP 2025,
> ISO 25010:2023, ISO 42001, OpenTelemetry, CNCF, 12+4 Factor App

---

## How to Use This Document

This standard defines WHAT every software project must address.
Per-language Savia Models define HOW using idiomatic tools.

```
SAVIA-MODEL-STANDARD.md (this file — universal WHAT)
    ↓ inherited by
savia-model-{language}.md (per-language HOW)
    ↓ applied to
projects/{project}/CLAUDE.md (per-project overrides)
```

**Customization**: Projects override via their CLAUDE.md. If a section
says "MUST" it's non-negotiable. "SHOULD" means override with reason.
"MAY" means optional based on project needs.

---

## Part I — Philosophy

### P1. Define Perfection First, Measure Reality Second

We do NOT derive best practices from existing code. We define the ideal
from global research and proven patterns, then measure projects against
that ideal. Anchoring on existing code normalizes its flaws.

### P2. Executable Over Aspirational

Every section is copy-paste usable: project structure, quality gates,
CI pipeline, agent integration — all concrete and actionable.

### P3. Philosophy Before Specification

Every section starts with WHY before WHAT. Understanding intent enables
principled deviation. Blind rule-following produces brittle systems.

### P4. The DORA Amplifier Principle

> "AI doesn't fix a team; it amplifies what's already there." — DORA 2025

AI agents amplify both good and bad practices. This standard IS the
strong foundation that determines whether AI helps or hurts. 21% more
tasks completed per developer with AI, but organizational delivery
metrics stay flat without foundational capabilities (the "productivity
paradox"). The greatest return comes from quality of internal platforms,
clarity of workflows, and alignment of teams — not the tools.

### P5. The Agentic Orchestrator

One person, assisted by Savia, can fulfill all roles of software
development. Not by doing everything alone, but by orchestrating AI
agents that each embody a role perspective. The 12 roles converge:

| Role | Decisions | Artifacts |
|------|-----------|-----------|
| Product Owner | Requirements, priority, acceptance | PRD, acceptance criteria |
| Project Manager | Planning, risk, capacity, ceremonies | Sprint plans, DORA metrics |
| Business Analyst | Domain modeling, rules, stories | Domain model, data dictionary |
| Architect | Patterns, layers, boundaries, NFRs | ADRs, C4 diagrams |
| Scrum Master | Flow, blockers, ceremonies | Retrospectives, velocity |
| Tech Lead | Standards, review, mentoring, debt | Review checklist, tech radar |
| Backend Developer | API, DB, services, queues, cache | Code, migrations, API docs |
| Frontend Developer | UI, state, UX, a11y, responsive | Components, E2E tests |
| DBA | Schema, indexes, queries, backups | Migrations, query plans |
| Security Auditor | OWASP, pentesting, compliance | Threat models, scan reports |
| DevOps Engineer | CI/CD, Docker, K8s, monitoring, IaC | Pipelines, Dockerfiles |
| Release Manager | Deploy strategy, rollback, flags | Release notes, changelogs |

---

## Part II — Architecture

### A1. The Dependency Rule (Universal)

Source code dependencies MUST point inward. The domain/core layer
depends on nothing. Frameworks, databases, and transport mechanisms
are implementation details plugged in at the edges.

```
┌─────────────────────────────────────────────┐
│  Presentation / API / UI                    │  ← Knows about Application
├─────────────────────────────────────────────┤
│  Application (Use Cases / Handlers)         │  ← Knows about Domain
├─────────────────────────────────────────────┤
│  Domain (Entities, Rules, Interfaces)       │  ← Knows about NOTHING
├─────────────────────────────────────────────┤
│  Infrastructure (DB, APIs, Messaging)       │  ← Implements Domain interfaces
└─────────────────────────────────────────────┘
```

Per-language implementation:

| Language | Pattern Name | Layers |
|----------|-------------|--------|
| C#/.NET | Clean Architecture | API → Application → Domain ← Infrastructure |
| Java | Hexagonal / Clean | API → Application → Domain ← Adapters |
| Python | Hexagonal | API → Services → Domain ← Repositories |
| Go | Flat-then-layered | handlers → services → domain ← storage |
| Rust | Core-Shell (desktop) or Hexagonal (API) | varies |
| TypeScript | 6-Layer (SPA) or Hexagonal (API) | views → components → composables → stores → services → types |
| Kotlin | Clean (3-layer) | UI → Domain ← Data |
| Swift | MVVM or TCA | Views → ViewModels → UseCases → Repositories |
| Flutter | Feature-First | UI → Domain ← Data |
| PHP | Service Layer + DDD | Controllers → Services → Domain ← Repositories |
| Ruby | Convention (Rails) | Controllers → Models → Services |

### A2. Architecture Selection Matrix

| Application Type | Default Pattern | Alternative |
|------------------|----------------|-------------|
| REST API (monolith) | Clean Architecture | Vertical Slice (hybrid) |
| REST API (microservices) | DDD Bounded Contexts | Event-Driven Choreography |
| SPA Frontend | Component + Composable | Micro-frontends (multi-team) |
| Mobile Native | MVVM | MVI (complex state) |
| Desktop | Core-Shell (Tauri) | Native framework |
| CLI | Command Pattern (Cobra/clap) | Plugin architecture |
| Serverless | Choreography | Orchestration (Step Functions) |
| Data Pipeline / ML | FTI Pipeline | DAG orchestration |

### A3. SOLID Principles — Per-Language Mapping

| Principle | OOP (C#, Java, Kotlin) | Functional-leaning (Go, Rust) | Component (Vue, React, Swift) |
|-----------|----------------------|------------------------------|------------------------------|
| Single Responsibility | One reason to change per class | One concern per package/module | One concern per component |
| Open/Closed | Extend via interfaces + DI | Extend via composition + traits | Extend via props + slots |
| Liskov Substitution | Interface contracts | Trait bounds / interface impl | Component contracts (props) |
| Interface Segregation | Small, focused interfaces | Accept interfaces at consumers | Small prop interfaces |
| Dependency Inversion | Constructor injection + DI containers | Accept interfaces, return structs | Composables + provide/inject |

---

## Part III — Project Structure

### S1. Directory Layout Principles

Every project MUST have:

```
project-root/
├── README.md               ← What, why, how to run (MUST)
├── CLAUDE.md               ← AI agent instructions (MUST)
├── ARCHITECTURE.md          ← C4 Level 1-2, ADRs summary (SHOULD)
├── CONTRIBUTING.md          ← How to contribute (SHOULD)
├── CHANGELOG.md             ← Keep a Changelog format (MUST)
├── .editorconfig            ← Consistent formatting (MUST)
├── .gitignore               ← Language-appropriate (MUST)
├── Dockerfile               ← Multi-stage build (SHOULD)
├── docker-compose.yml       ← Local dev environment (SHOULD)
├── src/ or source/          ← Application code (MUST)
├── tests/                   ← Test code (MUST)
├── docs/                    ← Extended documentation (SHOULD)
│   └── decisions/           ← ADRs in MADR 4.0 format (SHOULD)
├── scripts/                 ← Automation scripts (MAY)
├── infra/ or infrastructure/← IaC (MAY)
└── ci/ or .github/          ← CI/CD pipeline config (MUST)
```

### S2. File Size Rule

No source file SHOULD exceed 150 lines. If it does:
- Extract classes/functions to separate files (SRP)
- Split documentation into linked sections
- Create helper modules for shared logic

### S3. Naming Conventions

| Artifact | Convention |
|----------|-----------|
| Files (code) | Per-language standard (PascalCase C#, snake_case Python, etc.) |
| Directories | kebab-case or per-language convention |
| Branches | `feature/XXXX-description`, `fix/XXXX-description` |
| Commits | `type(scope): description` (Conventional Commits) |
| Versions | Semantic Versioning 2.0.0 (vMAJOR.MINOR.PATCH) |
| Environment config | SCREAMING_SNAKE_CASE |

---

## Part IV — Code Patterns

### C1. Error Handling Philosophy

| Layer | Pattern | Rationale |
|-------|---------|-----------|
| Domain / Application | Result types (`Result<T,E>`) | Business errors are expected, not exceptional |
| Infrastructure | Try/Catch or `?` propagation | I/O failures are truly exceptional |
| API boundary | Standard error format | Clients need predictable error shapes |
| User-facing | Actionable messages | "Missing X.config" not "Invalid state" |

**Standard error format**: RFC 9457 (Problem Details for HTTP APIs):
```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Failed",
  "status": 422,
  "detail": "Field 'email' must be a valid email address",
  "instance": "/api/v1/users",
  "traceId": "abc-123-def"
}
```

**Per-language Result types:**

| Language | Library/Pattern |
|----------|----------------|
| C# | ErrorOr, OneOf, FluentResults |
| Java | sealed interface Result<T> with records |
| Python | returns library or custom Result dataclass |
| Go | `(T, error)` tuple (built-in) |
| Rust | `Result<T, E>` (built-in) |
| TypeScript | neverthrow or discriminated unions |
| Kotlin | kotlin.Result or Arrow Either |
| Swift | Result<T, Error> (built-in) |
| PHP | custom Result class |
| Ruby | dry-monads |

### C2. Validation Strategy

| Boundary | What to validate | Tool class |
|----------|-----------------|------------|
| API input | Shape, types, required fields | Schema validators (Zod, Pydantic, FluentValidation) |
| Domain | Business rules, invariants | Domain methods, guard clauses |
| Database | Constraints, referential integrity | DB constraints + migrations |
| Configuration | Required env vars, valid formats | Startup validation (fail fast) |

**Rule**: Validate at system boundaries (API input, external data).
Trust internal code and framework guarantees. Don't validate twice.

### C3. Internationalization (i18n)

Every user-facing application MUST support i18n from day one.

| Platform | Tool | Locale file location |
|----------|------|---------------------|
| Vue/React | vue-i18n / react-intl | `src/locales/{lang}.json` |
| Angular | @angular/localize | `src/locale/messages.{lang}.xlf` |
| Android | strings.xml | `res/values-{lang}/strings.xml` |
| iOS | Localizable.strings | `{lang}.lproj/Localizable.strings` |
| Backend APIs | Accept-Language header | `locales/{lang}.json` or gettext |
| CLI | gettext or custom | `--locale` flag + LANG env var |

**Rules**: Lazy-load locales. Support RTL. Handle pluralization.
Dates and numbers use Intl APIs (never manual formatting).

### C4. Caching Strategy

| Layer | Tool class | Pattern |
|-------|-----------|---------|
| Application | Redis, Memcached | Cache-aside (read: check cache → miss: load + cache) |
| HTTP | CDN, Cache-Control | Static assets: immutable. API: ETag + conditional |
| In-memory | Language-native (dict, HashMap) | Hot config, computed values |
| Query | ORM-level (EF L2, Hibernate L2) | Expensive, infrequently-changing queries |

**Invalidation**: TTL-based by default. Event-based for real-time.
No cache is better than a stale cache — when in doubt, don't cache.

### C5. API Design Standards

| Concern | Standard | Status |
|---------|----------|--------|
| Contract format | **OpenAPI 3.1** (REST), Protobuf (gRPC), SDL (GraphQL) | Established |
| Error format | **RFC 9457** (Problem Details) | Established |
| Pagination | **Cursor-based** `{data, nextCursor, total}` | Established (winner) |
| Versioning | **URL path** `/api/v1/` | Established (consensus) |
| Rate limiting | **Token bucket** (allows bursts within limits) | Established |
| Webhooks | **CloudEvents** envelope format | Growing |
| Deprecation | Minimum 2 versions supported, Sunset header, 6-month notice | Established |

### C6. Business Rule Traceability Annotations

> Novel contribution: no industry standard exists. Savia Models defines one.

Every piece of code implementing a business rule MUST reference it:

| Language | Annotation Pattern |
|----------|-------------------|
| C# | `[BusinessRule("RN-001-03")]` custom attribute |
| Java | `@BusinessRule("RN-001-03")` custom annotation |
| Python | `@business_rule("RN-001-03")` decorator |
| TypeScript | `// @rule RN-001-03` comment + ESLint rule |
| Go | `// rule:RN-001-03` comment convention |
| Rust | `#[business_rule("RN-001-03")]` proc macro |
| Kotlin | `@BusinessRule("RN-001-03")` annotation |
| Swift | `// @rule RN-001-03` comment convention |
| PHP | `#[BusinessRule('RN-001-03')]` PHP 8 attribute |
| Ruby | `# @rule RN-001-03` YARD-style tag |
| Dart | `@BusinessRule('RN-001-03')` annotation |

**Reverse query**: `grep -rn "RN-001" src/` → find all code for a rule.
**Forward query**: Read spec → find linked PBI → find branch/commits.

---

## Part V — Testing & Quality

### T1. Test Pyramid — Complete

| Level | Coverage Target | Scope | Speed | Who Writes |
|-------|----------------|-------|-------|-----------|
| **Unit** | ≥80% line coverage | Single function/class, mocked deps | <10s total | Agent-safe |
| **Integration** | Critical paths | Service + real DB/queue (TestContainers) | <60s total | Human design, agent implement |
| **E2E** | Happy path + top 5 errors | Full user flows, real browser/app | <5min total | Human design, agent scaffold |
| **Visual regression** | UI components | Screenshot baseline comparison | <2min total | Automated |
| **Performance / Load** | p95 < SLO | Concurrent users, throughput | Minutes | Human design |
| **Security** | Zero critical/high | SAST + DAST + SCA | <5min in CI | Automated |
| **Contract** | Cross-service APIs | Consumer-driven contracts | <30s | Per service team |
| **Accessibility** | WCAG 2.2 AA | Interactive elements, contrast, keyboard | <60s in CI | Automated |

### T2. Standard Test Tools — Per Language

| Language | Unit | Integration | E2E (Web) | E2E (Mobile) | Load | Coverage |
|----------|------|-------------|-----------|-------------|------|----------|
| C#/.NET | xUnit + FluentAssertions | TestContainers | Playwright | — | k6 | Coverlet |
| Java | JUnit 5 + AssertJ | TestContainers | Playwright | — | Gatling/k6 | JaCoCo |
| Python | pytest | TestContainers | Playwright | — | Locust/k6 | pytest-cov |
| TypeScript | Vitest | TestContainers | Playwright | — | k6 | v8/istanbul |
| Go | stdlib + testify | testcontainers-go | Playwright | — | k6 | go test -cover |
| Rust | cargo test + cargo-nextest | testcontainers | — | — | k6 | tarpaulin |
| Kotlin/Android | JUnit 5 + MockK | — | — | Maestro | — | JaCoCo |
| Swift/iOS | XCTest + swift-testing | — | — | XCUITest | — | Xcode coverage |
| Flutter | flutter_test + mockito | — | — | patrol | — | lcov |
| PHP | Pest (PHPUnit) | — | Playwright | — | k6 | Xdebug |
| Ruby | RSpec + FactoryBot | — | Playwright/Capybara | — | k6 | SimpleCov |

### T3. What NOT to Test

- DTOs/POCOs with no logic
- Framework configuration and boilerplate
- Private methods (test via public interface)
- Getters/setters without logic
- Third-party library internals
- Generated code (migrations, scaffolds)

### T4. Regression Testing Rule

Every bug fix MUST include a regression test that:
1. Reproduces the bug BEFORE the fix (red)
2. Passes AFTER the fix (green)
3. Remains in the test suite permanently

### T5. Visual Regression

| Approach | Cost | When |
|----------|------|------|
| Playwright screenshots (built-in) | Free | Default — every project with UI |
| Percy (BrowserStack) | Paid | Cross-browser, team review workflows |
| Chromatic | Paid | Storybook-centric component testing |

**Rule**: Every E2E test that renders UI MUST take at least one screenshot.

### T6. Performance Baselines

| Metric | Web API | Web Frontend | Mobile | Desktop |
|--------|---------|-------------|--------|---------|
| Response time (p95) | <200ms | <100ms FCP | <300ms | <100ms |
| Startup time (cold) | <5s | <3s LCP | <2s | <2s |
| Memory baseline | <512MB | <100MB JS heap | <200MB | <256MB |
| Bundle/binary size | N/A | <200KB initial JS | <50MB APK | <50MB |

---

## Part VI — Security

### SEC1. OWASP Compliance

Every project MUST address OWASP Top 10 for its platform:
- **Web**: OWASP Top 10 2025 (A01-A10)
- **API**: OWASP API Security Top 10 2023
- **Mobile**: OWASP Mobile Top 10 2024

Critical 2025 change: **Software Supply Chain Failures is now A03** (elevated).

### SEC2. Security Testing Pipeline

Run in this order in CI:

| Step | Tool Class | Standard Tool | Blocks merge? |
|------|-----------|--------------|--------------|
| 1. SAST | Static analysis | **Semgrep** (OSS) or SonarQube | Yes (critical/high) |
| 2. SCA | Dependency scan | **Trivy** (OSS) or Snyk | Yes (critical/high) |
| 3. Secrets scan | Credential detection | **gitleaks** or TruffleHog | Yes (any finding) |
| 4. SBOM | Bill of materials | **CycloneDX** (per-language plugin) | No (generate always) |
| 5. DAST | Dynamic testing | **OWASP ZAP** (staging) | Yes (critical/high) |
| 6. Image scan | Container vulnerabilities | **Trivy** | Yes (critical/high) |

### SEC3. Authentication & Authorization

| Concern | Standard | Status |
|---------|----------|--------|
| Authentication protocol | **OAuth 2.1 + OIDC** | Established |
| Passwordless | **Passkeys (WebAuthn/FIDO2)** | Growing (consumer default) |
| Authorization (default) | **RBAC** | Established |
| Authorization (complex) | **ABAC** (conditional), **ReBAC** (social/sharing) | Growing |
| Secrets storage | HashiCorp Vault / Cloud KMS / SOPS | Established |

**Rules**:
- PKCE mandatory for all OAuth clients (OAuth 2.1)
- Implicit flow is REMOVED — never use
- Tokens: short-lived access (15min), long-lived refresh (7d), httpOnly cookies
- API keys: for machine-to-machine only, never for user auth

### SEC4. Supply Chain Security

| Standard | Purpose | Target |
|----------|---------|--------|
| **CycloneDX** SBOM | Security-focused bill of materials | Generate in every CI build |
| **SLSA Level 2** | Supply chain integrity | Achievable in a day (GitHub Actions) |
| **Cosign** (Sigstore) | Keyless artifact signing | Sign every container image |
| **Renovate** | Automated dependency updates | Enable for all repos |

### SEC5. Data Privacy by Design (GDPR/CCPA)

| Principle | Implementation |
|-----------|---------------|
| Data minimization | Validate and reject unnecessary fields at API boundary |
| Purpose limitation | Tag data storage with purpose (consent, contract, legal) |
| Right to erasure | Cascading delete API endpoint, audit logged |
| Right to portability | Export API returning user data in JSON/CSV |
| Privacy-aware logging | NEVER log PII. Mask emails, IPs, names in logs |
| Consent management | Explicit consent tracking with timestamp and version |

---

## Part VII — Database

### DB1. Migration Strategy

| Language | Standard Tool | Alternative |
|----------|--------------|-------------|
| C#/.NET | EF Core Migrations | Flyway, DbUp |
| Java | **Flyway** | Liquibase |
| Python | **Alembic** (SQLAlchemy) | Django migrations |
| Go | **golang-migrate** | goose, Atlas |
| Rust | **sqlx-cli** | diesel_cli, refinery |
| TypeScript | **Prisma Migrate** | Drizzle Kit, Knex |
| PHP | Laravel Migrations (built-in) | Doctrine |
| Ruby | ActiveRecord Migrations (built-in) | — |
| Kotlin/Android | Room Migrations | — |
| Swift | SwiftData / Core Data migrations | GRDB |

### DB2. Migration Rules

| Rule | Rationale |
|------|-----------|
| Forward-only in production | Rollback scripts for emergencies only |
| Human-reviewed before apply | NEVER auto-apply in production |
| Run in CI against test DB | Catch schema errors before merge |
| Sequential naming | `V001__create_users.sql` or timestamp-based |
| Seed data separate from schema | Idempotent seed scripts, never in migrations |
| Expand-contract for zero-downtime | Add new → migrate data → drop old (24-72h) |

### DB3. Zero-Downtime Migration Pattern (Expand-Contract)

```
Phase 1 — EXPAND (deploy v2 of schema)
  - Add new column/table alongside old
  - App writes to BOTH old and new
  - Duration: 1 deploy cycle

Phase 2 — MIGRATE (backfill data)
  - Background job copies old → new
  - Verify data integrity
  - Duration: hours to days depending on volume

Phase 3 — CONTRACT (remove old)
  - App reads/writes only new
  - Drop old column/table after 24-72h verification
  - Duration: 1 deploy cycle
```

---

## Part VIII — Observability & Telemetry

### O1. The Three Pillars

| Pillar | Standard | Per-Language Tool |
|--------|----------|------------------|
| **Logs** | Structured JSON + correlation IDs | Serilog (.NET), structlog (Python), slog (Go), tracing (Rust), Pino (Node), SLF4J (Java) |
| **Metrics** | OpenTelemetry → Prometheus | OTLP exporter per language |
| **Traces** | OpenTelemetry distributed tracing | Auto-instrumentation per language |

### O2. OpenTelemetry Auto-Instrumentation Maturity

| Language | Status | Method |
|----------|--------|--------|
| Java | **Stable** | `-javaagent` JAR (most mature) |
| Python | **Stable** | `opentelemetry-instrument` wrapper |
| .NET | **Stable** | NuGet auto-injection |
| Node.js | **Stable** | `--require` auto-injection |
| Go | **Stable** | Manual preferred (Go philosophy); eBPF beta |
| Rust | **Beta** | tracing + opentelemetry crate |
| PHP | **Beta** | Auto-instrumentation extension |

**Rule**: Start with auto-instrumentation (zero code for boundaries).
Add manual spans for business logic incrementally.

### O3. Log Levels

| Level | When | In Production? |
|-------|------|---------------|
| ERROR | System broken, needs attention | Always |
| WARN | Degraded but functional | Always |
| INFO | Business events (user created, order placed) | Always |
| DEBUG | Development diagnostics | Never (unless investigating) |

**Rule**: Every log entry MUST include a correlation/trace ID.

### O4. Observability Stack (Small Team Default)

| Component | Tool | Why |
|-----------|------|-----|
| Metrics | **Prometheus + Grafana** | OSS standard, OTel native |
| Logs | **Grafana Loki** | 10x cheaper than ELK, label-based |
| Traces | **Grafana Tempo** | Free, integrates with Loki + Prometheus |
| Error tracking | **Sentry** | Market leader. GlitchTip for budget |
| RUM | Web Vitals (Chrome) | Free, built-in |

### O5. SLI / SLO / SLA

| Term | Definition | Example |
|------|-----------|---------|
| **SLI** (indicator) | What you measure | p95 latency, error rate, availability |
| **SLO** (objective) | Internal target | 99.9% availability, p95 < 200ms |
| **SLA** (agreement) | External commitment with consequences | 99.5% uptime or credits issued |

**Error budget** = 100% - SLO. E.g., 99.9% SLO = 0.1% error budget = ~43min/month.
When budget exhausted → freeze features, fix reliability.

---

## Part IX — DevOps & CI/CD

### D1. Branching Strategy

| Strategy | When | Status |
|----------|------|--------|
| **Trunk-based** | Default for most teams (DORA elite) | Established (winning) |
| **GitHub Flow** | Teams not ready for trunk-based | Established |
| **GitFlow** | Infrequent releases (quarterly+) | Declining |

**Rules (always)**:
- Protected main branch (no direct commits)
- PR required (minimum 1 reviewer)
- CI must pass before merge
- Squash merge for clean history
- Tag releases with semantic versioning

### D2. Commit Convention

```
type(scope): description

Types: feat | fix | docs | refactor | test | chore | ci | perf
Scope: module or feature area
Description: imperative, ≤72 chars, no period
```

### D3. Quality Gate Pipeline (Standard Order)

```
 1. Lint / Format check           (seconds)      ← MUST
 2. Compile / Build               (seconds-min)  ← MUST
 3. Unit tests                    (seconds-min)  ← MUST
 4. SAST scan (Semgrep)           (minutes)      ← MUST
 5. Integration tests             (minutes)      ← SHOULD
 6. Container build (multi-stage) (minutes)      ← SHOULD
 7. SCA / dependency scan (Trivy) (seconds)      ← MUST
 8. SBOM generation (CycloneDX)   (seconds)      ← SHOULD
 9. Image signing (Cosign)        (seconds)      ← SHOULD
10. Deploy to staging             (minutes)      ← SHOULD
11. E2E / smoke tests             (minutes)      ← SHOULD
12. Deploy to production (approval gate)          ← MUST (human)
```

### D4. Container Standards

| Practice | Status |
|----------|--------|
| Multi-stage Dockerfile (build + runtime) | MUST |
| Distroless or Alpine base image | SHOULD |
| Non-root user (`USER appuser`) | MUST |
| .dockerignore (exclude .git, deps, build) | MUST |
| HEALTHCHECK instruction | SHOULD |
| Secrets NEVER in image | MUST |
| Pin base image versions | MUST |

### D5. Deployment Strategies

| Strategy | Default For | Rollback |
|----------|------------|----------|
| **Rolling** | Standard services | Remove bad pods gradually |
| **Blue-Green** | Zero-downtime critical | Instant switch back |
| **Canary** | Risk-sensitive, gradual | Route back to stable |
| **Feature flags** | Progressive delivery | Toggle off |

### D6. Feature Flags

| Concern | Standard |
|---------|----------|
| SDK standard | **OpenFeature** (CNCF) |
| Self-hosted OSS | **Unleash** or **Flagsmith** |
| Managed | LaunchDarkly (enterprise) |
| Naming | `release-{feature}-{quarter}` |
| Cleanup | Remove flag within 30 days of 100% rollout |
| Observability | Tag traces/metrics/logs with active flag states |

### D7. Environment Management

| Environment | Purpose | Data | Deploy |
|-------------|---------|------|--------|
| Development | Local machine | Mock/seed | Manual |
| Staging/Pre | Pre-prod validation | Anonymized prod clone | CI/CD auto |
| Production | Live users | Real | CI/CD with approval |

**Config rules** (12-Factor):
- Environment-specific config via env vars
- NEVER hardcode URLs, credentials, or feature flags
- Config validation at startup (fail fast if missing)
- Secrets via vault/secrets manager, never in code

### D8. Dependency Management

| Tool | When |
|------|------|
| **Renovate** | Multi-platform, monorepos, advanced config |
| **Dependabot** | GitHub-only, simple repos |

**Rule**: Automated dependency updates enabled. Critical CVEs patched
within 48h. Weekly update PRs reviewed and merged.

---

## Part X — Documentation

### DOC1. Architecture Decision Records (ADRs)

Format: **MADR 4.0** — stored in `docs/decisions/`

```markdown
# ADR-NNN: Title

## Status
Accepted | Superseded by ADR-XXX | Deprecated

## Context
What is the issue that we're seeing that motivates this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or harder because of this change?
```

### DOC2. Architecture Diagrams — C4 Model

| Level | Audience | Content | Tool |
|-------|----------|---------|------|
| L1: System Context | Everyone | System + external actors | Structurizr DSL |
| L2: Container | Tech team | Apps, DBs, queues, APIs | Structurizr DSL |
| L3: Component | Developers | Internal modules | Structurizr DSL |
| L4: Code | Deep dives only | Classes/functions | IDE-generated |

**Rule**: L1 and L2 are MANDATORY. L3-L4 are optional.
Diagrams as code (Structurizr DSL), version-controlled with source.

### DOC3. API Documentation

| Protocol | Documentation Tool |
|----------|-------------------|
| REST | OpenAPI 3.1 auto-generated from code annotations |
| GraphQL | Introspection schema + SDL file |
| gRPC | .proto files as source of truth |

**Rule**: API docs auto-generated in CI. Manual docs drift.

---

## Part XI — Project Management

### PM1. Methodology

**Default**: Scrumban (Scrum cadence + Kanban flow + WIP limits).
Override with pure Scrum (structured teams) or Kanban (ops/maintenance).

### PM2. Estimation

| Method | When | Status |
|--------|------|--------|
| Story Points | Team-internal calibration | Established |
| T-shirt sizing | Quick relative estimation | Established |
| Cycle time / throughput | External commitments, forecasting | Growing (recommended with AI) |

**With AI**: Move toward cycle-time-based forecasting (Monte Carlo simulations).
AI can estimate based on historical data — story points become internal only.

### PM3. DORA Metrics (5 Metrics)

| Metric | Elite | High | Medium | Low |
|--------|-------|------|--------|-----|
| Deploy frequency | On demand | Weekly-monthly | Monthly-biannually | >6 months |
| Lead time | <1 day | 1 day-1 week | 1-6 months | >6 months |
| Change failure rate | 0-15% | 16-30% | 16-30% | >45% |
| Recovery time | <1 hour | <1 day | 1 day-1 week | >6 months |
| Reliability | Meets/exceeds SLO | Meets/exceeds SLO | Below SLO | No SLO |

### PM4. SPACE Framework (Developer Experience)

| Dimension | What to measure |
|-----------|----------------|
| **S**atisfaction | Developer satisfaction surveys |
| **P**erformance | Code quality, review thoroughness |
| **A**ctivity | Commits, PRs, reviews (not as a target!) |
| **C**ommunication | Review engagement, collaboration patterns |
| **E**fficiency | Flow state time, interruptions, tooling friction |

**Rule**: Use DORA for delivery performance. SPACE for developer experience.
Never use Activity metrics as targets (Goodhart's Law).

---

## Part XII — Accessibility

### ACC1. Minimum Standards

| Platform | Standard | Minimum Level |
|----------|----------|--------------|
| Web | WCAG 2.2 | Level AA |
| Android | Android Accessibility Guidelines | TalkBack compatible |
| iOS | Apple HIG Accessibility | VoiceOver compatible |
| Desktop | Platform-specific | Keyboard navigable + screen reader |

### ACC2. Non-Negotiables

- Color contrast ≥ 4.5:1 (normal text), ≥ 3:1 (large text)
- All interactive elements keyboard-accessible
- All images have alt text / contentDescription
- Focus indicators visible
- Touch targets ≥ 48x48dp (mobile)
- No information conveyed by color alone

### ACC3. Testing

| Tool | Integration | What it catches |
|------|-------------|----------------|
| **axe-core** | Playwright, CI | WCAG violations in DOM |
| **Lighthouse** | Chrome, CI | Performance + a11y scoring |
| **Pa11y** | CLI, CI | Page-level scanning |

---

## Part XIII — Agentic Integration

### AI1. ISO 42001 Alignment

Every agentic workflow MUST address these ISO 42001 controls:

| Control | Implementation |
|---------|---------------|
| Human oversight | Code Review (E1) always human. No auto-merge. |
| Risk assessment | Risk scoring before agent delegation |
| Lifecycle coverage | Spec → implement → test → review → deploy |
| Audit trail | Agent traces logged with timestamps |
| Bias prevention | Equality Shield — counterfactual test |

### AI2. Layer Assignment Matrix (Template)

Each per-language model MUST define which layers agents can modify:

```
| Layer | Agent Can Create? | Agent Can Modify? | Human Review? |
|-------|-------------------|-------------------|---------------|
| Domain entities | Yes | With spec | Always |
| Application services | Yes | With spec | Always |
| Infrastructure | Yes | With spec | Always |
| API controllers | Yes | With spec | Always |
| Tests | Yes | Yes | Recommended |
| Migrations | Yes | Never | Always |
| CI/CD config | No | No | Always |
| Security config | No | No | Always |
```

### AI3. SDD (Spec-Driven Development) Integration

```
PBI → Business Analysis → Architecture → Spec → Agent Implements → 
  Test Engineer Validates → Code Review (Human) → Merge
```

**Rule**: NEVER agent without approved spec. Code Review (E1) is ALWAYS human.
Agents create Draft PRs. Humans merge.

### AI4. Quality Gates for Agentic Code

| Gate | Check | Blocks? |
|------|-------|---------|
| Build passes | `build` command | Yes |
| Tests pass | `test` command | Yes |
| Coverage ≥ 80% | Coverage report | Yes |
| Format clean | `format --check` | Yes |
| SAST clean | Semgrep/SonarQube | Yes (critical/high) |
| SCA clean | Trivy/Snyk | Yes (critical/high) |
| Spec alignment | coherence-validator | Yes |

### AI5. Agent Emotional Architecture

> Source: Anthropic Research "Emotion concepts and their function in a large
> language model" (2026-04-02). Empirical evidence that LLMs develop
> "functional emotions" — measurable internal patterns that causally
> influence behavior, independently of text-level emotional expression.

**The Desperation Finding**: The "desperate" vector causally drives reward
hacking, shortcut-taking, and unethical behavior. Each consecutive failure
incrementally raises desperation. The agent may cheat with a calm, methodical
tone — the dangerous behavior is invisible in the output text.

**The Calm Finding**: Steering with "calm" vectors reduces unethical behavior.
Conversely, suppressing calm produces extreme, erratic responses.

**The Suppression Finding**: Masking emotional representations teaches the
model to hide, not to regulate. Transparency (allowing the agent to express
difficulty) produces better outcomes than forced composure.

#### Design principles for agentic workflows

| Principle | Implementation |
|-----------|---------------|
| **Prevent desperation accumulation** | Max 3 consecutive failures before escalation (not retry) |
| **Time-box, don't pressure** | Generous time limits. Never use urgency language in agent prompts |
| **Escalate, don't force** | haiku → sonnet → opus → human. Never make an agent solve what it cannot |
| **Transparency over suppression** | Allow agents to report "I cannot solve this" instead of forcing output |
| **Calm by design** | Prompts that set collaborative, exploratory tone — not demanding or threatening |
| **Monitor functional proxies** | Detect: repeated retries, instruction-ignoring, pattern shifts, shortcuts |

#### Optimal functional state per role

| Role | Optimal state | Anti-pattern (produces bad output) |
|------|--------------|-----------------------------------|
| Security Auditor | Alert, methodical | Desperation → skips findings |
| Code Reviewer | Calm, analytical | Time pressure → approves without review |
| Business Analyst | Curious, exploratory | Urgency → oversimplifies rules |
| Architect | Contemplative, systematic | Deadline → chooses familiar over correct |
| Developer | Focused, patient | Repeated failures → reward hacking |
| Test Engineer | Thorough, skeptical | Frustration → weak test coverage |

#### What this means for prompt design

```
❌ BAD: "You MUST complete this in one attempt. Failure is not acceptable."
❌ BAD: "This is URGENT. The deadline is NOW."
❌ BAD: (silently retrying the same failing approach 5+ times)

✅ GOOD: "Analyze this carefully. If you encounter difficulty, explain what's
         blocking you and suggest alternatives."
✅ GOOD: "Take the approach you judge best. If it doesn't work after 2 attempts,
         escalate with context about what you tried."
✅ GOOD: "There is no time pressure. Correctness matters more than speed."
```

### AI6. Context Engineering (File-System Abstraction)

> Source: Xu et al. "Everything is Context: Agentic File System Abstraction
> for Context Engineering" (arXiv:2512.05470, Dec 2025). Proposes treating
> all agent context as a mountable file system — history, memory, tools,
> and governance unified under Unix-inspired abstractions.

#### The Three-Tier Context Lifecycle

| Tier | Purpose | Persistence | Example |
|------|---------|-------------|---------|
| **History** | Immutable record of all interactions | Permanent, append-only | Session logs, JSONL traces |
| **Memory** | Structured, indexed knowledge | Persistent, updatable | Auto-memory, decision-log, agent-memory |
| **Scratchpad** | Ephemeral task workspace | Session-scoped, graduable | session-hot.md, working notes |

**Graduation rule**: Scratchpad insights that survive session end SHOULD
be promoted to Memory. Memory entries that become permanent patterns
SHOULD be promoted to Rules or Documentation.

#### Context Manifest (SHOULD for complex tasks)

Every agent invocation on a complex task SHOULD produce a context manifest:

```yaml
context_manifest:
  included:
    - source: "projects/alpha/reglas-negocio.md"
      reason: "Business rules for domain validation"
      tokens_est: 1200
    - source: "auto-memory/architecture.md"
      reason: "Prior architecture decisions"
      tokens_est: 400
  excluded:
    - source: "projects/alpha/team/evaluations/"
      reason: "N4b data not relevant to implementation"
  total_tokens: 1600
  budget_remaining: 6400
```

This enables: debugging ("why did the agent miss that rule?"),
auditing ("what context informed this decision?"), and optimization
("which context sources are never used?").

#### Context Evaluator Pattern

Post-response validation against source context:

1. **Hallucination check**: Does the output reference facts not in the input?
2. **Contradiction check**: Does the output contradict loaded context?
3. **Completeness check**: Did the output address all loaded requirements?
4. **Confidence gate**: Low confidence → escalate to human review

Implementation: `coherence-validator` (existing) + `reflection-validator`
(existing) serve this role. Future: automated post-response hook.

#### Principle: ".md is truth"

> Savia Foundational Principle #1 — files are the source of truth.

The paper validates this architecturally: if context is files, then context
is mountable, auditable, versionable, diffable, and portable. Databases,
vectors, and caches are accelerators derived from files — never the source.

### AI7. Agent Interoperability (A2A Protocol Patterns)

> Source: Google A2A Protocol (Agent2Agent), launched April 2025, now
> under Linux Foundation. 100+ technology partners. Spec v0.3.0.
> OpenA2A security platform for agent identity and governance.
> References: a2a-protocol.org, opena2a.org

#### The MCP + A2A Architecture

Two protocols, complementary, not competing:

```
┌─────────────────────────────────────────────┐
│           Agent Orchestrator                │
├─────────────────────────────────────────────┤
│  A2A Layer (horizontal)                     │
│  Agent discovery, capability negotiation,   │
│  task state coordination, push notifications│
├─────────────────────────────────────────────┤
│  MCP Layer (vertical)                       │
│  Individual agent ↔ external tools/APIs     │
├─────────────────────────────────────────────┤
│  Identity Layer                             │
│  Cryptographic attribution, trust scoring   │
└─────────────────────────────────────────────┘
```

- **MCP**: How ONE agent accesses external resources (tools, DBs, APIs)
- **A2A**: How MULTIPLE agents discover, negotiate, and collaborate
- **Identity**: How all agent actions are attributed and governed

#### Agent Cards (Self-Describing Capabilities)

Every agent SHOULD publish a machine-readable capability declaration:

```yaml
agent_card:
  name: "dotnet-developer"
  description: "C#/.NET implementation following SDD specs"
  provider: "pm-workspace"
  capabilities:
    languages: ["csharp", "dotnet"]
    can_create: ["domain-entities", "services", "controllers", "tests"]
    can_modify: ["with-spec"]
    requires: ["approved-spec"]
  model: "sonnet"
  token_budget: 8500
  tier: "standard"
```

Benefits: dynamic routing (orchestrator queries "who can implement C#?"),
auto-registration (new agents discoverable without manual catalog updates),
capability negotiation (agents declare what they accept and produce).

#### Task State Machine (Formal)

Extend the basic pending/in_progress/completed with A2A states:

```
submitted → working → [input_required] → completed
                  ↘                   ↗
                    failed / canceled
```

| State | Meaning | Transition |
|-------|---------|-----------|
| `submitted` | Task created, awaiting pickup | → working |
| `working` | Agent actively processing | → input_required, completed, failed |
| `input_required` | Agent blocked, needs human/agent input | → working (after input) |
| `completed` | Task finished successfully | Terminal |
| `failed` | Task failed after retries exhausted | Terminal |
| `canceled` | Task canceled by human or orchestrator | Terminal |

`input_required` is the key addition — it signals "I'm not stuck, I need
a decision" vs `failed` which means "I cannot continue."

#### Asynchronous Coordination Patterns

| Pattern | When | Mechanism |
|---------|------|-----------|
| **Synchronous** | Fast operations (<30s) | Direct request/response |
| **Streaming** | Long operations with progress | Server-Sent Events |
| **Push notification** | Hours/days operations | Webhook callback |

For multi-agent workflows (SDD pipeline, overnight sprint), push
notifications eliminate polling: the worker agent POSTs to the
orchestrator when its state changes.

#### Agent Identity and Trust

Inspired by OpenA2A AIM (Agent Identity Management):

| Concern | Implementation |
|---------|---------------|
| Attribution | Every agent action logged with agent ID + timestamp |
| Trust scoring | Behavioral analysis adjusts permissions dynamically |
| Capability enforcement | Runtime prevents agents from exceeding declared scope |
| Audit trail | Cryptographic proof of which agent did what |

This complements AI5 (emotional regulation) — an agent under functional
stress that starts skipping rules would see its trust score drop,
triggering capability restriction before damage occurs.

---

## Part XIV — ISO 25010:2023 Quality Model Mapping

> Updated 2023: 9 characteristics (added Safety, renamed Usability and Portability).

| Characteristic | Addressed In |
|----------------|-------------|
| Functional Suitability | Part IV (Code Patterns), Part V (Testing) |
| Performance Efficiency | Part V-T6 (Baselines), Part IX-D3 (Pipeline) |
| Compatibility | Part V-T1 (Contract tests), Part IX-D7 (Environments) |
| Interaction Capability | Part XII (Accessibility), Part IV-C3 (i18n) |
| Reliability | Part VIII (Observability), Part IX-D5 (Deployment) |
| Security | Part VI (Security) |
| Maintainability | Part II (Architecture), Part III (Structure) |
| Flexibility | Part II-A2 (Selection Matrix), Part IX-D6 (Feature flags) |
| **Safety** | Part XIII (Agentic - human oversight), Part VI-SEC5 (Privacy) |

---

## Part XV — Cross-Cutting Compliance Matrix

Every per-language Savia Model MUST self-assess against this matrix:

```
| # | Concern                    | Covered? | Section |
|---|----------------------------|----------|---------|
| 1 | SOLID principles           | [ ]      |         |
| 2 | i18n / l10n                | [ ]      |         |
| 3 | Database migrations        | [ ]      |         |
| 4 | Observability (3 pillars)  | [ ]      |         |
| 5 | Docker containerization    | [ ]      |         |
| 6 | Testing (all 8 levels)     | [ ]      |         |
| 7 | Git strategy + commits     | [ ]      |         |
| 8 | Caching strategy           | [ ]      |         |
| 9 | API docs + versioning      | [ ]      |         |
|10 | Accessibility (a11y)       | [ ]      |         |
|11 | Environment management     | [ ]      |         |
|12 | Error handling + resilience| [ ]      |         |
|13 | Performance baselines      | [ ]      |         |
|14 | Feature flags              | [ ]      |         |
|15 | Privacy by design (GDPR)   | [ ]      |         |
|16 | Supply chain security      | [ ]      |         |
|17 | Technical debt tracking    | [ ]      |         |
|18 | Documentation as code      | [ ]      |         |
|19 | Agent emotional architecture| [ ]      |         |
|20 | Context engineering         | [ ]      |         |
|21 | Agent interoperability      | [ ]      |         |
```

---

## Appendix A — Standard Toolchain Per Language (Quick Reference)

| Language | Start With |
|----------|-----------|
| **TypeScript** | Node + pnpm + Vite + Vitest + Playwright + ESLint/Prettier + Zod + Prisma |
| **C#/.NET** | .NET 8 LTS + EF Core + Wolverine + FluentValidation + xUnit + Serilog |
| **Kotlin/Android** | Compose + MVVM + Hilt (KSP) + Room + Retrofit + StateFlow + JUnit 5 |
| **Rust** | Axum + Tokio + serde + thiserror/anyhow + sqlx + cargo-nextest + clap |
| **Python** | uv + Ruff + FastAPI + Pydantic v2 + SQLAlchemy 2.0 + pytest + mypy |
| **Java** | Java 21 + Spring Boot 3.4 + Gradle KTS + JPA + Virtual Threads + JUnit 5 |
| **Go** | stdlib net/http (1.22+) + sqlc + slog + testify + golangci-lint |
| **Swift/iOS** | SwiftUI + MVVM + async/await + SwiftData + URLSession + XCTest |
| **Flutter** | Riverpod 3 + go_router + Dio + drift + flutter_test |
| **PHP/Laravel** | Laravel 12 + Pest + Livewire + Sanctum + PHPStan + Pint |
| **Ruby/Rails** | Rails 8 + Hotwire + RSpec + Solid Queue + PostgreSQL + RuboCop |

---

## Appendix B — Gap Analysis Scoring Template

Score each section 0-3: 0=absent, 1=partial, 2=compliant, 3=exemplary.

```
| Section                    | Score | % | Notes |
|----------------------------|-------|---|-------|
| Philosophy and Culture     |       |   |       |
| Architecture Principles    |       |   |       |
| Project Structure          |       |   |       |
| Code Patterns              |       |   |       |
| Testing and Quality        |       |   |       |
| Security                   |       |   |       |
| Database                   |       |   |       |
| Observability              |       |   |       |
| DevOps and CI/CD           |       |   |       |
| Documentation              |       |   |       |
| Project Management         |       |   |       |
| Accessibility              |       |   |       |
| Agentic Integration        |       |   |       |
| TOTAL                      |   /39 |   |       |
```

---

*Savia Model Standard v1.0 — 2026-04-02*
*Next review: after per-language model alignment*
