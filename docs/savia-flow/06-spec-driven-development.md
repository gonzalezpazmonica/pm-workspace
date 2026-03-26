# Spec-Driven Development (SDD)
## Guía para Product Managers

**Autor:** Mónica González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Qué es SDD y Por Qué PMs Deberían Importarles

### Definición

Spec-Driven Development (SDD) es un enfoque donde:
1. **Especificaciones ejecutables** son el puente entre idea y código
2. **Especificaciones**, no historias de usuario, dirigen el trabajo
3. **Claridad precede código**—especificaciones eliminan ambigüedad antes de la implementación

### Por Qué Cambiar de Stories a Specs

**User Stories (Scrum Traditional):**
```
As a customer,
I want to filter products by price
So that I find affordable products

Acceptance Criteria:
- Filter appears on search page
- Shows price range
- Applies when changed
```

**Problemas:**
- Narrativa, no instrucción
- "Filter appears" — ¿dónde exactamente?
- "Price range" — ¿mínimo/máximo? ¿moneda?
- Builders adivinan, rework es probable
- IA genera múltiples interpretaciones

**Spec Ejecutable:**
```markdown
# Spec: Price Range Filter

## Outcome
Help customers find products in their budget.
Reduce search friction, increase conversion +8%.

## Success Metrics
- Conversion: +8% (baseline 3.2%)
- Filter usage: 25%+ of searches
- Time to result: <2 seconds

## Functional
- Location: Right sidebar, below category filter
- UI: Range slider ($0 to max product price)
- Behavior: Re-filter on slider change (debounced 300ms)
- Mobile: Input fields instead of slider
- Edge cases:
  - No products in range → show "no results"
  - No price data → hide filter

## Technical
- Backend: Indexed query on price field
- Performance: <100ms response time
- Caching: 1-hour TTL for price buckets

## Definition of Done
- Tests: All scenarios (empty range, no results, etc.)
- Performance: <100ms p95
- Mobile responsive
- WCAG AA accessible
```

**Ventajas:**
- Claridad precisa (no ambigüedad)
- IA entiende exactamente qué construir
- Builders preguntan si algo está poco claro, no después
- Testing puede ser automatizado (DoD es verificable)
- Rework disminuye 60%+

---

## Ciclo de Vida de Especificación

### Fase 1: Discovery (1-2 días)

**Objetivo:** Confirmar que el problema es real y vale la pena resolver

**Actividades:**
```
├─ User research (interviews, data analysis)
├─ Competitive analysis (how do others solve this?)
├─ Impact estimation (how many users affected?)
├─ Effort estimation (rough: days? weeks?)
└─ Decisión: Continue o shelve?
```

**Artefactos:**
- Problema statement (1 párrafo)
- User personas affected
- Data supporting need (si existe)

### Fase 2: Specification Writing (2-4 días)

**Objetivo:** Escribir spec ejecutable completa

**Actividades:**
```
├─ Outcome statement (qué problema resuelve)
├─ Success metrics (KPIs específicos)
├─ Functional spec (qué hace, cómo se comporta)
├─ Technical spec (cómo implementar)
├─ Edge cases (qué sucede si...)
├─ Definition of done (acceptance criteria++)
└─ Builder review (¿está clara? ¿preguntas?)
```

**Artefactos:**
- Spec ejecutable completa (2-5 páginas)
- Mockups si necesario (UI visual)
- Success metrics dashboard (qué medir)

### Fase 3: Build (3-7 días)

**Objetivo:** Convertir spec en código

**Actividades:**
```
├─ Builder reads spec (entiende requerimientos)
├─ Architecture design (cómo estructurar)
├─ IA-assisted implementation (AI generates code)
├─ Manual refinement (builder refines AI output)
├─ Testing (verify against spec)
└─ Quality gates (automated + human review)
```

**Artefactos:**
- Code repository
- Tests
- Documentation

### Fase 4: Validation (Continuous)

**Objetivo:** Verificar que spec fue cumplida y metrics son alcanzadas

**Actividades:**
```
├─ Deploy to production
├─ A/B test (si aplicable)
├─ Monitor success metrics
├─ Gather user feedback
├─ Iterate if metrics missed
└─ Document learnings
```

**Artefactos:**
- Metrics dashboard
- User feedback summary
- Learnings document

---

## Herramientas y Ecosistema

### Spec Writing Tools

**Markdown (GitHub, Notion):**
- ✓ Simplicidad, versionable con git
- ✓ Integrado con código
- ✗ No WYSIWYG, puede parecer técnico

