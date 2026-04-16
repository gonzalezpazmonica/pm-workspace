# Spec-Driven Development (SDD)

SDD is the workspace's most advanced feature. It allows technical tasks to be implemented by a human developer **or by a Claude agent**, depending on the type of task.

A Spec is a contract that describes exactly what to implement. If the contract is detailed enough, an agent can implement it without human intervention.

## Developer types

| Type | Who implements | When |
|------|----------------|------|
| `human` | Team developer | Domain logic, migrations, external integrations, Code Review |
| `agent-single` | One Claude agent | Handlers, Repositories, Validators, Unit Tests, DTOs, Controllers |
| `agent-team` | Implementer + Tester in parallel | Tasks ≥ 6h with production code + tests |

## SDD workflow

```
1. /pbi-decompose → task proposal with "Developer Type" column
2. /spec-generate {task_id} → generates .spec.md file from Azure DevOps
3. /spec-review {spec_file} → validates the spec (quality, completeness)
4. If developer_type = agent:
     /agent-run {spec_file} → agent implements the spec
   If developer_type = human:
     Assign to the developer
5. /spec-review {spec_file} --check-impl → pre-check of generated code
6. Code Review (E1) → ALWAYS human (Tech Lead)
7. PR → merge → Task: Done
```

## The Spec template

Each Spec (`.spec.md`) has 9 sections that eliminate ambiguity:

1. **Header** — Task ID, developer_type, estimate, assigned to
2. **Context and Goal** — why the task exists, relevant acceptance criteria
3. **Technical Contract** — exact class/method signatures, DTOs with types and constraints, dependencies to inject
4. **Business Rules** — table with each rule, its exception, and HTTP code
5. **Test Scenarios** — Given/When/Then for happy path, errors, and edge cases
6. **Files to Create/Modify** — exact list of paths (the agent cannot deviate from this list)
7. **Reference Code** — example of the same pattern in the project
8. **Implementation Status** — agent log, blockers
9. **Pre-Delivery Checklist** — verification before passing to Code Review

## What tasks an agent can do (by default)

The full matrix is in `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md` (there is one matrix per supported language). Generic summary:

**The agent can do:** Application/Service Layer (Handlers, Services, Validators, Mappers, DTOs), Infrastructure/Data Layer (Repositories, Entity Configurations, simple migrations), API/Presentation (CRUD Controllers, endpoints, documentation), Tests (Unit Tests when scenarios are in the Spec).

**Always human:** Domain Layer (new aggregate root entities, Domain Services, complex business logic), complex database migrations, authentication/authorization configuration, external system integrations, cloud infrastructure (apply/create requires human approval), Code Review (E1) — no exceptions.

---

## EXAMPLE — Full SDD flow: from task to production code

_Scenario: Task AB#302-B3 "GetHistorialCitasQueryHandler" is ready for the agent to implement._

**Step 1 — Generate the spec**

**You type:**
```
/spec-generate 302-B3 --project ClinicManagement
```

**Claude responds:**
```
Reading AB#302 (parent PBI) and AB#302-B3 (Task)...
Analyzing existing code in projects/clinic-management/source/...
→ Module: Appointments / Layer: Application / Type: QueryHandler
→ Developer type: agent-single (repeatable pattern, interfaces defined)

Spec generated:
  projects/clinic-management/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md

Preview of the most critical section (Technical Contract):
┌─────────────────────────────────────────────────────────────────┐
│  public sealed class GetHistorialCitasQuery                     │
│      : IRequest<PagedResult<HistorialCitaDto>>                  │
│  {                                                              │
│      public Guid PacienteId { get; init; }                      │
│      public DateOnly FechaInicio { get; init; }                 │
│      public DateOnly FechaFin { get; init; }                    │
│      public string? Cursor { get; init; }   // pagination       │
│      public int PageSize { get; init; } = 20;                   │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘

Do you want to review the spec before implementing? → /spec-review AB302-B3-...
```

**Step 2 — Validate the spec**

**You type:**
```
/spec-review AB302-B3-get-historial-citas-handler.spec.md
```

**Claude responds:**
```
Reviewing spec quality...

✅ Header complete (Task ID, developer_type, estimate, assigned to)
✅ Technical contract defined (interfaces, DTOs, dependencies)
✅ Business rules documented: 4 rules with exceptions and HTTP codes
✅ Test scenarios: 6 scenarios (happy path + invalid dates + patient not found)
✅ Files to create listed: 3 files at exact paths
✅ Reference code included (GetCitasDelDíaQueryHandler as pattern)

══════════════════════
  ✅ SPEC READY
  You can run /agent-run
══════════════════════
```

**Step 3 — Launch the agent**

**You type:**
```
/agent-run projects/clinic-management/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
```

