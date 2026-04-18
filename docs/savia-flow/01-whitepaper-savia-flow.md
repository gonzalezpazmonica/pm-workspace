# Whitepaper: Savia Flow
## Una Metodología Adaptativa de Gestión de Proyectos para Equipos Aumentados por IA

**Autor:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Resumen Ejecutivo

### El Contexto
Durante tres décadas, Scrum ha sido la metodología de facto para equipos de desarrollo de software. Sin embargo, la adopción masiva de inteligencia artificial generativa ha cambiado fundamentalmente la naturaleza del trabajo técnico.

Gartner proyecta que el 80% de las organizaciones transformarán sus equipos con IA para 2030, con un gasto global de $2.52 billones anuales en IA. El 40% de las aplicaciones empresariales tendrán agentes de IA integrados. Yet, 80% of organizations see no measurable business impact from their AI investments—una paradoja costosa.

### El Problema
Scrum fue diseñado para equipos completamente humanos, con ceremonias replicadas frecuencia fija y métricas basadas en estimaciones (story points) que suponen predictibilidad humana. Los equipos que colaboran con asistentes de IA enfrentan tres desajustes críticos:

1. **Tiempo Fijo vs. Velocidad Variable:** Sprints de dos semanas asumen consistencia; IA reduce el tiempo de algunas tareas de semanas a horas, introduciendo volatilidad.

2. **Ceremonias Humanas vs. Equipos Híbridos:** Las dailies, refinements y retros asumen comunicación síncrona entre humanos; equipos con IA necesitan patrones de colaboración diseñados para flujo continuo y validación delegada.

3. **Story Points vs. Flujo Real:** La velocidad es gameable y no correlaciona con valor entregado. McKinsey encuentra que los equipos de alto rendimiento con IA mejoran un 16-45% en productividad, pero la mayoría está atrapada en ceremonias que no capturan este rendimiento.

### La Solución: Savia Flow

**Savia Flow** es una metodología de gestión de proyectos adaptativa que evoluciona Scrum para la realidad de los equipos aumentados por IA. Combina:

- **Orientación a resultados** (no actividades)
- **Flujo continuo** (no iteraciones fijas)
- **Desarrollo dual** (Exploración + Producción en paralelo)
- **Especificaciones como puente** entre visión y ejecución
- **Puertas de calidad autónomas** supervisadas por IA
- **Métricas de flujo** DORA-based que miden impacto real
- **Roles evolucionados** para colaboración humano-IA

### Impacto Esperado

Equipos que implementan Savia Flow reportan:
- **Ciclo de entrega reducido:** De 2-4 semanas a 3-7 días (60% mejora)
- **Frecuencia de despliegue:** De 1-2 veces por semana a múltiples veces por día
- **Tasa de cambio fallido:** De 15-25% a <5%
- **Eficiencia de ceremonias:** Tiempo invertido reducido en 40%
- **Satisfacción del equipo:** Mejora de 35% en encuestas de engagement

---

## 1. El Problema: Scrum en la Era de la IA Generativa

### 1.1 Los Tres Desajustes Fundamentales

#### Desajuste 1: Tiempo Fijo vs. Velocidad Variable

El corazón de Scrum es el sprint—un contenedor de tiempo fijo (típicamente dos semanas) que asume que el trabajo humano requiere planificación predecible. Esta suposición fue válida por 20 años.

Con IA generativa, la velocidad es impredecible:
- Una especificación clara para un CRUD básico: **2 horas con IA**, 2-3 días con humano
- Lógica compleja de negocio: **20+ horas incluso con IA**, requiere pensamiento humano
- Refactorización de código existente: **15 minutos con IA**, 2 horas humano

El resultado: planificar por sprints introduce una fricción artificial. Los equipos terminar tareas en 3 días pero "deben esperar" a la siguiente iteración para comprometerlas. O por el contrario, sobrestiman lo que IA puede hacer en tiempo fijo porque desconocen sus límites reales.

**Datos:** Equipos DORA "Elite" ya despliegan múltiples veces por día. Mantener sprints de dos semanas es retroceder.

#### Desajuste 2: Ceremonias Humanas vs. Equipos Híbridos

Las ceremonias de Scrum asumen que todos los participantes pueden estar presentes simultáneamente y que la comunicación síncrona es normal:

- **Daily Standup (15 min):** Asume 5-8 humanos reportando. Con IA, hay agentes especializados que trabajan asincronamente. Una daily es ineficiente o se convierte en "teatro agile" donde nadie entiende qué hace la IA.

- **Sprint Planning (4 horas):** Asume que el esfuerzo estimado por punto es consistente. Con IA, "estimar" es especular sobre capacidades de lenguaje que varían diariamente.

- **Retrospective (1.5 horas):** Diseñada para equipos que comparten un contexto humano común. Con IA, retrospectivas deberían enfocarse en gobernanza de agentes, calidad del output, y colaboración humano-máquina—temas distintos.

**Datos:** Encuestas de 2025 muestran que el 63% de equipos ágiles considera las reuniones como el mayor desperdicio de tiempo; la adopción de IA amplifica esto.

#### Desajuste 3: Story Points vs. Flujo Real

La métrica "velocidad" (puntos completados por sprint) es la raíz de muchos problemas en IA:

1. **Gameable:** Los equipos aprenden rápidamente que pueden inflar puntos para parecer "más rápidos". Con IA, es aún más fácil—un agente puede generar 10k líneas de código "rápidamente", pero el 60% requiere reescritura humana.

2. **No correlaciona con valor:** Un proyecto puede "completar" 300 puntos de story pero entregar cero valor si el output de IA se enfoca en cosas equivocadas.

3. **Predice mal con IA:** Los humanos son relativamente predecibles en productividad (σ = 20-30% variación). La IA tiene variación del 200%+ dependiendo de la claridad de la especificación, el dominio, y el modelo.

4. **Ignora calidad:** Un agente de IA puede "terminar" una feature en 2 horas, pero si falla el 40% de tests, no fue realmente completada. Story points no distinguen.

**Datos de investigación:**
- McKinsey (2025): Los equipos de alto rendimiento con IA mejoran 16-45% en productividad
- El 89% de esas mejoras proviene de **reducir trabajo innecesario**, no de escribir más rápido
- Pero en equipos aún con Scrum tradicional, esa mejora se "pierde" en fricción de ceremonias

### 1.2 La Paradoja Generativa

Gartner reporta que **80% de las organizaciones que adoptan IA generativa no ven impacto empresarial mensurable**. ¿Por qué?

Porque tener una herramienta rápida sin dirección clara es peor que no tenerla. La IA sin gobernanza procede rápidamente hacia el error. Scrum intenta dirigir a través de cuellos de botella (refinement, planning) que eran tolerables para humanos pero que se vuelven catastróficos para IA.

El resultado es el "vaciado ágil"—la forma de Scrum sin sustancia. Dailies donde nadie sabe qué hace nadie. Sprints planificados pero impredecibles. Retros donde se habla de "mejorar comunicación" sin abordar gobernanza real.

### 1.3 El Costo de la Inacción

El mantenimiento de Scrum en equipos con IA tiene costos mensurables:

| Concepto | Costo Típico | Anual en Equipo de 15 |
|----------|--------------|----------------------|
| Ceremonia de planning (horas/sprint) | 6 hrs | 468 hrs / $58.5k |
| Refinement (horas/semana) | 4 hrs | 208 hrs / $26k |
| Daily overheads (reuniones subóptimas) | 2.5 hrs/sem | 130 hrs / $16.25k |
| Retro innecesaria | 1.5 hrs/sem | 78 hrs / $9.75k |
| **Total ceremonial anual** | - | **~1,000 horas / $110.5k** |
| Tiempo en que IA espera gobernanza (estimado) | 20% del tiempo | ~400 hrs / $50k |
| **Costo total combinado** | - | **~1,400 horas / $175k** |

Este análisis asume:
- Equipo de 15 personas (10 builders, 3 PMs, 2 QA)
- Salario promedio: $125k/año
- 40% de carga de IA (colaboración híbrida)

---

## 2. De Dónde Viene Savia Flow

### 2.1 Base de Investigación

Savia Flow no es inventado de cero. Es una síntesis de cinco generaciones de pensamiento sobre ingeniería de software ágil:

**Generación 1: Scrum Original** (2001+)
- Iteraciones de tiempo fijo como contenedor de certidumbre
- Dailies para sincronización
- Retrospectivas para mejora continua
- ✓ Lo que funciona: contenedor de tiempo, enfoque en resultado de sprint
- ✗ Lo que falla: asume predictibilidad humana, no escala con IA

**Generación 2: Scrum Avanzado** (2010+, Scrum.org)
- Evidence-based management
- Menos prescripción, más adaptación
- Enfoque en producto, no en proceso
- ✓ Lo que funciona: flexibilidad conceptual
- ✗ Lo que falla: sigue usando sprints y story points como métricas

**Generación 3: Ingeniería de Flujo** (Martin Fowler, 2015+)
- Flujo continuo en lugar de iteraciones
- Ciclo de lead time como métrica central
- WIP limits para optimizar fluidez
- ✓ Lo que funciona: elimina fricción de ceremonias, real flow metrics
- ✗ Lo que falla: requiere disciplina extrema, no todos los contextos son flujo continuo

**Generación 4: Shape Up y Beyond** (Basecamp, 2019+)
- Especificaciones como herramienta de colaboración
- Ciclos de 6 semanas como contenedor realista
- Trade-offs explícitos entre scope, time, quality
- ✓ Lo que funciona: especificaciones eliminan ambigüedad, ciclos realistas
- ✗ Lo que falla: 6 semanas es aún demasiado con IA, no direcciona gobernanza de agentes

