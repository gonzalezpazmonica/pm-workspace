# Meetings Cadence for Savia Flow (4-Person Team)

## Principle
Meetings exist to solve problems, not fulfill rituals. If no problems, no meeting.

## Daily: Async Dashboard Check
**Format:** 5 min, everyone, async

- Each person checks flow-board at start of day
- If blockers: post in team chat, tag affected person
- No standup meeting. Metrics dashboard replaces it.
- Tool: `/flow-board` shows WIP, bottlenecks, cycle time

## Weekly Sync
**Format:** 30 min, everyone, Monday 10:00

**Facilitator:** la usuaria

**Agenda:**
1. Flow metrics review (5 min) — cycle time trend, throughput, CFR
2. Bottleneck review (10 min) — items stuck >2 days, WIP exceeded
3. Exploration → Production handoff (10 min) — review Spec-Ready items, assign to builders
4. Decisions needed (5 min) — architecture, priority changes, dependency resolution

**Output:** Updated board, assignments, decisions logged

**Tools:** `/flow-metrics` + `/flow-intake`

## Spec Review
**Format:** 30 min, on-demand, when spec moves to Spec-Ready

**Participants:** Elena (author) + la usuaria (reviewer) + builder if complex

**Purpose:** Validate spec quality before handoff

**Checklist:**
- Outcome clear
- Metrics defined
- Edge cases covered
- DoD testable

**Tool:** `/flow-spec` output as basis

## Gate Review
**Format:** 15–30 min, on-demand, when gate fails

**Participants:** builder + Elena (QA) + Isabel (if architecture issue)

**Purpose:** Unblock failed quality gates

**Types of gates:**
- Security finding
- Performance regression
- Test coverage gap

**Output:** Fix plan with owner and deadline

## Monthly Retro
**Format:** 90 min, first Friday of month

**Facilitator:** la usuaria

**Sections:**
1. Metrics trend (15 min) — compare this month vs last
2. What's flowing well (20 min)
3. What's stuck (20 min) — recurring bottlenecks, patterns
4. Experiments to try (20 min) — adjust WIP limits, change handoff rules, new gates
5. Action items with owners (15 min)

**Tools:** `/retro-patterns --sprints 4` + `/flow-metrics --trend 4`

## Quarterly Planning
**Format:** 4h, first week of quarter

**Participants:**
- la usuaria + Elena (full session)
- Ana + Isabel (last 2h only)

**Structure:**
- First 2h: OKR review, strategic priorities, outcome definition
- Last 2h: Outcome decomposition into exploration items, rough capacity check

**Output:** Exploration backlog for next quarter, updated OKRs

**Tools:** `/okr-track`, `/capacity-forecast --sprints 6`

## Weekly Calendar Template (4-Person Team)

| Day | la usuaria | Elena | Ana | Isabel |
|---|---|---|---|---|
| Mon | Weekly sync 10:00 | Weekly sync 10:00 | Weekly sync 10:00 | Weekly sync 10:00 |
| Tue | Oversight + unblocking | Discovery + spec writing | Building (front) | Building (back) |
| Wed | Spec reviews (on-demand) | Spec reviews + gate reviews | Building (front) | Building (back) |
| Thu | Strategic + portfolio | Discovery + gate reviews | Building (front) | Building (back) + arch |
| Fri | Metrics review | QA gates + spec polish | Building + PR review | Building + PR review |

---

## Key Principle
No meeting without a clear decision or problem to solve. Default to async. Tools replace rituals.
