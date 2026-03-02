# Task Template — Spec-Driven Development (SDD) in Savia Flow

## Overview

This template ensures every implementation task contains the 5 essential components from Savia Flow. Use this as a checklist before marking a spec "Spec-Ready."

---

## The 5 Components of a Savia Flow Spec

### 1. Outcome Statement (Why)

Link to strategic parent Epic/OKR. Answer:
- **What problem?** Current pain point
- **For whom?** Target users/stakeholders
- **Why now?** Business urgency
- **Expected impact?** Quantifiable outcome

### 2. Success Metrics (What Success Looks Like)

3–5 KPIs with baseline (current) and target (desired).

Example:
```
Success Metrics:
1. Signup completion: 45% → 70%
2. Time to first action: <5 min → <3 min
3. Email verification success: 85% → 95%
4. Support tickets (related): 120/week → <80/week
5. DAU growth (new): +15 → +25
```

### 3. Functional Specification (What to Build)

Detailed behavior using **Given/When/Then** scenarios.

Must include: user journeys, mockups, edge cases, business rules, integrations.

Example (Registration):
```
SCENARIO 1: Valid email + password
GIVEN user on registration page
WHEN entering valid email (not registered) and strong password
THEN account created, verification email sent, redirect to verify page

SCENARIO 2: Duplicate email
GIVEN registration form
WHEN email already exists
THEN show error: "Email registered. Forgot password? Login here."

SCENARIO 3: Weak password
GIVEN password field
WHEN < 8 chars OR missing required types
THEN show inline error, disable submit, highlight red
```

### 4. Technical Constraints (How to Build It)

Explicit technical decisions:
- **Architecture**: Stack, services, data storage
- **Performance**: Latency budgets (< 2 sec), throughput (1K concurrent)
- **Security**: Auth method, validation, data classification, encryption
- **Dependencies**: APIs, databases, queues, libraries
- **Scalability**: Rate limiting, fallback strategies

### 5. Definition of Done (DoD Checklist)

Explicit, testable completeness criteria:
- Unit tests ≥80% coverage
- E2E tests (happy path + errors)
- Security scan: 0 blockers/criticals
- Accessibility: WCAG AA
- Performance validated (P95 < agreed latency)
- Documentation updated
- Code review approved

---

## Azure DevOps Field Mapping

| Field | Maps To | Example |
|---|---|---|
| Title | Spec name | "User Registration with Email & OAuth" |
| Description | Full spec (5 sections) | *[Complete spec]* |
| Acceptance Criteria | Given/When/Then scenarios | *[Scenarios]* |
| Story Points | Effort (1-8) | 5 |
| Tags | track:production, outcome:ID, spec-ready | `track:production outcome:EPIC-847` |
| Custom: Track | Savia Flow track | Production |
| Custom: Outcome ID | Parent Epic ID | EPIC-847 |
| Custom: Cycle Time Start | Auto when Building | *(automation)* |
| Custom: Cycle Time End | Auto when Deployed | *(automation)* |

---

## Spec Quality Checklist

Before marking "Spec-Ready":

- [ ] Outcome links parent Epic + OKR
- [ ] ≥3 success metrics (baseline → target, quantified, time-bound)
- [ ] ≥3 Gherkin scenarios (happy + error cases)
- [ ] Performance quantified (latency, throughput)
- [ ] Security explicit (auth, validation, classification, encryption)
- [ ] Dependencies listed (APIs, DBs, queues, services)
- [ ] DoD checklist complete (testing, gates, coverage)
- [ ] No ambiguity — every statement testable
- [ ] Architect approval
- [ ] QA plan achievable

See references/sdd-example-full.md for a complete worked example.