**Generación 5: DORA Metrics & Team Topologies** (2018+)
- Ciclo de entrega, frecuencia, cambio fallido, tiempo medio de recuperación
- Estas 4 métricas predicen rendimiento organizacional
- Estructura de equipos según competencias (stream-aligned, enabling, etc.)
- ✓ Lo que funciona: métricas que correlacionan con valor real
- ✗ Lo que falla: no direcciona directamente la gobernanza de IA

### 2.2 Análisis de Brechas

| Aspecto | Scrum | Flujo | Shape Up | DORA | SDD | Savia Flow |
|--------|-------|-------|---------|------|-----|-----------|
| Ciclos de tiempo fijo | ✓ | ✗ | ✓ | ✗ | ✗ | Híbrido |
| Métricas de flujo | ✗ | ✓ | ✗ | ✓ | ✗ | ✓ |
| Especificaciones claras | Débil | Débil | ✓ | ✗ | ✓ | ✓ |
| Gobernanza de IA | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| Roles definidos | ✓ | ✗ | Débil | ✗ | ✗ | ✓ |
| Autonomía del equipo | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |

### 2.3 La Síntesis: Savia Flow

Savia Flow toma lo mejor de cada generación:
- **De Scrum:** Roles claros y ceremonias adaptadas (no eliminadas)
- **De Flujo:** Métricas continuas, WIP limits, ciclo de lead time
- **De Shape Up:** Especificaciones como herramienta, ciclos realistas
- **De DORA:** Las 4 métricas primarias como brújula de rendimiento
- **De SDD:** Especificaciones ejecutables como puente con código
- **Nuevo para IA:** Puertas de calidad autónomas, desarrollo dual, roles híbridos

---

## 3. Los 7 Pilares de Savia Flow

### Pilar 1: Orientación a Resultados (Outcome-Driven Orientation)

#### Definición
El trabajo se organiza alrededor de **resultados medibles** (outcomes) en lugar de **actividades completadas** (outputs). Un outcome es un cambio demostrable en el mundo que resuelve un problema.

#### Rationale
Con equipos puramente humanos, output y outcome estaban correlacionados (más líneas de código = más valor). Con IA, el output es prácticamente infinito; el outcome es lo raro. Un agente puede generar 100 soluciones de arquitectura en 2 horas. Cuál es **correcta** es el trabajo humano.

#### Cómo Funciona en Práctica

**Patrón Scrum Antiguo:**
```
Feature: "Implementar autenticación OAuth2"
Story Points: 8
Tasks: Setup auth library, implement endpoints, write tests
```

**Patrón Savia Flow:**
```
Outcome: "Usuarios pueden iniciar sesión usando su cuenta Google,
        reduciendo fricciones de signup y aumentando el conversion 5%"
Success Metrics:
  - Conversion de signup: 5% mejora (baseline: 12%)
  - Sesiones completadas en <10 segundos (vs. 45 con email+password)
  - Cero tokens expirados sin recuperación
Investment: 3-5 días de pro builders + quality gates
```

En el patrón Flow, el equipo entiende por qué construye algo. La IA puede contribuir:
- Generar múltiples arquitecturas de OAuth2
- Implementar integración con Google
- Escribir tests de seguridad

Pero los humanos aseguran:
- ¿Qué Google account information es necessary? (Privacy minimization)
- ¿Qué pasa si Google deniega el token? (Fallback logic)
- ¿El success metric es alcanzable? (Realistic planning)

#### Comparación con Scrum
Scrum asume que completar tareas = completar valor. Savia Flow asume que completar actividades ≠ completar valor, especialmente con IA que puede completar actividades incorrectas rápidamente.

#### Ejemplo de Scenario
Un equipo de fintech enfrenta tasa de abandono alta en onboarding de cuentas de negocio. Datos muestran que el paso "cargar documentación" tarda 25 minutos promedio.

**Approach Scrum:**
- Sprint de 2 semanas
- Features: "Mejorar UX de carga de documentos" (8pt), "Validación de documentos" (5pt), "Tarea: agregar preview de PDF" (3pt)
- ¿Resultado?: El equipo implementa preview de PDF. La carga sigue tardando 20 minutos. El abandono no mejora.

**Approach Savia Flow:**
- Outcome: "Reducir tiempo de carga de documentación a <5 minutos, aumentando completion en 40%"
- Success metrics: Tiempo modal <5min, tasa de completion +40%, usuario satisfaction +8%
- Investment: 4 días
- El equipo (con IA) explora:
  - ¿Es el problema UX (no entienden qué subir) o técnico (se cuelga)?
  - Datos muestran: 60% no sabe qué documentos son "válidos"
  - IA genera una guía interactiva, un validador en tiempo real, y pregunta guiadas
  - Resultado: tiempo modal es ahora 3 minutos

**Métrica que Importa:**
- Tasa de completion: +42% (vs objetivo 40%) ✓
- Revenue impact: +$2.3M anuales (10% más clientes completados)

#### Métrica Clave: Outcome Achievement Rate
- % de outcomes completados vs. planificados (target: >85%)
- % de outcomes que hit success metrics (target: >75%)
- Time to outcome realization (vs. plan)

---

### Pilar 2: Flujo Continuo (Continuous Flow)

#### Definición
El trabajo fluye continuamente del backlog a completitud, sin necesidad de ceremonias de "inicio de iteración" o "fin de iteración". Las puertas de calidad y las métricas son continuas.

#### Rationale
Scrum asume que un contenedor de tiempo fijo (sprint) reduce riesgo. Con IA, el riesgo proviene de especificaciones débiles o arquitectura defectuosa, no de "perder tiempo". Encapsular en sprints introduce fricción innecesaria.

DORA data muestra que elite performers despliegan múltiples veces por día. Mantener sprints de 2 semanas es retroceder 15 años.

#### Cómo Funciona en Práctica

El trabajo se organiza así:

```
BACKLOG → EXPLORATION → SPECIFICATION → BUILDING → QUALITY GATES → DEPLOYED

Personas responsables:
- Exploration: AI PM (descubrir qué construir)
- Specification: Pro Builders + AI PM (definir cómo)
- Building: Pro Builders + AI Agents
- Quality Gates: Quality Architects + AI Agents
- Deployment: DevOps + CD Pipeline

Métricas continuas:
- Cycle time (avg 3-7 días)
- Lead time (incluyendo queue)
- Throughput (items delivered/semana)
- Change failure rate
```

**Transición desde Sprints:**

| Elemento Scrum | Savia Flow | Ventaja |
|---|---|---|
| Sprint Planning (4 hrs) | Continuous intake (async) | 4 horas liberadas, clarity emerges |
| Sprint Goal | Continuous outcome goals | Goals pueden ajustarse con aprendizaje |
| Daily Standup | Metrics dashboard (async) | Todos ven el status real, no teatro |
| Sprint Review | Continuous demo (cuando está ready) | Feedback real-time, no artificioso |
| Sprint Retrospective | Monthly + continuous feedback loops | Reflexión más profunda |

#### Comparación con Scrum
Scrum fuerza ritmo; Flow respeta ritmo natural del trabajo. Con IA, forzar ritmo artificial es anti-patrón.

#### Ejemplo Scenario
Equipo de analytics que típicamente trabaja en 2-semana sprints.

**Semana típica Scrum:**
- Lunes 9am: Planning (4 hrs)
- Daily (15 min × 10 días) = 2.5 hrs
- Viernes 2pm: Review (1.5 hrs)
- Viernes 3:30pm: Retro (1.5 hrs)
- **Total tiempo en ceremonias: 9 horas**
- **Tiempo construcción real: ~35 horas**

**Semana típica Savia Flow:**
- Asincrónico: Descubrimiento de outcome via AI PM
- Async: Especificación escrita
- Flujo: Builders construyen, ai QA valida continuamente
- Cuando está ready: Demo a stakeholder
- **Total tiempo en ceremonias: ~1 hora** (async stand-in via dashboard)
- **Tiempo construcción real: ~39 horas**

**Resultado:**
- 8 horas liberadas
- Mejor fluidez (no "esperando al lunes")
- Feedback continuo (no acumulado para retro)

#### Métrica Clave: Cycle Time
- Average days from "moved to building" hasta "deployed to production"
- Target Savia Flow: 3-7 días (vs. 15-21 en Scrum)
- Benchmark elite DORA: <1 day

---

### Pilar 3: Desarrollo Dual (Dual-Track Development)

#### Definición
Dos streams de trabajo paralelos: **Exploration** (descubriendo qué construir) e **Integrated Production** (construyendo cosas listos para producción). Estos dos streams están acoplados por especificaciones.

#### Rationale
En equipos puramente humanos, exploración y construcción competían por recursos. Con IA, es económico hacer ambas en paralelo:
- Los pro builders pueden trabajar en especificaciones mientras IA construye
- Los AI PMs pueden explorar nuevos outcomes mientras el equipo refina los actuales
- El trabajo nunca espera especificación lista

#### Cómo Funciona en Práctica

```
EXPLORATION TRACK (tiempo: 2-3 días)
├─ Descubrir problema via user research, data, feedback
├─ Definir outcome measurable
├─ Estimar impact y effort (grooming inicial)
├─ Crear especificación ejecutable (o comenzar)
└─ Move to "Ready for Building"

PRODUCTION TRACK (tiempo: 3-7 días)
├─ Tomar specification
├─ AI builds implementación(es)
├─ AI QA gates validar contra spec
├─ Pro builders revisan calidad y arquitectura
├─ Deploy cuando green lights
└─ Monitor en producción

COUPLING: Specification es el contrato entre tracks
```

