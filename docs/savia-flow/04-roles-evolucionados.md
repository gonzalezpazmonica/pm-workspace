# Roles Evolucionados en Savia Flow
## Guía Completa de Transición y Competencias

**Autor:** Mónica González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Introducción

En Scrum, los roles son claros pero asumen equipos completamente humanos. En Savia Flow, los roles evolucionan para colaboración humano-IA. Este documento define cada rol, competencias, actividades diarias, y camino de transición.

### Mapeo Scrum → Savia Flow

| Scrum | Savia Flow | Cambio Principal |
|-------|-----------|------------------|
| Product Owner | AI Product Manager | Define outcomes + métricas, no features |
| Scrum Master | Flow Facilitator | Optimiza flujo + métricas, no ceremonias |
| Developer | Pro Builder | Orquestra IA + arquitectura, no solo coding |
| QA Engineer | Quality Architect | Diseña puertas autónomas, supervisa agentes |

---

## 1. AI Product Manager

### Responsabilidades Core

El AI PM es responsable de **qué construir** y **por qué**, asegurando que cada outcome:
- Resuelve un problema real
- Tiene métricas de éxito claras
- Es especificado sin ambigüedad
- Es priorizado correctamente

### Competencias Requeridas

#### Técnicas
- **Análisis de datos:** Interpretar métricas de usuario, funnel analysis, cohortes
- **Especificación escrita:** Capaz de comunicar ideas complejas sin ambigüedad
- **Pensamiento sistémico:** Entender relaciones entre features, no aislar

#### De Negocio
- **Mentalidad de outcome:** Pensar en resultados, no features
- **Priorización:** Decir no, balancear impacto vs. esfuerzo
- **Estrategia:** Alineado con visión organizacional

#### De Colaboración IA
- **Prompt engineering:** Comunicar claramente con IA tools
- **Verificación crítica:** No confiar ciegamente en outputs de IA
- **Iteración rápida:** Usar IA para exploración rápida de ideas

### Actividades Diarias

```
8:00-8:30: Metrics Review
├─ Check DORA metrics (cycle time, throughput, CFR)
├─ Review deployed features (hit success metrics?)
├─ Identify trends (what's improving, what's not)
└─ Action: Note any features underperforming

8:30-9:30: Specification Work
├─ Writing new specs (exploratory)
├─ Refining existing specs based on builder feedback
├─ Ensuring clarity and testability
└─ Output: 1-2 specs drafted

9:30-10:30: Data Analysis
├─ User feedback review (support tickets, survey data)
├─ Competitive analysis (what are competitors doing)
├─ Trend spotting (what's emerging)
└─ Ideation: What outcomes could we pursue?

10:30-11:30: IA-Assisted Exploration
├─ Use Claude/ChatGPT to brainstorm outcomes
├─ Research unknowns (market size, user pain)
├─ Draft success metrics
└─ Output: Potential outcomes for next 2-3 weeks

12:00-13:00: Lunch + Stakeholder sync

13:00-14:30: Builder Collaboration
├─ Answer spec clarification questions
├─ Discuss architectural tradeoffs
├─ Validate assumptions (will this work?)
└─ Iterate specs based on feedback

14:30-15:30: Validation & Refinement
├─ Review builds completed this week
├─ Analyze metrics in production
├─ Gather user feedback on deployed features
└─ Input for next outcomes

15:30-16:30: Roadmap & Prioritization
├─ Prioritize upcoming specs (impact vs. effort)
├─ Align with business goals
├─ Communicate to stakeholders
└─ Output: Clear backlog order
```

### Herramientas

**Essentials:**
- Analytics platform (Mixpanel, Amplitude, custom)
- Spec repository (GitHub, Notion, Confluence)
- Product management tool (Jira, Linear)
- Communication (Slack)

**IA Tools:**
- Claude API (for exploration)
- ChatGPT (alternative)
- GitHub Copilot (for quick ideas)

### Métricas de Éxito para AI PM

| Métrica | Target |
|---------|--------|
| Specs completadas/semana | 2-3 |
| % de specs con éxito de métricas | >75% |
| Tiempo de especificación | 3-4 hrs/spec |
| Feedback loop con builders | <24 hrs |
| Features deployed on-time | >85% |

### Transición desde Product Owner

**Semana 1-2:**
- Continue siendo Product Owner
- Pero: Aprende especificación ejecutable (no historias)
- Escribe 2-3 specs como aprendizaje

**Semana 3-4:**
- Comienza spec-writing como actividad principal
- Menos tiempo en planning, más en análisis de datos
- Colabora con Flow Facilitator en metrics

