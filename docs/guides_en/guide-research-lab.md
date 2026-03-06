# Guide: Research Laboratory

> Scenario: research group at university or R&D center. Manages papers, experiments, datasets, funding proposals and multi-institutional collaborations.

---

## Your group

| Role | What they do | Main commands |
|---|---|---|
| **PI (Principal Investigator)** | Coordinates research lines, manages funding | `/ceo-report`, `/savia-sprint`, `/report-executive` |
| **Postdoc / Senior** | Leads experiments, supervises juniors | `/savia-pbi`, `/savia-board`, `/flow-spec-create` |
| **PhD Student** | Executes experiments, writes papers | `/my-focus`, `/flow-task-move`, `/flow-timesheet` |
| **Lab Technician** | Maintains equipment, processes samples | `/flow-task-*`, `/savia-inbox` |
| **External Collaborator** | Participates in shared projects | `/savia-send`, `/savia-directory` |

---

## Why Savia for research?

- **Traceability**: every decision, experiment and result is versioned in Git.
- **Reproducibility**: SDD specs document reproducible experimental procedures.
- **Secure collaboration**: end-to-end encrypted messaging for sensitive data.
- **No cloud dependency**: works offline (Travel Mode) — ideal for fieldwork.
- **Multi-project**: manages multiple research lines simultaneously.

---

## Group setup

### 1. Create the group repository

> "Savia, create an enterprise repository for the research group"

```
/company-repo
```

### 2. Define research lines as projects

```
/savia-pbi create "Paper: effect of X under conditions Y" --project linea-alpha
/savia-pbi create "H2020 Proposal: call ABC" --project financing
/savia-pbi create "Dataset: field sample collection" --project linea-beta
```

### 3. Incorporate researchers

```
/school-enroll inv01                 → For PhD students (privacy via aliases)
```

Or with full profiles for permanent staff:

> "Savia, add @postdoc1 as senior researcher"

---

## Research cycle with Savia

### 1. Research proposal → "Exploration" sprint

> "Savia, start an exploration sprint for the alpha line"

```
/savia-sprint start --project linea-alpha --goal "Literature review + hypothesis"
```

**Typical tasks:**

```
/flow-task-create research "Systematic review: effect X"
/flow-task-create research "Define hypotheses H1, H2, H3"
/flow-task-create research "Experimental design: variables, controls"
/flow-task-create research "Ethics protocol (if applicable)"
```

### 2. Experimentation → "Execution" sprint

```
/savia-sprint start --project linea-alpha --goal "Execute experiments batch 1"
```

**Each experiment as spec:**

> "Savia, create a spec for the sensor calibration experiment at 25°C"

```
/flow-spec-create "Experiment: sensor calibration 25°C"
```

The SDD spec adapted to research includes: hypothesis, materials, step-by-step procedure, expected data, success/failure criteria. This ensures reproducibility.

### 3. Analysis → "Analysis" sprint

```
/flow-task-create analysis "Statistical processing batch 1"
/flow-task-create analysis "Results visualization"
/flow-task-create analysis "Cross-validation with external dataset"
```

### 4. Publication → "Writing" sprint

```
/flow-task-create writing "Paper draft: introduction + methods"
/flow-task-create writing "Results + discussion"
/flow-task-create writing "Group internal review"
/flow-task-create writing "Journal submission"
```

---

## PI's day-to-day

### Monday — Group meeting

> "Savia, give me the status of all research lines"

```
/portfolio-overview                  → Global view of all projects
/savia-board linea-alpha             → Alpha line board
/savia-board linea-beta              → Beta line board
```

### Funding management

Funding proposals are projects with their own sprints:

```
/savia-pbi create "Write technical proposal" --project h2020-call
/savia-pbi create "Budget and cost justification" --project h2020-call
/savia-pbi create "Support letter: partner university" --project h2020-call
```

**Timesheet for hours justification:**

```
/flow-timesheet-report --monthly     → Hours per researcher and project
```

Essential for justifying dedication in funded projects (H2020, National Plan, etc.).

### Department report

```
/report-executive --project linea-alpha
/ceo-report --format md
```

---

## PhD student's day-to-day

### Start of day

> "Savia, what do I have pending?"

```
/my-focus                            → Your most priority task
/savia-inbox                         → Messages from supervisor
```

### Register experimental work

```
/flow-task-move EXP-003 in-progress  → Start experiment
/flow-timesheet EXP-003 5            → 5 hours of lab
/flow-task-move EXP-003 done         → Completed
```

### Communicate results

> "Savia, send @pi the results from batch 1: all samples above threshold"

```
/savia-send @pi "Batch 1 results: 23/25 samples exceed threshold (92%). Data in linea-alpha:resultados/batch1.csv"
```

---

## Digital lab notebook

The lab notebook is fundamental in research. Use `/school-diary` adapted:

```
/school-diary inv01                  → PhD student diary entries
```

Each entry records: date, experiment, observations, data, conclusions. Immutable because it's in Git — valid as evidence for patents and publications.

---

## Multi-institutional collaborations

For projects with researchers from other institutions:

1. The company repo is shared (private GitHub/GitLab)
2. Each collaborator has their `user/{handle}` branch
3. End-to-end encrypted messaging protects sensitive data
4. `/savia-directory` lists all participants

> "Savia, send @collab-univ-b the anonymized data from the pilot study"

---

## Gaps identified and proposals

| Gap | Description | Proposal |
|---|---|---|
| **Experiment tracking** | No native "experiment" entity with metadata (hypothesis, variables, results) | `/experiment-log {create\|run\|result\|compare}` |
| **Literature management** | No tracking of bibliographic references | `/biblio-add {doi\|bibtex}`, `/biblio-search` |
| **Dataset versioning** | Large datasets don't fit in Git | Integration with DVC (Data Version Control) or Git LFS |
| **Grant lifecycle** | Funding proposals have their own cycles (draft → submitted → review → awarded) | `/grant-track {submit\|status\|report}` |
| **Ethics/IRB tracking** | Ethics protocols not managed as standard PBIs | `/ethics-protocol {create\|status\|expire}` |

---

## Tips

- Use long sprints (4 weeks) for research — cycles are slower than software
- SDD specs are perfect for documenting reproducible experimental protocols
- `/flow-timesheet` is essential for hours justification in funded projects
- The lab notebook in Git has legal value for intellectual property disputes
- For sensitive data (patients, biological samples), end-to-end encrypted messaging protects communication
- ADRs (`/adr-create`) document methodological decisions that are forgotten in 6 months
