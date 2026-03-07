# Verification Lattice Domain

## Core Concepts

**Verification Layer:** A discrete set of checks that produce a structured report.

**Layer Composition:** Each layer contains criteria, agents responsible, and pass/fail gates.

**Progressive Enrichment:** Each layer receives previous layer results, enabling context-aware verification.

**Deterministic (L1):** Scripts, linters, type checkers, compilers, test runners. No AI.

**Semantic (L2):** Code-reviewer agent validates intent alignment and acceptance criteria.

**Security (L3):** security-reviewer agent scans for vulnerabilities, CVEs, secrets, PII, injection patterns.

**Agentic (L4):** architect agent validates performance, contracts, documentation, mental models, architecture.

**Human (L5):** Software engineers approve design, business alignment, maintainability. Informed by L1-L4 reports.

## Gate Policies

- **Critical Gate:** Layer must pass to proceed to next layer.
- **Soft Gate:** Layer may warn but permit override with justification.
- **Auto-Retry:** Layers 1-3 retry once on transient failure.

## Risk Scoring Integration

Layer results feed into risk-scoring skill. High-risk PRs require Layer 4. Very high risk requires all 5 layers.
