# Guide: Healthcare Organization

> Scenario: hospital, clinic or health center that manages improvement projects, clinical protocols, regulatory compliance and coordination of multidisciplinary teams.

**Note**: Savia is NOT a patient management system (HIS/HCE). It's a project management tool that helps healthcare teams coordinate improvement initiatives, implement protocols and meet regulations.

---

## Your organization

| Role | What you manage with Savia | Main commands |
|---|---|---|
| **Quality Director** | Improvement projects, audits, indicators | `/ceo-report`, `/compliance-scan`, `/portfolio-overview` |
| **Service Chief** | Service coordination, protocols | `/savia-sprint`, `/savia-board`, `/savia-pbi` |
| **IT Manager** | Systems, integrations, cybersecurity | `/security-audit`, `/arch-health`, `/spec-implement` |
| **Nursing Coordinator** | Shifts, training, procedures | `/flow-task-*`, `/savia-send`, `/school-*` |
| **Quality Technician** | Indicators, non-conformities, corrective actions | `/flow-task-*`, `/flow-timesheet`, `/qa-dashboard` |

---

## Why Savia in healthcare

- **Regulatory compliance**: tracking HIPAA, healthcare GDPR, JCI/EFQM accreditations.
- **Improvement project management**: PDCA cycles as sprints.
- **Staff training**: Savia School for mandatory courses and refresher training.
- **Extreme confidentiality**: E2E encryption for communications about incidents.
- **Traceability**: each decision and action is versioned — essential for audits.
- **No patient data**: Savia manages PROJECTS, not medical records.

---

## Use cases

### 1. Continuous improvement project (PDCA)

Each PDCA cycle is a sprint:

```
/savia-sprint start --project improve-emergency --goal "Reduce triage time by 15%"
```

**Plan:**
```
/flow-task-create plan "Map current triage flow"
/flow-task-create plan "Identify bottlenecks"
/flow-task-create plan "Design new protocol"
```

**Do:**
```
/flow-task-create do "Pilot new protocol (1 week)"
/flow-task-create do "Training for triage team"
```

**Check:**
```
/flow-task-create check "Measure times with new protocol"
/flow-task-create check "Staff satisfaction survey"
```

**Act:**
```
/flow-task-create act "Adjust protocol based on results"
/flow-task-create act "Document and standardize"
```

### 2. Implementation of new IT system

> "Savia, we're going to implement a new online appointment system"

```
/savia-pbi create "Selection of online appointment provider" --project appointment-system
/savia-pbi create "Integration with existing HIS" --project appointment-system
/savia-pbi create "Training for admission staff" --project appointment-system
/savia-pbi create "User acceptance tests" --project appointment-system
/savia-pbi create "Go-live + post-implementation support" --project appointment-system
```

For the technical part, SDD works normally:

```
/spec-generate {task-id}             → Integration spec
/spec-implement {spec}               → Implementation
/security-review {spec}              → OWASP review (critical in healthcare)
```

### 3. Regulatory compliance

```
/compliance-scan                     → Compliance scan
```

Savia detects healthcare sector requirements: health data protection, access control, encryption in transit and at rest, audit logs.

**Tracking corrective actions:**

```
/flow-task-create compliance "NC-001: Update password policy"
/flow-task-create compliance "NC-002: Encrypt test server backups"
/flow-task-create compliance "NC-003: Review HIS access permissions"
```

### 4. Mandatory training (Savia School)

For continuing education courses:

```
/school-setup "Hospital Example" "CPR-Training-2026"
/school-enroll healthcare-worker01
/school-enroll healthcare-worker02
```

```
/school-project healthcare-worker01 "cpr-simulation"
/school-evaluate healthcare-worker01 "cpr-simulation"
```

Evaluations are encrypted. Training records are exported for center accreditation.

---

## A quality director's day

### Morning

> "Savia, how are the improvement projects going?"

```
/portfolio-overview                  → View of all projects
/ceo-alerts                          → Alerts requiring decision
```

### Prepare quality committee

```
/ceo-report --format md              → Report for committee
/savia-board improve-emergency       → Main project board
```

### Audit

```
/compliance-scan                     → Compliance status
```

---

## Confidential communication

### On a patient safety incident

```
/savia-send @service-chief "Incident ISPA-2026-015: notification to safety committee. Urgent meeting tomorrow 08:00."
```

E2E encrypted. No patient data in the message — only incident code reference.

### Shift coordination

```
/savia-announce "Shift change 15-Mar: Dr. A covers Dr. B (night shift)"
```

---

## Privacy — Golden rule

**NEVER patient data in Savia.** Not names, not medical records, not patient codes.

Savia manages:
- Improvement projects (processes, not patients)
- Protocols and procedures
- Staff training
- Regulatory compliance
- Team coordination

Patient management systems (HIS, EHR) are separate tools.

---

## Detected gaps and proposals

| Gap | Description | Proposal |
|---|---|---|
| **PDCA native** | No PDCA cycle as native entity | `/pdca-cycle {plan\|do\|check\|act}` with metrics |
| **Incident tracking** | Patient safety incidents have their own flows | `/incident-register {classify\|investigate\|action}` |
| **Accreditation tracking** | Tracking JCI/EFQM/ISO 9001 standards | `/accreditation-track {standard\|evidence\|gap}` |
| **Training compliance** | Control mandatory training completed/pending by professional | `/training-compliance {status\|expired\|plan}` |
| **Indicator dashboard** | Healthcare KPIs (wait times, infection rate, readmissions) | `/health-kpi {define\|measure\|trend}` |

---

## Tips

- Improvement projects work very well as sprints — PDCA cycle maps naturally
- Never, under any circumstances, introduce patient data in Savia
- E2E encryption is especially relevant for incident communications
- `/compliance-scan` automatically detects healthcare sector requirements
- Savia School is ideal for mandatory continuing education
- Hour reports (`/flow-timesheet-report`) justify dedication to improvement projects
- For centers with multiple services, each service can be a "team" in Company Savia
