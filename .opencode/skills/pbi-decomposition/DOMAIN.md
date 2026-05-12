# PBI Decomposition — Domain Context

## Why this skill exists

Product Backlog Items describe WHAT business value to deliver but not HOW. Development teams need clear Task breakdown with hour estimates to plan capacity and assign intelligently. Without decomposition, sprints become chaotic estimation guesses and overcommit happens systematically.

## Domain concepts

- **Story Point (SP)** — Relative complexity unit; 1 SP ≈ calibration table value (e.g., 4-6 hours in most teams)
- **Task (1-8h)** — Atomic work unit; one dev, one Activity, one story point equivalent
- **Activity** — Task category: Development | Testing | Documentation | Design
- **Capacity** — Team available hours per sprint; accounts for focus factor (75% productive)
- **Assignment** — Match dev profile (skills, knowledge, load) to task; avoids single-threaded dependencies

## Business rules it implements

- **RN-ESTIM-01**: Sum of task hours must map to SP calibration (±30% tolerance)
- **RN-SCRUM-02**: Max 8h per task; split if exceeds
- **RN-SCRUM-03**: One responsible dev per task; no shared ownership
- **RN-CAP-01**: Team capacity must not exceed headcount × hours/day × focus_factor

## Relationship to other skills

**Upstream:** `/pbi-create` defines the PBI; `product-discovery` validates business value
**Downstream:** `sprint-management` uses Task list for sprint board; `capacity-planning` sums hours to validate sprint feasibility
**Parallel:** `azure-devops-queries` fetches PBI data; `spec-driven-development` generates specs from Tasks

## Key decisions

- **Task categorization (A-E)** — Categories by layer + activity, not by dev skill. Avoids skill-matching bias.
- **Estimation by factor** — Not T-shirt sizes. Explicit formula: base × complexity × knowledge × risk. Calibrated in team hours.
- **Smart assignment scoring** — Weighted: expertise (40%), capacity (35%), context (25%). Prevents burnout + single points of failure.
