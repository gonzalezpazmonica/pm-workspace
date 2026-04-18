# Guía Rápida de Adopción: Savia Flow en 12 Semanas
## Plan Accionable para Implementadores

**Autor:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Introducción

Esta guía es para equipos que quieren implementar Savia Flow **ahora**, no en 6 meses. Si tienes 12 semanas, este plan te lleva de Scrum tradicional a Savia Flow completamente operativo.

**Requisitos previos:**
- Equipo de 5-15 personas
- Ya usando alguna forma de Scrum
- Colaborando con IA (Copilot, Claude, etc.)
- Leadership buy-in (30 minutos de conversación)

**Resultado esperado:**
- Cycle time: De 15-21 días → 3-7 días
- Throughput: De 5-6 items/semana → 8-10 items/semana
- Team satisfaction: +3-4 puntos en escala 10
- Time in ceremonies: -40%

---

## Semana 1: Foundations

### Lunes: Kick-off Meeting (1.5 horas)

Reúne al equipo. Agenda:

```
9:00-9:30: Why Savia Flow?
  - Show: Scrum pain points (are they ours?)
  - Show: Cycle time improvement (15-21 días → 4 días)
  - Explain: 7 Pilares en 10 minutos

9:30-10:00: What Changes?
  - Specs instead of stories
  - Flujo continuo (no sprints)
  - Continuous quality gates
  - Evolved roles

10:00-10:30: What Stays?
  - Team autonomy
  - Quality focus
  - Customer obsession
  - Continuous improvement
```

**Outcome:** Team entiende qué es, por qué, qué cambia.

### Martes: Role Assignment (30 minutos)

Asigna los 4 roles:

```
AI Product Manager:
- Former: Product Owner
- Skills needed: Data analysis, spec writing, collaboration
- Recommendation: Choose strongest PM, not ceremonial PO

Flow Facilitator:
- Former: Scrum Master
- Skills needed: Metrics interpretation, coaching, removing blockers
- Recommendation: Existing SM is often good fit

Pro Builders:
- Former: Developers
- Skills needed: Architectural thinking, prompting, code review
- Recommendation: Your strongest engineers lead transition

Quality Architect:
- Former: QA (if you have dedicated QA)
- Skills needed: Testing strategy, automation, security mindset
- Recommendation: Can be shared role (part-time) initially
```

**Outcome:** Roles son formales. Personas saben sus nuevas responsabilidades.

### Miércoles-Viernes: Training (4-6 horas total)

Divide en sesiones pequeñas:

```
Wednesday 2pm: Specs-Driven Development (1.5 hrs)
  - What is a spec?
  - Parts: Outcome, success metrics, functional, technical, DoD
  - Live example: Rewrite a story as spec
  - Practice: Take 2 existing features, write specs

Thursday 9am: Metrics That Matter (1.5 hrs)
  - Why velocity is broken (with data)
  - The 4 DORA metrics
  - How to measure each
  - Dashboard walkthrough

Friday 10am: Quality Gates & Continuous Deployment (1.5 hrs)
  - 5-level gate architecture
  - Automated vs. human review
  - CI/CD pipeline walkthrough
  - Which checks are easy, which are hard
```

**Outcome:** Team understands specs, metrics, and quality gates. Ready to implement.

### End of Week 1

- [ ] Kick-off meeting completed
- [ ] 4 roles formally assigned
- [ ] Training sessions completed
- [ ] Team able to explain 7 Pilares
- [ ] Set baseline metrics (current cycle time, CFR, velocity)

---

## Semana 2: First Specs

### Objetivo
Write your first 5 spec ejecutables. This week is about learning format, not perfection.

### Monday: Template Kick-off

Create a spec template (or use provided one):

