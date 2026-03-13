---
name: verification-lattice
description: Multi-layer verification pipeline beyond Code Review
maturity: stable
context: fork
context_cost: high
category: "governance"
tags: ["verification", "multi-layer", "pipeline", "quality-gate"]
priority: "high"
---

# Verification Lattice: 5-Layer Verification Pipeline

A layered verification system where each layer builds on previous results, culminating in informed human review.

## Layer 1: Deterministic Verification
**Purpose:** Automated checks producing consistent, repeatable results.

**Checks:**
- Lint (code style, patterns)
- Format (whitespace, structure)
- Type checking (static type errors)
- Compilation (build errors)
- Unit tests (functional correctness)

**Agent:** None (scripts only)

**Gate:** All checks must pass. No exceptions.

**Output:** Pass/Fail + error log

---

## Layer 2: Semantic Verification
**Purpose:** AI-powered analysis of intent and correctness.

**Checks:**
- Implementation matches specification
- Acceptance criteria fully met
- Business logic correctness
- API contract compliance
- Documentation updates aligned with code

**Agent:** `code-reviewer`

**Gate:** All criteria mapped to code changes.

**Output:** Mapping report + acceptance criteria checklist

---

## Layer 3: Security Verification
**Purpose:** Identify vulnerabilities and compliance risks.

**Checks:**
- OWASP vulnerability patterns
- Dependency audit (known CVEs)
- Secret detection (API keys, credentials)
- PII exposure scan
- SQL injection patterns
- Authorization flaws

**Agent:** `security-reviewer`

**Gate:** No high or critical severity findings.

**Output:** Security scan report + remediation plan

---

## Layer 4: Agentic Verification
**Purpose:** Cross-cutting concerns beyond code functionality.

**Checks:**
- Performance regression analysis
- API contract compatibility
- Documentation consistency
- Mental model freshness
- Architecture alignment

**Agent:** `architect`

**Gate:** No regressions, architecture decisions justified.

**Output:** Architecture review + risk assessment

---

## Layer 5: Human Code Review
**Purpose:** Design decisions, business alignment, maintainability.

**Input:** Consolidated report from layers 1-4.

**Focus:**
- Design decisions rationale
- Business alignment
- Long-term maintainability
- Code clarity and readability

**Gate:** Human approval required.

**Output:** Reviewer sign-off + design notes

---

## Execution Flow

1. Layer 1 runs → produces report
2. Layer 2 consumes Layer 1 report → produces report
3. Layer 3 consumes Layers 1-2 reports → produces report
4. Layer 4 consumes Layers 1-3 reports → produces report
5. Human reviewer reads consolidated report from Layers 1-4 → approves/requests changes

Each layer is independent executable, but cascade provides context enrichment.

---

## Commands

- **`/verify-full {task-id}`** — Run all 5 layers sequentially
- **`/verify-layer {N} {task-id}`** — Run specific layer for debugging

---

## Output Storage

All verification results stored in `output/verification/{task-id}/`:
- `layer1-deterministic.json`
- `layer2-semantic.json`
- `layer3-security.json`
- `layer4-agentic.json`
- `layer5-human-checklist.md`