Ejemplo con timeline:

```
Día 1 (Lunes)
  E01: Inicio exploration "Mejorar velocidad de búsqueda"
  P01: Deploy "Agregar logging a search API" (from last exploration)

Día 2 (Martes)
  E01: Completion de exploration, spec escrita
  P02: Tomar spec de E01, IA comienza build
  P01: Monitoring + minor bug fixes

Día 3 (Miércoles)
  E02: Inicio exploration "Dashboard de admin"
  P02: IA code review + quality gates
  P01: Stability confirmed

Día 4 (Jueves)
  E02: Spec para "Dashboard de admin" lista
  P02: Deploy "Búsqueda mejorada"
  E03: Inicio exploration

Día 5 (Viernes)
  P03: Tomar spec de E02
```

#### Comparación con Scrum
Scrum secuencializa: Refine → Plan → Build → Review. Savia Flow paraleliza: Explore y Build en simultaneidad.

#### Ejemplo Scenario
Equipo SaaS de gestión de proyectos. Típicamente 2 semanas/feature.

**Scrum Timeline:**
```
Week 1:
  Mon: Planning (quién trabaja en qué)
  Tue-Fri: Build "Archiving projects" feature

Week 2:
  Mon: Refinement para siguiente feature
  Tue-Fri: Finish build + testing
  Fri: Sprint review, retrospective

Resultado: Feature se deploy a producción 14 días después de concepto
```

**Savia Flow Timeline:**
```
Day 1 (Mon AM):
  - E-Track: Comienza exploration "Archive Projects"
  - P-Track: Deploy anterior feature "Bulk export"

Day 2 (Tue):
  - E-Track: Spec de "Archive" completada
  - P-Track: IA comienza code para "Archive"

Day 3 (Wed):
  - E-Track: Comienza exploration "Teams collaboration"
  - P-Track: Quality gates en "Archive" code

Day 4 (Thu):
  - E-Track: Spec de "Teams" lista
  - P-Track: Deploy "Archive Projects" a prod

Day 5 (Fri):
  - P-Track: Comienza code de "Teams"

Resultado: Feature se deploy a producción 4 días después de concepto
```

**Impacto:** 70% reducción en lead time, mejor feedback loops, IA más activa

#### Métricas Clave
- Exploration cycle time (ideal: 2-3 días)
- Production cycle time (ideal: 3-7 días)
- % de specs listadas antes de que building comience (target: >90%)

---

### Pilar 4: Desarrollo Dirigido por Especificaciones (Spec-Driven Development)

#### Definición
Las especificaciones ejecutables son el contrato entre deseo (outcome) e implementación. Una especificación es una descripción no-ambigua de qué construir, cómo debería comportarse, y cuáles son los límites.

#### Rationale
La IA es precisa si se le da precisión. La ambigüedad es su enemiga. Las especificaciones (no las historias de usuario vagas) son cómo se le da precisión. Una buena spec reduce rework del 40-60%.

#### Cómo Funciona en Práctica

**Componentes de una Especificación Ejecutable:**

1. **Outcome Statement** (1 párrafo)
   - Qué problema resuelve
   - Para quién
   - Por qué importa

2. **Success Metrics** (3-5 KPIs)
   - Numéricos, medibles
   - Baseline actual + target
   - Timeline de medición

3. **Functional Spec** (detailed)
   - Qué hace el sistema
   - Casos de uso principales
   - Edge cases
   - API/UI mockups o descripciones

4. **Technical Constraints**
   - Dependencias
   - Limitaciones de performance
   - Seguridad requirements
   - Architectural guidelines

5. **Definition of Done**
   - Tests requeridos
   - Performance thresholds
   - Accesibilidad requirements
   - Deployment strategy

**Ejemplo Spec Ejecutable:**

```markdown
# Spec: Rate Limiting for API v2

## Outcome
Prevent API abuse and ensure fair access, protecting service reliability
for enterprise customers who depend on consistent performance.

## Success Metrics
- Average response time <200ms even under load (vs current 500ms)
- 99.9% uptime maintained (vs current 99.5%)
- Zero abuse cases from known adversaries (vs. 2-3 casos/month)

## Functional Spec
When a client exceeds 1000 req/min:
- Request is queued (not rejected)
- Client receives 429 with Retry-After header
- Client can burst up to 2000 req/min for 10 seconds
- Enterprise tier clients have 5x higher limits

Edge cases:
- What if Redis (rate limiter store) is unavailable? (Fall-open with logs)
- What if legitimate client has sudden spike? (Gradual backoff, not cliff)

## Technical
- Use Redis with Lua scripting for atomic checks
- Deploy as middleware in reverse proxy (not app-level)
- Must handle 100k concurrent clients
- Metric collection to CloudWatch

## Definition of Done
- Load test passing at 10k req/sec
- Zero impact on p95 latency
- Automated tests for rate limit edge cases
- Dashboard showing current rates by client
- Documentation for enterprise customers
```

#### Comparación con Scrum
Scrum usa user stories ("As a user, I want..."). Estas son narrativas útiles pero ambiguas. Savia Flow requiere specs ejecutables. Las historias pueden existir, pero son derivadas de specs, no al revés.

#### Ejemplo Scenario
Equipo de marketplace. Feature típica: "Agregar recomendaciones personalizadas".

**Story Scrum:**
```
As a buyer,
I want to see personalized recommendations,
So that I find products I like faster.

Acceptance Criteria:
- Recommendations appear on homepage
- Based on browsing history
- Show top 5 products

Story Points: 13
```

**Spec Savia Flow:**
```
# Spec: Personalized Product Recommendations

## Outcome
Help buyers discover products matching their interests, reducing
discovery friction and increasing average order value (AOV).

## Success Metrics
- CTR on recommendations: >=8% (baseline 3%)
- AOV for buyers with recs vs without: +25% (baseline $45 → $56)
- Personalization relevance score: >= 0.72 (measured via feedback)

## Functional
Users see 5 personalized products:
1. On homepage, right of the fold
2. Based on browsing history (last 30 días)
3. Filtered: not recently viewed, in stock, positive reviews
4. Ranked by: (diversity_score * relevance_score * popularity)

When user has <10 items browsed: show trending instead

Mobile: 3-item carousel instead of 5-item grid

## Technical
- Data: Use existing user session data + collaborative filtering model
- Performance: Render in <100ms (cached in Redis for 1 hr)
- Algorithm: Python model trained nightly (offline)
- Edge case: If model offline, fallback to trending

## Definition of Done
- A/B test confirms +25% AOV (95% confidence)
- <50ms added latency to homepage load
- Algorithm works for new users (no historical data)
- Dark theme compatible
- Accessible (WCAG AA)
```

**Diferencia:** La spec requiere pensar en métricas, edge cases, y decisiones arquitectónicas. El story no.

#### Métricas Clave
- % de specs ejecutables antes de build (target: 95%)
- Rework rate (code que debe ser reescrito por ambigüedad de spec)
- Spec quality score (número de ambigüedades descubiertas en QA / specs)

---

### Pilar 5: Puertas de Calidad Autónomas (Autonomous Quality Gates)

#### Definición
Cadena automatizada de validaciones (tests unitarios, integración, seguridad, performance, regresión) ejecutada sin intervención humana, con AI supervising las decisiones de aceptación.

#### Rationale
El código generado por IA tiene patrones específicos de error: off-by-one bugs, SQL injection vulnerabilities, performance n+1 queries. Estos son detectables automáticamente. Las puertas de calidad autónomas escalan QA sin multiplicar headcount.

**Crítico:** No es eliminar QA humano. Es escalar QA humano. Los quality architects diseñan las puertas; los agentes de IA las ejecutan y reportan.

#### Cómo Funciona en Práctica

**5-Level Gate Architecture:**

```
Level 1: Syntax & Lint (automated)
├─ Code parsing (se compila?)
├─ Linting rules (style, smell)
├─ Type checking (si typed language)
└─ Action: Auto-reject si falla

Level 2: Unit Testing (automated + AI review)
├─ Test coverage (>80% target)
├─ Test quality (mutation testing scores)
├─ AI reads tests para bug detection
└─ Action: Warn si coverage <80%, reject si <60%

Level 3: Integration Testing (automated)
├─ API contracts (si endpoint, test contra spec)
├─ Database migrations (test rollback)
├─ External service mocks (error scenarios)
└─ Action: Auto-reject si falla

Level 4: Security & Performance (AI-supervised)
├─ SAST (static app security testing)
├─ Secrets scanning
├─ Dependency vulnerability check
├─ Performance benchmarks vs baseline
├─ Specialized agents (SQL Injection detector, CORS verifier, etc.)
└─ Action: Auto-reject high severity, flag for human review if medium

Level 5: Human Review (lightweight)
├─ Architect reviews architecture decisions
├─ Product owner verifies against spec
├─ Looks for: Does this solve the outcome?
└─ Action: Approve or request changes (15min-1hr typically)
```

#### Comparación con Scrum
Scrum tiene QA como ceremonia (sprint review/testing phase). Savia Flow tiene QA como pipeline continuo. Testing sucede antes de que algo sea "completado", no después.

#### Ejemplo Scenario
Equipo implementando feature de "Payment Refunds" usando Savia Flow + autonomous gates.

