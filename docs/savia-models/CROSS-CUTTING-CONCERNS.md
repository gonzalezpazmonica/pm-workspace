# Savia Models — Cross-Cutting Concerns

> Applies to EVERY Savia Model regardless of language or architecture.
> These are PM-critical topics that transcend individual tech stacks.
> Every model MUST address each concern or explicitly state N/A with reason.

---

## 1. SOLID Principles

Every model must document how SOLID applies in that language:

| Principle | What it means | Per-language adaptation |
|-----------|--------------|----------------------|
| Single Responsibility | One reason to change per class/module | Varies: class (OOP), module (Go), component (Vue) |
| Open/Closed | Extend without modifying | Varies: inheritance (Java), composition (Go), slots (Vue) |
| Liskov Substitution | Subtypes must be substitutable | Varies: interfaces, protocols, generics |
| Interface Segregation | No client depends on unused methods | Varies: traits (Rust), protocols (Swift), small interfaces (Go) |
| Dependency Inversion | Depend on abstractions, not concretions | Varies: DI containers, constructor injection, composables |

**Requirement per model:** Section 2 (Architecture) MUST reference SOLID
and explain how each principle manifests in that language.

---

## 2. Internationalization (i18n) and Localization (l10n)

Every application that has a UI or generates user-facing text must support i18n.

| App type | i18n approach | Must address |
|----------|--------------|-------------|
| Web frontend | vue-i18n, react-intl, angular i18n | Lazy-loaded locales, RTL support, pluralization |
| Mobile | Android strings.xml, iOS Localizable.strings | Per-locale resources, dynamic switching |
| Backend API | Accept-Language header, response messages | Error messages localized, date/number formatting |
| Desktop | OS locale detection, embedded resources | System language detection, resource bundles |
| CLI | gettext or custom | --locale flag, LANG env var |

**Requirement per model:** Section 4 (Code Patterns) MUST include i18n
pattern with code example. Section 3 (Structure) must show where locale
files live.

---

## 3. Database Migration Strategy

Any application with persistent state needs a migration strategy.

| Concern | Rule |
|---------|------|
| Migration tool | ORM-native (EF Core, Alembic, Flyway, Diesel) |
| Direction | Forward-only in production. Rollback scripts for emergencies. |
| Review | NEVER auto-apply in prod. Always human-reviewed. |
| CI | Migrations run in CI against test DB before merge. |
| Seed data | Separate from migrations. Idempotent. |
| Naming | Sequential timestamp or version: `V001__create_users.sql` |

**Requirement per model:** Section 7 (DevOps) MUST include migration
strategy with tool choice and CI integration.

---

## 4. Observability (Telemetry, Logging, Monitoring)

The 3 pillars: logs, metrics, traces. Every production app needs all three.

| Pillar | Standard | Per-language tools |
|--------|----------|-------------------|
| Logs | Structured JSON, correlation IDs | Serilog (.NET), structlog (Python), slog (Go), tracing (Rust) |
| Metrics | OpenTelemetry, Prometheus-compatible | OTLP exporter per language |
| Traces | OpenTelemetry distributed tracing | Per-framework instrumentation |

**Log levels:** ERROR (broken), WARN (degraded), INFO (business events), DEBUG (development only, never in prod)

**Requirement per model:** Section 7 (DevOps) MUST include observability
setup with structured logging and OpenTelemetry.

---

## 5. Containerization (Docker)

Every deployable application must have a Dockerfile.

| Pattern | Rule |
|---------|------|
| Multi-stage build | Build stage + runtime stage. Never ship compiler/SDK in prod image. |
| Base image | Official language images, pinned versions. Alpine for small size. |
| Non-root user | ALWAYS. `USER appuser` in Dockerfile. |
| .dockerignore | Must exist. Exclude: .git, node_modules, target/, bin/, obj/ |
| Health check | HEALTHCHECK instruction or app-level /health endpoint |
| Secrets | NEVER in image. Use env vars or mounted secrets. |

**Requirement per model:** Section 7 (DevOps) MUST include Dockerfile
pattern with multi-stage build.

---

## 6. Testing Strategy (Complete Pyramid)

Every model must address ALL testing levels:

| Level | What | Target | Who writes |
|-------|------|--------|-----------|
| Unit | Single function/class, mocked deps | >=80% coverage | Agent-safe |
| Integration | Multiple components, real DB | Critical paths | Human design, agent implement |
| E2E | Full user flows, real browser/app | Happy path + top errors | Human design, agent scaffold |
| Regression | Re-run after changes to detect breakage | Automated in CI | CI automated |
| Visual | Screenshot comparison | UI components | Playwright/Roborazzi |
| Performance | Load testing, benchmarks | Response times, throughput | Human design |
| Security | SAST, DAST, dependency scan | OWASP compliance | Automated in CI |

**Regression testing:** MUST be automated. Every bug fix MUST include a
regression test that reproduces the bug BEFORE the fix.

**Requirement per model:** Section 5 (Testing) MUST address unit,
integration, E2E, and regression explicitly with coverage targets.

---

## 7. Git Strategy

Every project needs a defined branching and release strategy.

