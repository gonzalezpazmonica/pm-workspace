# Puertas de Calidad Autónomas
## Arquitectura de 5 Niveles para Supervisión basada en IA

**Autor:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## La Crisis de Calidad del Código Generado por IA

### Problema Real

Investigación 2025-2026 muestra:

```
50% del código generado por IA contiene defectos
└─ Off-by-one errors (10%)
└─ SQL injection vulnerabilities (8%)
└─ Unhandled exceptions (12%)
└─ Performance n+1 queries (10%)
└─ Otros (10%)

Sin calidad gates:
├─ Defect escape rate: 40-60% (IA bugs llegan a producción)
├─ Deployment frequency baja (miedo a romper cosas)
├─ Team morale baja (arreglando bugs constantemente)

Con calidad gates bien diseñadas:
├─ Defect escape rate: <1-2% (IA bugs atrapados antes de producción)
├─ Deployment frequency alta (confianza en process)
├─ Team morale alta (working software, no firefighting)
```

### Solución: Autonomous Quality Gates

**Idea:** Diseña un sistema de validaciones automatizadas que:
1. Ejecuta sin intervención humana
2. Proporciona feedback inmediato
3. Escala a volumen de IA (10x código es generado)
4. Tiene human escalation para edge cases

---

## Arquitectura de 5 Niveles

### Nivel 1: Syntax & Linting (Instant)

**Qué valida:**
```
├─ Code parses (not syntax errors)
├─ Formatting consistent (Prettier, Black, etc.)
├─ Linting rules pass (ESLint, Flake8, etc.)
├─ No obvious code smells (unused vars, dead code)
└─ Type checking (if typed language)
```

**Herramientas:**
- ESLint (JS), Flake8 (Python), Checkstyle (Java), golangci-lint (Go)
- Prettier (formatting)
- Language-specific type checkers

**Tiempo:** <10 segundos
**Action si falla:** Auto-reject, show error to developer

**Ejemplo:**
```
Builder submits code
    ↓
Level 1 runs ESLint
    ↓
Found issues:
├─ Line 12: Unused variable 'temp'
├─ Line 45: Missing semicolon
├─ Line 89: var instead of const
    ↓
Rejected: "Fix linting errors and resubmit"
    ↓
Builder fixes
    ↓
Resubmitted
    ↓
Level 1 Pass ✓
    ↓
Proceed to Level 2
```

### Nivel 2: Unit Tests & Coverage (5-30 segundos)

**Qué valida:**
```
├─ All unit tests pass (no red tests)
├─ Code coverage ≥80% (or configured threshold)
├─ Test quality (via mutation testing if available)
├─ No test warnings/deprecations
└─ Benchmarks (for performance-critical code)
```

**Herramientas:**
- Jest (JS), Pytest (Python), JUnit (Java), etc.
- Istanbul/nyc (coverage), coverage.py
- Stryker (mutation testing)

**Tiempo:** 5-30 segundos (depende test suite size)
**Action si falla:**
- Coverage <80%: Reject con requerimiento "Add tests"
- Test rojo: Reject con error stacktrace
- Low mutation score: Warn (no reject)

**Ejemplo:**
```
Level 2 Execution:
├─ Run: npm test
├─ Results:
│  ├─ 45 tests passed ✓
│  ├─ Coverage: 92% ✓
│  ├─ Mutation score: 0.87 ✓
└─ Action: Pass, proceed to Level 3
```

### Nivel 3: Integration Tests (30-120 segundos)

**Qué valida:**
```
├─ API contracts met (if endpoint)
├─ Database migrations work + rollback
├─ External service integrations (mocked or real)
├─ Data flow end-to-end
├─ No SQL injection (parameterized queries)
└─ Concurrent operations (if applicable)
```

**Herramientas:**
- Postman / REST Client (API testing)
- Testcontainers (database testing)
- Docker Compose (service mocking)
- Selenium / Playwright (E2E if needed)

**Tiempo:** 30-120 segundos
**Action si falla:** Reject con error details

**Ejemplo:**
```
Level 3 Execution:
├─ Spin up test database
├─ Run migrations: ✓
├─ Test rollback: ✓
├─ Test API endpoints:
│  ├─ POST /api/users: 201 ✓
│  ├─ GET /api/users/{id}: 200 ✓
│  ├─ PUT /api/users/{id}: 200 ✓
│  └─ DELETE /api/users/{id}: 204 ✓
├─ Test edge cases:
│  ├─ GET nonexistent ID: 404 ✓
│  ├─ POST invalid data: 400 ✓
└─ Action: Pass, proceed to Level 4
```