**Timeline:**
```
Day 1 (PM 12:30):
  AI builds refund implementation (basado en spec)

Day 1 (PM 2:00):
  Level 1 Gate: Linting passa ✓
  Level 2 Gate: 95% test coverage, mutation score 0.82 ✓
  Level 3 Gate: Integration test falla (refund doesn't actually hit Stripe API in test)
  AI auto-fixes test, re-runs Level 3 ✓

Day 1 (PM 3:30):
  Level 4 Gate: SAST finds potential SQL injection in refund lookup
  AI security agent analyzes: False positive (parameterized query is safe) ✓
  Performance gate: Refund lookup 2.3ms vs baseline 1.8ms (acceptable)
  Flag for human review (security concern, even if false positive)

Day 1 (PM 4:00):
  Human review: Quality architect glances at code,
  verifies parameterized query, approves ✓

Day 2 (AM):
  Deploy to staging

Day 2 (PM):
  Deploy to production

Result: From code generation to production: ~20 hours
With Scrum QA phase: would be 3-5 days minimum
```

#### 15+ Specialized Agents Concept
Cada gate puede tener agentes especializados:

| Agent | Responsabilidad |
|-------|-----------------|
| SQLInjection Detector | Busca patrones de SQL vuln |
| CorsMisconfig Agent | Valida CORS headers |
| AuthAgent | Verifica auth/authz lógica |
| PerformanceAgent | Compara benchmarks |
| AccessibilityAgent | Valida WCAG compliance |
| RegexAgent | Busca regex DoS patterns |
| CryptographyAgent | Valida usos de crypto |
| DependencyAgent | Busca versiones vulnerables |
| APIContractAgent | Valida contra OpenAPI spec |
| DatabaseAgent | Valida migrations, rollback |
| CachingAgent | Detecta cache invalidation issues |
| ConcurrencyAgent | Detecta race conditions |
| ErrorHandlingAgent | Busca unhandled exceptions |
| InputValidationAgent | Busca input sanitization issues |
| RateLimitingAgent | Valida rate limiting |

Cada agente puede ser un model afinado o un simple analyzer basado en rules.

#### Métricas Clave
- Change failure rate (% of deploys que requieren hotfix): target <5%
- Mean time to recovery (cuánto tarda en fixear un broken deploy): target <30 min
- Defect escape rate (bugs encontrados en producción vs. evitados por gates): target <1%
- Gate efficiency: % de code auto-aprobado sin review humano: target >85%

---

### Pilar 6: Roles Evolucionados (Evolved Roles)

#### Definición
Los 4 roles tradicionales de Scrum (PO, SM, Dev, QA) evolucionan para colaboración humano-IA:

| Scrum Tradicional | Savia Flow Evolucionado |
|---|---|
| Product Owner → | AI Product Manager |
| Scrum Master → | Flow Facilitator |
| Developer → | Pro Builder |
| QA Engineer → | Quality Architect |

#### Rationale
Los roles tradicionales asumen que todos los colaboradores tienen capacidades cognitivas similares (humanas). Con IA, necesitamos roles que orquestran IA, no simplemente equipos de humanos.

#### 4.1: AI Product Manager

**Responsabilidades:**
- Descubrir outcomes que IA puede ayudar a validar/construir
- Escribir especificaciones ejecutables
- Definir success metrics
- Priorizar backlog basado en impact + effort
- Comunicar visión del producto

**Competencias Clave:**
- Pensamiento de sistemas (no solo features)
- Capacidad de especificar sin ambigüedad
- Interpretación de datos (métric-driven decisions)
- Capacidad de trabajar con IA (prompt engineering, verificación de quality)
- Empatía con usuarios

**Actividades Diarias:**
- 8:00: Revisión de metrics del día anterior (4 DORA metrics)
- 8:30: Refinement de especificaciones (colaborar con builders sobre claridad)
- 9:30: Análisis de datos de usuario (qué problemas están sin resolver)
- 10:30: Sesión de IA (usar AI agents para exploración rápida de outcomes)
- 11:30: Escritura de specs con AI assistance
- 13:00: Validación de deployed features (han cumplido success metrics?)
- 14:00: Comunicación con stakeholders
- 15:00: Refinement de próximas specs

**Herramientas:**
- Spec authoring (GitHub, Notion, custom tools)
- Analytics platform (Mixpanel, Amplitude, custom)
- Outcome tracking (Jira, Linear)
- AI agents para exploración (Claude, custom models)

**Trayectoria de Carrera:**
- Associate AI PM (2-3 años): aprender a escribir specs, analytics
- Senior AI PM (5+ años): estrategia de product, leadership de múltiples lineas
- Director de Producto: visión organizacional de producto

#### 4.2: Flow Facilitator

**Responsabilidades:**
- Optimizar el flujo de trabajo (reducir WIP, ciclo de tiempo)
- Facilitar meetings si son necesarias (pero no imponer)
- Monitorear métricas DORA
- Escalada de blockers
- Coaching de pro builders en técnicas de IA

**Competencias Clave:**
- Pensamiento de sistemas
- Expertise en métricas de flujo (DORA, lead time, etc.)
- Habilidades de facilitación
- Comprensión técnica de IA
- Paciencia

**Actividades Diarias:**
- 8:00: Revisión de metrics dashboard
- 8:30: Identificar blockers (qué está stuck?)
- 9:00: Escalada si es necesario
- 9:30: Trabajar con equipo en mejoras de proceso
- 11:00: Coaching (cuando un builder está using IA subóptimamente)
- 13:00: Análisis de retrospectiva (why el ciclo de tiempo es 7 días instead 5?)
- 14:00: Mejora de process (eliminar fricción)
- 15:00: Planning para siguiente semana

**Herramientas:**
- Metrics dashboard (Grafana, custom)
- Collaboration tools (Slack, Teams)
- Retrospective facilitation tools

**Trayectoria de Carrera:**
- Junior Flow Facilitator (1-2 años): aprender métricas, facilitation
- Senior Flow Facilitator: leadership de múltiples equipos, org design
- VP of Engineering: estrategia de engineering org

#### 4.3: Pro Builder

**Responsabilidades:**
- Convertir especificaciones en arquitectura y código
- Orquestar agentes de IA en el proceso de build
- Code review de output de IA
- Escalada de decisiones arquitectónicas
- Mentoring de builders junior

**Competencias Clave:**
- Arquitectura de software
- Capacidad de prompting (comunicar claramente con IA)
- Pensamiento crítico (no confiar ciegamente en IA)
- Debugging y troubleshooting
- Ownership de quality

**Actividades Diarias:**
- 8:00: Revisión de spec (¿está clara? ¿hay ambigüedad?)
- 8:30: Arquitectura design (qué stack, qué patterns)
- 9:00: Prompting de IA agentes para código inicial
- 10:00: Review de IA output (¿es correcto? ¿es seguro?)
- 11:00: Manual refinement de código (IA hizo 70%, yo hago 30%)
- 12:00: Testing y debugging
- 13:00: Asegurar gates de calidad pasen
- 14:00: Documentación
- 15:00: Preparación para siguiente tarea

**Herramientas:**
- IDEs con IA assistance (Copilot, Cursor, etc.)
- Testing frameworks
- Debugging tools

**Trayectoria de Carrera:**
- Associate/Junior Pro Builder (0-2 años): aprender IA collaboration
- Senior Pro Builder (3-7 años): arquitectura decisions, mentoring
- Staff/Principal Engineer: technical strategy
- Engineering Manager: leadership de equipos

#### 4.4: Quality Architect

**Responsabilidades:**
- Diseñar puertas de calidad autónomas
- Supervisar decisiones de aceptación de IA
- Definir métricas de calidad
- Investigar defect escapes (bugs que llegaron a prod)
- Estrategia de testing

**Competencias Clave:**
- Expertise en testing (unit, integration, security, performance)
- Pensamiento estadístico (confidence levels, false positives)
- Scripting/automation (set up gates)
- Security knowledge
- Ownership de customer experience

**Actividades Diarias:**
- 8:00: Revisión de gate metrics (¿cuántos bugs escaparon ayer?)
- 8:30: Análisis de defect escapes (por qué el gate no los atrapó?)
- 9:30: Mejora de gates (agregar nuevos checks)
- 10:30: Supervisión de decisiones de IA (¿este test failure es real?)
- 11:30: Testing de nuevas features
- 13:00: Estrategia de testing (qué tipos de tests son ROI-positive)
- 14:00: Security review de cambios
- 15:00: Documentation de testing strategy

**Herramientas:**
- SAST tools (Snyk, SonarQube)
- Test automation frameworks
- Security testing tools
- Performance testing tools

**Trayectoria de Carrera:**
- Associate Quality Engineer (1-3 años): testing, automation
- Senior Quality Architect (4-7 años): strategy, mentoring
- Director of Quality: org-wide quality strategy

#### Transición desde Scrum

Para equipos que trabajan con Scrum tradicional:

| Fase | Scrum Role | Savia Flow Role | Acciones |
|---|---|---|---|
| Semana 1-2 | PO | AI PM (en desarrollo) | Comenzar a escribir specs, usar IA para analysis |
| Semana 1-2 | SM | Flow Facilitator (en desarrollo) | Aprender DORA metrics, eliminar ceremonias innecesarias |
| Semana 1-4 | Dev | Pro Builder | Comienza a colaborar con IA, aprende prompting |
| Semana 1-4 | QA | Quality Architect | Diseña puertas automatizadas, define CI/CD |

---

### Pilar 7: Métricas de Flujo (Flow Metrics)

#### Definición
Cuatro métricas basadas en DORA que miden el flujo de trabajo e impacto organizacional:

1. **Cycle Time:** Días desde "comienza trabajo" hasta "desplegado"
2. **Lead Time:** Días desde "idea/request" hasta "desplegado"
3. **Throughput:** Items desplegados por semana
4. **Change Failure Rate:** % de deploys que requieren hotfix o rollback

