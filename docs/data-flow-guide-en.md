# Data Flow Guide

> 🦉 I'm Savia. Here I explain how the parts of pm-workspace connect. Every piece of data that enters has a destination, and every report that comes out has a source. Nothing is lost, nothing is duplicated.

---

## Flow 1: Hours → Costs → Invoices → Reports

```
Team logs hours              Cost Management calculates    Billing             Leadership
┌──────────────┐    ──→    ┌─────────────────┐    ──→    ┌──────────┐    ──→    ┌────────────┐
│ /report-hours│           │ cost/hour × h    │           │ monthly  │           │ /ceo-report│
│ /savia-timesheet│        │ per project      │           │ invoices │           │ margins    │
└──────────────┘           └─────────────────┘           └──────────┘           └────────────┘
```

**How it works:** The team logs hours against PBIs (`/savia-timesheet` or Azure DevOps integration). The `cost-management` skill multiplies hours × cost/hour per profile. That generates billing data. `/ceo-report` aggregates margins per project.

**Files involved:** `output/timesheets/` → in-memory calculations → `output/reports/`

**Why it matters:** If hours aren't logged, costs are wrong, invoices fail, and the executive report doesn't reflect reality.

---

## Flow 2: Sprint → Velocity → Capacity → Alerts

```
Sprint items             Velocity trend         Capacity forecast         Alerts
┌──────────────┐   ──→  ┌──────────────┐  ──→  ┌──────────────────┐  ──→  ┌────────────┐
│ /sprint-status│        │ story points  │       │ Monte Carlo sim  │       │ /ceo-alerts│
│ item states   │        │ last 6 sprints│       │ probability      │       │ burnout    │
└──────────────┘        └──────────────┘       └──────────────────┘       └────────────┘
```

**How it works:** Each sprint closes with X story points completed. That feeds the velocity trend (moving average). With that velocity, `/capacity-forecast` runs Monte Carlo to predict if the next sprint is viable. If velocity drops and hours rise → burnout alert for PM and CEO.

**Files involved:** `.claude/commands/sprint-*.md` → `output/sprint-snapshots/` → alerts in `output/alerts/`

**Why it matters:** Without historical velocity, there's no prediction. Without prediction, the PM plans blind.

---

## Flow 3: Spec → Code → Tests → Deploy → Metrics

```
SDD spec generated      Agent implements        Code review + tests      DORA metrics
┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────────┐  ──→  ┌────────────┐
│ /spec-generate│       │ worktree      │       │ pre-commit hooks  │       │ /kpi-dora  │
│ exec contract │       │ handlers+tests│       │ quality gates     │       │ lead time  │
└──────────────┘       └──────────────┘       └──────────────────┘       └────────────┘
```

**How it works:** The PO or Tech Lead generates a spec (`/spec-generate`). An agent (or human) implements in an isolated worktree. Pre-commit hooks validate size, schema, and rules. If they pass, a PR is created. Automated code review checks against domain rules. Tests update coverage. Everything is measured as DORA metrics.

**Files involved:** `output/specs/` → `.claude/agents/developer-*.md` → `output/implementations/` → metrics in `/kpi-dora`

**Why it matters:** This is the flow that allows a "developer" to be human or AI interchangeably. The spec is the contract that guarantees quality.

---

## Flow 4: Memory → Entities → Continuity

```
Day's decisions          Memory store           Entity recall          Next session
┌──────────────┐   ──→  ┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────┐
│ conversation  │        │ JSONL + hash  │       │ stakeholders  │       │ /context-load│
│ ADRs, changes │        │ dedup + topic │       │ components    │       │ auto-inject  │
└──────────────┘        └──────────────┘       └──────────────┘       └──────────────┘
```

**How it works:** During a session, decisions are saved to the memory store (JSONL with hash deduplication). Entities (stakeholders, components, services) are tracked with `/entity-recall`. When starting a new session, `/context-load` automatically injects relevant context. The post-compaction hook preserves memory across sessions.

**Files involved:** `output/.memory-store.jsonl` → filter by topic/project → context injection

**Why it matters:** Without persistent memory, every session starts from zero. With it, Savia remembers who each stakeholder is, what was decided, and why.

---

## Hidden dependencies

These are cross-signals I detect automatically:

- **Low velocity + high hours** = possible burnout → alert to PM and CEO
- **Low coverage + fast PRs** = quality at risk → alert to Tech Lead
- **High WIP + growing cycle time** = bottleneck → alert to PO
- **Rising costs + stable velocity** = operational inefficiency → CEO alert
- **Specs without tests** = growing tech debt → blocked by quality gate

---

## File map

| Data | Where it's generated | Where it's consumed |
|---|---|---|
| Logged hours | `output/timesheets/` | cost-management, `/report-hours` |
| Project costs | in-memory calculation | invoices, `/ceo-report` |
| Sprint snapshots | `output/sprint-snapshots/` | velocity, forecast, reports |
| SDD specs | `output/specs/` | developer agents, code review |
| Implementations | `output/implementations/` | tests, PRs, DORA |
| Persistent memory | `output/.memory-store.jsonl` | context-load, entity-recall |
| Executive reports | `output/reports/` | CEO, stakeholders, clients |
