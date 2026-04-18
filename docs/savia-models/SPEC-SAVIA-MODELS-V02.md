# SPEC: Savia Models v0.2 — The Agentic Orchestrator

> Status: DRAFT | Priority: HIGH | Estimated: 40-60h
> Depends on: v0.1 merged (7 models + cross-cutting + gap analyses)

---

## Objective

Evolve Savia Models from technical programming guides into the
**complete manual for the Agentic Orchestrator** — one person who,
assisted by Savia, can fulfill ALL roles of software development.

Test criterion (from la usuaria): "One of my children should need nothing
more than reading the Savia Model and learning to work with Savia
to build the software they need."

---

## What v0.1 delivers (DONE)

- 7 language models (TypeScript, .NET, Kotlin, Rust, Python, Java, Go)
- 9 sections per model (philosophy through agentic integration)
- 13 cross-cutting concerns (SOLID, i18n, migrations, observability,
  Docker, testing pyramid, git strategy, caching, API docs, a11y,
  environments, error handling, performance)
- 3 gap analyses + improvement roadmap

## What v0.1 is MISSING

The models are written from a developer's perspective only. They lack
the perspectives of all other roles, the full traceability chain, and
the pedagogical scaffolding needed for someone starting from zero.

---

## v0.2 Deliverables

### Layer 1: Role Perspectives

Add a section to each model (or companion doc) showing how EVERY role
interacts with that technology. The 12 roles that converge in the
Agentic Orchestrator:

| Role | What they need from the model |
|------|-------------------------------|
| Product Owner | How to write requirements, acceptance criteria, business rules in this stack |
| Project Manager | Planning, capacity, risk, deadlines, ceremonies, DORA metrics |
| Business Analyst | Domain modeling, rule extraction, user stories, data dictionary |
| Software Architect | Patterns, layers, boundaries, NFRs, ADRs, tech debt assessment |
| Scrum Master | Flow optimization, blockers, ceremonies, retrospectives, velocity |
| Tech Lead | Code standards, review checklist, mentoring patterns, tech debt |
| Backend Developer | API design, DB access, services, queues, cache, error handling |
| Frontend Developer | UI components, state management, UX patterns, a11y, responsive |
| DBA | Schema design, migrations, indexes, queries, backups, replication |
| Security Auditor | OWASP checklist, pentesting scope, compliance gates, GDPR/AEPD |
| DevOps Engineer | CI/CD pipelines, Docker, K8s, monitoring, IaC, secrets management |
| Pipeline Admin | Build config, deploy strategy, rollback, feature flags, environments |

For each role: what decisions they make, what artifacts they produce,
what quality gates they enforce, and how Savia assists them.

### Layer 2: End-to-End Traceability

Define the complete traceability chain for each model:

```
User action
  -> API endpoint (traced via OpenTelemetry)
    -> Controller (logged with correlation ID)
      -> Service / Use Case
        -> Domain Rule (RN-XXX in reglas-negocio.md)
          -> PBI that originated this feature (AB#XXXX)
            -> Spec that defined the implementation
              -> Branch + commits (git log)
                -> Agent or human who wrote the code
                  -> Tests that validate it (unit/integration/E2E)
                    -> Pipeline that built and deployed it
                      -> Environment where it runs
                        -> Telemetry that monitors it
                          -> Alert if it fails
                            -> Back to the team
```

Each model must define:
- How to tag code with business rule references
- How to link commits to PBIs/specs
- How to maintain correlation IDs across layers
- How to query "which business rule generated this code?"
- How to query "which code implements this business rule?"
- Integration with Savia Flow (dual-track) and SDD (specs)

### Layer 3: Pedagogical Scaffolding

Each model must include (or link to) a learning path for someone
who has NEVER programmed before:

| Level | What they learn | Output |
|-------|----------------|--------|
| 0. Orientation | What is software, what is Savia, how do they work together | Mental model |
| 1. First project | Clone template, run it, see it work | Running app |
| 2. First change | Modify one thing, test it, deploy it | Confidence |
| 3. First feature | Write a spec, let Savia implement it, review the code | Understanding of SDD |
| 4. First architecture | Understand layers, why they exist, when to add them | Design thinking |
| 5. First team project | Collaborate via git, PRs, code review, ceremonies | Team skills |
| 6. Autonomy | Build a complete project from idea to production | Independence |

Each level includes:
- Glossary of terms used at that level
- "What can go wrong" and how to recover
- When to ask for human help vs. when to ask Savia
- Concrete exercises per language/stack

---

## Additional models to create

| # | Model | Language | App types |
|---|-------|----------|-----------|
| 08 | savia-model-swift | Swift | iOS, macOS, server-side Swift |
| 09 | savia-model-flutter | Dart/Flutter | Mobile cross-platform, web |
| 10 | savia-model-php | PHP/Laravel | Web apps, APIs |
| 11 | savia-model-ruby | Ruby/Rails | Web apps, APIs |

---

## Updates to existing models

All 7 existing models must be audited against CROSS-CUTTING-CONCERNS.md
compliance matrix. Known gaps from v0.1 audit:

- SOLID: 0 mentions across all models
- API docs/versioning: 0 mentions
- Git strategy: 2 mentions total
- Accessibility: 3 mentions total

Each model needs these topics added or expanded.

---

## Standards and references to research

- ISO 25010 (Software quality model)
- ISO 42001 (AI management system)
- TOGAF (Enterprise architecture framework)
- ITIL v4 (IT service management)
- DORA metrics (2025 report findings)
- OWASP Top 10 (Web, Mobile, API)
- 12-Factor App methodology
- C4 Model (architecture diagrams)
- ADR (Architecture Decision Records) format
- SDD (Spec-Driven Development) — Thoughtworks/arXiv

---

## Acceptance criteria

1. Any person with reading comprehension can follow Level 0-3
   of the pedagogical path and produce a running application
2. Every role's perspective is documented with concrete artifacts
3. Traceability chain is demonstrable end-to-end on at least
   one example project (savia-web or sala-reservas)
4. All 7 models score 100% on CROSS-CUTTING-CONCERNS compliance
5. At least 4 additional language models created (Swift, Flutter, PHP, Ruby)

---

*Spec: v0.1 | Date: 2026-04-02 | Author: Savia + la usuaria*
