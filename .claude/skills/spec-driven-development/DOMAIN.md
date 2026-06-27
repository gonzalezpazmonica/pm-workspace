# Spec-Driven Development (SDD) — Domain Context

## Why this skill exists

Specs bridge product intent and technical execution. Without executable specs, developers implement different things and rework cascades. SDD ensures specs are testable, complete, and become the source of truth for what devs build. Reduces ambiguity by 80%+ in practice.

## Domain concepts

- **Executable Spec** — Spec with acceptance criteria matching test cases 1:1. Dev can run tests to verify spec compliance.
- **Layer Assignment** — Which architectural layer implements each requirement (domain logic, application, infrastructure, API)
- **Spec Review Gate** — 3-judge consensus: architect (design soundness), developer (implementability), analyst (completeness)
- **SDD Iteration** — Spec ← review feedback ↔ developer until "ready to code"

## Business rules it implements

- **RN-SDD-01**: Spec required before Task creation (except trivial bugs)
- **RN-SDD-02**: Spec must have acceptance criteria linked to test cases
- **RN-SDD-03**: Spec passed review gate before code starts
- **RN-SDD-04**: Spec changes require review (no silent implementation drift)

## Relationship to other skills

**Upstream:** `product-discovery` provides PRD; `rules-traceability` maps business rules to spec requirements
**Downstream:** `spec-driven-development` is INPUT to `dev-session` for implementation; tests defined in spec become `test-runner` validation
**Parallel:** `spec-driven-development` works with all language stacks via agents

## Key decisions

- **Spec-first, code-second** — Consensus on spec prevents rework. Cheaper to debate spec than refactor code.
- **Layer-aware** — Spec assigns which layer owns each requirement. Prevents architectural drift.
- **Consensus gate** — 3 judges (architect, dev, analyst) prevent single-person blind spots.