### Nivel 4: Security, Performance, & IA Agents (30-120 segundos)

**Qué valida:**
```
Level 4a - Security:
├─ SAST (Static App Security Testing)
│  ├─ SQL injection patterns
│  ├─ XSS vulnerabilities
│  ├─ CSRF protection
│  ├─ Insecure crypto usage
│  └─ Hard-coded credentials
├─ Secrets scanning
│  ├─ No API keys in code
│  ├─ No private data exposed
├─ Dependency vulnerabilities
│  ├─ Known CVEs in libraries
│  ├─ Outdated dependency check

Level 4b - Performance:
├─ Performance benchmarks vs baseline
├─ Memory leaks detection
├─ n+1 query detection
├─ Unnecessary network calls
└─ Large bundle size check

Level 4c - Specialized IA Agents (15+ possible):
├─ Permission Checker: Detects missing auth validation
├─ CORS Validator: Checks CORS headers
├─ Rate Limiter Verifier: Validates rate limiting
├─ Cache Strategy: Checks cache invalidation
├─ Error Handler: Detects unhandled exceptions
├─ Logging Verifier: Ensures proper logging
├─ Concurrency Checker: Detects race conditions
├─ Input Validator: Checks input sanitization
├─ Output Encoder: Validates output encoding
├─ Async Handler: Checks promise chains
├─ Type Safety: Validates type usage
├─ Regex Safety: Detects ReDoS patterns
├─ Crypto Proper Usage: Validates cryptography
├─ API Design: Validates REST/API principles
└─ [Custom agents for your domain]
```

**Herramientas:**
- SAST: Snyk, SonarQube, GitHub Advanced Security
- Secrets: git-secrets, TruffleHog, Snyk
- Performance: Lighthouse, PyTest benchmarks, JMH
- Dependency: Snyk, OWASP Dependency Check, pip-audit
- Custom Agents: Build yourself or use specialized models

**Tiempo:** 30-120 segundos
**Action si falla:**
- High severity security issue: Auto-reject
- Medium severity: Flag for human review
- Performance regression >10%: Reject
- False positive: Tune threshold, resubmit

**Ejemplo:**
```
Level 4 Execution:
├─ SAST Results:
│  ├─ SQL injection patterns: 0 ✓
│  ├─ XSS vulnerabilities: 0 ✓
│  ├─ Secrets found: 0 ✓
├─ Dependency check:
│  ├─ High severity CVEs: 0 ✓
│  ├─ Medium severity CVEs: 1 ⚠ (review)
├─ Performance:
│  ├─ Benchmark vs baseline: +2% (acceptable) ✓
├─ IA Agents:
│  ├─ Permission Checker: Pass ✓
│  ├─ CORS Validator: Pass ✓
│  ├─ Rate Limiter: Missing! ⚠ (flag for review)
│  ├─ Async Handler: Pass ✓
│  └─ [10 more agents] ✓
├─ Decisión:
│  ├─ 1 medium security issue detected
│  └─ Action: Flag for Level 5 human review
```

### Nivel 5: Human Review (Lightweight, 15-30 minutos)

**Qué valida:**
```
Human Review (Architects/Leads):
├─ Architecture decisions (does this fit our design?)
├─ Code quality (is this maintainable?)
├─ Spec compliance (does this solve the intended problem?)
├─ Business logic (is this correct for the domain?)
├─ Escalations from Level 4 (security, perf concerns)
└─ Known limitations (is IA output limited in expected ways?)
```

**Process:**
```
1. Review gates 1-4 results (should be mostly green)
2. Read PR/commit message (understand intent)
3. Skim code (don't read line-by-line, gates did that)
4. Check for:
   ├─ Does this achieve the outcome?
   ├─ Any architecture red flags?
   ├─ Spec violations?
   ├─ Unplanned side effects?
   └─ Known limitations?
5. Approve or request changes (rarely needed, <10% rate)
```

**Tiempo:** 15-30 minutos (much lighter than before gates)
**Action:**
- Approve → Deploy
- Request changes → Back to builder (usually minor)
- Escalate → Security team, performance team, etc.

**Ejemplo:**
```
Level 5 Review:
Architect reviews PR for "Real-time notifications"

Review notes:
├─ Gates 1-4: All green ✓
├─ Spec review: Matches spec perfectly ✓
├─ Architecture: Uses Pub/Sub (good choice) ✓
├─ One concern: Fallback from WebSocket to polling
│  └─ Check: Is this specified? Yes ✓
├─ Decisión: APPROVE ✓

Time spent: 12 minutes
Result: Deploy to production
```