```markdown
# Spec: [Feature Name]

## Outcome
[What problem does this solve? For whom? Why now?]

## Success Metrics
- Metric 1: [baseline] → [target]
- Metric 2: [baseline] → [target]

## Functional Spec
[What does the feature do? Step by step]

### User Scenarios
[Main paths and edge cases]

## Technical
- Architecture: [How implemented]
- Performance: [Benchmarks]
- Constraints: [Limits, dependencies]

## Definition of Done
- [ ] Tests cover main scenarios
- [ ] Performance benchmarks met
- [ ] Accessible (WCAG AA)
- [ ] Documented
```

### Tuesday-Friday: Write 5 Specs

Take 5 current backlog items. Rewrite as executable specs.

Process for each:
```
1. Read existing story / understand feature
2. Write outcome (1 paragraph)
3. Define success metrics (3-5 KPIs, specific numbers)
4. Write functional spec (what, how, when)
5. Technical details (stack, constraints, performance)
6. Definition of done (acceptance criteria++)

Time per spec: 2-4 hours (first time is slower)
```

Example transformation:

```
OLD STORY:
"As a user, I want to see product recommendations
 so that I discover new products"

Acceptance Criteria:
- Recommendations show on homepage
- Based on browsing history
- Top 5 products

---

NEW SPEC:
# Spec: Personalized Product Recommendations

## Outcome
Help users discover products matching their interests,
reducing discovery friction and increasing AOV 20%.

## Success Metrics
- CTR on recommendations: 8% (baseline: 3%)
- AOV for users with recommendations: +25% (baseline: $45 → $56)
- Personalization relevance score: 0.72+

## Functional Spec
1. Homepage: 5 product carousel below main content
2. Logic: Products selected from user browsing history (30 days)
3. Filtering: Remove recently viewed, out of stock, low reviews
4. Ranking: Diversity × relevance × popularity

Edge cases:
- New users (<10 items browsed): Show trending
- No applicable products: Show empty state with suggestion
- Mobile: 3-item carousel instead of 5

## Technical
- ML model: Use collaborative filtering (retrain nightly)
- Caching: Redis 1-hour TTL
- Performance: Render <100ms
- Data: Existing session data, no new collection

## Definition of Done
- A/B test 2 weeks, 95% confidence on metrics
- <50ms added latency to homepage
- Works for new users (cold start handled)
- Mobile responsive
- WCAG AA compliant
```

### End of Week 2

- [ ] 5 specs written and reviewed
- [ ] Team comfortable with spec format
- [ ] Specs stored in accessible location (Notion, GitHub, etc.)
- [ ] Builders reviewed specs for clarity (feedback cycle established)

---

## Semana 3-4: Parallel Tracks

### Objetivo
Begin work on two parallel tracks: Exploration (specs) and Production (building).

### Monday Week 3: Start Dual-Track

Stop planning next sprint. Instead:

```
EXPLORATION TRACK (AI PM + 1 Pro Builder):
- Discovering next 2-3 outcomes
- Writing specs
- Validating with users if needed
Timeline: 3-5 days per spec

PRODUCTION TRACK (Rest of team):
- Taking completed specs
- Building + testing
- Quality gates
Timeline: 3-7 days per spec
```

### Tuesday: Setup Metrics Dashboard

Create a simple dashboard showing:

```
Team: [Team Name]
Last 7 days:

Items completed: 4
Average cycle time: 5.2 days
Items in progress: 2
Blockers: None

[Visual: Trend line of cycle time]
[Visual: WIP over time]
```

Tools:
- Google Sheets (manual, but works)
- Jira dashboards (if you use Jira)
- Grafana (if you want fancy)
- Metabase (good middle ground)

### Wednesday-Friday: Continue Building

Builders start working on spec from Week 2.

Process:
```
1. Take spec
2. IA generates code (with detailed prompts)
3. Manual refinement (20-30%)
4. Local testing
5. Submit to quality gates

This week: Gates are mostly manual. Automate next week.
```

### End of Week 3-4

- [ ] Dual-track is operating (exploration + production parallel)
- [ ] Metrics dashboard live and visible daily
- [ ] At least 1 feature entered production
- [ ] Team cycle time is visible/measurable
- [ ] No more sprint planning meetings

---