| Strategy | When to use | Pattern |
|----------|-------------|---------|
| Trunk-based | Small teams, continuous deployment | Short-lived feature branches (<1 day), merge to main |
| GitHub Flow | Most teams | Feature branches, PR review, merge to main |
| GitFlow | Release-scheduled products | develop, release/*, hotfix/* branches |

**Rules that apply always:**
- Protected main branch (no direct commits)
- PR required for merge (minimum 1 reviewer)
- CI must pass before merge
- Commit message convention: `type(scope): description`
- Types: feat, fix, docs, refactor, test, chore, ci
- Squash merge preferred for clean history
- Tag releases with semantic versioning (vX.Y.Z)

**Requirement per model:** Section 7 (DevOps) MUST specify recommended
git strategy and commit conventions.

---

## 8. Caching Strategy

Any app with external data sources should define a caching approach.

| Layer | Tools | When |
|-------|-------|------|
| Application cache | Redis, Memcached | Repeated DB queries, session data |
| HTTP cache | CDN, Cache-Control headers | Static assets, API responses |
| In-memory cache | Language-native (dict, HashMap, ConcurrentHashMap) | Hot data, config |
| Query cache | ORM-level (EF Core, Hibernate L2) | Expensive queries |

**Cache invalidation rules:**
- TTL-based for most use cases
- Event-based for real-time requirements
- Cache-aside pattern as default (read: check cache, miss: load + cache)

**Requirement per model:** Section 4 (Code Patterns) should address
caching when applicable to the architecture type.

---

## 9. API Documentation and Versioning

Every API (REST, GraphQL, gRPC) must be documented and versioned.

| Concern | Standard |
|---------|----------|
| REST docs | OpenAPI 3.1 / Swagger. Auto-generated from code annotations. |
| GraphQL docs | Introspection schema + SDL file |
| gRPC docs | .proto files as source of truth |
| Versioning | URL path (/api/v1/) or header (Api-Version). Never break existing clients. |
| Deprecation | Minimum 2 versions supported. Sunset header. 6-month deprecation notice. |
| Changelog | API changelog separate from app changelog |

**Requirement per model:** Any model that includes API development MUST
address documentation (OpenAPI) and versioning strategy.

---

## 10. Accessibility (a11y)

Every user-facing application must meet minimum accessibility standards.

| Platform | Standard | Minimum |
|----------|----------|---------|
| Web | WCAG 2.2 | Level AA |
| Mobile (Android) | Android Accessibility Guidelines | TalkBack compatible |
| Mobile (iOS) | Apple HIG Accessibility | VoiceOver compatible |
| Desktop | Platform-specific | Keyboard navigable, screen reader compatible |

**Non-negotiables:**
- Color contrast ratio >= 4.5:1 (normal text), >= 3:1 (large text)
- All interactive elements keyboard-accessible
- All images have alt text / contentDescription
- Focus indicators visible
- Touch targets >= 48x48dp (mobile)

**Requirement per model:** Section 4 (Code Patterns) or Section 8
(Anti-Patterns) MUST address accessibility with concrete patterns.

---

## 11. Environment Management

Every deployable application needs at minimum 2 environments.

| Environment | Purpose | Deployment | Data |
|-------------|---------|-----------|------|
| Development | Local developer machine | Manual | Mock/seed |
| Staging/Pre | Pre-production validation | CI/CD auto | Anonymized prod clone |
| Production | Live users | CI/CD with approval | Real |

**Config rules:**
- Environment-specific config via env vars (12-factor)
- NEVER hardcode environment URLs, credentials, or feature flags
- Config validation at startup (fail fast if missing)
- Secrets: vault/secrets manager, never in code or env files in git

**Requirement per model:** Section 7 (DevOps) MUST address environment
management and config strategy.

---

## 12. Error Handling and Resilience

Every application needs a defined error handling philosophy.

| Pattern | When |
|---------|------|
| Result types (Result<T,E>) | Domain/application layer. No exceptions for business logic. |
| Exceptions | Infrastructure failures, truly exceptional situations |
| Retry with backoff | External service calls. Max 3 retries. Exponential backoff. |
| Circuit breaker | Microservice communication. Prevent cascade failures. |
| Graceful degradation | Feature unavailable != app down |
| Dead letter queue | Async message processing failures |

**User-facing errors:**
- Never expose stack traces or internal details
- Provide actionable error messages
- Log full details server-side with correlation ID
- Return standard error format (ProblemDetails, RFC 7807)

**Requirement per model:** Section 4 (Code Patterns) MUST include
error handling strategy with concrete examples.

---

## 13. Performance Baseline

Every model should define acceptable performance targets.

| Metric | Web API | Web Frontend | Mobile | Desktop |
|--------|---------|-------------|--------|---------|
| Response time (p95) | <200ms | <100ms FCP | <300ms | <100ms |
| Startup time | <5s cold | <3s LCP | <2s cold | <2s |
| Memory baseline | <512MB | <100MB JS heap | <200MB | <256MB |
| Bundle/binary size | N/A | <200KB initial JS | <50MB APK | <50MB |

**Requirement per model:** Section 7 (DevOps) or Section 8 (Anti-Patterns)
should reference performance targets and profiling tools.

---

## Compliance Matrix

Every model must self-assess coverage of these 13 concerns:

```
| Concern | Covered in Section | Status |
|---------|-------------------|--------|
| SOLID | S2 Architecture | [ ] |
| i18n | S4 Code Patterns | [ ] |
| Migrations | S7 DevOps | [ ] |
| Observability | S7 DevOps | [ ] |
| Docker | S7 DevOps | [ ] |
| Testing (all levels) | S5 Testing | [ ] |
| Git strategy | S7 DevOps | [ ] |
| Caching | S4 Code Patterns | [ ] |
| API docs/versioning | S4 or S7 | [ ] |
| Accessibility | S4 or S8 | [ ] |
| Environments | S7 DevOps | [ ] |
| Error handling | S4 Code Patterns | [ ] |
| Performance | S7 or S8 | [ ] |
```

---

*v0.1 — 2026-04-02*
*Status: MANDATORY companion to all Savia Models*
