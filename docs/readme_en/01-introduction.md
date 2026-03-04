# PM-Workspace — AI-Powered Project Management for Claude Code

## What is this?

This workspace turns Claude Code into an **AI-powered automated Project Manager** for projects of **any programming language**. It works with Azure DevOps, Jira, or 100% Git-native via Savia Flow. It supports 16 languages (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) with specialized conventions, rules, and agents for each. Its most advanced feature is **Spec-Driven Development (SDD)**: a process in which technical tasks are documented as executable contracts, and Claude can implement them as a coding agent.

**Sprint management:** burndown tracking, team capacity, board status, KPIs, automatic retrospective and review reports in Excel/PowerPoint.

**PBI decomposition:** Claude analyzes the backlog, breaks each PBI into tasks with hour estimates, detects team workload balance, and proposes assignments using a scoring algorithm (expertise × availability × balance × growth).

**Spec-Driven Development:** tasks become executable specifications. A "developer" can be a human or a Claude agent. Claude can automatically implement handlers, repositories, unit tests, and more in the project's language — following the spec as a contract.

**Infrastructure as Code:** multi-cloud management (Azure, AWS, GCP) with automatic detection of existing resources, creation at the lowest possible tier, and scaling only with human approval.

**Multi-environment:** support for DEV/PRE/PRO (or any custom configuration) with confidential configuration protection — connection strings and secrets never go into the repository.

---

## EXAMPLE — First five minutes with the workspace

_Scenario: Monday morning. You open Claude Code for the first time from the `pm-workspace/` root._

**You type:**
```
What projects do I have configured and what can I do?
```

**Claude responds:**
```
I have 2 active projects configured:
  • ProjectAlpha  — 6-person team, sprint 2026-04 active
  • ProjectBeta   — 4-person team, fixed price, sprint 2026-04 active

I can help you with:
  Sprint        → /sprint-status, /sprint-plan, /sprint-review, /sprint-retro
  Reports       → /report-hours, /report-executive, /report-capacity
  Backlog       → /pbi-decompose, /pbi-plan-sprint, /pbi-assign
  SDD (agents)  → /spec-generate, /agent-run, /spec-status

Where do you want to start? If it's Monday, I recommend /sprint-status
to see the current sprint state before the Daily standup.
```

**You type:**
```
/sprint-status --project ProjectAlpha
```

**Claude responds:**
```
══════════════════════════════════════════
  Sprint 2026-04 · ProjectAlpha · Day 6/10
══════════════════════════════════════════

  Burndown  ████████░░░░░░░░  40% complete  ⚠️ below plan
  Sprint goal: Patient Module v2

  Active items (In Progress): 4
    AB#1021  Create POST /patients endpoint  → Laura S.   [3/5h]
    AB#1022  Unit tests PatientService       → 🤖 agent   [Running]
    AB#1023  Allergies table migration       → Diego T.   [0/4h] ⚠️ no progress
    AB#1024  Swagger annotations             → 🤖 agent   [Done, in Review]

  🔴 Alerts:
    • AB#1023 has had no movement for 2 days — is it blocked?
    • Burndown at 40% on day 6 → risk of not completing sprint goal
    • Current WIP: 4 items (configured limit: 5) ✅

  Remaining capacity: 68 human hours + ~12 agent hours available
```