## Semana 5-6: Automate Quality Gates

### Objetivo
Implement first 3 levels of quality gates (Lint, Unit Tests, Integration).

### Setup (Monday)

```
Level 1 - Lint (ESLint, Prettier, or language equivalent)
├─ Add to CI/CD pipeline
├─ Configure rules
└─ Auto-reject if fails

Level 2 - Unit Tests
├─ Require >80% coverage
├─ Run on every commit
└─ AI can help write tests

Level 3 - Integration Tests
├─ Database migrations tested
├─ API contracts verified
└─ Run before deploy approval
```

### Tuesday-Wednesday: Implement

```
For your tech stack:
- Node.js: ESLint + Jest + Docker Compose for DB
- Python: Flake8/Black + Pytest + test DB
- Java: Checkstyle + JUnit + test containers
- Go: golangci-lint + testing

Goal: Push code → Gates run automatically → Result in 5 minutes

If gates fail: Feedback to builder immediately, not next day.
```

### Thursday-Friday: Run Through

```
Have builders push code with intentional bugs:
- Syntax error (Level 1 catches)
- Missing test (Level 2 catches)
- Bad SQL (Level 3 catches)

Verify gates work. Builders see feedback loop.
```

### End of Week 5-6

- [ ] CI/CD gates 1-3 automated
- [ ] Builders receive instant feedback
- [ ] Code quality baseline established
- [ ] Developers understand gate failures

---

## Semana 7-9: Add Advanced Gates & Formalize Roles

### Semana 7: Level 4 Gates (Security & Performance)

```
Level 4a - Security
├─ SAST (Static Application Security Testing)
├─ Secrets scanning
├─ Dependency vulnerabilities
└─ Tool: Snyk, SonarQube, or GitHub Advanced Security

Level 4b - Performance
├─ Benchmark against baseline
├─ Flag if >10% regression
├─ Warn if architecture smell detected
└─ Tool: Custom script or APM tool
```

### Semana 8: Level 5 (Human Review)

```
Light human review:
- Architect: Does this solve the outcome? Any arch concerns?
- Product: Does this match the spec?
- Security (if needed): Looks OK?

Target time: 30 minutes per feature
```

### Semana 9: Formalize Roles

Make roles official:

```
AI Product Manager (AI PM):
- Responsible for: Outcome discovery, spec writing, metrics
- Time: 40% strategic (discoveries), 60% spec writing
- Tools: Analytics, IA tools, Notion/GitHub

Flow Facilitator:
- Responsible for: Metrics, blockers, continuous improvement
- Time: 80% coaching/process, 20% metrics
- Daily: 30 min metrics review, 2 hrs coaching

Pro Builder:
- Responsible for: Architecture, IA orchestration, code quality
- Time: 60% building, 40% code review + mentoring
- Tools: IDE + IA, debugging, code review

Quality Architect:
- Responsible for: Gate design, defect prevention, testing strategy
- Time: Can be part-time (1-2 days/week initially)
- Tools: SAST, testing frameworks
```

### End of Weeks 7-9

- [ ] Security gates in place
- [ ] Performance gates established
- [ ] Human review SLA <1 hour
- [ ] Roles are official and responsibilities clear
- [ ] Builders understand what each role does

---

## Semana 10-11: Optimize & Scale

### Semana 10: Reduce Ceremony Overhead

Stop these meetings:

```
❌ Daily standup (use dashboard instead)
❌ Sprint planning (continuous intake)
❌ Sprint review (demo when ready)
❌ Weekly refinement (integrated in exploration track)

Keep these (evolved):
✓ Monthly retro (what did we learn?)
✓ Quarterly planning (strategic priorities)
✓ On-demand escalation meetings (blockers, decisions)
```

**Time saved:** ~9 hours/week → return to builders

### Semana 11: Optimize Metrics

```
Analyze:
- Cycle time trend: Improving? Why/why not?
- Throughput: Increasing? Stable?
- CFR: Decreasing (fewer bugs escaping)?
- Team satisfaction: Improving?

Adjust gates:
- False positives? Loosen thresholds
- Too permissive? Tighten checks
- Missing something? Add new gate
```