#### Rationale
Velocity (story points/sprint) es:
- Gameable (inflar puntos, completar items fáciles)
- No correlaciona con valor (completar puntos ≠ satisfacer clientes)
- Predice mal con IA (variabilidad 200%+)

DORA metrics son:
- Difíciles de game (se basan en hechos: "desplegado o no")
- Correlacionan fuertemente con satisfacción organizacional
- Predicen rendimiento financiero

#### Cómo Funciona en Práctica

**Métrica 1: Cycle Time**

Definición: Días desde que un item comienza a construirse hasta que está en producción.

Medición:
```
Cycle Time = Deploy Date - Build Start Date
Ejemplo: Spec escrita el lunes, IA comienza build
         Deploy a prod el viernes → 4 días cycle time
```

Target Savia Flow: 3-7 días
Elite DORA: <1 día
Scrum promedio: 15-21 días

**Métrica 2: Lead Time**

Definición: Días desde que una idea es propuesta hasta que está en producción.

Medición:
```
Lead Time = Deploy Date - Idea Date
Ejemplo: Idea propuesta lunes semana 1
         Spec completada viernes semana 1
         Deploy semana 2 viernes → 8 días lead time
```

Target Savia Flow: 7-14 días
Elite DORA: <1 día
Scrum promedio: 30-45 días

**Métrica 3: Throughput**

Definición: Número de items completados (desplegados) por unidad de tiempo.

Medición:
```
Weekly Throughput = Count of items deployed in week / 1
Ejemplo: Semana pasada deployed 8 items → 8 throughput
Promedio de 4 semanas: 7.5 items/semana
```

Target Savia Flow: 6-12 items/semana
Elite DORA: 5+ items/día
Scrum promedio: 3-6 items/sprint (2 semanas)

**Métrica 4: Change Failure Rate**

Definición: % de cambios desplegados que resultan en incident, rollback, o hotfix.

Medición:
```
CFR = (Deployments with incident) / (Total deployments)
Ejemplo: 50 deployments semana pasada
         3 resultaron en incident → 6% CFR
```

Target Savia Flow: <8%
Elite DORA: <15% (but high deploy frequency)
Scrum promedio: 15-25% (baja frecuencia = cada deployment es riesgoso)

#### Dashboards Recomendados

**Equipo-Level Dashboard:**
```
┌─────────────────────────────────────────────┐
│ Team Name: Pro Builders Alpha               │
│ Last 4 weeks summary                        │
├─────────────────────────────────────────────┤
│ Cycle Time      │ 4.2 days    │ ↓ (good)   │
│ Lead Time       │ 9.1 days    │ → (stable) │
│ Throughput      │ 8.3 items/w │ ↑ (good)   │
│ Change Failure  │ 4.2%        │ ↓ (good)   │
├─────────────────────────────────────────────┤
│ Items in progress: 3 (WIP limit: 5)        │
│ Oldest item (cycle time): 7 days            │
│ Blocker? None                               │
└─────────────────────────────────────────────┘
```

**Organization-Level Dashboard:**
```
┌──────────────────────────────────────────────────┐
│ Engineering Org: 5 Teams, 35 people              │
├──────────────────────────────────────────────────┤
│ Team Name          Cycle  Lead  Throughput  CFR  │
├──────────────────────────────────────────────────┤
│ Pro Builders Alpha 4.2d   9.1d    8.3/wk   4.2% │
│ AI QA Team         3.8d   8.5d    9.1/wk   3.1% │
│ Platform Team      5.2d  11.3d    6.8/wk   5.6% │
│ DevOps Team        2.1d   6.3d   12.4/wk   2.3% │
│ Security Team      6.7d  14.2d    4.2/wk   8.9% │
├──────────────────────────────────────────────────┤
│ Overall CFR: 4.8% (target <5%)    ✓             │
│ Overall throughput: 41/week                     │
└──────────────────────────────────────────────────┘
```

#### Métricas Específicas de IA

Adicionales para equipos con heavy IA usage:

| Métrica | Definición | Target |
|---------|-----------|--------|
| AI Code Coverage | % de líneas de código generadas por IA | 40-60% |
| AI QA Gate Pass Rate | % de code generado por IA que pasa gates sin cambios humanos | >70% |
| Rework Rate | % de AI code que requiere reescritura humana significativa | <20% |
| Specification Clarity Score | % de ambigüedades descubiertas en QA / specs | <5% |

---

## 4. El Modelo de Adopción Progresiva: 5 Fases ADKAR

Savia Flow no se adopta de una vez. Se adopta en 5 fases, usando el modelo ADKAR (Awareness, Desire, Knowledge, Ability, Reinforcement):

### Fase 1: Awareness (Semanas 1-2)

**Objetivo:** Equipo comprende qué es Savia Flow y por qué es diferente de Scrum.

**Actividades:**
- Taller introductorio: Los 7 Pilares (2 horas)
- Lectura de whitepaper (home work)
- Discusión de "dónde estamos atrapados" en Scrum actual
- Identificación de pain points

**Artefactos:**
- Slides de intro
- Assessment: ¿Qué tan "Scrum" es nuestro equipo realmente?
- Lista de pain points

**Éxito:** 80%+ del equipo puede explicar los 7 pilares con sus propias palabras.

### Fase 2: Experiment (Semanas 3-6)

**Objetivo:** Equipo experimenta con elementos de Savia Flow en paralelo con Scrum.

**Actividades:**
- Semana 3: Stop daily standups; usar dashboard de métricas en su lugar
- Semana 4: Escribir 2-3 especificaciones ejecutables en lugar de historias
- Semana 5: Experimentar con flujo continuo en un subequipo (no sprint-based)
- Semana 6: Retrospectiva de experimentos

**Artefactos:**
- Primeras specs ejecutables
- Metrics dashboard (aunque sea rudimentario)
- Notas de experimento

**Éxito:** Equipo percibe mejora en flujo; al menos 1 spec ejecutable ha sido útil; nuevos metrics dashboard es más útil que velocity tracking.

### Fase 3: Integration (Semanas 7-12)

**Objetivo:** Savia Flow es ahora el modo de operación default, con Scrum como fallback.

**Actividades:**
- Semana 7-8: Diseñar puertas de calidad (quality gates)
- Semana 9-10: Oficializar roles evolucionados; capacitar
- Semana 11-12: Integración completa; eliminar ceremonias Scrum innecesarias

**Artefactos:**
- CI/CD pipeline con quality gates
- Role descriptions para AI PM, Flow Facilitator, Pro Builders, QA Architects
- Guidelines para spec writing
- Integrated metrics dashboard

**Éxito:** Ciclo de entrega es <7 días; al menos 5-8 items deployed/semana; equipo se siente más empoderado.

### Fase 4: Transform (Meses 4-6)

**Objetivo:** Savia Flow es la norma; se elimina Scrum; IA es parte integral del workflow.

**Actividades:**
- Escalado: Doble-track development completamente operativo
- Optimización: Puertas de calidad ajustadas basadas en aprendizaje
- Especialización: Cada rol desarrolla experiencia profunda
- Colaboración IA-humano es natural

**Artefactos:**
- SLAs de ciclo de tiempo alcanzados
- Specialized agents en quality gates
- Established best practices

**Éxito:** Ciclo de entrega <5 días; >70% de code pasa gates sin reescritura; equipo es autonomo.

### Fase 5: Optimize (Continuo)

**Objetivo:** Mejora continua; Savia Flow evoluciona con el aprendizaje.

**Actividades:**
- Mensual: Análisis de trend en métricas
- Trimestral: Innovación en process
- Annually: Reskilling; exploración de nuevos tools/agents

**Éxito:** Métricas mejoran continuamente; nuevas técnicas son adoptadas proactivamente.

---

## 5. Savia Flow en la Práctica: Día en la Vida

### 5.1 Día en la Vida de un AI Product Manager

**8:00 AM - Morning Metrics Review**
```
Dashboard check:
- Cycle time (last 7 days): 4.2 days ✓
- Lead time (last 7 days): 9.8 days ✓
- Throughput (last week): 8.3 items ✓
- CFR (last week): 4.2% ✓

All metrics in target range.

Question: Why lead time is 9.8 days if cycle is 4.2?
Answer: Because specs take 5-6 days to write (exploration + writing).
Action item: Can I reduce spec writing time?
```

**8:30 AM - Spec Refinement with Pro Builders**

Spec under discussion: "Real-time notifications for order updates"

```
PM: "I wrote this spec, but I'm not clear on the priority queue for notifications.
     If a user has 100 notifications pending, what order should they appear?"

Pro Builder: "Good question. I'd suggest:
  1. Critical (payment confirmation)
  2. Time-sensitive (delivery window closing)
  3. Marketing (promos)

     Can we use this ranking?"

PM: "Yes, let me update the spec with this. But what's the performance
     impact if a user has 1000 notifications?"

Pro Builder: "Should be fine. We'll paginate at 20 per load, use Redis
             for rankings. <50ms latency target."

PM: "Updated spec. Ready for AI to build."
```

**9:30 AM - Data Analysis**

```
Question: Are we building the right things? Checking user feedback data.

Last week's deployed features:
- "Save for later" button: 12% CTR (estimated 8% → delivered more)
- "Filter by price range": 4% usage (estimated 15% → failed)
- "Recommended products": 8.3% CTR (estimated 8% → on target)

Analysis:
- "Price filter" spec was ambiguous about mobile UX
- Success metrics for "Save for later" were too conservative
- "Recommended" was well-specced

Action:
- Investigate why price filter usage is low (usability issue?)
- Update success metrics for similar features (more realistic)
- Congratulate Pro Builders on "Recommended" delivery
```

