# Ideal Agile Configuration — pm-workspace Reference

> Defines the Azure DevOps configuration that pm-workspace WIQL queries and skills expect.

---

## Required Work Item Types

| Type | Backlog Level | Parent |
|---|---|---|
| Epic | Portfolio (top) | — |
| Feature | Portfolio | Epic |
| User Story | Requirement | Feature |
| Task | Task | User Story |
| Bug | Requirement (asRequirements) | Feature |

---

## Required States per Type

| Type | New | Active | Resolved | Closed | Removed |
|---|---|---|---|---|---|
| User Story | ✅ | ✅ | ✅ | ✅ | optional |
| Task | ✅ | ✅ | — | ✅ | optional |
| Bug | ✅ | ✅ | ✅ | ✅ | — |
| Feature | ✅ | ✅ | ✅ | ✅ | optional |
| Epic | ✅ | ✅ | ✅ | ✅ | optional |

---

## Required Fields per Type

### User Story
| Field Reference | Display Name |
|---|---|
| `Microsoft.VSTS.Scheduling.StoryPoints` | Story Points |
| `Microsoft.VSTS.Common.Priority` | Priority (1-4) |

### Task
| Field Reference | Display Name |
|---|---|
| `Microsoft.VSTS.Scheduling.OriginalEstimate` | Original Estimate (hours) |
| `Microsoft.VSTS.Scheduling.RemainingWork` | Remaining Work (hours) |
| `Microsoft.VSTS.Scheduling.CompletedWork` | Completed Work (hours) |
| `Microsoft.VSTS.Common.Priority` | Priority (1-4) |
| `Microsoft.VSTS.Common.Activity` | Activity (Development, Testing, etc.) |

### Bug
| Field Reference | Display Name |
|---|---|
| `Microsoft.VSTS.Scheduling.StoryPoints` | Story Points |
| `Microsoft.VSTS.Common.Priority` | Priority (1-4) |
| `Microsoft.VSTS.Common.Severity` | Severity (1-4) |

### Date Fields (all types, used in metrics)
| Field Reference | Description |
|---|---|
| `Microsoft.VSTS.Common.ActivatedDate` | When moved to Active |
| `Microsoft.VSTS.Common.ResolvedDate` | When marked Resolved |
| `Microsoft.VSTS.Common.ClosedDate` | When closed |
| `Microsoft.VSTS.Common.StateChangeDate` | Last state transition |

---

## Backlog Configuration

- **Bug behavior**: `asRequirements` — bugs appear in backlog alongside User Stories
- **Hierarchy**: Epic (portfolio) → Feature (portfolio) → User Story (requirement) → Task
- **Requirement backlog** must include: User Story (and optionally Product Backlog Item)

---

## Sprint / Iteration Setup

- At least one sprint must have start and end dates
- Recommended naming: `Sprint YYYY-NN` (e.g., Sprint 2026-05)
- Iteration path convention: `{Project}\Sprints\{Sprint Name}`
- Sprint duration: 2 weeks (configurable via `SPRINT_DURATION_WEEKS`)

---

## PAT Scopes Required

| Scope | Permission | Used By |
|---|---|---|
| Work Items | Read & Write | WIQL queries, create/edit PBIs, Tasks, Bugs |
| Project and Team | Read | Project config, team settings, iterations |
| Analytics | Read | Burndown, velocity, DORA metrics |
| Code | Read & Write | SDD: read repos, create PRs |
| Build | Read & Write | Pipeline management (CI/CD) |
| Release | Read | Release status and history |
| Process | Read | Process template validation (`/devops-validate`) |

---

## Scrum Process Compatibility Notes

If project uses **Scrum** instead of Agile:
- `Product Backlog Item` maps to `User Story` in queries (both are included)
- `Done` state → equivalent to `Closed` in Agile
- `Committed` state → equivalent to `Active`
- `Approved` state → equivalent to `New`
- `Effort` field → maps to `StoryPoints`