### End of Weeks 10-11

- [ ] Ceremonies reduced by 70%
- [ ] Team happiness improved
- [ ] Metrics show improvement (cycle time down 30%+)
- [ ] Gates are tuned to team's reality

---

## Semana 12: Full Operation + Consolidation

### Monday: Review Progress

```
Compare Week 1 baseline to Week 12:

Metric          | Week 1    | Week 12   | Target
Cycle time      | 18 days   | 5 days    | 3-7d ✓
Throughput      | 5 items/w | 9 items/w | 8-10 ✓
CFR             | 12%       | 4%        | <5% ✓
Time in meets   | 13 hrs/w  | 2 hrs/w   | 1-2 ✓
Team satisfaction| 3.2/5     | 4.1/5     | 4+ ✓
```

### Tuesday-Thursday: Documentation

Document your implementation:

```
1. Spec template used
2. Gate configuration (what each gate checks)
3. Metrics dashboard setup
4. Roles and responsibilities
5. Process flowchart
6. Common issues and solutions

Purpose: When new team members join, they can get up to speed.
```

### Friday: Retrospective + Planning

Full team retro:

```
What went well:
- We're deploying 2x faster
- Quality improved (fewer bugs)
- Team is less burned out (fewer meetings)
- Feedback loops are real-time

What was hard:
- Writing first specs took longer than expected
- IA prompting required learning curve
- Some gates were too strict initially

What's next (Month 4+):
- Expand to other teams
- Add more specialized agents in gates
- Refine spec templates further
- Continue optimizing cycle time
```

### End of Week 12

- [ ] Full Savia Flow implementation complete
- [ ] All 7 Pilares are operational
- [ ] Metrics show significant improvement
- [ ] Team is trained and proficient
- [ ] Documentation exists for onboarding

---

## Tools Needed

### Essential (Must Have)

- **Spec Repository:** GitHub (Markdown), Notion, or Confluence
- **Metrics Dashboard:** Google Sheets, Jira, or custom
- **CI/CD:** GitHub Actions, GitLab CI, or Jenkins
- **Code Quality:** ESLint/Flake8 + language-specific tools
- **Testing:** Jest/Pytest + test framework
- **Issue Tracking:** Jira, Linear, or GitHub Issues

### Recommended (Nice to Have)

- **SAST:** Snyk, SonarQube, GitHub Advanced Security
- **Monitoring:** Datadog, New Relic, or CloudWatch
- **Communication:** Slack with automation bots
- **Analytics:** Amplitude, Mixpanel, or custom

### IA-Specific Tools

- **Code Generation:** GitHub Copilot, Cursor, Claude API
- **Spec Drafting:** Claude, GPT-4
- **Test Writing:** IA agents or Copilot

### Budget Estimate (Monthly)

```
CI/CD Pipeline enhancements: $200-500
SAST tooling: $100-300
Monitoring tools: $200-500
Analytics: $100-300
Total: $600-1600/month (for team of 10)
```

---

## Common Pitfalls & How to Avoid

### Pitfall 1: Specs are Too Long/Detailed

**Problem:** Team spends 2 weeks writing a spec.

**Solution:** Specs should be 2-5 pages, not 20. Focus on:
- Outcome (1 paragraph)
- Success metrics (3-5 lines)
- Functional (1-2 pages)
- Technical (1 page)
- DoD (checklist)

**Time target:** 3-4 hours per spec, not 40.

### Pitfall 2: Quality Gates are Too Strict

**Problem:** Gates reject valid code, team frustrated.

**Solution:** Tuning is iteration.
- Start permissive (catch obvious issues)
- Tighten over time based on patterns
- Disable false-positive generators

### Pitfall 3: IA Prompts are Vague

**Problem:** "Generate API" produces garbage.

**Solution:** Detailed prompts.