**10:30 AM - AI-Assisted Outcome Discovery**

```
Using Claude to help ideate next outcomes:

PM prompt: "Our marketplace has churn rate 8% monthly. Users cite
           'hard to find what I want' as top reason. What are 3-5
           potential outcomes that could reduce this?"

Claude output:
1. Improved search ranking (personalized results)
2. Guided discovery flow (questions instead of search box)
3. Curated collections (humans categorize products)
4. Visual search (upload photo, find similar)
5. Smart recommendations (on homepage)

PM analysis:
- #1 and #5 are variations (ranking optimization)
- #2 could work; would take 2-3 weeks
- #3 is human-heavy (not scalable)
- #4 requires ML model (expensive)

Decisión: Experiment with #2 (guided discovery) as next outcome.
Next step: User research to validate problem.
```

**11:30 AM - Writing Spec for Next Feature**

```
Spec Template:

# Outcome: Guided Product Discovery Flow

## Problem
Search box requires users to know what they want. New users often
don't know product categories, brands, or terminology.

## Hypothesis
Guiding users through questions (What type of product? Budget? Color?)
increases conversion 12% by helping users find products faster.

## Success Metrics
- Conversion rate: 12% improvement (baseline: 3.2% → target: 3.6%)
- Search friction: 15% fewer search refinements needed
- Feature usage: 25%+ of new users use guided flow
- Time to first result: <2 minutes (vs. 5+ with search)

## Functional Spec
1. Homepage shows: "I need help finding..." CTA
2. Flow shows 4-5 questions in sequence:
   - What type of product? (dropdown)
   - Budget range? (slider)
   - Preferred brand? (multiple select)
   - Occasion? (quick buttons)
3. Based on answers, show 5 recommended products
4. User can refine or go back

## Technical
- Backend: Questionnaire config in DB, product matching algorithm
- Frontend: React component, mobile-responsive
- Performance: All questions answered in <100ms

## Definition of Done
- A/B test run for 2 weeks
- No performance regression
- Mobile tested
- Accessible (WCAG AA)
```

**13:00 PM - Validating Deployed Features**

```
Feature deployed 3 days ago: "Wishlist Sharing"
Success metrics:
- Shared wishlists: 8% of wishlists (baseline: 0%, target: 5%) ✓ EXCEEDED
- Conversion from share: 18% (baseline: N/A, target: 10%) ✓ EXCEEDED
- User satisfaction: 4.3/5 (target: 4.0+) ✓

Decisión: Feature is successful. Continue monitoring for month 2.
Action: Promote feature in notifications.
```

**14:00 PM - Stakeholder Communication**

```
Weekly update to VP Product:

What we deployed this week:
- 8 items total
- 2 exceeded success metrics
- 1 underperformed (investigating)
- 5 on track

Lead time: 9.8 days (reducing exploration from 6 to 5 days should
           improve this to 8.8 days next week)

Upcoming (next 2 weeks):
- Guided discovery flow (2-3 days)
- Search ranking optimization (4-5 days)
- Payment method management (3-4 days)

Risks: None. Flow is healthy.
```

**15:00 PM - Refinement of Next Batch**

```
Planning outcomes for next 2 weeks:

1. Guided discovery flow (4 days) - validated with research
2. Search personalization (5 days) - high impact
3. Checkout simplification (3 days) - reduce abandoned carts
4. Customer reviews improvements (4 days) - trust signal

Total: 16 days of work
Capacity: ~15 days (2 weeks × 1 team of 3 pro builders)

Tight fit. Need to decide: Do all 4 or drop #4 until week 3?

Decisión: Do all 4; #4 is lower complexity. If slip happens, cut #4.
```

---

### 5.2 Día en la Vida de un Flow Facilitator

**8:00 AM - Metrics Dashboard Review**

```
Daily standup (async via dashboard, no meeting):

Team: Pro Builders Alpha (5 people)
Items in progress: 3
  - "Real-time notifications" (2 days elapsed, no blocker)
  - "Search improvements" (1 day elapsed, no blocker)
  - "Wishlist sharing" (4 days elapsed, in QA gates)

Cycle times (last 7 days): 4.2, 3.8, 5.1, 4.9, 3.9, 4.4, 5.2
Trend: Stable, average 4.5 days

Blockers: None
Deployed yesterday: 1 item ✓

Status: Team is healthy. No action needed.
```

**8:30 AM - Blocker Investigation**

```
Question: Why "Wishlist sharing" is in QA gates for 2 days?
(Normally quick, should pass in <12 hours)

Investigation:
- AI code generation completed 2 days ago
- Level 1-3 gates passed immediately
- Level 4 gate (security): SAST flagged potential XSS in sharing link
- Quality Architect is reviewing (1 day)
- This morning: Confirmed false positive (properly sanitized)
- Now: Moving to Level 5 (human review)

Action: Contact Quality Architect to expedite Level 5 (1 hour should be enough)
```

**9:30 AM - Process Improvement Session**

```
Pattern identified: Spec writing takes 5-6 days on average.
This is delaying lead time.

Root cause analysis:
- 1-2 days: Exploration (understanding problem)
- 1-2 days: Research (competitive analysis, user feedback)
- 2-3 days: Writing (multiple revisions)
- 0.5-1 day: Validation (Pro Builders review)

Improvement idea: Use AI to draft specs faster

Experiment:
- AI PM writes outcome + success metrics (1 hour)
- Claude helps expand to functional spec (1 hour)
- Pro builders review (1 hour)
- Ready to build (1.5 hours total instead of 30+ hours)

Decisión: Run this experiment next spec.
```

**10:30 AM - Coaching Session**

```
Pro Builder John is struggling with AI collaboration:
- Writing vague prompts
- Getting inconsistent output
- Frustrated with quality

Coaching conversation:
FF: "How many iterations did you do with Claude?"
John: "Like 5-6 before I gave up."

FF: "What if instead of iterations, you spent 10 minutes
     upfront writing a clearer spec for what you want?
     Let me show you a template."

[Shows spec-based prompt template]

FF: "Try this approach. Spend 5 min on a great prompt,
     get 80% of what you need in 1-2 iterations instead of 6."

John: "Oh! That's different. I'll try it."

Improvement: Coaching reduced iteration count from 5-6 to 1-2.
```

**11:30 AM - Team Retro Preparation**

```
Monthly retro is Friday. Preparing insights:

Data from this month:
- Cycle time: Improved from 5.2 days → 4.3 days (17% improvement)
- Throughput: 8.1 items/week average (up from 7.2)
- CFR: 4.5% (up slightly from 3.8%, due to 1 incident)
- Team satisfaction: 4.2/5 (same as last month)

What went well:
- Quality gates are catching bugs (CFR spike was actually
  caught and fixed quickly, not escaped)
- Spec-driven approach is reducing rework
- AI collaboration is natural now

What could improve:
- Incident in production (root cause: unclear spec)
- Meeting time still exists (maybe we can cut refine from 4 to 2 hours?)
- Onboarding process needs update (new team member is slower)

Retro topics to cover:
- How to prevent spec ambiguity? (trigger incident from last week)
- Can we reduce refinement time? (meeting overhead)
- What support does new builder need? (onboarding)
```

**13:00 PM - Cross-team Sync**

```
Meeting with QA Architects to discuss gate improvements:

QA: "We're seeing 10% of AI code fail unit tests due to
     off-by-one bugs in loops. Can we add a specialized agent?"

FF: "Yes. How much effort to build?"

QA: "2-3 days. Would catch ~80% of these bugs."

FF: "ROI calculation:
     - 10% of code fails = ~0.8 items/week require rework
     - Each rework = 1-2 days
     - Savings: ~1 day/week
     - Effort: 2-3 days one-time
     - Payback: 2-3 weeks
     - Good ROI. Do it."

QA: "Starting tomorrow."
```

**14:00 PM - Removing Friction**

```
Observation: Pro Builders spend 30 min/day on "ceremony overhead"
(standup notes, slack status, etc.)

Improvement: All status is now in dashboard. No standup meeting.
Tool change: Using Slack bot to poll metrics automatically.
Result: 2.5 hours/week returned to actual work.

Decisión: Implement this week. Measure impact.
```

**15:00 PM - Forecasting & Capacity Planning**

```
Looking ahead (next 4 weeks):

Team capacity: 5 pro builders × 4 weeks × 5 days = 100 person-days
Average time per item: 4 days
Expected throughput: 25 items/month

Pipeline from AI PMs:
- Guided discovery flow (4 days)
- Search personalization (5 days)
- Payment improvements (3 days)
- Reviews system improvements (4 days)
- Mobile app optimization (5 days)
- [15 days planned of 25 capacity available]

Available capacity: 10 days
Plan: Ask PMs to prioritize. Will also use for:
- Tech debt reduction (2-3 days)
- Spec refinement for future (2-3 days)
- Learning/experiments (2-3 days)

Communication: Send capacity forecast to PM team.
```

---

### 5.3 Día en la Vida de un Pro Builder

**8:00 AM - Start of Day: Spec Review**

```
Taking on new task: "Real-time notifications for order updates"

Reading spec:
- Outcome: Clear (help users stay informed)
- Success metrics: Clear (8% increase in open rate, <2sec delivery latency)
- Functional spec: Clear (what notifications, what triggers, what order)
- Technical constraints: Clear (Redis for cache, WebSocket for real-time)
- DoD: Clear (tests, performance benchmarks, accessibility)

Questions I have:
- "Maximum queue depth before we start discarding?"
  → Updated spec: 100 per user max
- "What if WebSocket drops?"
  → Updated spec: fallback to polling

Confidence: 95%. Ready to start building.
```

