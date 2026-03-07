# Sprint Management — Domain Context

## Why this skill exists

Sprints provide cadence and focus: fixed scope, fixed duration (typically 2 weeks), clear goal. Without structured sprint management, teams drift into chaos: scope creep mid-sprint, no visibility into progress, ceremonies become theater. This skill implements Scrum rigor and flow visibility.

## Domain concepts

- **Sprint** — 2-week (standard) timebox with committed scope, daily syncs, review + retro
- **Sprint Goal** — 1-2 sentence vision for sprint (not feature list); unifies team
- **WIP Limit** — Max items in "In Progress"; forces flow, prevents context switching
- **Burndown** — Daily graph of remaining points. Shows if sprint is on track to commit.
- **DoD (Definition of Done)** — Checklist: code written + tested + reviewed + documented + shipped

## Business rules it implements

- **RN-SCRUM-01**: Sprint scope locked after planning (no mid-sprint addition without removal)
- **RN-SCRUM-02**: Daily standup at fixed time; blocks flagged same day
- **RN-SCRUM-03**: WIP limit = avg team size (e.g., 5 people → max 5 items In Progress)
- **RN-SCRUM-04**: Sprint review + retro mandatory (not optional)

## Relationship to other skills

**Upstream:** `capacity-planning` provides max capacity for sprint
**Downstream:** `azure-devops-queries` pulls sprint data for burndown; `reporting` generates velocity trends
**Parallel:** `pbi-decomposition` Task creation uses sprint as scope boundary

## Key decisions

- **Fixed duration** — 2 weeks is default, non-negotiable (stability over flexibility)
- **No mid-sprint scope adds** — Protects estimates; if critical, swap equal-size item out
- **WIP limit enforced** — Prevents multitasking; maximizes flow
- **Retro as driver** — Continuous improvement from team feedback, not top-down mandates
