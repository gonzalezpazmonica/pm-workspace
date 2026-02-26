# Roadmap

This document describes what is planned for each upcoming version of PM-Workspace.

Milestone status: 🔴 Not started · 🟡 In progress · ✅ Done · 💡 Proposed (not committed)

Community votes on features via 👍 reactions on the corresponding GitHub Issue. The most-voted open issues are prioritised for the next milestone.

---

## ✅ v0.1.0 — Foundation (released 2026-03-01)

Complete core workspace: sprint management, reporting, PBI decomposition, Spec-Driven Development, test project, and 96-test suite. See [CHANGELOG.md](CHANGELOG.md) for full details.

---

## ✅ v0.2.0 — Quality, Discovery & Operations (released 2026-02-26)

Adds product discovery workflow (JTBD + PRD), multi-perspective PR review, session context loading, changelog automation, external repo auditing, and enhances security-guardian and commit-guardian. See [CHANGELOG.md](CHANGELOG.md) for full details.

---

## 🟡 v0.3.0 — Backlog Intelligence

_Target: Q2 2026_

Extends the workspace with features that close the loop between external inputs and the structured backlog, plus risk management.

| Feature | Issue | Status |
|---------|-------|--------|
| `backlog:capture` — create PBIs from unstructured input (emails, meeting notes, Slack threads) | [#1] | 🔴 |
| `backlog:estimate` — AI-assisted Story Point estimation based on historical PBI similarity | [#2] | 🔴 |
| `tech-debt:review` — scan backlog for tech-debt items and propose a maintenance sprint slot | [#3] | 🔴 |
| `sprint:release-notes` — auto-generate release notes combining work items + commits (builds on `/changelog:update`) | [#4] | 🔴 |
| `risk:log` — structured risk register (probability × impact) updated on each `/sprint:status` | [#5] | 🔴 |
| `risk:escalate` — automatic escalation of critical risks to PM via daily digest | [#6] | 🔴 |

---

## 🔴 v0.4.0 — Governance & Onboarding

_Target: Q3 2026_

Adds PR lifecycle tracking and team onboarding automation.

| Feature | Issue | Status |
|---------|-------|--------|
| `pr:status` — track PR state in AzDO (reviewers, pending comments, review time) — extends `/pr:review` | [#7] | 🔴 |
| `team:onboarding` — generate personalised onboarding guide for new team members | [#8] | 🔴 |

---

## 🔴 v0.5.0 — Multi-methodology and Multi-stack

_Target: Q4 2026_

Extends support beyond .NET/Scrum to other stacks and frameworks.

| Feature | Issue | Status |
|---------|-------|--------|
| Kanban support — WIP limits, flow metrics, cycle time by swimlane | [#9] | 🔴 |
| SAFe / PI Planning support — program increment planning, team PI objectives | [#10] | 🔴 |
| Java Spring Boot stack support for SDD layer matrix | [#11] | 🔴 |
| Python FastAPI stack support for SDD layer matrix | [#12] | 🔴 |
| Jira integration as alternative to Azure DevOps | [#13] | 🔴 |

---

## 💡 Proposed — No milestone yet

Ideas from the community that are not yet committed to a version. Open an issue to discuss and vote.

- GitHub Actions integration: track CI/CD pipeline status per sprint item
- Multi-language documentation (EN, DE, FR)
- `report:client` — client-facing progress report (lighter than executive report, no internal metrics)
- Budget tracking per project (burned vs. estimated cost)
- VS Code extension for running workspace commands from the editor sidebar
- MCP server exposing workspace tools to other Claude Code projects

---

## How to influence the roadmap

1. Check if your idea already has an open issue. If so, add a 👍 reaction.
2. If not, open a new issue using the **Feature request** template.
3. The most-voted open issues are pulled into the next milestone during planning.
4. If you want to implement something yourself, comment on the issue — maintainers will confirm whether the approach fits the roadmap before you invest time in a PR.