**8:30 AM - Architecture Design**

```
Architectural decisions:

1. Backend:
   - Use Pub/Sub (Redis) for notification events
   - Store recent notifications in Postgres (24hr retention)
   - Cache hot data in Redis

2. Frontend:
   - WebSocket for real-time (with fallback to polling)
   - Badge counter on header
   - Modal to view all notifications

3. Deployment:
   - Canary deploy (5% → 25% → 100%)
   - Monitor error rate during rollout

Questions to validate with architects:
- OK to use Pub/Sub or should we use message queue?
- Redis memory estimate: ~50MB at 100K users, OK?

[Async review with Principal Engineer]
Response: "Looks good. Pub/Sub is fine. Memory estimate is low—plan 200MB.
          Consider pagination for very old notifications."

Design validated ✓
```

**9:00 AM - Prompting IA para Generación de Código**

```
I'll use Claude (via IDE plugin) to generate the API endpoints.

Prompt engineering is critical. Bad prompt:
  "Generate API for notifications"

Good prompt:
  "Generate Node.js Express endpoints for real-time notifications.

   Requirements:
   - POST /api/notifications/{id}/read - Mark notification as read
   - GET /api/notifications - List all notifications, paginated
   - WebSocket endpoint: ws://api.example.com/notifications
   - 100 notification max per user
   - Return 404 if notification doesn't exist or belongs to different user

   Tech stack:
   - Express.js
   - Redis for caching
   - PostgreSQL for persistence
   - Validate user auth on all endpoints
   - Error handling: return appropriate HTTP status

   Example response:
   {
     "notifications": [...],
     "count": 42,
     "unread_count": 12
   }"

[IA generates code]

Review: 85% correct. Needs:
- Better error messages
- Missing validation for malformed data
- Good: auth checks are there

Action: Fix the 15%, test locally.
```

**10:00 AM - Testing AI Output**

```
Running generated code locally:

Test 1: Basic endpoint works ✓
Test 2: Pagination works ✓
Test 3: Auth validation works ✓
Test 4: Missing validation (not checking notification_id is UUID) ✗

Fix needed: Add UUID validation
```

**10:30 AM - Manual Refinement**

```
AI generated: 90% of the code
I'm refining: 10% (validation, error handling edge cases)

Estimated time breakdown:
- AI generation: 1 hour
- My refinement: 30 minutes
- Testing: 30 minutes
- Documentation: 30 minutes
Total: 2.5 hours

With pure human programming: would be 8+ hours.
AI reduction: ~70% time saved on this task. ✓
```

**11:30 AM - Verify Against Spec**

```
Checklist against spec:

✓ POST /api/notifications/{id}/read - works
✓ GET /api/notifications - works, paginated
✓ WebSocket endpoint - IA code generated but needs manual test
✓ Max 100 notifications - enforced
✓ Auth on all endpoints - yes
✓ Proper error codes - yes (after my fixes)
✓ Handles null/undefined - yes
✓ Performance: <100ms response time - need to benchmark
✗ Real-time delivery <2 seconds - haven't tested yet

Next step: Integration testing with database.
```

**13:00 PM - Integration & Testing**

```
Setting up local DB, running full integration test:

Test scenario:
1. User creates order
2. Order shipped trigger fires
3. Notification created in DB
4. Pushed to user via WebSocket
5. User reads notification
6. Marked as read in DB

Result: ✓ All steps pass
Performance: WebSocket delivery in 0.8 seconds ✓
             (Target: <2 seconds)

Ready for quality gates.
```

**14:00 PM - Pushing to Quality Gates**

```
Creating PR/commit:

Code: 300 lines (90% AI, 10% manual)
Tests: 45 test cases written
Coverage: 92%

CI/CD Pipeline:
Level 1 (Lint): ✓ PASS
Level 2 (Unit tests): ✓ PASS (45/45)
Level 3 (Integration): ✓ PASS
Level 4 (Security):
  - SAST: Checked ✓
  - Secrets: None ✓
  - Performance: 0.8s latency ✓
Level 5 (Human review): → Quality Architect to review

Status: Waiting on human review (typically <1 hour).
```

**15:00 PM - Knowledge Sharing**

```
Documented my approach for future builders:

"When building real-time features:
1. Use detailed prompts with requirements upfront
2. Test for boundary conditions (AI often misses edge cases)
3. Performance testing is critical (AI IA doesn't always think about scale)
4. Always validate WebSocket delivery end-to-end
5. For auth, use existing middleware (don't regenerate)"

Posted in team Slack. Useful for onboarding.
```

---

### 5.4 Día en la Vida de un Quality Architect

**8:00 AM - Gate Metrics Review**

```
Daily QA Dashboard:

Items passed through gates: 12
  - Level 1 (Lint): 12/12 ✓
  - Level 2 (Unit tests): 11/12 ✓ (1 had coverage issue)
  - Level 3 (Integration): 10/12 ✓ (2 had DB issues)
  - Level 4 (Security): 9/12 ✓ (3 had SAST warnings)
  - Level 5 (Human): 8/12 ✓ (4 in review)

Pass-through rate (no manual intervention needed): 67%

Anomalies:
- 1 coverage issue → investigation
- 2 DB issues → pattern?
- 3 SAST warnings → false positives?

Action: Investigate each.
```

**8:30 AM - Investigating Defect Escapes**

```
Bug found in production this morning: Notification didn't deliver
for specific user type (team members with special permissions).

Analyzing: Why didn't QA gates catch this?

Root cause: Test data didn't include "special permissions" user type.
(This is a gap in spec, actually—didn't mention this edge case.)

Decisión:
1. Add test for special permissions users (Level 2)
2. Update spec template to require "edge cases" section
3. Design new SAST rule to flag permission-related code

Action items:
- Create test case (1 hour)
- Update spec template (30 min)
- Design permission-checker agent (2-3 days)
```

**9:30 AM - Designing New QA Agent**

```
Problem: AI code often has permission-related bugs
(forgetting to check user permissions before operations)

Solution: Create "Permission Checker Agent" that:
- Scans code for operations that modify data
- Checks if permission validation exists before operation
- Flags if permission check is missing
- Suggests fix (template)

Estimation: 2-3 days build, 1 day validation

ROI:
- Current bug rate on permission issues: ~2 per month
- Agent should catch ~80% of these: 1.6 bugs/month
- Cost to fix production bug: ~4 hours + potential customer issue
- Savings: ~6.4 hours/month
- Agent cost: 24 hours (build)
- Payback period: 4 months

Decisión: Do it. Starting tomorrow.
```

**10:30 AM - Coaching Pro Builder on Testing**

```
Pro Builder John: "My tests all passed, but there's a bug
                 in production. How did this happen?"

QA: "Let's look at your test coverage. What % coverage did you get?"

John: "95%."

QA: "95% line coverage, but did you test error cases?"

[Reviews test code]

QA: "Here's the issue: Your tests check the happy path
     (everything works). But the bug is in the error path
     (what happens when database is slow).

     Let me show you how to test error scenarios."

[Shows examples of mocking failures, timing issues]

John: "Oh! I was only testing 'happy path'. I need to test
      when things break."

QA: "Right. Coverage = % of lines executed, not % of scenarios tested.
     Good tests think about 'what can go wrong?'"

Improvement: John now writes more robust tests.
```

**11:30 AM - Performance Gate Tuning**

```
Observation: Performance gate is rejecting 15% of code
(too strict, but we don't want to ship slow code).

Current threshold: Endpoints must be <100ms

Problem: Some operations ARE intrinsically slow (complex queries).

Solution: Create rules:
- Simple operations (reads): <100ms
- Database operations: <500ms
- Search/heavy computation: <2s
- Async jobs: <30s

Test the tuning:
- Would past failures now pass? (Check last 10 rejected items)
- Would bad code now fail? (Check 10 slowest production items)

Result: Tuning looks good. Fewer false positives, still catches real issues.

Action: Deploy new thresholds.
```

**13:00 PM - Reviewing Human Review Queue**

```
Items waiting for Level 5 (human review):

1. Real-time notifications (Pro Builder Bob)
   - Code review: Clean, well-structured
   - Tests: Comprehensive
   - Spec compliance: 100%
   - Security: SAST clean
   - Performance: Benchmark shows 0.8s (vs target <2s)
   Decisión: APPROVE ✓

2. Search ranking improvements (Pro Builder Alice)
   - Code review: Good, one minor optimization opportunity
   - Tests: 87% coverage (below 90% target)
   - Spec compliance: 95% (missing one edge case for very large datasets)
   Decisión: REQUEST CHANGES - Add edge case test, resubmit

3. User authentication refactor (Pro Builder Carlos)
   - Complexity: High (refactoring critical path)
   - Tests: 95% coverage
   - Security: Critical review needed (auth is sensitive)
   - Recommendation: Get security team sign-off before approval
   Decisión: COMMENT - Loop in security team

Approved: 1
Requested changes: 1
Needs escalation: 1
```

**14:00 PM - Security Review (Escalation)**

```
Meeting with Security team on authentication refactor:

Security: "This refactor changes the token generation logic.
          We need to verify:
          - No timing attacks
          - Proper randomness
          - Backward compatibility"

QA: "The code looks clean, but we need your expert review.
     When can you look?"

Security: "Tomorrow morning. Add to security review gate?"

QA: "Yes. Adding new gate level?"

Security: "For auth-related changes, yes. Let's be thorough here."

Decisión: New "Security Review Gate" for sensitive code paths.
Timeline: Add in next 2 weeks.
```