---

## 15+ Specialized Agents Concept

### Agentes Implementables Hoy

| Agent | Detecta | Severidad | Effort |
|-------|---------|-----------|---------|
| SQL Injection Detector | SQL vuln patterns | High | 2-3 days |
| CORS Misconfiguration | CORS header issues | High | 1 day |
| Auth/Authz Verifier | Missing auth validation | High | 3-4 days |
| Rate Limiter Validator | Missing rate limiting | Medium | 2 days |
| Cache Invalidation | Cache bugs | Medium | 2-3 days |
| Error Handler Checker | Unhandled exceptions | Medium | 1 day |
| Input Validator | Missing input sanitization | High | 2 days |
| Output Encoder | XSS risks | High | 2 days |
| Async Handler | Promise/callback chains | Medium | 1-2 days |
| Type Safety | Type mismatches | Low | 1 day |
| Regex DoS Detector | ReDoS patterns | Medium | 1 day |
| Crypto Proper Usage | Insecure crypto | High | 2-3 days |
| API Design | REST violations | Low | 1 day |
| Concurrency Detector | Race conditions | Medium | 3-4 days |
| Logging Verifier | Missing logs | Low | 1 day |

**Total implementation:** ~30-40 days to build all 15 agents

**ROI:** Each agent catches bugs, prevents production incidents, improves quality dramatically

---

## Human Escalation Criteria

### Cuándo Escalar a Humanos

```
Escalar si:
├─ Security issue (medium or higher severity)
├─ Performance regression (>10% vs baseline)
├─ Architecture concern (agent detects unusual pattern)
├─ Spec deviation (gates flag mismatch)
├─ Unknown: Agent confidence < 70%
├─ Multi-system impact (complex integration)
└─ Business logic (IA might misunderstand intent)

Don't escalar si:
├─ Gates 1-3 all green (mechanical check, no human insight needed)
├─ Security issue is false positive (tune agent, resubmit)
├─ Performance within tolerance (even if slightly slower)
└─ Trivial code style (gates should have caught)
```

---

## Implementation Roadmap

### Month 1: Foundation

**Week 1-2:**
```
└─ Level 1: Lint + formatting
   └─ Setup ESLint/Prettier in CI
   └─ Time to implement: 1 day
   └─ Value: Catch style issues immediately
```

**Week 3-4:**
```
└─ Level 2: Unit tests + coverage
   └─ Configure test runner, coverage tool
   └─ Time to implement: 1-2 days
   └─ Value: Ensure tests exist and quality
```

### Month 2: Integration & Security

**Week 5-6:**
```
└─ Level 3: Integration tests
   └─ Set up database testing, API mocking
   └─ Time to implement: 2-3 days
   └─ Value: End-to-end validation
```

**Week 7-8:**
```
└─ Level 4a: Basic SAST + secrets
   └─ Integrate Snyk or GitHub Advanced Security
   └─ Time to implement: 1-2 days
   └─ Value: Security vulnerability detection
```

### Month 3: Advanced

**Week 9-10:**
```
└─ Level 4b: Performance gates
   └─ Set up performance benchmarking
   └─ Time to implement: 2-3 days
   └─ Value: Prevent performance regressions
```

**Week 11-12:**
```
└─ Level 5: Human review SLA
   └─ Process definition, training
   └─ Time to implement: 1 day
   └─ Value: Lightweight architectural validation
```

### Month 4+: Specialized Agents

**Ongoing:**
```
└─ Build 1-2 specialized agents per sprint
   └─ Start with high-impact: Auth, SQL, XSS
   └─ Add others based on team pain points
   └─ Value: Continuous improvement, fewer bugs
```

---

## Métricas que Importan

### Defect Escape Rate

**Definición:** % de bugs que escapan a producción

```
Target Savia Flow: <1%
Calculation:
├─ Bugs found in production last month: 3
├─ Total features deployed: 40
├─ Escape rate: 3/40 = 7.5% ❌ (too high)

Investigation:
├─ Bugs found: Off-by-one (not caught by tests)
├─ Root cause: Test coverage weak for loops
├─ Fix: Add Permission Checker agent, improve tests
└─ Result (next month): 1/40 = 2.5% ✓ (better)
```

### Gate Pass-Through Rate

