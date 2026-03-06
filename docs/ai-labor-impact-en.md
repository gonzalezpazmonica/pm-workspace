# AI Labor Impact Analysis

## Overview

pm-workspace includes a labor impact analysis module that enables organizations to measure and anticipate how artificial intelligence affects their teams. Based on Anthropic's "observed exposure" framework (2026), Savia provides concrete metrics to distinguish between automation (AI replaces tasks) and augmentation (AI amplifies human capabilities), with integrated reskilling plans.

Compatible with Azure DevOps, Jira, and Savia Flow (Git-native).

## Components

### Command: `/ai-exposure-audit`

Comprehensive AI exposure audit by role. Breaks down each role into tasks (O*NET taxonomy), measures theoretical exposure (what AI could do) vs. observed exposure (what it already does), and classifies displacement risk with action plans.

**Subcommands:**

- `/ai-exposure-audit` — full team audit
- `/ai-exposure-audit --role {role}` — single role analysis
- `/ai-exposure-audit --team {team}` — team-level analysis
- `/ai-exposure-audit --threshold {N}` — only roles with exposure > N%
- `/ai-exposure-audit reskilling` — per-role reskilling plan

Reports generated at `output/analytics/ai-exposure-YYYYMMDD.md`.

### Rule: `ai-exposure-metrics.md`

Defines the 4 core metrics and a talent pipeline index:

- **Theoretical Exposure (TE)** — percentage of tasks theoretically automatable
- **Observed Exposure (OE)** — percentage already being automated in practice
- **Adoption Gap (AG)** — difference between TE and OE (window for action)
- **Augmentation Ratio (AR)** — proportion of AI use as copilot vs. replacement

Also includes the **Junior Hiring Gap Index (JHG)**, which detects whether a team has stopped hiring juniors in exposed roles — a leading indicator of talent pipeline erosion. Reference: ~14% decline in junior hiring post-ChatGPT (Anthropic, 2026). JHG can be fed from the SaviaHub member directory (`/savia-directory`) to compute historical onboarding rates.

### Skill: `ai-labor-impact`

Orchestrates 4 analysis flows in isolated context (subagent):

1. **Audit** — exposure mapping and risk classification
2. **Reskilling** — reskilling plans with timelines, resources, and ai-competency-framework levels
3. **JHG** — Junior Hiring Gap monitoring using team data or SaviaHub
4. **Simulate** — automation impact simulation on team capacity (connects to `/capacity-forecast`)

## Risk Classification

| Observed Exposure | Risk | Action |
|---|---|---|
| > 60% | 🔴 High | Immediate reskilling plan (8 weeks) |
| 30-60% | 🟡 Medium | Monitor + preventive plan (12 weeks) |
| < 30% | 🟢 Low | Augmentation focus; optimize AI usage |

## Integration with pm-workspace

- `/capacity-forecast --scenario automate` — simulates capacity impact on team
- `/enterprise-dashboard team-health` — includes exposure score in SPACE radar
- `/team-skills-matrix` — bus factor + exposure = compound risk per module
- `/burnout-radar` — correlates burnout with roles in AI transition
- `/daily-routine` — role definitions feed task decomposition
- `/savia-directory` — onboarding data for JHG computation
- `ai-competency-framework.md` — defines 6 AI competency levels for reskilling paths

## Ethical Use

Savia treats this module as a planning and care tool, not a headcount reduction instrument. Command restrictions explicitly prohibit using scores to justify layoffs or sharing individual data without consent. Aligned with `equality-shield.md` (mandatory counterfactual test in evaluations).

## References

- Anthropic, "The Labor Market Impacts of AI" (2026)
- O*NET OnLine — Occupational Information Network
- BLS Occupational Outlook Handbook
- Eloundou et al. — "GPTs are GPTs" theoretical capability scores
