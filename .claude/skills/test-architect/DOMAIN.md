# Test Architect — Domain Context

## Why this skill exists

Tests written without knowing the quality bar fail audits and require multiple
rounds of rework. Session 2026-03-30 proved it: 57 tests took 4 iterations to
reach score 80+. The Test Architect encodes those lessons so every test passes
from the first attempt. Prevention over correction.

## Domain concepts

- **Excellence Pattern** — One of 8 structural rules (setup, safety, positive, negative, edge, spec-ref, assertions, coverage) that guarantee auditor score >= 80
- **Test Type** — Classification of test purpose: unit, integration, E2E, validation, regression, security, etc. (14 types total)
- **Auditor Score** — Deterministic 0-100 score from 9 criteria (SPEC-055). Tests must reach >= 80 to be certified
- **Language Pack** — Framework selection matrix mapping each of 16 languages to its native test toolchain
- **Golden Template** — A reference test file that scores 90+ on the auditor, used as starting point for all BATS tests

## Business rules it implements

- **RN-TEST-01**: Every test file must have setup/teardown isolation
- **RN-TEST-02**: BATS tests must score >= 80 on the auditor (SPEC-055)
- **RN-TEST-03**: Tests must cover positive (3+), negative (2+), and edge cases
- **RN-TEST-04**: No test may depend on external services without mock/container

## Relationship to other skills

**Upstream:** `spec-driven-development` provides specs; `product-discovery` defines acceptance criteria
**Downstream:** Generated tests feed `test-runner` for execution; `code-improvement-loop` uses regression tests
**Parallel:** `test-engineer` executes and maintains tests; `test-architect` designs and generates them

## Key decisions

- **Opus model** — Test design requires deep understanding of spec intent, edge cases, and language idioms. Sonnet is insufficient for multi-language strategy.
- **8 patterns, not 3** — Early iterations with fewer patterns scored 40-65. All 8 are needed for consistent 80+ scores.
- **Template-first for BATS** — A golden template eliminates structural errors. Customization happens in test content, not structure.
