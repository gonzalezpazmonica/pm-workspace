# Introduction to PM-Workspace

> 🦉 I'm Savia. If you just arrived, this page is for you. In 5 minutes you'll know what I am, what I can do for you, and how to start based on your role.

---

## What is this?

PM-Workspace turns Claude Code into an AI-powered automated Project Manager. I manage sprints, backlog, code agents, infrastructure, billing, and reports — in 16 languages, with Azure DevOps, Jira, or 100% Git-native (Savia Flow).

My most advanced feature is **Spec-Driven Development**: tasks are documented as executable contracts, and an agent (or human) implements them following that contract.

---

## Who are you?

Your experience with me depends on your role. Go directly to your quick-start:

- **PM / Scrum Master** → [quick-start-pm](../quick-starts_en/quick-start-pm.md)
- **Tech Lead** → [quick-start-tech-lead](../quick-starts_en/quick-start-tech-lead.md)
- **Developer** → [quick-start-developer](../quick-starts_en/quick-start-developer.md)
- **QA** → [quick-start-qa](../quick-starts_en/quick-start-qa.md)
- **Product Owner** → [quick-start-po](../quick-starts_en/quick-start-po.md)
- **CEO / CTO** → [quick-start-ceo](../quick-starts_en/quick-start-ceo.md)

---

## Example — First 5 minutes

_Scenario: Monday morning. You open Claude Code in pm-workspace._

**You:** `What projects do I have and what can I do?`

**Savia:**
```
I have 2 active projects:
  • ProjectAlpha — 6-person team, sprint 2026-04 active
  • ProjectBeta  — 4-person team, fixed price

I can help you with:
  Sprint   → /sprint-status, /sprint-plan, /sprint-review
  Reports  → /report-hours, /report-executive
  Backlog  → /pbi-decompose, /pbi-plan-sprint
  SDD      → /spec-generate, /agent-run

Where shall we start? If it's Monday, I recommend /sprint-status.
```

**You:** `/sprint-status --project ProjectAlpha`

**Savia:**
```
Sprint 2026-04 · ProjectAlpha · Day 6/10
Burndown ████████░░░░░░░░ 40% ⚠️ below plan

Active items: 4
  AB#1021  POST /patients → Laura [3/5h]
  AB#1022  Unit tests     → 🤖 agent [running]
  AB#1023  Migration      → Diego [0/4h] ⚠️ no progress
  AB#1024  Swagger        → 🤖 agent [review]

🔴 AB#1023 has had no movement for 2 days
🔴 Burndown at 40% on day 6 → risk of not completing
```

---

## Where we are in the documentation

```
docs/
├── readme_en/
│   ├── 01-introduction.md    ← YOU ARE HERE
│   ├── 02-structure.md       ← directories and files
│   ├── 03-setup.md           ← PAT, constants, setup
│   ├── 04-usage-sprint-*.md  ← sprints and reports
│   ├── 05-sdd.md             ← Spec-Driven Development
│   └── ...                   ← 13 sections total
├── quick-starts_en/          ← role-based quick guides
├── guides_en/                ← 13 scenario guides
└── data-flow-guide-en.md     ← how the parts connect
```

---

## Next step

Go to your [role quick-start](#who-are-you) or continue with [workspace structure](02-structure.md).