**Semana 5+:**
- Completamente transicionado
- Define outcomes, no features
- Obsesionado con success metrics

---

## 2. Flow Facilitator

### Responsabilidades Core

El Flow Facilitator es responsable de **cómo trabaja el equipo**, optimizando para:
- Fluidez (ciclo de tiempo bajo, sin bloqueos)
- Claridad (métricas visible, decisiones transparentes)
- Autonomía (equipo se auto-organiza)
- Aprendizaje (mejora continua)

### Competencias Requeridas

#### Técnicas
- **Métricas DORA:** Entender cycle time, lead time, throughput, CFR
- **Estadística básica:** Trend analysis, causation vs. correlation
- **CI/CD:** Entender pipelines, gates, deployment
- **IA collaboration:** Entender cómo IA impacta flujo

#### De Liderazgo
- **Coaching:** Desarrollar habilidades de builders
- **Facilitación:** Meetings sin control (autonomía, no micromanagement)
- **Comunicación:** Explicar métricas a no-technical stakeholders
- **Decisión:** Tomar decisiones con datos (no intuición)

#### De Empatía
- **Escucha:** Entender pain points del equipo
- **Paciencia:** Cambio es gradual
- **Humildad:** Aprender de errores

### Actividades Diarias

```
8:00-8:30: Morning Metrics Check
├─ Review dashboard (cycle time, throughput, CFR, WIP)
├─ Spot anomalies (why is cycle time 9 days, not 4?)
├─ Identify blockers (what's stuck?)
└─ Action: List of potential issues to investigate

8:30-9:30: Blocker Removal
├─ Contact owner of stuck item (why is it blocked?)
├─ Escalate if needed (remove dependencies)
├─ Help builders (pair programming if needed)
└─ Output: Unblocked work, faster flow

9:30-10:30: Coaching Session(s)
├─ 1:1 with builder struggling with IA prompting
├─ Share technique: "Write detailed prompts first"
├─ Practice together: Show/tell/do model
└─ Output: Builder improves (fewer iterations needed)

10:30-11:30: Process Improvement
├─ Analyze metrics trend
├─ Root cause analysis (why CFR increased?)
├─ Brainstorm improvements
├─ Test: Run small experiment (e.g., add new gate)
└─ Output: Process improvement proposal

12:00-13:00: Lunch + Team Sync (async via dashboard)

13:00-14:30: One-on-Ones
├─ Check in with each team member
├─ How are you feeling? (workload, stress, satisfaction)
├─ What support do you need?
├─ Share feedback on recent work
└─ Output: Team feels heard, individual needs addressed

14:30-15:30: Stakeholder Communication
├─ Report metrics to leadership
├─ Explain trends (cycle time improved 15%)
├─ Discuss blockers (need decisión from X)
├─ Align on priorities
└─ Output: Leadership informed, aligned

15:30-16:30: Retrospective Prep
├─ Gather data for retro (if retro is this week)
├─ Synthesize insights
├─ Prepare questions for reflection
└─ Output: Structured retro ready to run
```

### Herramientas

**Essentials:**
- Metrics dashboard (Grafana, Google Sheets, Jira)
- Issue tracking (Jira, Linear)
- Communication (Slack)
- Video conferencing (for 1:1s)

**Data Tools:**
- SQL query tool (analyze trends)
- Spreadsheets (trend analysis)

### Métricas de Éxito para Flow Facilitator

| Métrica | Target |
|---------|--------|
| Cycle time trend | ↓ 15% month-over-month |
| CFR trend | ↓ 10% month-over-month |
| Team satisfaction | 4.0+ / 5.0 |
| Blocker resolution time | <4 hours |
| % of time in meetings | <20% |

### Transición desde Scrum Master

**Semana 1-2:**
- Continue faciliating ceremonies
- Pero: Begin tracking DORA metrics (install dashboard)
- Learn cycle time, CFR calculations

**Semana 3-4:**
- Stop daily standups
- Use dashboard as standup replacement
- Begin 1:1s (coaching-focused)

**Semana 5+:**
- Completely transitioned
- Focus on metrics, not ceremonies
- Optimize flow, not process compliance

---

## 3. Pro Builder

### Responsabilidades Core

El Pro Builder es responsable de **cómo se construye**, asegurando:
- Arquitectura es sólida
- IA es orquestada efectivamente
- Código es revisado (por humanos y agentes)
- Calidad es mantenida

### Competencias Requeridas