**Claude responds:**
```
Launching claude-opus-4-7 agent on AB302-B3...
Live log: output/agent-runs/20260519-094512-AB302-B3-single.log

[09:45:14] Agent started — reading spec and project context
[09:45:31] Creating GetHistorialCitasQuery.cs
[09:45:44] Creating GetHistorialCitasQueryHandler.cs
[09:46:02] Creating HistorialCitaDto.cs + AutoMapper profile
[09:46:18] Running dotnet build... ✅ 0 errors
[09:46:35] Running dotnet test --filter "GetHistorial"... 6/6 ✅
[09:46:41] Agent finished.

══════════════════════════════════════════════
  ✅ IMPLEMENTATION COMPLETE
  Build: OK | Tests: 6/6 | Duration: 87s
  Estimated cost: ~$0.62 USD
══════════════════════════════════════════════

Files created:
  + Application/Appointments/Queries/GetHistorialCitas/GetHistorialCitasQuery.cs
  + Application/Appointments/Queries/GetHistorialCitas/GetHistorialCitasQueryHandler.cs
  + Application/Appointments/Queries/GetHistorialCitas/HistorialCitaDto.cs

⚠️  IMPORTANT: Code Review (E1) is mandatory before merging.
   Assign AB#302-E1 to Carlos TL for review.

Shall I update Task AB#302-B3 in Azure DevOps to "In Review" status?
```

---

## EXAMPLE — Sprint spec dashboard

_Scenario: You want to see the status of all SDD tasks in the sprint at a glance._

**You type:**
```
/spec-status --project ClinicManagement
```

**Claude responds:**
```
══════════════════════════════════════════════════════════════════
  SDD Status · ClinicManagement · Sprint 2026-05
══════════════════════════════════════════════════════════════════

  Task                             Spec         Dev Type     Status   h    Assigned
  ─────────────────────────────────────────────────────────────────────────────────
  AB#302-B3 GetHistorialCitas      ✅ ready      agent-single  ✅ done  4h   agent
  AB#302-C1 HistorialController    ✅ ready      agent-single  🔄 impl  3h   agent
  AB#302-C2 Cursor pagination      ✅ ready      agent-single  ⏳ queue 3h   agent
  AB#302-D1 Unit tests handler     ✅ ready      agent-single  ⏳ queue 2h   agent
  AB#301-B3 SendConfirmationCmd    ⚠️ incomplete agent-single  🚫 blk   4h   agent
  AB#301-D1 EmailTemplateService   ⏳ pending    agent-single  ⏳ queue 3h   agent

  Summary:
    Completed: 1 | In progress: 1 | In queue: 3 | Blocked: 1
    Agent hours saved (completed): 4h (~$2.48 USD)
    Agent hours estimated (full sprint): 19h (~$11.78 USD est.)

  ⚠️  AB#301-B3 blocked:
     The spec has an incomplete Technical Contract section —
     the IEmailService signature is missing. Run /spec-review AB301-B3-...
     to see exactly what's missing.
```

---

## Agent team patterns

For large tasks, you can use a team of agents in parallel:

```bash
/agent-run {spec_file} --team
# Launches: Implementer (opus) + Tester (haiku) in parallel
# Time: ~50% less than sequential
# Cost: ~$0.80-1.80 per spec
```

Available patterns are documented in `references/agent-team-patterns.md`:

- `single` — 1 agent (tasks ≤ 6h)
- `impl-test` — Implementer + Tester in parallel
- `impl-test-review` — adds a Reviewer after the parallel phase
- `full-stack` — 4 agents per layer (API, Application, Infrastructure, Tests)
- `parallel-handlers` — N agents for N specs simultaneously

---

## EXAMPLE — Launch an agent team for a large task

_Scenario: Task AB#301-B3 "SendCitaConfirmationCommandHandler" is complex (6h), has production code, and needs tests. You use the `impl-test` pattern._

**You type:**
```
/agent-run projects/clinic-management/specs/sprint-2026-05/AB301-B3-send-confirmation-cmd.spec.md --team
```

**Claude responds:**
```
Selected pattern: impl-test (production code + tests in parallel)
  Agent 1 — Implementer: claude-opus-4-7  (handler + service)
  Agent 2 — Tester:      claude-haiku-4-5-20251001 (unit tests + mocks)

Estimated cost: ~$1.40 USD
Confirm launch?
```

**You type:**
```
Yes
```

**Claude responds:**
```
Launching 2 agents in parallel...

[Agent 1 — opus] 09:51:03 → Implementing SendCitaConfirmationCommandHandler...
[Agent 2 — haiku] 09:51:04 → Generating unit tests for SendCitaConfirmationCommand...

[Agent 1] 09:52:41 → Handler + EmailTemplateService complete. Build OK.
[Agent 2] 09:52:58 → 9 unit tests generated. Waiting for implementation to run.

[Syncing] → Running dotnet test... 9/9 ✅

══════════════════════════════════════════════
  ✅ TEAM COMPLETE
  Total duration: 118s (vs ~210s sequential)
  Build: OK | Tests: 9/9
  Actual cost: $1.22 USD
══════════════════════════════════════════════
```