**Notion:**
- ✓ UI visual, fácil para no-técnicos
- ✓ Embeds, multimedia
- ✗ Menos versionable, silo

**Confluence:**
- ✓ Enterprise, integración Jira
- ✓ Permisos granulares
- ✗ Caro, pesado

**Custom Tools:**
- GitHub Spec Kit: https://github.com/github/spec-kit
- Kiro: Spec management platform
- Tessl: Spec collaboration tool

**Recomendación:** Comienza con Markdown en GitHub. Escalas a herramienta especializada después.

### Ecosystem de Herramientas Relacionadas

```
Spec Writing
    ↓
GitHub Repo / Notion
    ↓
IA-Assisted Code Generation (Copilot, Claude)
    ↓
CI/CD Pipelines (GitHub Actions, GitLab CI)
    ↓
Quality Gates (Lint, Tests, SAST, Perf)
    ↓
Deployment (Staging, Prod)
    ↓
Monitoring (DataDog, New Relic)
    ↓
Success Metrics Tracking (Analytics platform)
```

---

## Plantillas

### Plantilla: Outcome Pitch (1 página)

```markdown
# [Feature Name] - Outcome Pitch

## Problem Statement
[What problem are we solving? Who has it? Data if available]

## Solution Hypothesis
[What do we think solves it? Why this approach?]

## Success Metrics
- Metric 1: [baseline] → [target]
- Metric 2: [baseline] → [target]
- Metric 3: [baseline] → [target]

## Effort Estimate
[Rough estimate: 1-3 days? 1-2 weeks? Why?]

## Confidence
[How confident are we? What are unknowns?]

## Next Steps
[What needs to happen next to move forward?]
```

### Plantilla: Especificación Ejecutable (2-5 páginas)

```markdown
# Spec: [Feature Name]

## Executive Summary
[1-2 sentences: What are we building and why?]

## Outcome
[How does this solve the user problem?]
[How does this support business goals?]
[What is the impact?]

## Success Metrics
- Metric 1: Current [baseline], Target [target], Deadline [when measured]
- Metric 2: Current [baseline], Target [target], Deadline [when measured]
- Metric 3: Current [baseline], Target [target], Deadline [when measured]

## User Scenarios
### Main Flow
[Step-by-step: What does the user do?]
1. User does X
2. System responds with Y
3. User sees Z

### Alternative Flows
[What if things aren't normal?]
- If condition A, then do B
- If condition C, then do D

### Edge Cases
[What weird things might happen?]
- No data exists → Show empty state with guide
- User doesn't have permission → Show error message
- System is slow → Show loading spinner

## Functional Specification

### User Interface
[Description or mockup of what user sees]
- Location on page
- Layout
- Colors/styling
- Responsive behavior (mobile, tablet, desktop)
- Accessibility (WCAG AA)

### Behavior
[Detailed description of how feature works]
- What triggers it?
- What happens step-by-step?
- What feedback does user get?
- What data is stored/modified?

### Integration Points
[How does this interact with other systems?]
- APIs it calls
- Databases it queries/modifies
- Third-party services
- Events it emits

## Technical Specification

### Architecture
[How will this be built?]
- Frontend: [technology stack]
- Backend: [technology stack]
- Database: [schema changes if needed]
- Cache: [if applicable]
- Message queue: [if applicable]

### Performance Requirements
- Page load: < [X] ms
- API response: < [X] ms
- Database query: < [X] ms
- Acceptable latency budget

### Data Privacy & Security
- What data is collected?
- How is it stored?
- Retention policy
- GDPR/compliance implications
- Access controls

### Scalability
[How much traffic can this handle?]
- Expected QPS (queries per second)?
- Expected data volume?
- Growth projections?
- Optimization strategies?

### Monitoring & Observability
[How will we know if it's working?]
- Metrics to track
- Dashboards to create
- Alerts to configure
- Logging requirements

## Definition of Done

### Testing
- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] E2E tests for main flows
- [ ] Performance tests (benchmarks met)
- [ ] Security tests (SAST passing)
- [ ] Accessibility tests (WCAG AA)

### Quality Gates
- [ ] Code review approved
- [ ] All tests passing
- [ ] No performance regression
- [ ] Documentation updated
- [ ] Deployment checklist completed

### Deployment
- [ ] Deployed to staging
- [ ] Smoke tests passed
- [ ] Canary deployed (5% → 25% → 100%)
- [ ] Monitoring dashboards active
- [ ] Runbook created (if ops needed)

## Risks & Mitigation
[What could go wrong?]
- Risk 1: Mitigation strategy
- Risk 2: Mitigation strategy

## Dependencies
[What must be done first?]
- On other teams?
- On infrastructure?
- On vendor APIs?

## Acceptance
- [ ] Signed off by: [Product Manager]
- [ ] Signed off by: [Tech Lead]
- [ ] Signed off by: [Other stakeholders if needed]
```

