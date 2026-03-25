# Guide: Law Firm / Legal Practice

> Scenario: law practice with 3–20 professionals managing cases, files, legal deadlines and voluminous documentation. Requires extreme confidentiality and traceability.

---

## Your practice

| Role | Needs | Main commands |
|---|---|---|
| **Senior Partner/Director** | Global vision, billing, reporting | `/ceo-report`, `/portfolio-overview`, `/flow-timesheet-report` |
| **Senior Attorney** | Manage cases, supervise juniors | `/savia-sprint`, `/savia-board`, `/savia-pbi` |
| **Junior Attorney** | Execute tasks, research, drafting | `/my-focus`, `/flow-task-move`, `/flow-timesheet` |
| **Paralegal** | Documentation, filing, deadlines | `/flow-task-*`, `/savia-inbox` |
| **Secretary / Admin** | Schedule, billing, communications | `/flow-timesheet-report`, `/excel-report` |

---

## Why Savia for a law firm

- **Confidentiality**: E2E encryption (RSA-4096 + AES-256-CBC) for internal communications about cases.
- **Timesheet for billing**: time tracking by case/task, essential for hourly billing.
- **Traceability**: each document, decisión and communication is versioned in Git.
- **Deadline management**: legal deadlines modeled as tasks with critical dates.
- **Offline**: Travel Mode for courts, client visits, areas without coverage.

---

## Practice setup

### 1. Install and create repo

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, create a repository for the practice"

### 2. Structure by practice areas

Each area is a "team" and each case a "project":

```
/savia-team init --name commercial
/savia-team init --name labor
/savia-team init --name criminal
```

### 3. Create a case

> "Savia, create a new case in the commercial area"

```
/savia-pbi create "Case: claim for payment — file 2026-M-0042" --project commercial
```

**Case tasks:**

```
/flow-task-create investigation "Analysis of documents provided by client"
/flow-task-create drafting "Drafting of claim"
/flow-task-create filing "Electronic filing with court"
/flow-task-create hearing "Preparation of hearing"
/flow-task-create deadline "DEADLINE: response to claim — 20 business days"
```

---

## Case management as sprints

Each case has its own pace. Use flexible sprints:

### Quick case (demand, claim)

```
/savia-sprint start --project case-2026-M-0042 --goal "Claim filed on time"
```

Sprint of 2–4 weeks with fixed deadline.

### Long case (litigation, insolvency)

Divide into phases as sprints:

```
Sprint 1: "Pleading phase"
Sprint 2: "Evidence phase"
Sprint 3: "Closing arguments + hearing"
Sprint 4: "Judgment + appeal"
```

### The case board

```
/savia-board case-2026-M-0042
```

```
┌──────────┬───────────┬─────────────┬────────┬────────┐
│ Pending  │ In progress│ In review  │ Filing │ Done   │
├──────────┼───────────┼─────────────┼────────┼────────┤
│ Evidence │ Claim    │ Analysis   │        │ Docs   │
│ Hearing  │           │ doc.       │        │ client │
└──────────┴───────────┴─────────────┴────────┴────────┘
```

---

## Timesheet and billing

**Time tracking is the heart of a law practice's business.**

### Log hours

```
/flow-timesheet TASK-001 2.5         → 2.5h on drafting claim
/flow-timesheet TASK-002 1           → 1h reviewing documentation
/flow-timesheet TASK-003 0.5         → 30min on client call
```

### Billing reports

```
/flow-timesheet-report --monthly     → Hours by attorney/case/month
/excel-report time-tracking          → Excel for accounting
```

> "Savia, generate the hours report for case 2026-M-0042 to bill the client"

Savia produces a breakdown: date, attorney, task, hours, description — ready to attach to invoice.

---

## Confidential communication

### On a sensitive case

```
/savia-send @senior1 "Case 0042: expert confirms client's versión. Attached report in case branch."
```

All E2E encrypted. Even a repo administrator cannot read messages without private keys.

### Practice coordination

```
/savia-announce "Partners meeting Friday at 13:00. Agenda in governance board."
/savia-broadcast "Reminder: close timesheet on the 30th"
```

---

## Deadline control

Legal deadlines are non-negotiable. Model them as tasks with maximum priority:

```
/flow-task-create deadline "FATAL DEADLINE: appeal — 20 days"
```

> "Savia, what deadlines do we have this week?"

Savia filters deadline-type tasks and displays them sorted by urgency.

---

## A junior attorney's day

### Morning

> "Savia, what do I have for today?"

```
/my-focus                            → Most priority task
/savia-inbox                         → Instructions from senior
```

### During the day

```
/flow-task-move TASK-005 in-progress → Start research
/flow-timesheet TASK-005 3           → 3h research
/flow-task-move TASK-005 review      → Pass to senior for review
```

### End of day

```
/savia-send @senior1 "Finished analysis of TASK-005. Found 3 favorable Supreme Court judgments."
```

---

## Reporting for partners

### Practice workload

```
/portfolio-overview                  → All active cases
/ceo-alerts                          → Only critical alerts (deadlines, blockers)
```

### Productivity metrics

```
/ceo-report                          → Executive summary
/velocity-trend                      → Case resolution trend
```

---

## Detected gaps and proposals

| Gap | Description | Proposal |
|---|---|---|
| **Deadline management** | No native "legal deadline" entity with alarms | `/legal-deadline {set\|list\|alert}` with notifications |
| **Court calendar** | Integration with court calendars | `/court-calendar {import\|sync}` |
| **Conflict check** | Verify conflicts of interest before accepting case | `/conflict-check {client\|matter}` |
| **Document templates** | Templates for judicial documents | `/legal-template {claim\|response\|appeal}` |
| **Billing rates** | Hourly rates differentiated by attorney/type | `/billing-rate {set\|calculate\|invoice}` |

---

## Tips

- Each case is a separate project — never mix files
- Log hours immediately, not at end of day — precision is money
- Use `/savia-send` for instructions on cases — recorded and encrypted
- Legal deadlines ALWAYS as maximum priority tasks
- E2E encryption is especially important here: professional secrecy is a deontological obligation
- For multi-office practices, Company Savia enables secure collaboration without VPN