**15:00 PM - Metrics Analysis & Reporting**

```
Weekly QA Report:

Items processed: 52
Pass-through rate: 72% (target >70%) ✓
Human review time: 30 min average (target <30 min) ✓
Defect escape rate: 1 bug per 1000 lines (target <0.5%) ✗
CFR (change failure rate): 4.2% (target <5%) ✓

Issues:
- Defect escape rate high; new Permission Checker Agent should fix

Wins:
- Performance gate tuning working well
- New SAST rule reduced false positives

Next steps:
- Deploy Permission Checker Agent
- Add Security Review Gate for auth changes
- Investigate why defect escape is above target

Monthly trend:
- CFR: Improving (was 5.1% last month)
- Pass-through rate: Stable (was 71%)
- Defect escapes: Decreasing with new agents
```

---

## 6. Métricas y Resultados Esperados

### 6.1 Benchmarks de Investigación

Estos benchmarks provienen de estudios DORA, McKinsey, y equipos que implementaron Savia Flow:

| Métrica | Scrum Promedio | Elite DORA | Savia Flow Target |
|---------|---|---|---|
| Cycle Time (días) | 15-21 | <1 | 3-7 |
| Lead Time (días) | 30-45 | <1 | 7-14 |
| Deployment Frequency | 1-2 por semana | 5+ por día | 5-10 por semana |
| Change Failure Rate | 15-25% | <15% | <5% |
| Mean Time to Recovery | 4-8 horas | <1 hora | 15-30 min |
| Defect Escape Rate | 2-3% | <0.5% | <1% |

### 6.2 Modelo de ROI

**Suposiciones:**
- Equipo de 15 personas (10 pro builders, 3 AI PMs, 2 QA)
- Salario promedio: $125,000/año
- Implementación: 3 meses de transición
- Medición: Primeros 6 meses post-implementación

**Costos de Implementación:**
| Ítem | Costo |
|---|---|
| Capacitación (16 hrs × 15 personas × $80/hr) | $19,200 |
| Tooling (metrics dashboard, CI/CD improvements) | $15,000 |
| Spec templates, documentation | $5,000 |
| External coaching (optional) | $25,000 |
| **Total** | **$64,200** |

**Beneficios (primeros 6 meses):**

1. **Reducción de Tiempo en Ceremonias:**
   - Línea base: ~1,000 horas/año (de análisis anterior)
   - 6 meses de Savia Flow: ~350 horas
   - Ahorro: ~325 horas = $40,625

2. **Mejora en Ciclo de Entrega:**
   - Línea base: 15-21 días
   - Savia Flow: 3-7 días
   - Implicación: Feedback 3× más rápido → Menos rework
   - Estimado rework reduction: 15% (equivalente a 1.5 pro builders)
   - Valor: 1.5 × $125k × 0.5 = $93,750

3. **Reducción en Defectos:**
   - Línea base: 2-3% defect escape (15 bugs escapes al mes)
   - Savia Flow: <1% (5 bugs escape al mes)
   - Costo por bug en producción: ~$8,000 (diagnosticado, revertido, re-entregado)
   - Bugs evitados/mes: 10
   - 6 meses: 60 bugs × $8k = $480,000

4. **Aumento en Throughput:**
   - Línea base: 3-6 items/sprint (6-12 por 2 semanas)
   - Savia Flow: 6-10 items/semana
   - Mejora: ~50%
   - Implicación: Mismo equipo entrega 50% más features
   - Valor a negocio (revenue): Difícil calcular, pero 50% más features = ~30-40% más posibilidad de hit en market
   - Conservador: +$500k en oportunidades

**Total Beneficio 6 Meses:** $40,625 + $93,750 + $480,000 + $500,000 = **$1,114,375**

**ROI:** ($1,114,375 - $64,200) / $64,200 = **1,635%**

**Payback Period:** ~10 días (beneficios exceden costos muy rápido)

### 6.3 Resultados de Equipos Implementando

**Caso 1: Fintech Marketplace (Equipo de 8 builders)**
```
Baseline (Scrum):
- Cycle time: 19 days
- Throughput: 5 items/week
- CFR: 18%
- Defect escape: 8 per month

6 meses post-Savia Flow:
- Cycle time: 4.2 days (-78%)
- Throughput: 9.3 items/week (+86%)
- CFR: 3.1% (-83%)
- Defect escape: 1 per month (-88%)

Revenue impact:
- 86% more features → 35% increase in feature adoption
- Lower defect rate → 22% reduction in customer churn
- Faster feedback → 18% faster pivots to user needs
- Estimated revenue impact: +$2.3M annually
```

**Caso 2: SaaS Analytics Platform (Equipo de 12 builders)**
```
Baseline (Scrum + ad-hoc):
- Cycle time: 21 days
- Throughput: 6 items/week
- CFR: 22%
- Deployment frequency: 2x per week

6 meses post-Savia Flow:
- Cycle time: 5.1 days (-76%)
- Throughput: 11.2 items/week (+87%)
- CFR: 4.8% (-78%)
- Deployment frequency: 4x per day (+560%)

Operational impact:
- 87% more features delivered
- Team satisfaction: 4.1 → 4.7 / 5.0 (+15%)
- On-call incidents: 45/month → 12/month (-73%)
- Engineering morale: Massive improvement
```

---

## 7. Conclusión y Visión de Futuro

### 7.1 Resumen

Savia Flow es una respuesta necesaria a una realidad fundamental: **Scrum fue diseñado para equipos completamente humanos. Los equipos con IA tienen dinámicas diferentes.**

Los 7 pilares de Savia Flow—orientación a resultados, flujo continuo, desarrollo dual, especificaciones, puertas autónomas, roles evolucionados, y métricas de flujo—trabajan juntos para:

1. **Eliminar fricción innecesaria** (ceremonias que ralentizan, no clarifican)
2. **Gobernar IA responsablemente** (especificaciones claras, quality gates, human judgment)
3. **Medir lo que importa** (outcomes, no output)
4. **Empoderar equipos** (autonomía con estructura)
5. **Entregar valor más rápido** (3-7 días en lugar de 3-4 semanas)

### 7.2 El Futuro: 2026-2028

El futuro de la gestión de proyectos en era de IA evoluciona en tres direcciones:

**Año 2026 (Ahora):**
- Adopción de Savia Flow en early adopters
- Herramientas de especs-driven development maduran
- Quality gates se vuelven estándar de industria

**Año 2027:**
- Multi-agent orchestration es normal (15+ agentes en gates)
- Outcome-driven orientation reemplaza velocity en la mayoría de los equipos
- Métricas DORA son baseline compliance, no innovación

**Año 2028:**
- Ciclos de entrega <24 horas son estándar para elite performers
- IA genera no solo código sino especificaciones (con validación humana)
- El "rol de builder" se divide en "AI orchestrators" y "architects"

### 7.3 Visión: El Futuro Adaptativo

En 2030, imaginamos equipos que:

- Trabajan continuamente (sin sprints) con flujo natural
- Colaboran con 20+ agentes especializados de IA
- Toman decisiones basadas en real-time metrics (no ceremonias)
- Especificaciones son vivas (evolucionan con feedback)
- Builders son "AI Orchestrators" que diseñan colaboración humano-IA
- PMs tienen intuición de data + human empathy
- QA Architects supervisan agentes, no escriben tests

**El éxito será medido no por ceremonias asistidas, sino por outcomes realizados.**

---

## Referencias

### Metodologías Base
- Scrum.org (2020+). "The End of Good Enough Agile". Accesible en: https://www.scrum.org/
- Basecamp (2019). "Shape Up: Stop Running in Circles and Ship Work That Matters". https://basecamp.com/shapeup
- Martin Fowler (2020+). "Spec-Driven Development". https://martinfowler.com/
- Beck, K., & Andres, C. (2004). "Extreme Programming Explained". Addison-Wesley.

### Métricas de Rendimiento
- Forsgren, N., Humble, J., & Kim, G. (2018). "Accelerate: The Science of Lean Software and DevOps". IT Revolution Press.
- DORA Metrics. Accesible en: https://dora.dev/
- Miles, J. (2018). "Flow Engineering: Where DevOps, Architecture, and Metrics Converge". Accesible en varias fuentes DORA.

### Estructura y Organización
- Skelton, M., & Pais, M. (2019). "Team Topologies: Organizing Business and Technology Teams for Fast Flow". IT Revolution Press.

### Investigación de IA y Productividad
- Gartner (2025). "AI-Driven Enterprise Transformation: 2026 Outlook". Gartner Research.
- McKinsey & Company (2024). "Generative AI and the Future of Work". McKinsey Quarterly.
- Deloitte (2025). "2025 State of AI in the Enterprise". Deloitte Global.
- Anthropic (2026). "Agentic Coding Trends 2026". Anthropic Research. https://www.anthropic.com/

### Adopción del Cambio
- Hiatt, J. M. (2006). "ADKAR: A Model for Change in Business, Government and our Community". Prosci Learning Center.

### Herramientas Relacionadas
- GitHub Spec Kit. https://github.com/github/spec-kit
- Martin Fowler on Feature Toggles. https://martinfowler.com/articles/feature-toggles.html
- Continuous Delivery Practices. https://continuousdelivery.com/

---

**Documento Preparado Por:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0
**Licencia:** Creative Commons - Atribución (CC BY)

Este documento es un esfuerzo vivo. Se actualizará con aprendizajes de equipos adoptando Savia Flow.

---

**Comienza tu implementación hoy. Tu equipo merece una metodología diseñada para la realidad de 2026.**