**Definición:** % de código que pasa los gates en el primer intento

```
Target Savia Flow: >75%
Calculation:
├─ Code submissions: 20
├─ Passed gates 1st attempt: 15
├─ Pass-through: 15/20 = 75% ✓

Meaning:
├─ 75% passed in first attempt (good)
├─ 25% required fixes/resubmission (acceptable)
├─ If <50%: Gates too strict or IA quality low
├─ If >90%: Possible gates too lenient
```

### Mean Time to Fix (MTTF)

**Definición:** Tiempo promedio para que un builder corrija un rechazo de gate

```
Target Savia Flow: <30 minutos
Calculation:
├─ Gate rejection: 3:30 PM
├─ Builder fixes + resubmits: 4:00 PM
├─ MTTF: 30 minutos ✓

If MTTF > 1 hour:
├─ Gates may be unclear
├─ Feedback messages need improvement
├─ Add context (what exactly failed?)
```

---

## Caso de Uso: Real-time Notifications Feature

### Timeline com Quality Gates

```
Day 1 (Monday 2pm):
└─ Pro Builder submits code
   └─ Level 1 (Lint): ✓ Pass (2 sec)
   └─ Level 2 (Tests): ✓ Pass (15 sec, 94% coverage)
   └─ Level 3 (Integration): ✓ Pass (45 sec)
   └─ Level 4 (Security):
      ├─ SAST: ✓ Clean
      ├─ Auth Verifier: ⚠ Missing permission check on one endpoint
      └─ Action: Flag for human review
   └─ Notify builder: "Fix auth issue or request human review"

Day 1 (2:45pm):
└─ Builder fixes missing auth check
   └─ All gates pass ✓
   └─ Submit to Level 5

Day 1 (3:00pm):
└─ Architect reviews (Level 5):
   ├─ Gates all green ✓
   ├─ Code matches spec ✓
   ├─ WebSocket + fallback to polling is good ✓
   └─ APPROVE

Day 1 (3:15pm):
└─ Feature deploys to staging

Day 2 (10am):
└─ QA tests on staging (manual smoke test)
└─ All good

Day 2 (12pm):
└─ Feature deploys to production (canary 5%)

Day 2 (1pm):
└─ Canary expanded to 25%
└─ Monitor dashboards for errors
└─ No issues

Day 2 (2pm):
└─ Full 100% deployment

Timeline: Code → Production = ~22 hours
(With old process: would be 5-7 days)
```

---

## Troubleshooting Common Issues

### Problema: Gates too strict (75% pass-through)

**Symptom:**
```
Builders frustrated: "3 out of 4 submissions get rejected"
```

**Root cause analysis:**
```
Review rejected submissions:
├─ 60% false positives (agent is too conservative)
├─ 40% legitimate issues
```

**Solution:**
```
├─ Tune agent thresholds (reduce strictness)
├─ Test tuning on historical data
├─ Measure: Did false positives decrease?
├─ Did real defects still get caught?
```

### Problema: Gates too lenient (CFR high at 8%)

**Symptom:**
```
Bugs escaping to production: 3-4 per week
```

**Root cause analysis:**
```
Bugs escaped:
├─ Auth issue (should be caught by Auth Verifier)
├─ SQL injection (should be caught by SAST)
├─ Race condition (should be caught by Concurrency Detector)
```

**Solution:**
```
├─ Re-enable strictness on those agents
├─ Add new agents for missed patterns
├─ Improve test coverage for those scenarios
```

### Problema: Human review bottleneck

**Symptom:**
```
Features waiting in Level 5: 3-4 days
Architects overwhelmed with reviews
```

**Solution:**
```
├─ Gates 1-4 should be >90% green
├─ If so, architect review should be 15-30 min
├─ If not, gates need tuning (too many escalations)
├─ Distribute review responsibility (not just architects)
└─ SLA: Level 5 must review within 4 hours
```

---

## Conclusión

Autonomous Quality Gates son el futuro del control de calidad con IA:

1. **Level 1-4:** Automated validation (instant feedback)
2. **Level 5:** Human judgment (lightweight, focused)
3. **Specialized Agents:** Capture domain-specific patterns
4. **Escalation:** Only when human insight is needed

**Resultado:**
- Defect escape rate: 40% → 1% (-97%)
- Deployment confidence: High
- Team morale: Significantly improved
- Code quality: Better than pre-IA era

---

**Comienza con Levels 1-2 esta semana. Agrega Levels 3-5 progresivamente.**
