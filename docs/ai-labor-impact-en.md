# AI Labor Impact Analysis

## Overview

This module enables organizations to measure and anticipate the impact of artificial intelligence on their teams. Based on Anthropic's "observed exposure" framework (2026), it provides concrete metrics to distinguish between automation (AI replaces tasks) and augmentation (AI amplifies human capabilities).

## Components

### Command: `/ai-exposure-audit`

Comprehensive AI exposure audit by role. Breaks down each role into tasks, measures theoretical exposure (what AI could do) vs. observed exposure (what it already does), and classifies displacement risk.

**Subcommands:**

- `/ai-exposure-audit` — full team audit
- `/ai-exposure-audit --role {role}` — single role analysis
- `/ai-exposure-audit --team {team}` — team-level analysis
- `/ai-exposure-audit --threshold {N}` — only roles with exposure > N%
- `/ai-exposure-audit reskilling` — reskilling plan generation

### Rule: `ai-exposure-metrics.md`

Defines the 4 core metrics:

- **Theoretical Exposure (TE)** — percentage of tasks theoretically automatable
- **Observed Exposure (OE)** — percentage already being automated in practice
- **Adoption Gap (AG)** — difference between TE and OE (window for action)
- **Augmentation Ratio (AR)** — proportion of AI use as copilot vs. replacement

Also includes the **Junior Hiring Gap Index (JHG)**, which detects whether a team has stopped hiring juniors in exposed roles — a leading indicator of talent pipeline erosion. Reference: ~14% decline in junior hiring post-ChatGPT (Anthropic, 2026).

### Skill: `ai-labor-impact`

Orchestrates 4 analysis flows:

1. **Audit** — exposure mapping and risk classification
2. **Reskilling** — reconversion plans with timelines and resources
3. **JHG** — Junior Hiring Gap monitoring
4. **Simulate** — automation impact simulation on team capacity

## Risk Classification

| Observed Exposure | Risk | Action |
|---|---|---|
| > 60% | 🔴 High | Immediate reskilling plan (8 weeks) |
| 30-60% | 🟡 Medium | Monitor + preventive plan (12 weeks) |
| < 30% | 🟢 Low | Augmentation focus; optimize AI usage |

## Integration with Existing Commands

- `/capacity-forecast --scenario automate` — simulates capacity impact
- `/enterprise-dashboard team-health` — includes exposure score
- `/team-skills-matrix` — bus factor + exposure = compound risk
- `/burnout-radar` — correlates burnout with roles in transition
- `ai-competency-framework.md` — defines reskilling competency levels

## Ethical Use

This module is designed as a planning and care tool, not a headcount reduction instrument. Command restrictions explicitly prohibit using scores to justify layoffs or sharing individual data without consent.

## References

- Anthropic, "The Labor Market Impacts of AI" (2026)
- O*NET OnLine — Occupational Information Network
- BLS Occupational Outlook Handbook
- Eloundou et al. — "GPTs are GPTs" theoretical capability scores
