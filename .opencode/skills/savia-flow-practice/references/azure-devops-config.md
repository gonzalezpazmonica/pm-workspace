# Azure DevOps Configuration for Savia Flow

## Board Columns Design

Implement two tracks on the same board using column splits by Area Path.

### Exploration Track Columns
- **Discovery**: Researching outcomes, validating hypotheses
- **Spec-Writing**: Creating executable specifications
- **Spec-Ready**: Specifications ready for production handoff

### Production Track Columns
- **Ready**: Approved specs awaiting builder capacity
- **Building**: Active development (in progress)
- **Gate-Review**: Awaiting quality/security/performance gates
- **Deployed**: Released to production
- **Validating**: Monitoring success metrics post-deployment

Use column splits by Area Path (Exploration vs Production) to visually separate tracks.

---

## Custom Fields

Add these fields to User Story and Task work item types:

| Field | Type | Purpose |
|-------|------|---------|
| Track | Picklist | `Exploration` \| `Production` |
| Outcome ID | String | Reference to parent Epic ID for traceability |
| Cycle Time Start | DateTime | Set when item enters "Building" state |
| Cycle Time End | DateTime | Set when item enters "Deployed" state |

---

## Work Item Type Mapping

| Savia Role | Azure DevOps Type | Purpose |
|------------|-------------------|---------|
| Outcome | Epic | Strategic goal with success metrics and parent OKR |
| Spec | User Story | Executable specification with 5 Savia components |
| Implementation Task | Task | Technical work unit, max 8 hours |
| Bug | Bug | Defect found in gates or production |

---

## Area Paths

Organize items by track using Area Paths:

```
{Project}/Exploration
└─ All discovery and spec-writing items

{Project}/Production
└─ All building, gates, and deployed items
```

---

## Tag Conventions

Standardize tags for filtering and traceability:

- **Track**: `exploration`, `production`
- **Specification Status**: `spec-ready`, `spec-draft`
- **Gate Status**: `gate-passed`, `gate-failed`
- **Outcome Tracing**: `outcome:{epic-id}` (e.g., `outcome:EPIC-42`)
- **Milestone**: `m1-discovery`, `m2-spec`, `m3-build`

---

## WIQL Query Examples

Get Exploration items ready for handoff:
```wiql
SELECT [System.Id], [System.Title], [System.State]
WHERE [System.AreaPath] UNDER '{Project}\Exploration'
  AND [System.Tags] CONTAINS 'spec-ready'
```

Get active Production Work-in-Progress:
```wiql
SELECT [System.Id], [System.Title], [System.State]
WHERE [System.AreaPath] UNDER '{Project}\Production'
  AND [System.State] = 'In Progress'
  AND [System.AssignedTo] <> ''
```

Get items blocked by dependencies:
```wiql
SELECT [System.Id], [System.Title]
WHERE [System.Tags] CONTAINS 'blocked'
  OR [System.Tags] CONTAINS 'needs-exploration'
```

---

## WIP Limits Configuration

Enforce limits to prevent overload and maintain flow:

### Exploration Track WIP Limits
- Discovery: **3 items max**
- Spec-Writing: **2 items max**
- Spec-Ready: **5 items max** (buffer for production)

### Production Track WIP Limits
- Ready: **5 items max**
- Building: **4 items max**
- Gate-Review: **3 items max** (avoid review bottleneck)
- Validating: **3 items max**

---

## Board Configuration Best Practices

1. **Automate state transitions**: Use rules to set Cycle Time Start/End dates automatically
2. **Sprint Planning**: Use Exploration items for 2-week discovery sprints; Production for 1-week build sprints
3. **Metrics**: Track lead time (Spec-Ready → Deployed) and cycle time (Building → Deployed)
4. **Notifications**: Alert on WIP limit violations and gate review timeouts (>2 days)