#### Técnicas
- **Arquitectura de software:** System design, patterns, tradeoffs
- **Lenguajes/frameworks:** Experto en stack del equipo
- **IA prompting:** Comunicar precisamente con IA
- **Testing:** Escribir/revisar tests efectivos
- **Debugging:** Encontrar raíz de problemas rápidamente

#### De Liderazgo
- **Code review:** Retroalimentación constructiva
- **Mentoring:** Desarrollar skills de engineers junior
- **Decisión-making:** Tomar decisiones arquitectónicas
- **Ownership:** Responsable de calidad del código

#### De Crítica
- **Escepticismo sano:** Verificar outputs de IA
- **Cuestionamiento:** Why did IA generate this?
- **Iteración:** Refinar AI output cuando es necesario

### Actividades Diarias

```
8:00-8:30: Stand-in (Dashboard Review)
├─ Check what's in progress
├─ Check what's waiting for me (code review?)
├─ Check if blocked (dependent systems down?)
└─ Action: Prioritize work

8:30-10:00: Feature Build
├─ Read spec (ensure clarity)
├─ Design architecture (on paper if complex)
├─ Prompt IA for initial implementation
├─ Local testing
└─ Output: Code ready for review (70-90% complete)

10:00-11:00: IA Output Review & Refinement
├─ Read IA-generated code (understand what it did)
├─ Identify issues (off-by-one, missing edge cases, etc.)
├─ Manual refinement (20-30% of code)
├─ Ensure spec compliance
└─ Output: Code is solid

11:00-12:00: Testing & Quality Gates
├─ Run unit tests (fix any failures)
├─ Run integration tests
├─ Performance checks
├─ Security review
└─ Output: Ready for CI/CD gates

12:00-13:00: Lunch

13:00-14:30: Code Review (Others' Code)
├─ Review 2-3 PRs from other builders
├─ Check architecture, security, tests
├─ Provide constructive feedback
├─ Approve or request changes
└─ Output: Team code quality maintained

14:30-15:30: Knowledge Sharing & Mentoring
├─ If junior engineer struggling:
│  └─ Pair programming session (30 min)
├─ Document patterns learned
├─ Share in team slack
└─ Output: Team learns, spreads knowledge

15:30-16:30: Prep for Next Task
├─ Read spec for next feature
├─ Ask clarification questions to PM
├─ Design architecture mentally
├─ Prepare prompts for IA
└─ Output: Ready to build tomorrow
```

### Herramientas

**Essentials:**
- IDE (VS Code, JetBrains, etc.)
- IA code generation (Copilot, Claude API, Cursor)
- Git/GitHub (versión control, code review)
- Testing frameworks (Jest, Pytest, JUnit, etc.)
- Debugging tools (Chrome DevTools, debugger, logs)

**IA-Specific:**
- GitHub Copilot (in IDE)
- Claude (via API or web)
- Specialized IA agents (your custom tools)

### Métricas de Éxito para Pro Builder

| Métrica | Target |
|---------|--------|
| Code review turnaround | <4 hours |
| % code passing gates on 1st attempt | >80% |
| Rework rate | <15% |
| Feature delivery on-time | >85% |
| Test coverage | >85% |

### Transición desde Developer

**Semana 1-2:**
- Continue coding as usual
- Pero: Learn IA prompting (Copilot, Claude)
- Start collaborating with new roles (AI PM, Flow Facilitator)

**Semana 3-4:**
- Begin reading specs instead of stories
- IA assistance becomes standard
- Code review focus shifts to architecture

**Semana 5+:**
- Completely transitioned
- Prompting is natural
- Architectural thinking is primary

---

## 4. Quality Architect

### Responsabilidades Core

El Quality Architect es responsable de **asegurar calidad en escala**, diseñando:
- Puertas de calidad autónomas (gates)
- Estrategia de testing (qué testar, cómo)
- Agentes especializados de QA
- Prevención, no solo detección

### Competencias Requeridas

#### Técnicas
- **Testing strategies:** Unit, integration, security, performance, accessibility
- **Automation:** CI/CD, SAST, dependency scanning, etc.
- **Security:** OWASP top 10, secure coding, threat modeling
- **Scripting:** Escribir scripts para automatización
- **IA tools:** SAST, security agents, automated testing frameworks

#### De Arquitectura
- **Pensamiento preventivo:** Prevenir bugs, no solo detectarlos
- **Escala:** Diseñar gates que escalen con IA (15+ agents)
- **Trade-offs:** Qué checks are worth cost?
- **Governance:** Balancear strictness vs. developer friction

#### De Estadística
- **False positives/negatives:** Entender trade-offs
- **Confidence levels:** Qué tan seguro estamos?
- **Trend analysis:** CFR mejorar? Bug escape rate crecer?

