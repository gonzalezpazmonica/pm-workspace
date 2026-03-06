# Guide: NGO / Non-Profit Organization

> Scenario: NGO of 5–30 people with volunteers, social impact projects, grant management and need for reporting to donors. Limited budget for tools.

---

## Your organization

| Role | What they need | Main commands |
|---|---|---|
| **Director** | Overall vision, reporting to board and donors | `/ceo-report`, `/portfolio-overview`, `/ceo-alerts` |
| **Project Coordinator** | Manages teams and deliveries | `/savia-sprint`, `/savia-board`, `/report-executive` |
| **Volunteer Manager** | Onboarding, assignment, tracking | `/team-onboarding`, `/savia-directory` |
| **Field Technician** | Executes activities, reports progress | `/flow-task-move`, `/flow-timesheet`, `/savia-send` |
| **Admin / Finance** | Grant justification, hours | `/flow-timesheet-report`, `/excel-report` |

---

## Why Savia for an NGO?

- **Zero cost**: no licenses. Git + Claude Code is all you need.
- **Hours justification**: `/flow-timesheet` generates reports for grants (essential for public funds).
- **Privacy**: beneficiary data never in the repo (PII-Free rule + E2E encryption).
- **Offline fieldwork**: Travel Mode for areas without connectivity.
- **Multi-project**: manages multiple programs and grants simultaneously.

---

## Organization setup

### 1. Install and create repo

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, create an enterprise repository for our NGO"

### 2. Define programs as projects

Each program or grant is an independent project:

```
/savia-pbi create "Digital literacy training for seniors" --project programa-digital
/savia-pbi create "Q1 Food distribution" --project banco-alimentos
/savia-pbi create "Annual report for donors" --project gobernanza
```

### 3. Add team and volunteers

> "Savia, add vol01 as a volunteer in the digital training program"

For volunteers: use aliases (not real names) to protect their privacy.

---

## Program management

### Sprint planning adapted for NGOs

NGOs don't have "software sprints" but activity cycles. Savia adapts:

> "Savia, start a 4-week cycle for the digital training program"

```
/savia-sprint start --project programa-digital --goal "10 workshops across 4 centers"
```

**Tasks for a social program:**

```
/flow-task-create activity "Workshop 1: smartphone introduction (North Center)"
/flow-task-create activity "Workshop 2: WhatsApp and video calls (North Center)"
/flow-task-create logistics "Prepare materials for 40 participants"
/flow-task-create admin "Register attendance workshop 1"
/flow-task-create reporting "Partial report for the funder"
```

### Daily tracking

> "Savia, how is the digital training program going?"

```
/savia-board programa-digital        → Visual board
/flow-burndown                       → Progress vs. planned
```

### Hours registration (grant justification)

```
/flow-timesheet TALLER-001 3         → 3h teaching workshop
/flow-timesheet TALLER-001 1         → 1h preparation
/flow-timesheet-report --monthly     → Monthly report by person
```

**This is critical**: many public grants require detailed hours justification by activity and person. Savia generates these reports automatically.

---

## Team communication

### Coordination with volunteers

```
/savia-send @vol01 "Remember tomorrow's workshop at 10:00 am at North Center"
/savia-broadcast "Coordination meeting Friday at 5:00 pm"
/savia-announce "Thursday workshop cancelled due to local holiday"
```

### Field reports

Field technicians report progress directly:

> "Savia, tell the coordinator: workshop completed, 12 attendees, 2 need follow-up"

End-to-end encrypted messaging protects sensitive information about beneficiaries.

---

## Reporting to donors and board

### Executive report

> "Savia, generate the quarterly report for the board"

```
/ceo-report --format md              → Multi-project report
/portfolio-overview                  → Global view of all programs
```

### Impact report

```
/report-executive --project programa-digital
```

Savia generates: activities completed, people served (as metric, no personal data), hours invested, progress vs. objectives.

### Grant data

```
/excel-report time-tracking          → Excel with hours by project/person
/flow-timesheet-report --monthly     → Monthly breakdown
```

---

## Fieldwork (offline)

For rural areas or countries without stable connectivity:

```
/savia-travel-pack                   → Prepare portable package
```

In the field, everything works offline. Upon returning to an area with internet:

```
/savia-travel-init                   → Sync changes
```

---

## Beneficiary privacy

**Fundamental rule**: beneficiary data NEVER goes in the repo.

- Use aggregate metrics: "12 attendees", not names
- Beneficiary identifiers are managed in external systems (NGO databases)
- Internal communication about cases uses aliases or codes
- `/hook-pii-gate.sh` detects personal data before commit

---

## Gaps identified and proposals

| Gap | Description | Proposal |
|---|---|---|
| **Impact metrics** | No native tracking of social impact metrics | `/impact-metric {define\|log\|report}` |
| **Volunteer management** | Onboarding doesn't distinguish between permanent staff and volunteers | `/volunteer-manage {register\|availability\|hours}` |
| **Grant lifecycle** | Grants have their own cycles (application → award → execution → justification) | `/grant-track {apply\|awarded\|execute\|justify}` |
| **Donor reporting templates** | Donors request specific formats | Report templates by donor type |

---

## Tips

- Each grant should be a separate project — facilitates hours justification
- Register hours daily, not at month-end — precision matters for audits
- Use `/savia-broadcast` for general team communications
- The Kanban board (`/savia-board`) works very well in weekly coordination meetings
- For volunteers with little technical experience, the coordinator can log their hours for them
- Travel Mode is especially valuable for international cooperation projects
