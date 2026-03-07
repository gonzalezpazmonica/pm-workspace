---
name: verification-policy
description: Mandatory layers for verification. Gates and retry policies.
context: domain
---

# Verification Policy — Mandatory Layers & Gates

Policy governing which layers must pass before PR can merge, based on risk scoring.

## Mandatory Layer Requirements

### Layers 1-3: ALWAYS REQUIRED

Every PR must pass:
- **Layer 1 (Deterministic):** All automated checks
- **Layer 2 (Semantic):** Spec compliance mapping complete
- **Layer 3 (Security):** No high or critical vulnerabilities

**Gate:** ALL PASS → proceed to Layer 4
**Gate:** ANY FAIL → stop, fix, re-run failed layer

### Layer 4: Required if Risk Score > 50

- **Risk Score 0-50:** Layer 4 optional (agile delivery)
- **Risk Score 51-100:** Layer 4 mandatory (architecture review required)

### Layer 5: Required UNLESS Risk Score < 25

- **Risk Score 0-25:** Layer 5 optional (auto-approve possible)
- **Risk Score 26-100:** Layer 5 mandatory (human review always required)

## Gate Policies

| Layer | Gate Type | Fail Action | Retry |
|---|---|---|---|
| 1-3 | Hard gate | Stop, fix code | Auto-retry once |
| 4 | Conditional gate | Stop if risk > 50 | Manual retry |
| 5 | Human gate | Requires approval | N/A (human decides) |

## Automatic Retry Policy

- **Layers 1-3:** Automatic retry once on failure (2 attempts total)
- **Transient failures only:** build timeout, network error, etc.
- **Logic failures:** do NOT retry automatically, escalate
- **Escalation:** After 2 failures, require human review of root cause

## Output Storage

All verification results stored in: `output/verification/{task-id}/`

Artifacts:
- `layer1-deterministic.json` — lint, format, compile, test results
- `layer2-semantic.json` — spec mapping, acceptance criteria
- `layer3-security.json` — vulnerability scan results
- `layer4-agentic.json` — performance, contracts, architecture
- `layer5-human-checklist.md` — human review template

## Risk Score Integration

Risk score calculated independently by `risk-scoring` skill:
- **0-25:** Minimal complexity (CRUD, formulaic)
- **26-50:** Moderate complexity (business logic, few dependencies)
- **51-75:** High complexity (cross-cutting, auth, integrations)
- **76-100:** Critical complexity (infrastructure, migrations, security)

Verification pipeline adapts:
- Low risk → fast-track (L1-3 only)
- Medium/high risk → full pipeline (L1-5)
- Critical risk → full pipeline + human escalation to PM/security

## Policy Enforcement

- `/verify-full` respects these policies automatically
- `/verify-layer` can override (for debugging only)
- Each layer reports its gate status
- Consolidated report lists gates passed/failed
- NEVER merge with failed hard gate

## Configuration Per Project

Projects can override via `projects/{proyecto}/verification-policy.md`:

```yaml
layers_required: [1, 2, 3]  # Always 1-3
layer_4_threshold: 50        # Risk score threshold
layer_5_threshold: 25        # Risk score threshold
auto_retry: true
retry_count: 1
stop_on_critical: true
```