### Actividades Diarias

```
8:00-8:30: Gate Metrics Review
├─ How many items passed gates yesterday?
├─ How many required human intervention?
├─ Any anomalies? (e.g., unusual SAST warnings)
└─ Action: Investigate issues

8:30-9:30: Defect Analysis
├─ If bug escaped to production:
│  ├─ Why didn't gates catch it?
│  ├─ Is this a gate gap?
│  └─ Design fix
├─ If gate rejected valid code:
│  ├─ False positive?
│  ├─ Need tuning?
│  └─ Adjust threshold
└─ Output: Gates improved

9:30-10:30: Agent Design/Tuning
├─ Current focus: Permission Checker Agent
├─ Design: Detect missing permission validation
├─ Test: Does it catch known bugs?
├─ Implement: Add to Level 4 security gate
└─ Output: New gate operational

10:30-11:30: Gate Performance Review
├─ Are gates too slow? (taking >5 min)
├─ Are gates catching the right issues?
├─ Tuning: Thresholds, checks, rules
└─ Output: Gates optimized

12:00-13:00: Lunch + Casual Review

13:00-14:30: Testing Strategy & Patterns
├─ Review test quality (mutation testing scores)
├─ Design new test patterns (builders should use)
├─ Document testing best practices
├─ Share via wiki/slack
└─ Output: Team writes better tests

14:30-15:30: Security & Compliance
├─ Security review of critical components
├─ Dependency vulnerability scan
├─ Compliance check (GDPR, SOX, etc.)
├─ Escalate if needed
└─ Output: Security risks identified/mitigated

15:30-16:30: Research & Innovation
├─ Explore new SAST tools
├─ Research specialized agents
├─ Prototype new gate (performance profiling?)
└─ Output: Innovations to pilot next month
```

### Herramientas

**Essentials:**
- SAST tools (Snyk, SonarQube, GitHub Advanced Security)
- Testing frameworks (Jest, Pytest, Selenium, etc.)
- Performance monitoring (DataDog, New Relic, APM)
- Security scanners (OWASP ZAP, Burp)
- CI/CD platform (GitHub Actions, GitLab CI, Jenkins)

**IA-Specific:**
- Custom security agents (your own or 3rd party)
- Test generation tools
- Vulnerability analysis agents

### Métricas de Éxito para Quality Architect

| Métrica | Target |
|---------|--------|
| CFR (Change Failure Rate) | <5% |
| Defect escape rate | <1% |
| Gate pass-through rate | >75% (no human review) |
| Mean time to detect bug | <4 hours |
| False positive rate | <10% |

### Transición desde QA Engineer

**Semana 1-2:**
- Continue manual testing
- Pero: Learn SAST tools, CI/CD, gates
- Design first automated gate (Lint)

**Semana 3-4:**
- Shift from testing to gate design
- Automate level 2-3 gates (Unit tests, integration)
- Mentor builders on testing

**Semana 5+:**
- Completely transitioned
- Focus on prevention, not detection
- Design specialized agents
- Become expert in security testing

---

## Transición Organizacional

### Timeline Recomendado

```
Week 1-2: Announce roles
├─ Email to team
├─ Explain rationale
├─ Q&A session
└─ Assign people formally

Week 3-4: Training by role
├─ AI PM: Spec writing workshop
├─ Flow Facilitator: Metrics deep dive
├─ Pro Builders: IA prompting + architecture
├─ Quality Architect: Gate design + SAST tools

Week 5-6: New roles active (part-time)
├─ People learn while doing
├─ Old roles continue (70%)
├─ New roles begin (30%)

Week 7-12: New roles full-time
├─ Gradual shift
├─ Mentoring continues
├─ Role definitions refined

Week 13+: Stabilized
├─ Roles are normal
├─ Continuous optimization
└─ Career growth continues
```

### Change Management Tips

1. **Communicate why:** Show data (Scrum pain points, IA reality)
2. **Acknowledge concerns:** "This is different, and it will take learning"
3. **Celebrate wins:** When cycle time improves, celebrate team
4. **Iterate:** Roles will evolve; gathering feedback is important
5. **Invest in training:** Each role needs 20-40 hours of training
6. **Pair programming:** Experienced builder mentors struggling one
7. **Quick wins:** Start with 1-2 features to build confidence

---

## Career Paths

### AI Product Manager → Director of Product

