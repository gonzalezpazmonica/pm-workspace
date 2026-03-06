# Guide: Education Center (Savia School)

> Scenario: educational institution (secondary school, university, academy, bootcamp) that wants to manage student projects, evaluations and academic progress with Savia School.

---

## Your center

| Role | Who it is | What they use |
|---|---|---|
| **Teacher** | Creates projects, evaluates, tracks progress | `/school-setup`, `/school-evaluate`, `/school-analytics` |
| **Student** | Submits projects, checks progress | `/school-submit`, `/school-progress`, `/school-portfolio` |
| **Coordinator** | Overall view of the course | `/school-analytics`, `/school-export` |

---

## Center setup (the teacher)

### 1. Install pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Create the classroom

> "Savia, set up a classroom for the Web Development course, 2nd DAW"

```
/school-setup "IES Example" "2DAW-WebDevelopment"
```

Savia creates the structure: folders per student, rubrics, and project templates. Everything in Git, no database.

### 3. Enroll students

> "Savia, enroll the students in the course"

```
/school-enroll student01
/school-enroll student02
/school-enroll student03
```

Savia School uses **aliases** instead of real names. The teacher chooses the aliases and they do not contain personal data (GDPR compliance). The mapping between alias and real identity is kept outside the system, in the institution's records.

### 4. Create evaluation rubrics

> "Savia, create a rubric for web projects"

```
/school-rubric create
```

Savia guides you to define criteria (functionality, design, clean code, documentation, tests) with levels and weights.

---

## Teacher's day-to-day

### Assign a project

> "Savia, create an online store project for student01"

```
/school-project student01 "online-store"
```

Savia creates the project structure with: assignment statement, evaluation criteria, delivery date, and submission space for the student.

### Receive submissions

Students submit with:

```
/school-submit student01 "online-store"
```

The teacher sees pending submissions:

> "Savia, who has submitted?"

### Evaluate

> "Savia, evaluate student01's online-store project"

```
/school-evaluate student01 "online-store"
```

Savia applies the defined rubric. The teacher reviews, adjusts scores and adds comments. The evaluation is encrypted with AES-256 (only the teacher and student can view it).

### View course analytics

```
/school-analytics                    → Global course metrics
/school-progress --class             → Progress of all students
```

---

## Student's day-to-day

### Check assigned projects

> "Savia, what projects do I have?"

### Submit a project

> "Savia, I'm submitting my online-store project"

```
/school-submit student01 "online-store"
```

### View my progress

```
/school-progress student01            → Grades and feedback
/school-portfolio student01           → Full portfolio
```

### Check my learning diary

```
/school-diary student01               → Progress diary
```

---

## Privacy and GDPR

Savia School complies with GDPR for minors:

- **Art. 8**: Parental consent for under-14s (in Spain). The institution manages consents outside the system.
- **Art. 15**: Right of access. `/school-portfolio` gives the student complete access.
- **Art. 17**: Right to be forgotten. `/school-forget student01` deletes all student data.
- **Encrypted evaluations**: AES-256-CBC, accessible only by teacher and student.
- **No PII in repo**: only aliases, never names, IDs or emails.

---

## Data export

At the end of the course:

```
/school-export student01              → Export student data
/school-export --class                → Export entire course
```

Generates files with evaluations, progress and portfolio for the institution's official records.

---

## Extended use cases

### Programming bootcamp

Savia School works especially well for bootcamps:

- Short projects with frequent deliveries
- Continuous evaluation with predefined rubrics
- Portfolio that the student can show to employers
- Progress analytics to identify at-risk students

### University — Final Projects (Thesis)

For final degree/master projects:

- Single project per student, long duration
- Intermediate milestones with `/school-project` for each milestone
- Research diary with `/school-diary`
- Evaluation by panel applying shared rubric

### Internal company training

For corporate training courses:

- Alias = employee code (no names)
- Practical projects evaluated with rubric
- Competency report for HR with `/school-export`

---

## Tips

- Aliases should be consistent and not reveal identity (use codes, not initials)
- Run `/school-analytics` weekly to identify students falling behind
- Rubrics can be reused across courses with `/school-rubric edit`
- The Git repository acts as an immutable historical record of evaluations
- For large groups (>30 students), consider dividing into sections with separate `/school-setup`
