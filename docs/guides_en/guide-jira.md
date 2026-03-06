# Guide: Software Consultancy with Jira

> Scenario: development team that uses Jira as a project management tool, possibly combined with GitHub/GitLab for code and CI/CD.

---

## Your team

| Role | What they need from Savia |
|---|---|
| **PM / Scrum Master** | Jira ↔ Savia synchronization, reports, sprint management |
| **Tech Lead** | Architecture, code review, technical debt |
| **Developers** | Daily focus, SDD specs, implementation |
| **Product Owner** | Backlog grooming, prioritization, value metrics |

---

## Initial setup

### 1. Install pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Connect Jira

> "Savia, connect my Jira project"

Savia will run `/jira-connect` which guides you through:

- URL of your Jira instance (Cloud or Server)
- API token (saved in local file, never in repo)
- Project to synchronize
- State mapping (To Do → New, In Progress → Active, Done → Closed)

### 3. Bidirectional synchronization

```
/jira-sync                         → Synchronize Jira items ↔ Savia
/jira-connect map                  → Review/adjust field mapping
```

Synchronization is bidirectional: changes in Jira are reflected in Savia and vice versa. Savia maintains its own data model for advanced analysis without depending on the Jira API on every operation.

---

## Hybrid mode: Jira + Savia

The most common pattern is to use Jira as the "single source of truth" for the client/stakeholders and Savia as an internal tool for the technical team:

**In Jira** (visible to the client):
- Epics, Stories, Bugs
- Sprint board
- Releases

**In Savia** (internal power):
- Intelligent PBI decomposition → `/pbi-decompose`
- Executable SDD specs → `/spec-generate`
- Automated code review → `/pr-review`
- Predictive metrics → `/sprint-forecast`
- Technical debt → `/debt-analyze`

### Typical flow

1. PO creates Story in Jira
2. `/jira-sync` brings the item to Savia
3. PM decomposes with `/pbi-decompose` → tasks stay in Savia
4. Dev implements with SDD → `/spec-generate` + `/spec-implement`
5. PR + merge → automatic quality hooks
6. `/jira-sync` updates the status in Jira
7. Client sees progress on their Jira board

---

## PM's day to day

### Morning

> "Savia, sync Jira and give me sprint status"

```
/jira-sync                         → Bring in changes from Jira
/sprint-status                     → Status with fresh data
/daily-routine                     → Daily routine based on your role
```

### Standup

> "Savia, prepare data for the daily"

Savia combines Jira data (states, assignments) with its own metrics (velocity, burndown, detected blockers) to give you a complete summary.

### End of sprint

```
/sprint-review                     → Delivery summary
/sprint-retro                      → Retrospective
/report-executive                  → Report for stakeholders
/jira-sync                         → Ensure Jira reflects everything
```

---

## Developer's day to day

> "Savia, what do I have assigned today?"

```
/my-sprint                         → Your personal view
/my-focus                          → Highest priority item
```

### SDD implementation

The SDD flow works the same as with Azure DevOps — the spec is agnostic to the project management tool:

1. `/spec-generate {jira-key}` → generate spec from the Jira issue
2. `/spec-implement {spec}` → implement
3. `/pr-review` → automated code review
4. When done, `/jira-sync` updates the status in Jira

---

## Differences from Azure DevOps

| Aspect | Azure DevOps | Jira |
|---|---|---|
| Connection | Native (REST API) | Via `/jira-connect` + sync |
| Pipelines | `/pipeline-*` direct | GitHub Actions / GitLab CI separate |
| Work items | WIQL queries | JQL queries via sync |
| State mapping | Automatic (Agile template) | Configurable with `/jira-connect map` |
| Board | Azure Boards | Jira Board + `/savia-board` local |

---

## Tips specific to Jira

- Sync frequently (`/jira-sync`) to keep data fresh
- Jira custom fields map to Savia fields in the configuration
- If using Jira Cloud, the API is faster than Jira Server
- Savia can work with multiple Jira projects simultaneously
- Savia reports (`/report-executive`, `/kpi-dashboard`) are richer than native Jira ones because they combine code, PR, and flow metrics data
- If your client only wants to see Jira, use Savia as an internal tool and sync results