```
Associate AI PM (2-3 years)
├─ Learn spec writing
├─ Learn analytics
├─ Manage 1-2 product areas
└─ Compensation: $120-150k

Senior AI PM (3-5 years)
├─ Own multiple areas
├─ Strategic thinking
├─ Lead feature strategy for platform
└─ Compensation: $150-200k

Director of Product
├─ Own product strategy (entire platform)
├─ Lead team of 2-3 PMs
├─ Work with executive team
└─ Compensation: $200-300k+
```

### Flow Facilitator → VP Engineering

```
Junior Flow Facilitator (1-2 years)
├─ Learn DORA metrics
├─ Facilitate single team
├─ Coaching/mentoring
└─ Compensation: $110-140k

Senior Flow Facilitator (2-4 years)
├─ Lead multiple teams
├─ Org design thinking
├─ Process improvement strategy
└─ Compensation: $140-180k

VP Engineering
├─ Entire engineering org
├─ Hiring, strategy, culture
├─ Director-level leadership
└─ Compensation: $250-400k+
```

### Pro Builder → Staff/Principal Engineer

```
Associate Pro Builder (0-2 years)
├─ Learn IA collaboration
├─ Code review from seniors
├─ Deliver features
└─ Compensation: $100-130k

Senior Pro Builder (2-5 years)
├─ Architecture decisions
├─ Mentoring junior builders
├─ Feature ownership
└─ Compensation: $130-170k

Staff Engineer (5+ years)
├─ Technical strategy
├─ Cross-team architecture
├─ Mentoring senior engineers
└─ Compensation: $200-300k+

Principal Engineer
├─ Org-level technical strategy
├─ Innovation leadership
├─ Executive visibility
└─ Compensation: $300k+
```

### Quality Architect → Director of Quality/Security

```
Associate Quality Engineer (1-3 years)
├─ Write tests
├─ Gate implementation
├─ Learn SAST tools
└─ Compensation: $100-130k

Quality Architect (3-5 years)
├─ Gate design
├─ Strategy for testing/security
├─ Custom agent development
└─ Compensation: $130-170k

Director of Quality (5+ years)
├─ Org-level quality strategy
├─ Compliance/security governance
├─ Team leadership
└─ Compensation: $200-300k+
```

---

## Competencia de Transición: Matriz de Habilidades

### AI Product Manager

| Competencia | Scrum PO | AI PM | Brecha | Desarrollo |
|-----------|----------|-------|-------|-----------|
| Análisis de datos | Débil | Fuerte | Alto | Cursos analytics, práctica |
| Especificación escrita | Débil | Fuerte | Alto | Templates, mentoring |
| Métrica-driven thinking | Débil | Fuerte | Alto | Coaching con Flow Facilitator |
| IA collaboration | N/A | Fuerte | Alto | Hands-on experimentation |

### Flow Facilitator

| Competencia | Scrum Master | Flow Facilitator | Brecha | Desarrollo |
|-----------|---|---|---|---|
| Faciliación | Fuerte | Fuerte | Bajo | Mantener |
| Métricas DORA | Débil | Fuerte | Alto | Training + dashboard practice |
| Coaching | Fuerte | Fuerte | Bajo | Refocarse en coaching |
| Estadística | Débil | Fuerte | Alto | Data analysis training |

### Pro Builder

| Competencia | Developer | Pro Builder | Brecha | Desarrollo |
|-----------|---|---|---|---|
| Coding | Fuerte | Fuerte | Bajo | Continuar |
| Arquitectura | Débil | Fuerte | Alto | System design training |
| IA prompting | N/A | Fuerte | Alto | Hands-on practice |
| Code review | Débil | Fuerte | Medio | Mentoring de seniors |

### Quality Architect

| Competencia | QA Engineer | Quality Architect | Brecha | Desarrollo |
|-----------|---|---|---|---|
| Testing | Fuerte | Fuerte | Bajo | Mantener |
| Automation | Débil | Fuerte | Medio | Scripting + CI/CD |
| Security | Débil | Fuerte | Alto | Security training |
| Estadística | Débil | Fuerte | Medio | Stats fundamentals |

---

## Conclusión

Los roles evolucionados de Savia Flow son **más especializados pero más autónomos**. Cada rol tiene propiedad clara:

- **AI PM:** "¿Qué construir?"
- **Flow Facilitator:** "¿Cómo trabaja el equipo?"
- **Pro Builder:** "¿Cómo construir?"
- **Quality Architect:** "¿Cómo asegurar calidad?"

La transición toma 8-12 semanas. Requiere training, pero es inversión que paga dividendos: equipo más competente, satisfecho, y productivo.

---

**Comienza la transición esta semana. Asigna roles formalmente. El resto sigue naturalmente.**