```
BAD: "Build search API"

GOOD: "Build Express.js GET /api/search?q=query&limit=10
      Returns JSON with products matching query.
      Must query PostgreSQL, use Redis cache, handle empty results.
      Validate query length >2 chars, <100 chars.
      Return 404 if invalid query, 500 if database error."
```

### Pitfall 4: Metrics Dashboard is Ignored

**Problem:** Dashboard sits in Jira, nobody looks.

**Solution:** Make it visible and actionable.
- Display on team monitor
- Review first thing in morning (async or quick sync)
- Connect to Slack (daily notifications)
- Link to business value (not just numbers)

### Pitfall 5: Team Resists Giving Up Sprints

**Problem:** "We need sprints for planning."

**Solution:** Show data.
- Measure cycle time in Sprints 1-2 (baseline)
- After week 4 without sprints, show improvement
- Let data convince, not arguments

---

## Success Criteria

### Week 4: Minimal Viable Implementation

- [ ] Specs format established and in use
- [ ] At least 1 feature deployed from spec
- [ ] Metrics dashboard exists and is accessible
- [ ] Roles are formally assigned
- [ ] Team can articulate the 7 Pilares

**Outcome:** "This might actually work"

### Week 8: Intermediate Progress

- [ ] Cycle time is measuring and trending down
- [ ] Quality gates 1-4 are automated
- [ ] Dual-track (exploration + production) is operational
- [ ] Team reports 25%+ time saved from fewer meetings
- [ ] At least 2-3 features deployed per week

**Outcome:** "This IS working"

### Week 12: Full Implementation

- [ ] Cycle time is 3-7 days (was 15-21 days = 70% improvement)
- [ ] Throughput is 8-10 items/week (was 5-6 = 60% improvement)
- [ ] CFR is <5% (was 12%+ = 60% improvement)
- [ ] All 7 Pilares are operational
- [ ] Team satisfaction improved 20%+

**Outcome:** "We've successfully adopted Savia Flow"

---

## What to Do Right Now

### Today (Start of Week 1)

1. **Email to team:** "We're adopting Savia Flow starting Monday"
   - Attach this guide + whitepaper
   - Explain why (data-driven)
   - Ask for questions

2. **Schedule kick-off meeting** (Monday, 1.5 hours)

3. **Assign roles** (even if temporary):
   - Who's the new AI PM?
   - Who's the Flow Facilitator?
   - Who leads Pro Builders?
   - Who's QA Architect?

### This Week

4. **Choose spec repository:** Where will specs live?
   - GitHub? Notion? Confluence?
   - Set up one spec as example

5. **Identify your first 5 features** for spec writing

6. **Set baseline metrics:**
   - What's your current cycle time?
   - What's your CFR?
   - What's your velocity?

### Next Week

7. **Write first spec** (with team feedback)

8. **Deploy first CI/CD gate** (even if just lint)

9. **Start measuring** (cycle time, throughput)

---

## Recursos Adicionales

- **Whitepaper:** Leer `01-whitepaper-savia-flow.md` para fundamentos profundos
- **Comparativa:** `02-comparativa-scrum-vs-flow.md` para convencer stakeholders
- **Roles Detallados:** `04-roles-evolucionados.md` para role-specific training
- **Métricas:** `05-métricas-flujo-guia.md` para setup de dashboard
- **Quality Gates:** `07-quality-gates-autonomos.md` para gate architecture

---

## Conclusión

**12 semanas es suficiente para ir de Scrum a Savia Flow completamente operativo.**

El camino es:
1. Weeks 1-2: Learn (specs, metrics, gates)
2. Weeks 3-4: Implement dual-track (exploration + production)
3. Weeks 5-6: Automate basic gates
4. Weeks 7-9: Add advanced gates + formalize roles
5. Weeks 10-11: Optimize + scale
6. Week 12: Full operation + consolidation

**Resultado:** 70% reducción en ciclo de entrega, 60% más throughput, equipo más feliz.

---

**¡Comienza esta semana! Tu equipo está listo.**
