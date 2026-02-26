## Onboarding New Team Members

PM-Workspace includes a complete workflow for onboarding developers to a project, reducing ramp-up time from 4-8 weeks to 5-10 days. The process is GDPR-compliant.

### 5-Phase Flow

```
New member joins the project
    ↓
/team:privacy-notice "Name"       ← 1. GDPR privacy notice (mandatory)
    ↓                                   Worker reads and signs acknowledgment
/team:onboarding "Name"           ← 2. Project context + codebase tour
    ↓                                   Mentor validates each phase
  [First assisted task]            ← 3. Mentor assigns B/C task, pair with Claude
    ↓                                   Human Code Review mandatory
/team:evaluate "Name"              ← 4. Competency questionnaire (8 dimensions)
    ↓                                   Self-assessment + Tech Lead calibration
  [Progressive autonomy]           ← 5. Weeks 1-3 with decreasing supervision
```

Phases 3 and 5 are human-driven processes guided by the mentor, not commands.

### Phase 1 — GDPR Privacy Notice

Before collecting any worker data, the law requires delivering a privacy notice (Art. 13 GDPR). The command `/team:privacy-notice "Name" --project MyProject` generates the document from a template covering: data controller, purpose (task assignment and training), legal basis (legitimate interest), worker rights (access, rectification, erasure, objection, portability).

The worker signs the acknowledgment before proceeding. Without this signature, `/team:evaluate` is blocked.

### Phase 2 — Onboarding: Context and Codebase Tour

The command `/team:onboarding "Name" --project MyProject` generates a personalized guide covering:

- **Immediate context**: project architecture, layers, modules, patterns, team conventions, members and roles
- **Codebase tour**: end-to-end request walkthrough (Controller → Handler → Repository → Entity), patterns with real project examples, test structure, SDD spec locations

The guide is saved to `projects/{project}/onboarding/{name}-guide.md`. The mentor reviews and adjusts before delivering it to the new member.

### Phase 3 — First Assisted Task (Human Process)

The mentor assigns a B/C complexity task. The new member implements it with Claude-assisted pair programming. Code Review is always human in this phase.

### Phase 4 — Competency Evaluation

The command `/team:evaluate "Name" --project MyProject` runs an interactive questionnaire in three sections: A (stack-specific technical skills, 12 competencies), B (cross-cutting skills, 7 competencies), C (project domain knowledge, dynamically generated from project modules).

For each competency, level (1-5) and interest (Y/N) are collected. The `business-analyst` agent compares self-assessment with observable evidence (PRs, Git history) and suggests adjustments. The Tech Lead co-signs the final result.

The resulting profile is integrated into `projects/{project}/equipo.md` as per-module `expertise` field, feeding the task assignment algorithm.

### Phase 5 — Progressive Autonomy (Human Process)

Weeks 1-3 with decreasing supervision. Success metrics: first PR approved within 3 days, ≤3 review rounds, self-reported confidence ≥7/10 by day 5.

### Storage and Privacy

```
projects/{project}/
├── privacy/         ← Signed GDPR privacy notices
├── onboarding/      ← Personalized guides
└── evaluaciones/    ← Raw responses (YAML) for audit
```

All three directories are in `.gitignore` — never pushed to the repository. Raw responses are retained for 4 years after end of employment, then permanently deleted.

### Legal Restrictions

- Individual productivity metrics are never collected (LOC, commits/day, closure speed)
- Data is only used for task assignment and training, never as a disciplinary tool
- If the worker exercises their right to object (Art. 21 GDPR), their profile is no longer used for automatic assignment
- Evaluations are not conducted outside working hours (Art. 88 LOPDGDD, digital disconnection)
