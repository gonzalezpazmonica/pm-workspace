# Rules Traceability — Domain Context

## Why this skill exists

Business rules (RN-XXX) define constraints, policies, calculations the system must enforce. Without traceability matrix, rules get lost in PRD/code, forgotten in testing, violated in edge cases. This skill ensures every rule has a PBI home and test coverage.

## Domain concepts

- **Business Rule (RN-XXX-NN)** — Constraint or policy (e.g., "max 8h per task", "customer age ≥18")
- **Traceability** — Mapping: RN ↔ PBI ↔ Tasks ↔ Tests. Bidirectional links.
- **Coverage Gap** — RN with no PBI (unimplemented), or PBI not traceable to RN (orphan feature)
- **Rule Violation Test** — Test that FAILS if rule broken (guards against regression)

## Business rules it implements

- **RN-TRACE-01**: Every business rule must have ≥1 tracing PBI
- **RN-TRACE-02**: Every PBI must trace to ≥1 business rule (or product discovery JTBD)
- **RN-TRACE-03**: Every rule must have test coverage (rule-violation test required)
- **RN-TEST-01**: Rule changes require test update + PBI update

## Relationship to other skills

**Upstream:** `product-discovery` proposes features; business rules are documented in reglas-negocio.md
**Downstream:** `pbi-decomposition` breaks PBI (with rule tag) into testable Tasks
**Cross-cutting:** All skills validate against traceability matrix

## Key decisions

- **Matrix ownership** — Kept in `projects/{p}/traceability-matrix.md`, owned by PM
- **Automated detection** — NL analysis on PRD and code to find missing links
- **Tag-based enforcement** — PBI tags: `rule:RN-XXX` for quick filtering
