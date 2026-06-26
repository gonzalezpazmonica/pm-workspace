# Dual-Track Coordination: Exploration & Production

## Two Tracks, One Team

**Exploration** discovers WHAT to build  
**Production** builds WHAT's ready  
Together, they keep the team flowing.

## Role Allocation

### Elena (AI Product Manager + Quality Architect)
- **60% Exploration:** user research, hypothesis validation, spec writing
- **40% Production:** quality gate design, gate reviews, defect investigation
- **Key outputs:** Specs, test strategies, gate configurations

### Ana (Pro Builder — Frontend)
- **100% Production:** Ionic components, screens, UX implementation
- **Consulted by:** Elena (for UX feasibility during spec writing)
- **WIP limit:** 2 items simultaneously

### Isabel (Pro Builder — Backend + Architecture)
- **90% Production:** microservices, APIs, RabbitMQ, MongoDB
- **10% Exploration:** architecture consultations during spec writing
- **Key responsibility:** Review technical constraints in specs before Spec-Ready
- **WIP limit:** 2 items simultaneously

### la usuaria (Flow Facilitator)
- **Oversight:** metrics, unblocking, priority decisions
- **Handoff:** reviews Spec-Ready items, assigns to builders
- **Escalation:** resolves cross-track dependencies
- **Note:** Not counted in WIP (enabler role)

## Handoff Ritual: Spec-Ready → Production

1. Elena marks spec as **Spec-Ready** (all 5 sections complete)
2. la usuaria reviews: outcome clear? metrics measurable? DoD testable?
3. If complex backend: Isabel reviews technical constraints (15 min)
4. la usuaria assigns to available builder based on:
   - Skill match (front vs back)
   - Current WIP (don't exceed limit)
   - Context (has the person worked on related items?)
5. Item moves from Area Path **Exploration → Production**
6. Builder starts: **Cycle Time Start** timestamp set

## Capacity Split Strategy

- **Exploration buffer:** should always have ≥3 Spec-Ready items
  - If buffer <3: Elena focuses 80% on exploration (reduce gate time)
  - If buffer >7: Elena shifts to 60% gates (avoid spec staleness)
- **Production:** should never have 0 Ready items (avoid starvation)
  - If starvation detected: la usuaria escalates, Elena prioritizes spec completion

## Dependency Management

**Front ↔ Back Coordination:**
- Ana needs Isabel's API → create linked items, Isabel delivers API contract first
- Pattern: API contract first (Isabel), then parallel build (Ana front + Isabel implementation)

**Exploration ↔ Production:**
- If spec needs production data, tag with "needs-production-input"

**External Dependencies:**
- Third-party APIs, infrastructure → track as blockers with owner

## Anti-Patterns to Avoid

- **Exploration starvation:** Elena pulled into too many gate reviews → production stops
- **Spec pile-up:** more specs ready than team can build → specs go stale, need rework
- **Single-track thinking:** everyone works exploration OR production → lose parallel benefit
- **Handoff without review:** specs skip quality check → rework in production
- **Architecture as bottleneck:** Isabel consulted on everything → becomes blocker

## Metrics to Monitor Balance

- **Spec-Ready buffer size** — target: 3–5 items
- **Time in Spec-Ready** — target: <5 days (stale if >10 days)
- **Exploration throughput** — specs completed per week
- **Production throughput** — items deployed per week
- **Handoff latency** — Spec-Ready → Building start, target: <2 days
