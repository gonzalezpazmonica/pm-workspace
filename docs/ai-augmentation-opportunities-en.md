# AI Augmentation Opportunities by Sector

> 🦉 I'm Savia. This analysis identifies sectors where AI has the highest theoretical capability but the lowest real adoption — and how pm-workspace can help close that gap.

---

## The concept: AI Augmented Donut

The "AI Augmented Donut" model (Anthropic, analyzed by Miguel Luengo-Oroz) compares two dimensions for each occupation: theoretical AI exposure (how much of that work could AI do) and observed adoption (how much is actually being used). The gap between them is the augmentation opportunity.

Sectors with the largest gap would benefit most from well-designed AI tools — but are using them the least today.

---

## Sectors with the greatest opportunity

| Sector | Theoretical capability | Real adoption | Gap | pm-workspace today |
|---|---|---|---|---|
| Healthcare (practitioners) | High | Low | Large | guide-healthcare.md |
| Education & library | High | Low | Large | guide-education.md |
| Social services | High | Very low | Very large | Does not exist |
| Sales | High | Low | Large | Does not exist |
| Legal | High | Medium-low | Large | guide-legal-firm.md |
| Arts & media | High | Low | Large | Does not exist |
| Business & finance | High | Medium | Medium | Partial (enterprise) |

---

## How pm-workspace already covers them

**Healthcare** — The `guide-healthcare.md` adapts pm-workspace for healthcare organizations: continuous improvement protocols, HIPAA compliance, shift management, and clinical indicator tracking. Sprint and reporting commands apply to PDCA improvement cycles.

**Education** — The `guide-education.md` and Savia School cover educational project management, competency assessment, student portfolios, and GDPR compliance for minors. Timesheets track teaching dedication.

**Legal** — The `guide-legal-firm.md` adapts the workspace for law firms: case management as PBIs, legal deadlines as sprints, hourly billing integrated with cost-management, and sector compliance.

---

## Identified gaps

### Social services (very large gap)

**Opportunity:** Social case management, multi-agency coordination, beneficiary tracking, impact reporting for funders.

**Applicable pm-workspace workflows:** Sprint management for intervention cycles, capacity planning for caseload distribution, time tracking for grant justification, executive reporting for activity reports.

**Extensión needed:** Domain entities (beneficiary, case, intervention), custom states (assessment → plan → follow-up → closure), social impact metrics.

### Sales (large gap)

**Opportunity:** Commercial pipeline management, sales forecasting, campaign coordination, performance reporting.

**Applicable workflows:** Backlog management for pipeline (leads as PBIs), sprint for campaign cycles, velocity for conversion rate, stakeholder reports for sales leadership.

**Extensión needed:** Domain entities (lead, opportunity, account), funnel stages, commercial metrics (CAC, LTV, churn).

### Arts & media (large gap)

**Opportunity:** Creative production management, multidisciplinary team coordination, deliverable and review tracking, production budgets.

**Applicable workflows:** Sprint for production cycles, spec-driven for creative briefs, code review adapted for content review, time tracking for production budgets.

**Extensión needed:** Domain entities (piece, campaign, brief), review states (draft → review → approval → publication), production metrics.

---

## Relationship with `/ai-exposure-audit`

The `/ai-exposure-audit` command already calculates each role's AI exposure using O*NET data. It could be extended to show not just exposure but the augmentation gap: how much that role could benefit from tools like pm-workspace, comparing theoretical capability vs real adoption.

This would transform the audit from a risk analysis ("Will AI replace me?") into an opportunity analysis ("Where can I multiply my impact with AI?").

---

## Next steps

1. Create `guide-social-services.md` for the social services vertical
2. Create `guide-sales.md` for the sales vertical
3. Create `guide-arts-media.md` for the arts & media vertical
4. Extend `/ai-exposure-audit` with the augmentation gap dimension

> Source: Analysis based on Anthropic's "AI Augmented Donut" model, reviewed by Miguel Luengo-Oroz (2025).