---

## Cómo SDD Coexiste con User Stories

**Pregunta:** ¿Eliminamos user stories completamente?

**Respuesta:** No. Specs y stories tienen propósitos diferentes.

```
User Story (narrative, for communication):
"As a customer, I want to filter by price
 so that I find affordable products"

Spec (executable, for implementation):
[The detailed spec from above]

Relación:
User Story = "What and why" (communicate intent)
Spec = "Exactly how" (guide implementation)

En práctica:
├─ Story vive en Jira/Linear (visible a stakeholders)
├─ Spec vive en GitHub (visible to builders)
├─ Story links to Spec ("See details in Spec X")
├─ When story is moved to "In Progress", Spec is ready
```

---

## Ventajas de SDD para IA

### Con IA, la precisión es crítica

```
Story (vago):
"Build search API that returns products matching query"

IA interpreta como:
- Option A: Full text search in all fields
- Option B: Exact match only
- Option C: ML-powered relevance ranking
- Option D: Faceted search with filters

Result: IA genera una de las 4. Probablemente no es la correcta.
Rework: 3-5 días.

Spec (precisa):
"Build search API GET /api/search?q=query&limit=10

Returns: { products: [...], total: X, facets: {...} }

Behavior:
- Full text search across name, description
- Rank by relevance (TF-IDF)
- Support facets (price, category, brand)
- Pagination: limit=10, offset=0 by default
- Performance: <100ms p95"

Result: IA sabe exactamente qué construir.
Rework: <10% necesita refinement.
Improvement: 70% reducción en rework.
```

---

## Best Practices para Spec Writing

### 1. Be Specific, Not Verbose

**Bad:**
```
The user should be able to search for products
in various ways including by name, description,
and other attributes using a sophisticated search
algorithm that provides relevant results.
```

**Good:**
```
GET /api/search?q=query&limit=10

Returns products matching query across name + description.
Full text search, ranked by TF-IDF relevance.
Response time target: <100ms.
```

### 2. Include Examples

**Bad:**
```
The API should return product data.
```

**Good:**
```
Request: GET /api/search?q=laptop&limit=5

Response:
{
  "products": [
    {
      "id": 123,
      "name": "MacBook Pro",
      "price": 1299.99
    },
    ...
  ],
  "total": 1042
}
```

### 3. Define Edge Cases

**Bad:**
```
Handle error cases appropriately.
```

**Good:**
```
Error Cases:
- Query length <2 characters: Return 400 Bad Request
- Query length >100 characters: Truncate to 100
- No results found: Return 200 with empty products array
- Database timeout: Return 503 Service Unavailable with retry header
```

### 4. Measurable Success Metrics

**Bad:**
```
The feature should improve user experience.
```

**Good:**
```
Success Metrics:
- Search usage: 15% of homepage visitors (baseline 8%)
- Average results reviewed: 3.2 products (baseline 1.8)
- Conversion from search: 12% → 18% (+50%)
- Time to first result: <2 seconds (baseline 5 seconds)
```

---

## Métricas de Éxito para Spec Quality

| Métrica | Target |
|---------|--------|
| % of specs with 0 clarification questions | >80% |
| Rework rate (code requiring changes post-delivery) | <15% |
| Time to write spec | 3-4 hours |
| % of specs hitting success metrics | >75% |
| Team satisfaction with spec clarity | 4+ / 5 |

---

## Conclusión

Spec-Driven Development transforma cómo building sucede:
- PMs escriben menos historias, más especificaciones claras
- Builders implementan, no interpretan
- IA genera mejor código (menos ambigüedad)
- Rework disminuye dramáticamente
- Quality mejora naturalmente

**Para PMs:** SDD significa gastar más tiempo en pensamiento profundo (outco­mes, métricas) y menos tiempo en refinar historias vagas.

**Para builders:** SDD significa más claridad, menos adivinanzas, menos rework.

**Para IA:** SDD significa precisión, y precisión es lo que IA necesita para brillar.

---

**Comienza a escribir specs esta semana. Tus builders te lo agradecerán.**
