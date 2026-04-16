---
name: risk-escalation
description: Escalation policies for code review based on risk score
---

# Rule: Risk-Based Escalation

Four-tier escalation system routing code reviews to appropriate approval levels based on automated risk assessment.

## Thresholds

| Score Range | Level | Review Path | Timeline |
|---|---|---|---|
| 0-25 | Low | Auto-merge + spot-check 24h | Expedited |
| 26-50 | Medium | Standard Code Review E1 | 24h |
| 51-75 | High | Enhanced (2 reviewers + architect) | 48h |
| 76-100 | Critical | Full (2 reviewers + architect + security + PM) | 72h |

## Escalation Process

### Phase 1: Automatic Score Calculation
Risk-scoring skill calculates score (0-100) from 8 factors.

### Phase 2: Route Assignment
Based on score, automatically request review at appropriate level.

### Phase 3: PM Override (Optional)
Product Manager can manually escalate or de-escalate by 1 level.

### Phase 4: Audit Trail
Every escalation decision logged automatically with timestamp, score, and decision.

## Integration with Code Review E1

When a code review request is created:
1. Risk score (0-100) displayed in request header
2. Factor breakdown shown in description
3. Reviewers suggested based on risk type
4. SLA per review level

## Compliance & Configuration

- Thresholds configurable via `/risk-policy --update`
- Security gate: Critical level always requires security review
- Audit immutable: All decisions logged and unmodifiable

## Special Cases

### Data Migrations
Always escalated to High minimum (schema changes are risky).

### Security Patches
Always escalated to Critical (automatic security team engagement).

### First-Time Contributor to Module
Add +10 points to risk score (penalize unfamiliarity).

## Metrics

Risk escalation metrics tracked:
- Accuracy of auto-routing
- Override frequency
- Average review time per level
- Escalation trends

Available via `/kpi-dashboard --metric risk-escalation`.
